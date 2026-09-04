import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';
import 'siklus.dart';

/// Satu-satunya tempat data tinggal.
///
/// Dulu aplikasi menyimpan cerminannya sendiri di SQLite dan menyalin isi
/// server setiap beberapa menit. Cerminan itu tidak pernah bisa membuang
/// baris: sinkronisasinya hanya menanyakan apa yang berubah, dan baris yang
/// dihapus di server tidak muncul dalam jawaban apa pun. Akibatnya admin
/// menghapus sebuah nota, teknisi masih melihatnya, dan tidak ada yang bisa
/// menjelaskan mana yang benar.
///
/// Sekarang tiap layar berlangganan langsung ke Postgres lewat Realtime.
/// Tambah, ubah, dan hapus sampai ke semua perangkat dalam hitungan detik,
/// dan hanya ada satu kenyataan.
///
/// Konsekuensinya jujur: tanpa koneksi, aplikasi tidak bisa dipakai.
class Db {
  Db(this._c);

  final SupabaseClient _c;

  /// Selang penarikan ulang berkala.
  ///
  /// Berjalan berdampingan dengan Realtime, bukan sebagai gantinya. Inilah
  /// yang menyembuhkan keadaan paling menipu: langganan yang tersambung
  /// lalu diam. Websocket yang putus saat HP ditidurkan, atau tabel yang
  /// belum terdaftar di publikasi Realtime, tidak melempar galat apa pun --
  /// alirannya hanya berhenti mengirim, dan layar membeku pada tarikan
  /// pertama tanpa satu pun tanda bahwa ada yang salah.
  static const _jedaSegar = Duration(seconds: 90);

  /// Seluruh isi tabel, diperbarui sendiri saat ada perubahan di server.
  ///
  /// Sengaja tidak disaring di sisi server. Satu langganan per tabel jauh
  /// lebih hemat daripada satu langganan per kombinasi filter, dan tabel di
  /// sini semuanya kecil. Penyaringan dan pengurutan dikerjakan di Dart oleh
  /// yang memakainya.
  ///
  /// Tiga sumber mengisi aliran ini: satu tarikan awal supaya layar segera
  /// terisi, kabar Realtime supaya perubahan tampak seketika, dan penarikan
  /// berkala supaya keadaan selalu kembali benar dengan sendirinya.
  ///
  /// Penarikan berkala mengganti seluruh daftar, bukan menambahinya, jadi
  /// baris yang dihapus di server tetap hilang di layar -- lebih lambat
  /// daripada Realtime, tetapi tidak pernah salah.
  ///
  /// Galat hanya diteruskan bila tarikan pertama gagal. Sesudah ada isi di
  /// layar, gangguan jaringan ditelan diam-diam: keadaan terakhir yang
  /// benar jauh lebih berguna daripada layar galat, dan penarikan
  /// berikutnya akan membetulkannya sendiri.
  Stream<List<T>> _semua<T>(
    String tabel,
    T Function(Map<String, dynamic>) bentuk, {
    List<String> kunci = const ['id'],
  }) {
    List<T> olah(List<Map<String, dynamic>> rows) => rows.map(bentuk).toList();
    Future<List<T>> tarik() async => olah(await _c.from(tabel).select());

    final keluar = StreamController<List<T>>();
    StreamSubscription<List<Map<String, dynamic>>>? langganan;
    Timer? jam;
    var hidup = false;
    var pernahTerisi = false;

    Future<void> segarkan() async {
      if (!hidup) return;
      try {
        final isi = await tarik();
        if (!hidup) return;
        pernahTerisi = true;
        keluar.add(isi);
      } catch (e, s) {
        if (!hidup) return;
        if (!pernahTerisi) keluar.addError(e, s);
      }
    }

    keluar.onListen = () {
      hidup = true;
      segarkan();

      jam = Timer.periodic(_jedaSegar, (_) {
        // Aplikasi yang tergeletak di saku tidak perlu menarik apa pun.
        if (Siklus.aktif) segarkan();
      });

      langganan = _c
          .from(tabel)
          .stream(primaryKey: kunci)
          .listen(
            (rows) {
              if (!hidup) return;
              // Kedatangan dicatat, bukan hanya kegagalan. Langganan ke
              // tabel yang tidak terdaftar di publikasi tetap terpasang
              // tanpa protes -- ia hanya tidak pernah mengirim apa pun, dan
              // tanpa catatan ini keadaan itu tidak bisa dibedakan dari
              // server yang memang sedang sepi.
              debugPrint('[realtime] $tabel: ${rows.length} baris');
              pernahTerisi = true;
              keluar.add(olah(rows));
            },
            // Tidak diteruskan ke layar dengan sengaja: langganan yang
            // gagal bukan alasan mengosongkan halaman, karena penarikan
            // berkala tetap menjaga isinya benar. Tetapi dicatat -- galat
            // yang ditelan tanpa sisa membuat penyebabnya tidak bisa
            // diperiksa siapa pun kemudian.
            onError: (Object e) =>
                debugPrint('[realtime] langganan $tabel gagal: $e'),
          );
    };

    keluar.onCancel = () async {
      hidup = false;
      jam?.cancel();
      await langganan?.cancel();
    };

    return keluar.stream;
  }

