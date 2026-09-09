// Bentuk baris yang datang dari Supabase.
//
// Dulu kelas-kelas ini dibuatkan drift dari cerminan SQLite di perangkat.
// Cerminan itu sudah dibuang: satu-satunya tempat data tinggal sekarang
// adalah Supabase, supaya admin dan teknisi tidak pernah melihat dua
// kenyataan yang berbeda.
//
// Namanya sengaja dipertahankan sama persis dengan yang dulu dihasilkan
// drift. Yang berubah dari pindahan ini hanyalah dari mana datanya
// datang -- bukan bagaimana layar membacanya.

DateTime _ts(Object? v) => DateTime.parse(v as String).toLocal();

/// Kolom bertipe `date` di Postgres. Tidak dikenai toLocal: isinya tanggal
/// kalender, bukan titik waktu, dan menggesernya menurut zona waktu justru
/// memindahkannya ke hari yang salah.
DateTime? _tgl(Object? v) => v == null ? null : DateTime.parse(v as String);

double _num(Object? v) => _numN(v) ?? 0;

/// Angka yang boleh benar-benar tidak ada.
///
/// Terpisah dari [_num] karena nol dan "belum diisi" adalah dua keadaan
/// yang berbeda: harga part yang masih dicari bukan berarti gratis.
///
/// Teks ikut diterima. Postgres mengirim numeric sebagai angka JSON, tapi
/// tidak untuk semua jalur -- dan `as num` yang meleset melempar galat
/// yang menjatuhkan seluruh aliran data, bukan satu kolom.
double? _numN(Object? v) => switch (v) {
  null => null,
  final num n => n.toDouble(),
  final String s => double.tryParse(s),
  _ => null,
};

/// Kolom bertipe array angka.
///
/// Bentuk kirimannya bisa dua rupa: larik JSON, atau literal array
/// Postgres seperti `{10.00,15.00}`. Keduanya diterima -- kalau salah
/// satunya tidak, akibatnya bukan galat melainkan daftar pilihan yang
/// diam-diam kosong, dan pengaturan yang tampak tidak pernah tersimpan.
List<double> _daftarAngka(Object? v) => switch (v) {
  final List<dynamic> l => [for (final e in l) ?_numN(e)],
  final String s => [
    for (final p in s.replaceAll(RegExp(r'[{}]'), '').split(','))
      ?_numN(p.trim()),
  ],
  _ => const [],
};

class Brand {
  const Brand({required this.id, required this.nama, this.aktif = true});

  final int id;
  final String nama;
  final bool aktif;

  factory Brand.fromMap(Map<String, dynamic> r) => Brand(
    id: r['id'] as int,
    nama: r['nama'] as String,
    aktif: r['aktif'] as bool? ?? true,
  );
}

class PartType {
  const PartType({
    required this.id,
    required this.kode,
    required this.nama,
    this.aktif = true,
  });

  final int id;
  final String kode;
  final String nama;
  final bool aktif;

  factory PartType.fromMap(Map<String, dynamic> r) => PartType(
    id: r['id'] as int,
    kode: r['kode'] as String,
    nama: r['nama'] as String,
    aktif: r['aktif'] as bool? ?? true,
  );
}

class Profile {
  const Profile({
    required this.id,
    required this.nama,
    required this.role,
    this.aktif = true,
  });

  final String id;
  final String nama;
  final String role;
  final bool aktif;

  factory Profile.fromMap(Map<String, dynamic> r) => Profile(
    id: r['id'] as String,
    nama: r['nama'] as String,
    role: r['role'] as String,
    aktif: r['aktif'] as bool? ?? true,
  );
}

