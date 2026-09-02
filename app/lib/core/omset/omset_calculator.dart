/// Perhitungan omset jasa servis.
///
/// Terpisah dari bagi hasil garansi: yang itu sumbernya fee dari brand, yang
/// ini jasa yang dibayar pelanggan. Sengaja fungsi murni tanpa ketergantungan
/// ke database maupun Flutter, supaya bisa diuji — rumus yang menyangkut
/// target dan imbalan orang harus punya tes.
library;

class OmsetSettings {
  const OmsetSettings({
    this.targetTeknisi = 4000000,
    this.feeAdminPerNota = 0,
  });

  /// Target produksi bulanan tiap teknisi, dalam rupiah.
  final double targetTeknisi;

  /// Imbalan admin untuk tiap nota yang keluar, berapa pun biaya jasanya.
  final double feeAdminPerNota;
}

/// Nota yang ikut dihitung. Pemanggil bertanggung jawab menyaring periode
/// dan memastikan pekerjaannya memang sudah selesai.
class OmsetNota {
  const OmsetNota({
    required this.teknisiId,
    required this.biaya,
    this.lunas = false,
  });

  final String? teknisiId;
  final double biaya;

  /// Dipakai hanya untuk memisahkan mana yang uangnya sudah masuk. Omset
  /// tetap dihitung penuh: pelanggan yang menunda membayar bukan salah
  /// teknisi yang mengerjakannya.
  final bool lunas;
}

class OmsetTeknisi {
  const OmsetTeknisi({
    required this.teknisiId,
    required this.jumlahNota,
    required this.omset,
  });

  final String teknisiId;
  final int jumlahNota;
  final double omset;

  double persenTarget(double target) =>
      target <= 0 ? 0 : (omset / target * 100);

  double kurangDariTarget(double target) {
    final sisa = target - omset;
    return sisa < 0 ? 0 : sisa;
  }
}

class OmsetResult {
  const OmsetResult({
    required this.omsetToko,
    required this.jumlahNota,
    required this.sudahMasuk,
    required this.piutang,
    required this.omsetAdmin,
    required this.notaTanpaTeknisi,
    required this.teknisi,
  });

  /// Seluruh jasa yang dihasilkan pada periode ini.
  final double omsetToko;

  final int jumlahNota;

  /// Bagian omset yang uangnya sudah diterima, dan yang masih tertahan.
  final double sudahMasuk;
  final double piutang;

  /// Imbalan admin: fee per nota dikalikan jumlah nota yang keluar.
  final double omsetAdmin;

  /// Nota selesai yang kolom teknisinya kosong. Nilainya tetap masuk omset
  /// toko, tetapi tidak jatuh ke siapa pun -- diangkat tersendiri supaya
  /// kekosongan datanya terlihat.
  final int notaTanpaTeknisi;

  final List<OmsetTeknisi> teknisi;
}

OmsetResult hitungOmset({
  required List<OmsetNota> nota,
  required OmsetSettings settings,
}) {
  var toko = 0.0;
  var masuk = 0.0;
  var tertahan = 0.0;
  var tanpaTeknisi = 0;

  final jumlahPer = <String, int>{};
  final nilaiPer = <String, double>{};

  for (final n in nota) {
    toko += n.biaya;
    if (n.lunas) {
      masuk += n.biaya;
    } else {
      tertahan += n.biaya;
    }

    final t = n.teknisiId;
    if (t == null) {
      tanpaTeknisi++;
      continue;
    }
    jumlahPer.update(t, (v) => v + 1, ifAbsent: () => 1);
    nilaiPer.update(t, (v) => v + n.biaya, ifAbsent: () => n.biaya);
  }

  final daftar = [
    for (final id in nilaiPer.keys)
      OmsetTeknisi(
        teknisiId: id,
        jumlahNota: jumlahPer[id] ?? 0,
        omset: nilaiPer[id]!,
      ),
  ]..sort((a, b) => b.omset.compareTo(a.omset));

  return OmsetResult(
    omsetToko: toko,
    jumlahNota: nota.length,
    sudahMasuk: masuk,
    piutang: tertahan,
    // Dihitung dari JUMLAH nota, bukan dari nilainya: imbalan admin adalah
    // upah menangani satu transaksi, dan nota kecil sama repotnya dengan
    // nota besar.
    omsetAdmin: settings.feeAdminPerNota * nota.length,
    notaTanpaTeknisi: tanpaTeknisi,
    teknisi: daftar,
  );
}