  // ------------------------------------------------------------------
  // Master
  // ------------------------------------------------------------------

  Stream<List<Brand>> watchAllBrands() => _semua('brands', Brand.fromMap)
      .map((l) => l..sort((a, b) => a.nama.compareTo(b.nama)));

  Stream<List<PartType>> watchAllPartTypes() =>
      _semua('part_types', PartType.fromMap)
          .map((l) => l..sort((a, b) => a.nama.compareTo(b.nama)));

  Stream<List<Profile>> watchAllProfiles() =>
      _semua('profiles', Profile.fromMap)
          .map((l) => l..sort((a, b) => a.nama.compareTo(b.nama)));

  Future<List<Profile>> allProfiles() async {
    final rows = await _c.from('profiles').select();
    return [for (final r in rows) Profile.fromMap(r)];
  }

  // ------------------------------------------------------------------
  // Klaim garansi
  // ------------------------------------------------------------------

  Stream<List<Claim>> watchClaims() => _semua('claims', Claim.fromMap)
      .map((l) => l..sort((a, b) => b.tanggal.compareTo(a.tanggal)));

  Stream<List<ClaimPart>> watchParts() =>
      _semua('claim_parts', ClaimPart.fromMap);

  Future<List<ClaimPart>> partsOf(String claimId) async {
    final rows = await _c
        .from('claim_parts')
        .select()
        .eq('claim_id', claimId);
    return [for (final r in rows) ClaimPart.fromMap(r)];
  }

  /// Upsert, bukan insert. Id klaim dibuat di aplikasi, dan penyimpanan
  /// yang gagal separuh jalan akan diulang dengan id yang sama; kalau ini
  /// insert, percobaan kedua ditolak sebagai id kembar padahal maksudnya
  /// justru melanjutkan yang tadi.
  ///
  /// Aman terhadap penyalahgunaan: upsert yang jatuh menjadi update tetap
  /// melewati trigger di server, yang hanya mengizinkan teknisi menyentuh
  /// kolom teknisi.
  Future<void> simpanClaim(Map<String, dynamic> baris) =>
      _pastikan(_c.from('claims').upsert(baris).select('id'), 'klaim');

  Future<void> ubahClaim(String id, Map<String, dynamic> perubahan) => _pastikan(
    _c.from('claims').update(perubahan).eq('id', id).select('id'),
    'klaim',
  );

  /// Mengganti teknisi yang mengerjakan. Ini satu-satunya perubahan yang
  /// boleh dilakukan teknisi terhadap klaim yang sudah ada -- kolom lain
  /// ditolak trigger di server.
  Future<void> gantiTeknisi(String claimId, String teknisiId) =>
      ubahClaim(claimId, {'teknisi_id': teknisiId});

  Future<void> gantiStatus(String claimId, String status) =>
      ubahClaim(claimId, {'status': status});

  Future<void> simpanPart(Map<String, dynamic> baris) =>
      _pastikan(_c.from('claim_parts').upsert(baris).select('id'), 'part');

  Future<void> hapusPart(String id) => _pastikan(
    _c.from('claim_parts').delete().eq('id', id).select('id'),
    'part',
  );

  /// Memastikan penulisannya benar-benar mengenai sebuah baris.
  ///
  /// Ini penjagaan yang paling penting di berkas ini. Postgres menganggap
  /// UPDATE dan DELETE yang tidak cocok dengan satu baris pun sebagai
  /// berhasil -- tidak ada galat, tidak ada apa pun. Aturan akses yang
  /// menyaring barisnya keluar menghasilkan persis keadaan itu, dan tanpa
  /// pemeriksaan ini aplikasi akan berkata "tersimpan" atas perubahan yang
  /// tidak pernah terjadi.
  ///
  /// Menambahkan .select() membuat server mengembalikan baris yang benar-
  /// benar tersentuh, jadi kosong berarti tidak ada yang berubah.
  Future<void> _pastikan(
    PostgrestTransformBuilder<PostgrestList> permintaan,
    String apa,
  ) => pastikanTulis(permintaan, apa, _c);

  // ------------------------------------------------------------------
  // Administrasi servis
  // ------------------------------------------------------------------

  Stream<List<ServiceOrderEntry>> watchServiceOrders() =>
      _semua('service_orders', ServiceOrderEntry.fromMap)
          .map((l) => l..sort((a, b) => b.tanggalMasuk.compareTo(a.tanggalMasuk)));

  /// Mengubah nota servis. Teknisi hanya boleh menyentuh kolom pekerjaan --
  /// status, catatan, dan teknisinya; biaya serta identitas nota ditahan
  /// trigger di server.
  Future<void> ubahNota(String id, Map<String, dynamic> perubahan) => _pastikan(
    _c.from('service_orders').update(perubahan).eq('id', id).select('id'),
    'nota servis',
  );

