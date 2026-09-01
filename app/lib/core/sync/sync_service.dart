import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/database.dart';

enum SyncState { idle, syncing, offline, error }

class SyncStatus {
  const SyncStatus(this.state, {this.message, this.lastSync});
  final SyncState state;
  final String? message;
  final DateTime? lastSync;
}

/// Jembatan antara database lokal dan Supabase.
///
/// Aturannya satu arah dan sederhana:
///   - dorong dulu perubahan lokal yang mengantre,
///   - baru tarik perubahan dari server,
///   - baris yang masih punya perubahan lokal tidak ditimpa data server.
class SyncService {
  SyncService(this._db, this._client);

  final AppDatabase _db;
  final SupabaseClient _client;

  static const _kLastPull = 'last_pull_at';

  final _statusCtrl = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get status => _statusCtrl.stream;

  StreamSubscription<List<ConnectivityResult>>? _connSub;
  Timer? _timer;
  bool _running = false;

  /// Sinkron saat sinyal kembali, dan berkala tiap 5 menit sebagai jaring
  /// pengaman kalau perubahan konektivitas tidak terdeteksi.
  void start() {
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) syncNow();
    });
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => syncNow());
    syncNow();
  }

  void dispose() {
    _connSub?.cancel();
    _timer?.cancel();
    _statusCtrl.close();
  }

  Future<void> syncNow() async {
    if (_running) return;
    _running = true;
    _statusCtrl.add(const SyncStatus(SyncState.syncing));

    try {
      final conn = await Connectivity().checkConnectivity();
      if (conn.every((r) => r == ConnectivityResult.none)) {
        _statusCtrl.add(const SyncStatus(SyncState.offline));
        return;
      }

      await _pushClaims();
      await _pushParts();
      await _pullMasterData();
      await _pullClaims();

      _statusCtrl.add(SyncStatus(SyncState.idle, lastSync: DateTime.now()));
    } catch (e) {
      _statusCtrl.add(SyncStatus(SyncState.error, message: e.toString()));
    } finally {
      _running = false;
    }
  }

  // ------------------------------------------------------------------
  // Dorong ke server
  // ------------------------------------------------------------------

  Future<void> _pushClaims() async {
    for (final c in await _db.pendingClaims()) {
      try {
        await _client.from('claims').insert(_claimToRow(c));
      } on PostgrestException catch (e) {
        // 23505 = baris sudah ada di server, berarti ini perubahan bukan
        // klaim baru. Kirim hanya kolom yang memang bisa berubah setelah
        // klaim dibuat, supaya tidak bentrok dengan aturan di server yang
        // melarang teknisi menyentuh kolom lain.
        if (e.code == '23505') {
          await _client.from('claims').update({
            'teknisi_id': c.teknisiId,
            'status': c.status,
            'catatan': c.catatan,
          }).eq('id', c.id);
        } else {
          rethrow;
        }
      }
      await _db.markClaimSynced(c.id);
    }
  }

  Future<void> _pushParts() async {
    for (final p in await _db.pendingParts()) {
      try {
        await _client.from('claim_parts').insert({
          'id': p.id,
          'claim_id': p.claimId,
          'part_type_id': p.partTypeId,
          'sn_bad_part': p.snBadPart,
        });
      } on PostgrestException catch (e) {
        if (e.code != '23505') rethrow;
      }
      await _db.markPartSynced(p.id);
    }
  }

  // ------------------------------------------------------------------
  // Tarik dari server
  // ------------------------------------------------------------------

  Future<void> _pullMasterData() async {
    final brandRows = await _client.from('brands').select();
    for (final r in brandRows) {
      await _db.into(_db.brands).insertOnConflictUpdate(
            BrandsCompanion.insert(
              id: Value(r['id'] as int),
              nama: r['nama'] as String,
              aktif: Value(r['aktif'] as bool? ?? true),
            ),
          );
    }

    final partRows = await _client.from('part_types').select();
    for (final r in partRows) {
      await _db.into(_db.partTypes).insertOnConflictUpdate(
            PartTypesCompanion.insert(
              id: Value(r['id'] as int),
              kode: r['kode'] as String,
              nama: r['nama'] as String,
              aktif: Value(r['aktif'] as bool? ?? true),
            ),
          );
    }

    final profileRows = await _client.from('profiles').select();
    for (final r in profileRows) {
      await _db.into(_db.profiles).insertOnConflictUpdate(
            ProfilesCompanion.insert(
              id: r['id'] as String,
              nama: r['nama'] as String,
              role: r['role'] as String,
              aktif: Value(r['aktif'] as bool? ?? true),
            ),
          );
    }
  }

  Future<void> _pullClaims() async {
    final since = await _db.getMeta(_kLastPull);
    var query = _client.from('claims').select();
    if (since != null) query = query.gt('updated_at', since);

    final rows = await query;
    var newest = since != null ? DateTime.parse(since) : null;

    for (final r in rows) {
      final id = r['id'] as String;

      // Jangan timpa baris yang perubahannya belum sempat terkirim.
      if (await _db.hasPendingChange(id)) continue;

      final updatedAt = DateTime.parse(r['updated_at'] as String);
      if (newest == null || updatedAt.isAfter(newest)) newest = updatedAt;

      await _db.upsertClaimLocal(
        ClaimsCompanion.insert(
          id: id,
          tanggal: DateTime.parse(r['tanggal'] as String).toLocal(),
          brandId: r['brand_id'] as int,
          namaPelanggan: r['nama_pelanggan'] as String,
          telp: Value(r['telp'] as String?),
          sn: r['sn'] as String,
          teknisiId: Value(r['teknisi_id'] as String?),
          keluhan: Value(r['keluhan'] as String?),
          noPerbaikan: Value(r['no_perbaikan'] as String?),
          status: Value(r['status'] as String),
          catatan: Value(r['catatan'] as String?),
          createdBy: r['created_by'] as String,
          createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
          updatedAt: updatedAt.toLocal(),
        ),
      );

      final partRows =
          await _client.from('claim_parts').select().eq('claim_id', id);
      for (final p in partRows) {
        await _db.upsertPartLocal(
          ClaimPartsCompanion.insert(
            id: p['id'] as String,
            claimId: id,
            partTypeId: p['part_type_id'] as int,
            snBadPart: Value(p['sn_bad_part'] as String?),
          ),
        );
      }
    }

    if (newest != null) {
      await _db.setMeta(_kLastPull, newest.toUtc().toIso8601String());
    }
  }

  Map<String, dynamic> _claimToRow(Claim c) => {
        'id': c.id,
        'tanggal': c.tanggal.toUtc().toIso8601String(),
        'brand_id': c.brandId,
        'nama_pelanggan': c.namaPelanggan,
        'telp': c.telp,
        'sn': c.sn,
        'teknisi_id': c.teknisiId,
        'keluhan': c.keluhan,
        'no_perbaikan': c.noPerbaikan,
        'status': c.status,
        'catatan': c.catatan,
        'created_by': c.createdBy,
      };
}
