import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

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

  /// Seluruh isi tabel, diperbarui sendiri saat ada perubahan di server.
  ///
  /// Sengaja tidak disaring di sisi server. Satu langganan per tabel jauh
  /// lebih hemat daripada satu langganan per kombinasi filter, dan tabel di
  /// sini semuanya kecil. Penyaringan dan pengurutan dikerjakan di Dart oleh
  /// yang memakainya.
  Stream<List<T>> _semua<T>(
    String tabel,
    T Function(Map<String, dynamic>) bentuk, {
    List<String> kunci = const ['id'],
  }) => _c
      .from(tabel)
      .stream(primaryKey: kunci)
      .map((rows) => rows.map(bentuk).toList());

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
      _c.from('claims').upsert(baris);

  Future<void> ubahClaim(String id, Map<String, dynamic> perubahan) =>
      _c.from('claims').update(perubahan).eq('id', id);

  /// Mengganti teknisi yang mengerjakan. Ini satu-satunya perubahan yang
  /// boleh dilakukan teknisi terhadap klaim yang sudah ada -- kolom lain
  /// ditolak trigger di server.
  Future<void> gantiTeknisi(String claimId, String teknisiId) =>
      ubahClaim(claimId, {'teknisi_id': teknisiId});

  Future<void> gantiStatus(String claimId, String status) =>
      ubahClaim(claimId, {'status': status});

  Future<void> simpanPart(Map<String, dynamic> baris) =>
      _c.from('claim_parts').upsert(baris);

  Future<void> hapusPart(String id) =>
      _c.from('claim_parts').delete().eq('id', id);

  // ------------------------------------------------------------------
  // Administrasi servis
  // ------------------------------------------------------------------

  Stream<List<ServiceOrderEntry>> watchServiceOrders() =>
      _semua('service_orders', ServiceOrderEntry.fromMap)
          .map((l) => l..sort((a, b) => b.tanggalMasuk.compareTo(a.tanggalMasuk)));

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