  Stream<List<ShipmentEntry>> watchShipments() =>
      _semua('shipments', ShipmentEntry.fromMap)
          .map((l) => l..sort((a, b) => b.tanggalKirim.compareTo(a.tanggalKirim)));

  Stream<List<CustomerEntry>> watchCustomers() =>
      _semua('customers', CustomerEntry.fromMap)
          .map((l) => l..sort((a, b) => a.nama.compareTo(b.nama)));

  // ------------------------------------------------------------------
  // Pengaturan
  // ------------------------------------------------------------------

  Stream<StoreSetting?> watchStoreSettings() =>
      _semua('store_settings', StoreSetting.fromMap).map(_satu);

  Stream<ServiceSettingsRow?> watchServiceSettings() =>
      _semua('service_settings', ServiceSettingsRow.fromMap).map(_satu);

  Stream<RevenueConfig?> watchRevenueConfig() =>
      _semua('revenue_settings', RevenueConfig.fromMap).map(_satu);

  Stream<List<BrandFeeEntry>> watchBrandFees() =>
      _semua('brand_fees', BrandFeeEntry.fromMap);

  Stream<List<BrandShareEntry>> watchBrandShares() => _semua(
    'brand_technician_shares',
    BrandShareEntry.fromMap,
    kunci: const ['brand_id', 'profile_id'],
  );

  Stream<List<BrandRuleEntry>> watchBrandRules() => _semua(
    'brand_revenue_rules',
    BrandRuleEntry.fromMap,
    kunci: const ['brand_id'],
  );

  /// Tabel berbaris tunggal. Kosong berarti belum pernah diisi -- atau,
  /// untuk tabel yang dibatasi aturan akses, bahwa pengguna ini memang
  /// tidak berhak melihatnya.
  static T? _satu<T>(List<T> l) => l.isEmpty ? null : l.first;
}

/// Penulisan yang diterima server tetapi tidak mengubah satu baris pun.
///
/// Hampir selalu berarti aturan akses menolaknya secara diam-diam: akun
/// yang dipakai tidak berhak atas baris itu, atau barisnya sudah tidak ada
/// di server.
class GagalTulis implements Exception {
  const GagalTulis(this.apa);

  /// Apa yang gagal ditulis, untuk disebut dalam pesannya.
  final String apa;

  @override
  String toString() => 'GagalTulis: $apa';
}

/// Memastikan sebuah penulisan benar-benar mengenai baris di server.
///
/// Ini penjagaan terpenting dalam berkas ini, dan sengaja berupa fungsi
/// lepas: sebagian layar menulis langsung lewat SupabaseClient tanpa
/// melalui [Db], dan justru di sanalah cacatnya paling lama tidak
/// ketahuan.
///
/// Postgres menganggap UPDATE dan DELETE yang tidak cocok dengan satu
/// baris pun sebagai berhasil -- tidak ada galat, tidak ada apa pun.
/// Aturan akses yang menyaring barisnya keluar menghasilkan persis keadaan
/// itu. Tabel nota servis, kirim, pelanggan, brand, dan seluruh pengaturan
/// hanya boleh ditulis admin; teknisi yang menyuntingnya dari HP tidak
/// pernah mendapat penolakan, hanya diam.
///
/// Menambahkan .select() membuat server mengembalikan baris yang
/// benar-benar tersentuh, jadi kosong berarti tidak ada yang berubah.
Future<void> pastikanTulis(
  PostgrestTransformBuilder<PostgrestList> permintaan,
  String apa,
  SupabaseClient client,
) async {
  try {
    final kena = await permintaan;
    if (kena.isEmpty) {
      _catat(client, 'tulis $apa: server menerima, 0 baris tersentuh');
      throw GagalTulis(apa);
    }
  } on PostgrestException catch (e) {
    _catat(client, 'tulis $apa ditolak: ${e.code} ${e.message}');
    rethrow;
  }
}

/// Menulis sebab kegagalan ke log perangkat.
///
/// Kegagalan menulis selalu sampai ke pengembang sebagai "tidak tersimpan"
/// tanpa keterangan lain, dan tanpa catatan ini tidak ada cara memisahkan
/// aturan akses, sesi yang kedaluwarsa, dan jaringan. Sengaja tetap hidup
/// di build rilis: di situlah kejadiannya, bukan di meja pengembang.
///
/// Yang dicatat hanya sebab dan identitas sesi -- tidak ada token, tidak
/// ada isi data pelanggan.
void _catat(SupabaseClient client, String pesan) {
  final sesi = client.auth.currentSession;
  final kedaluwarsa = sesi?.expiresAt == null
      ? 'tidak ada sesi'
      : DateTime.fromMillisecondsSinceEpoch(
          sesi!.expiresAt! * 1000,
        ).toLocal().toIso8601String();

  debugPrint(
    '[db] $pesan | user=${client.auth.currentUser?.id ?? '-'} '
    '| sesi berakhir=$kedaluwarsa | sekarang=${DateTime.now()}',
  );
}
