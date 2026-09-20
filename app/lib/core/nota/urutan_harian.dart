import '../data/models.dart';
import 'nomor_nota.dart';

/// Kelompok sebuah nota pada laporan harian, menurut urutan bacanya:
/// yang menghasilkan uang di atas, yang tidak menghasilkan uang di bawah.
///
/// Urutan ini dari pemilik toko, dan begitulah laporan harian dibaca di
/// pusat: pertama yang uangnya sudah masuk, lalu yang masih ditagih, lalu
/// unit garansi yang biayanya nol, terakhir yang dibatalkan.
enum KelompokHarian {
  /// Servis berbayar yang sudah lunas -- atau servis biasa tanpa tagihan.
  berbiaya('Berbiaya'),

  /// Ada tagihannya, uangnya belum masuk.
  piutang('Piutang'),

  /// Unit bergaransi.
  garansi('Garansi'),

  /// Nota dibatalkan tanpa biaya.
  cancel('Cancel');

  const KelompokHarian(this.label);
  final String label;
}

/// Kelompok [n] pada laporan harian.
///
/// Nota batal ditentukan oleh biayanya, karena pembatalan bisa berbiaya
/// dan bisa tidak:
///
///   batal tanpa biaya   Cancel -- tidak ada uang yang terlibat.
///   batal berbiaya      seperti servis berbayar biasa, Berbiaya kalau
///                       sudah lunas dan Piutang kalau belum. Uangnya
///                       nyata (biaya cek, misalnya); menaruhnya di
///                       Cancel menyembunyikannya di antara baris yang
///                       tidak menghasilkan apa-apa. Kata Cancel-nya
///                       tetap terbaca di kolom keterangan.
///
/// Sesudah itu yang diperiksa lebih dulu menang: garansi mengalahkan
/// tagihan (unit bergaransi yang dikenai biaya layanan tambahan tetap
/// terbaca Garansi, karena begitulah ia ditandai di kolom keterangan).
///
/// Piutang diukur dengan cara yang sama seperti kolom PIUTANG di laporan
/// penerimaan: ada biaya, dan tanggal lunasnya masih kosong.
KelompokHarian kelompokHarian(ServiceOrderEntry n) {
  if (n.status == 'batal') {
    if (n.biaya <= 0) return KelompokHarian.cancel;
    return n.tanggalLunas == null
        ? KelompokHarian.piutang
        : KelompokHarian.berbiaya;
  }
  if (n.garansi) return KelompokHarian.garansi;
  if (n.biaya > 0 && n.tanggalLunas == null) return KelompokHarian.piutang;
  return KelompokHarian.berbiaya;
}

/// Urutan baris laporan harian: per kelompok, lalu menurut nomor nota --
/// urutan buku toko -- di dalam tiap kelompok.
int bandingHarian(ServiceOrderEntry a, ServiceOrderEntry b) {
  final kelompok = kelompokHarian(a).index.compareTo(kelompokHarian(b).index);
  if (kelompok != 0) return kelompok;
  return bandingNomorNota(a.noNota, b.noNota);
}
