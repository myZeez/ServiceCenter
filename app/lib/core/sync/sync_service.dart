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
      await _pullAdministrasi();

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

  /// Apakah pengguna yang sedang login berperan admin.
  ///
  /// Menentukan seberapa banyak kolom yang boleh ikut terkirim. Server tetap
  /// menegakkan aturannya sendiri; ini hanya mencegah permintaan yang sudah
  /// pasti akan ditolak.
  Future<bool> _isAdmin() async {
    final id = _client.auth.currentUser?.id;
    if (id == null) return false;
    final profile = await _db.profileById(id);
    return profile?.role == 'admin';
  }

  Future<void> _pushClaims() async {
    final pending = await _db.pendingClaims();
    if (pending.isEmpty) return;

    final admin = await _isAdmin();

    for (final c in pending) {
      try {
        await _client.from('claims').insert(_claimToRow(c));
      } on PostgrestException catch (e) {
        // 23505 = baris sudah ada di server, jadi ini penyuntingan, bukan
        // klaim baru.
        if (e.code != '23505') rethrow;

        // Admin boleh mengubah seluruh isi klaim. Teknisi hanya kolom
        // teknisi -- mengirim kolom lain akan ditolak trigger di server,
        // dan nilainya bisa saja sudah usang di perangkat ini.
        final changes = admin
            ? _claimToRow(c)
            : {'teknisi_id': c.teknisiId};

        await _client.from('claims').update(changes).eq('id', c.id);
      }
      await _db.markClaimSynced(c.id);
    }
  }

  Future<void> _pushParts() async {
    for (final p in await _db.pendingParts()) {
      if (p.pendingDelete) {
        await _client.from('claim_parts').delete().eq('id', p.id);
        // Baru dibuang dari perangkat setelah server mengonfirmasi.
        await _db.deletePartLocal(p.id);
        continue;
      }

      await _client.from('claim_parts').upsert({
        'id': p.id,
        'claim_id': p.claimId,
        'part_type_id': p.partTypeId,
        'sn_bad_part': p.snBadPart,
      });
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

    // Data bagi hasil. Aturan akses di server yang menentukan siapa
    // menerima apa: teknisi menarik nol baris, jadi angka fee tidak pernah
    // sampai ke perangkat mereka.
    final feeRows = await _client.from('brand_fees').select();
    await _db.replaceBrandFees([
      for (final r in feeRows)
        BrandFeeEntriesCompanion.insert(
          id: Value(r['id'] as int),
          brandId: r['brand_id'] as int,
          fee: (r['fee'] as num).toDouble(),
          berlakuDari: DateTime.parse(r['berlaku_dari'] as String),
        ),
    ]);

    final configRows =
        await _client.from('revenue_settings').select().eq('id', 1);
    for (final r in configRows) {
      await _db.upsertRevenueConfig(
        RevenueConfigsCompanion.insert(
          id: Value(r['id'] as int),
          persenToko: (r['persen_toko'] as num).toDouble(),
          persenAdmin: (r['persen_admin'] as num).toDouble(),
          persenTeknisi: (r['persen_teknisi'] as num).toDouble(),
          metodeTeknisi: r['metode_teknisi'] as String,
        ),
      );
    }

    final shareRows = await _client.from('brand_technician_shares').select();
    await _db.replaceBrandShares([
      for (final r in shareRows)
        BrandShareEntriesCompanion.insert(
          brandId: r['brand_id'] as int,
          profileId: r['profile_id'] as String,
          persen: (r['persen'] as num).toDouble(),
        ),
    ]);

    final ruleRows = await _client.from('brand_revenue_rules').select();
    await _db.replaceBrandRules([
      for (final r in ruleRows)
        BrandRuleEntriesCompanion.insert(
          // Kunci utama bertipe integer diperlakukan drift sebagai opsional.
          brandId: Value(r['brand_id'] as int),
          persenToko: (r['persen_toko'] as num).toDouble(),
          persenAdmin: (r['persen_admin'] as num).toDouble(),
          persenTeknisi: (r['persen_teknisi'] as num).toDouble(),
        ),
    ]);

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
        // Part yang perubahannya belum terkirim tidak boleh ditimpa -- kalau
        // tidak, part yang baru ditandai hapus akan hidup lagi.
        if (await _db.hasPendingPart(p['id'] as String)) continue;

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

  /// Nota servis dan pengiriman. Cerminan baca saja -- penulisannya
  /// langsung ke server, jadi tidak ada antrean yang perlu didorong.
  ///
  /// Teknisi menarik nol baris karena aturan akses di server membatasinya
  /// ke admin; angka biaya dan piutang tidak pernah sampai ke perangkat
  /// mereka.
  Future<void> _pullAdministrasi() async {
    const kunciNota = 'last_pull_nota';
    const kunciKirim = 'last_pull_kirim';

    final sejakNota = await _db.getMeta(kunciNota);
    var qNota = _client.from('service_orders').select();
    if (sejakNota != null) qNota = qNota.gt('updated_at', sejakNota);

    DateTime? terbaruNota =
        sejakNota != null ? DateTime.parse(sejakNota) : null;

    for (final r in await qNota) {
      final diubah = DateTime.parse(r['updated_at'] as String);
      if (terbaruNota == null || diubah.isAfter(terbaruNota)) {
        terbaruNota = diubah;
      }

      await _db.upsertServiceOrder(
        ServiceOrderEntriesCompanion.insert(
          id: r['id'] as String,
          noNota: r['no_nota'] as String,
          tanggalMasuk: DateTime.parse(r['tanggal_masuk'] as String).toLocal(),
          estimasiSelesai: Value(_tanggal(r['estimasi_selesai'])),
          customerNama: r['customer_nama'] as String,
          customerTelp: Value(r['customer_telp'] as String?),
          operatorId: Value(r['operator_id'] as String?),
          barangNama: r['barang_nama'] as String,
          barangType: Value(r['barang_type'] as String?),
          barangSn: Value(r['barang_sn'] as String?),
          kelengkapan: Value(r['kelengkapan'] as String?),
          keluhan: Value(r['keluhan'] as String?),
          teknisiId: Value(r['teknisi_id'] as String?),
          perbaikan: Value(r['perbaikan'] as String?),
          garansi: Value(r['garansi'] as bool? ?? false),
          claimId: Value(r['claim_id'] as String?),
          status: r['status'] as String,
          biaya: Value((r['biaya'] as num?)?.toDouble() ?? 0),
          caraBayar: Value(r['cara_bayar'] as String?),
          tanggalLunas: Value(_tanggal(r['tanggal_lunas'])),
          keterangan: Value(r['keterangan'] as String?),
          updatedAt: diubah.toLocal(),
        ),
      );
    }
    if (terbaruNota != null) {
      await _db.setMeta(kunciNota, terbaruNota.toUtc().toIso8601String());
    }

    final sejakKirim = await _db.getMeta(kunciKirim);
    var qKirim = _client.from('shipments').select();
    if (sejakKirim != null) qKirim = qKirim.gt('updated_at', sejakKirim);

    DateTime? terbaruKirim =
        sejakKirim != null ? DateTime.parse(sejakKirim) : null;

    for (final r in await qKirim) {
      final diubah = DateTime.parse(r['updated_at'] as String);
      if (terbaruKirim == null || diubah.isAfter(terbaruKirim)) {
        terbaruKirim = diubah;
      }

      await _db.upsertShipment(
        ShipmentEntriesCompanion.insert(
          id: r['id'] as String,
          tanggalKirim: _tanggal(r['tanggal_kirim'])!,
          dariCabang: r['dari_cabang'] as String,
          keCabang: r['ke_cabang'] as String,
          userNama: Value(r['user_nama'] as String?),
          barangNama: r['barang_nama'] as String,
          serialNumber: Value(r['serial_number'] as String?),
          keluhan: Value(r['keluhan'] as String?),
          kelengkapan: Value(r['kelengkapan'] as String?),
          status: r['status'] as String,
          tanggalKembali: Value(_tanggal(r['tanggal_kembali'])),
          keterangan: Value(r['keterangan'] as String?),
          updatedAt: diubah.toLocal(),
        ),
      );
    }
    if (terbaruKirim != null) {
      await _db.setMeta(kunciKirim, terbaruKirim.toUtc().toIso8601String());
    }
  }

  static DateTime? _tanggal(Object? v) =>
      v == null ? null : DateTime.parse(v as String);

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