class Claim {
  const Claim({
    required this.id,
    required this.tanggal,
    required this.brandId,
    required this.namaPelanggan,
    this.telp,
    this.email,
    required this.sn,
    this.jenis = 'brand',
    this.teknisiId,
    this.keluhan,
    this.noPerbaikan,
    required this.status,
    this.tanggalClose,
    this.catatan,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final DateTime tanggal;
  final int brandId;
  final String namaPelanggan;
  final String? telp;

  /// Email pelanggan. Dipakai brand untuk registrasi RMA; kosong pada
  /// klaim lama yang dicatat sebelum kolom ini ada.
  final String? email;

  /// Nomor seri unit. Kosong berarti belum diisi -- dan pada garansi toko
  /// memang tidak perlu diisi.
  final String sn;

  /// 'brand' atau 'toko'. Lihat [ClaimJenis].
  ///
  /// Klaim lama seluruhnya 'brand': sebelum kolom ini ada, tidak ada cara
  /// mencatat garansi toko sama sekali.
  final String jenis;
  final String? teknisiId;
  final String? keluhan;
  final String? noPerbaikan;
  final String status;

  /// Kapan klaimnya dinyatakan selesai. Inilah yang menentukan sebuah
  /// unit masuk rekap bulan yang mana -- bukan tanggal unitnya datang,
  /// karena unit yang masuk akhir Maret sering baru tuntas di April.
  final DateTime? tanggalClose;

  final String? catatan;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Claim.fromMap(Map<String, dynamic> r) => Claim(
    id: r['id'] as String,
    tanggal: _ts(r['tanggal']),
    brandId: r['brand_id'] as int,
    namaPelanggan: r['nama_pelanggan'] as String,
    telp: r['telp'] as String?,
    email: r['email'] as String?,
    // Kosong, bukan null. Garansi toko memang tidak memerlukan nomor
    // seri, dan seluruh layar yang membaca kolom ini sudah memperlakukan
    // teks kosong sebagai "belum diisi" -- membuatnya nullable hanya
    // memindahkan pemeriksaan yang sama ke belasan tempat.
    sn: (r['sn'] as String?) ?? '',
    jenis: (r['jenis'] as String?) ?? 'brand',
    teknisiId: r['teknisi_id'] as String?,
    keluhan: r['keluhan'] as String?,
    noPerbaikan: r['no_perbaikan'] as String?,
    status: r['status'] as String,
    tanggalClose: _tgl(r['tanggal_close']),
    catatan: r['catatan'] as String?,
    createdBy: r['created_by'] as String,
    createdAt: _ts(r['created_at']),
    updatedAt: _ts(r['updated_at']),
  );
}

class ClaimPart {
  const ClaimPart({
    required this.id,
    required this.claimId,
    required this.partTypeId,
    this.snBadPart,
  });

  final String id;
  final String claimId;
  final int partTypeId;
  final String? snBadPart;

  factory ClaimPart.fromMap(Map<String, dynamic> r) => ClaimPart(
    id: r['id'] as String,
    claimId: r['claim_id'] as String,
    partTypeId: r['part_type_id'] as int,
    snBadPart: r['sn_bad_part'] as String?,
  );
}

class BrandFeeEntry {
  const BrandFeeEntry({
    required this.id,
    required this.brandId,
    required this.fee,
    required this.berlakuDari,
  });

  final int id;
  final int brandId;
  final double fee;
  final DateTime berlakuDari;

  factory BrandFeeEntry.fromMap(Map<String, dynamic> r) => BrandFeeEntry(
    id: r['id'] as int,
    brandId: r['brand_id'] as int,
    fee: _num(r['fee']),
    berlakuDari: _tgl(r['berlaku_dari'])!,
  );
}

/// Hasil pencocokan satu unit dengan rekap bulanan yang dikirim brand.
///
/// Barisnya hanya ada untuk unit yang memang perlu dicatat: yang angkanya
/// berbeda dari fee brand, atau yang sudah ditandai cocok.
class ClaimSettlement {
  const ClaimSettlement({
    required this.claimId,
    this.fee,
    this.cocok = false,
    this.catatan,
    required this.updatedAt,
  });

  final String claimId;

  /// Angka sebenarnya dari surat brand. Kosong berarti memakai fee brand
  /// sebagai nilai awal -- berbeda dari nol, yang berarti brand memang
  /// tidak membayar unit ini.
  final double? fee;

  /// Sudah ditemukan di surat brand dan angkanya sama.
  final bool cocok;

  final String? catatan;
  final DateTime updatedAt;

  factory ClaimSettlement.fromMap(Map<String, dynamic> r) => ClaimSettlement(
    claimId: r['claim_id'] as String,
    fee: (r['fee'] as num?)?.toDouble(),
    cocok: r['cocok'] as bool? ?? false,
    catatan: r['catatan'] as String?,
    updatedAt: _ts(r['updated_at']),
  );
}

class RevenueConfig {
  const RevenueConfig({
    required this.id,
    required this.persenToko,
    required this.persenAdmin,
    required this.persenTeknisi,
    required this.metodeTeknisi,
  });

  final int id;
  final double persenToko;
  final double persenAdmin;
  final double persenTeknisi;
  final String metodeTeknisi;

  factory RevenueConfig.fromMap(Map<String, dynamic> r) => RevenueConfig(
    id: r['id'] as int,
    persenToko: _num(r['persen_toko']),
    persenAdmin: _num(r['persen_admin']),
    persenTeknisi: _num(r['persen_teknisi']),
    metodeTeknisi: r['metode_teknisi'] as String,
  );
}

class BrandShareEntry {
  const BrandShareEntry({
    required this.brandId,
    required this.profileId,
    required this.persen,
  });

  final int brandId;
  final String profileId;
  final double persen;

  factory BrandShareEntry.fromMap(Map<String, dynamic> r) => BrandShareEntry(
    brandId: r['brand_id'] as int,
    profileId: r['profile_id'] as String,
    persen: _num(r['persen']),
  );
}

class BrandRuleEntry {
  const BrandRuleEntry({
    required this.brandId,
    required this.persenToko,
    required this.persenAdmin,
    required this.persenTeknisi,
  });

  final int brandId;
  final double persenToko;
  final double persenAdmin;
  final double persenTeknisi;

  factory BrandRuleEntry.fromMap(Map<String, dynamic> r) => BrandRuleEntry(
    brandId: r['brand_id'] as int,
    persenToko: _num(r['persen_toko']),
    persenAdmin: _num(r['persen_admin']),
    persenTeknisi: _num(r['persen_teknisi']),
  );
}

class ServiceOrderEntry {
  const ServiceOrderEntry({
    required this.id,
    required this.noNota,
    required this.tanggalMasuk,
    this.estimasiSelesai,
    required this.customerNama,
    this.customerTelp,
    this.customerEmail,
    this.customerId,
    this.operatorId,
    required this.barangNama,
    this.barangType,
    this.barangSn,
    this.kelengkapan,
    this.keluhan,
    this.teknisiId,
    this.perbaikan,
    this.garansi = false,
    this.claimId,
    required this.status,
    this.biaya = 0,
    this.caraBayar,
    this.tanggalLunas,
    this.tanggalSelesai,
    this.keterangan,
    required this.updatedAt,
  });

  final String id;
  final String noNota;
  final DateTime tanggalMasuk;
  final DateTime? estimasiSelesai;

  /// Salinan, bukan tautan. Nota yang sudah tercetak harus tetap cocok
  /// dengan kertasnya walau data pelanggannya berubah kemudian.
  final String customerNama;
  final String? customerTelp;

  /// Email pelanggan. Ikut disalin ke klaim garansi yang lahir dari nota
  /// ini; kosong pada nota lama yang dicatat sebelum kolom ini ada.
  final String? customerEmail;

  final String? customerId;

  final String? operatorId;

  final String barangNama;
  final String? barangType;
  final String? barangSn;
  final String? kelengkapan;

  final String? keluhan;
  final String? teknisiId;
  final String? perbaikan;

  final bool garansi;
  final String? claimId;

  final String status;
  final double biaya;
  final String? caraBayar;
  final DateTime? tanggalLunas;

  /// Kapan pekerjaannya dinyatakan rampung. Dasar perhitungan omset --
  /// bukan tanggal masuk, bukan pula tanggal pelunasan.
  final DateTime? tanggalSelesai;
  final String? keterangan;

  final DateTime updatedAt;

  factory ServiceOrderEntry.fromMap(Map<String, dynamic> r) =>
      ServiceOrderEntry(
        id: r['id'] as String,
        noNota: r['no_nota'] as String,
        tanggalMasuk: _ts(r['tanggal_masuk']),
        estimasiSelesai: _tgl(r['estimasi_selesai']),
        customerNama: r['customer_nama'] as String,
        customerTelp: r['customer_telp'] as String?,
        customerEmail: r['customer_email'] as String?,
        customerId: r['customer_id'] as String?,
        operatorId: r['operator_id'] as String?,
        barangNama: r['barang_nama'] as String,
        barangType: r['barang_type'] as String?,
        barangSn: r['barang_sn'] as String?,
        kelengkapan: r['kelengkapan'] as String?,
        keluhan: r['keluhan'] as String?,
        teknisiId: r['teknisi_id'] as String?,
        perbaikan: r['perbaikan'] as String?,
        garansi: r['garansi'] as bool? ?? false,
        claimId: r['claim_id'] as String?,
        status: r['status'] as String,
        biaya: _num(r['biaya']),
        caraBayar: r['cara_bayar'] as String?,
        tanggalLunas: _tgl(r['tanggal_lunas']),
        tanggalSelesai: _tgl(r['tanggal_selesai']),
        keterangan: r['keterangan'] as String?,
        updatedAt: _ts(r['updated_at']),
      );
}

class ServiceSettingsRow {
  const ServiceSettingsRow({
    required this.id,
    required this.targetOmset,
    required this.feeAdminPerNota,
  });

  final int id;
  final double targetOmset;
  final double feeAdminPerNota;

  factory ServiceSettingsRow.fromMap(Map<String, dynamic> r) =>
      ServiceSettingsRow(
        id: r['id'] as int,
        targetOmset: _num(r['target_omset']),
        feeAdminPerNota: _num(r['fee_admin_per_nota']),
      );
}

class ShipmentEntry {
  const ShipmentEntry({
    required this.id,
    required this.tanggalKirim,
    required this.dariCabang,
    required this.keCabang,
    this.userNama,
    required this.barangNama,
    this.serialNumber,
    this.keluhan,
    this.kelengkapan,
    required this.status,
    this.tanggalKembali,
    this.keterangan,
    required this.updatedAt,
  });

  final String id;
  final DateTime tanggalKirim;
  final String dariCabang;
  final String keCabang;
  final String? userNama;

  final String barangNama;
  final String? serialNumber;
  final String? keluhan;
  final String? kelengkapan;

  final String status;
  final DateTime? tanggalKembali;
  final String? keterangan;

  final DateTime updatedAt;

  factory ShipmentEntry.fromMap(Map<String, dynamic> r) => ShipmentEntry(
    id: r['id'] as String,
    tanggalKirim: _tgl(r['tanggal_kirim'])!,
    dariCabang: r['dari_cabang'] as String,
    keCabang: r['ke_cabang'] as String,
    userNama: r['user_nama'] as String?,
    barangNama: r['barang_nama'] as String,
    serialNumber: r['serial_number'] as String?,
    keluhan: r['keluhan'] as String?,
    kelengkapan: r['kelengkapan'] as String?,
    status: r['status'] as String,
    tanggalKembali: _tgl(r['tanggal_kembali']),
    keterangan: r['keterangan'] as String?,
    updatedAt: _ts(r['updated_at']),
  );
}

/// Master pelanggan. Nota tetap menyimpan salinan nama dan teleponnya
/// sendiri; tabel ini hanya untuk mencari dan menautkan.
class CustomerEntry {
  const CustomerEntry({
    required this.id,
    required this.kode,
    required this.nama,
    this.telp,
    this.alamat,
    this.catatan,
    required this.updatedAt,
  });

  final String id;
  final String kode;
  final String nama;
  final String? telp;
  final String? alamat;
  final String? catatan;
  final DateTime updatedAt;

  factory CustomerEntry.fromMap(Map<String, dynamic> r) => CustomerEntry(
    id: r['id'] as String,
    kode: r['kode'] as String,
    nama: r['nama'] as String,
    telp: r['telp'] as String?,
    alamat: r['alamat'] as String?,
    catatan: r['catatan'] as String?,
    updatedAt: _ts(r['updated_at']),
  );
}

/// Identitas toko untuk kepala dan kaki nota.
class StoreSetting {
  const StoreSetting({
    required this.id,
    required this.nama,
    this.alamat,
    this.telepon,
    this.ketentuan,
    this.tutupJam = 17,
  });

  final int id;
  final String nama;
  final String? alamat;
  final String? telepon;
  final String? ketentuan;

  /// Jam laporan harian ditutup. Nota pada jam ini atau sesudahnya
  /// dihitung sebagai hari berikutnya; 24 berarti hari kalender biasa.
  final int tutupJam;

  factory StoreSetting.fromMap(Map<String, dynamic> r) => StoreSetting(
    id: r['id'] as int,
    nama: r['nama'] as String,
    alamat: r['alamat'] as String?,
    telepon: r['telepon'] as String?,
    ketentuan: r['ketentuan'] as String?,
    // Bawaannya dipakai juga saat kolomnya belum ada -- aplikasi yang
    // lebih baru dari databasenya tidak boleh gagal membaca, ia cukup
    // memakai jam yang sama dengan bawaan servernya.
    tutupJam: (r['tutup_jam'] as num?)?.toInt() ?? 17,
  );
}

// ---------------------------------------------------------------------
// Tanya harga dan pemesanan part
// ---------------------------------------------------------------------

/// Sebuah unit non-garansi yang partnya harus dibeli.
///
/// Satu baris ini melintasi dua layar: selama tahapnya masih `tanya` ia
/// muncul di Tanya Harga, dan begitu pelanggan membayar DP ia pindah ke
/// Pemesanan Part. Bukan dua catatan -- satu catatan yang berjalan.
class PartOrder {
  const PartOrder({
    required this.id,
    required this.tanggal,
    required this.customerNama,
    this.customerTelp,
    this.customerId,
    this.barangType,
    this.barangSn,
    required this.partReq,
    this.keterangan,
    this.teknisiId,
    required this.tahap,
    this.harga,
    this.dp = 0,
    this.caraBayar,
    this.sisa = 0,
    this.tanggalDp,
    this.tanggalOrder,
    this.noPo,
    this.tanggalSelesai,
    this.serviceOrderId,
    this.catatan,
    required this.updatedAt,
  });

  final String id;
  final DateTime tanggal;

  final String customerNama;
  final String? customerTelp;
  final String? customerId;

  final String? barangType;
  final String? barangSn;

  final String partReq;

  /// Asal partnya: OEM, ORI, atau saluran resmi merek seperti ASUS ID.
  /// Teks bebas -- daftarnya tumbuh sendiri sepanjang tahun.
  final String? keterangan;

  final String? teknisiId;

  final String tahap;

  /// Harga jual. Null selama partnya masih dicari.
  final double? harga;

  final double dp;

  /// Lewat mana uangnya diterima. Kodenya dari tabel metode_bayar.
  final String? caraBayar;

  /// Dihitung Postgres, tidak pernah dikirim aplikasi.
  final double sisa;

  /// Kapan pelanggan membayar mukanya. Diisi server saat tahapnya
  /// berpindah ke 'dipesan'; inilah yang dipakai mengelompokkan laporan
  /// per bulan, bukan tanggal orangnya bertanya.
  final DateTime? tanggalDp;

  /// Kapan partnya dipesan ke supplier. Sering berbeda beberapa hari dari
  /// tanggal DP, dan selisih itulah yang ditanyakan pelanggan.
  final DateTime? tanggalOrder;

  /// Nomor PO ke distributor, atau nama tempat membeli lepasan.
  final String? noPo;

  final DateTime? tanggalSelesai;

  /// Nota servis untuk jasa pasangnya. Uang jasa tidak ada di sini.
  final String? serviceOrderId;

  final String? catatan;
  final DateTime updatedAt;

  factory PartOrder.fromMap(Map<String, dynamic> r) => PartOrder(
    id: r['id'] as String,
    tanggal: _ts(r['tanggal']),
    customerNama: r['customer_nama'] as String,
    customerTelp: r['customer_telp'] as String?,
    customerId: r['customer_id'] as String?,
    barangType: r['barang_type'] as String?,
    barangSn: r['barang_sn'] as String?,
    partReq: r['part_req'] as String,
    keterangan: r['keterangan'] as String?,
    teknisiId: r['teknisi_id'] as String?,
    tahap: r['tahap'] as String,
    harga: _numN(r['harga']),
    dp: _num(r['dp']),
    caraBayar: r['cara_bayar'] as String?,
    sisa: _num(r['sisa']),
    tanggalDp: _tgl(r['tanggal_dp']),
    tanggalOrder: _tgl(r['tanggal_order']),
    noPo: r['no_po'] as String?,
    tanggalSelesai: _tgl(r['tanggal_selesai']),
    serviceOrderId: r['service_order_id'] as String?,
    catatan: r['catatan'] as String?,
    updatedAt: _ts(r['updated_at']),
  );
}

/// Modal dan margin sebuah pesanan, disimpan terpisah karena hanya admin
/// yang boleh melihatnya.
///
/// Bagi teknisi tabel asalnya selalu kosong -- itu aturan akses yang
/// bekerja, bukan data yang belum diisi.
class PartCost {
  const PartCost({required this.partOrderId, this.hpp, this.upPersen});

  final String partOrderId;
  final double? hpp;
  final double? upPersen;

  factory PartCost.fromMap(Map<String, dynamic> r) => PartCost(
    partOrderId: r['part_order_id'] as String,
    hpp: _numN(r['hpp']),
    upPersen: _numN(r['up_persen']),
  );
}

/// Pilihan persentase yang muncul saat menetapkan harga.
class PartSettingsRow {
  const PartSettingsRow({
    required this.upTokoPilihan,
    required this.upTokoBawaan,
  });

  final List<double> upTokoPilihan;
  final double upTokoBawaan;

  factory PartSettingsRow.fromMap(Map<String, dynamic> r) => PartSettingsRow(
    upTokoPilihan: _daftarAngka(r['up_toko_pilihan']),
    upTokoBawaan: _num(r['up_toko_bawaan']),
  );
}

/// Cara pelanggan membayar. Daftarnya diatur dari Pengaturan, bukan
/// dikunci di kode: rekening dan dompet digital baru muncul lebih sering
/// daripada aplikasi ini dibangun ulang.
class MetodeBayar {
  const MetodeBayar({
    required this.id,
    required this.kode,
    required this.nama,
    this.piutang = false,
    this.urutan = 0,
    this.aktif = true,
  });

  final int id;

  /// Yang tersimpan di nota. Tidak boleh berubah ejaannya: nota lama
  /// menyimpan kode ini apa adanya.
  final String kode;

  final String nama;

  /// Uangnya belum diterima saat nota ditutup. Hanya ini yang membuat
  /// sebuah nota jadi piutang -- tunai, transfer, dan QRIS sama saja bagi
  /// kas toko.
  final bool piutang;

  final int urutan;
  final bool aktif;

  factory MetodeBayar.fromMap(Map<String, dynamic> r) => MetodeBayar(
    id: r['id'] as int,
    kode: r['kode'] as String,
    nama: r['nama'] as String,
    piutang: r['piutang'] as bool? ?? false,
    urutan: (r['urutan'] as num?)?.toInt() ?? 0,
    aktif: r['aktif'] as bool? ?? true,
  );
}
