/// Aturan waktu dan ambang untuk peringatan omset.
///
/// Fungsi murni, tanpa Flutter dan tanpa database: yang diputuskan di sini
/// -- siapa dianggap kurang, dan kapan toko diingatkan -- menyangkut
/// pekerjaan orang, jadi harus bisa diuji.
library;

/// Bawaan jumlah hari sebelum ganti bulan saat peringatan mulai berlaku.
/// Diatur dari Pengaturan; ini hanya nilai selama pengaturannya belum termuat.
const hariPeringatanOmsetBawaan = 10;

/// Sisa hari sampai bulan berganti, HARI INI IKUT DIHITUNG: tanggal terakhir
/// bulan bernilai 1.
///
/// Dihitung begini, bukan "tanggal terakhir dikurangi hari ini", supaya
/// "10 hari sebelum ganti bulan" berarti persis sepuluh hari kerja terakhir
/// -- pada bulan 30 hari itu tanggal 21, bukan tanggal 20 -- dan hari
/// terakhir tidak bernilai nol.
int sisaHariSebelumGantiBulan(DateTime hari) {
  final terakhir = DateTime(hari.year, hari.month + 1, 0).day;
  return terakhir - hari.day + 1;
}

/// Apakah [hari] termasuk masa peringatan omset: [hariSebelum] hari terakhir
/// sebelum bulan berganti.
///
/// Nol -- atau kurang -- mematikan peringatan. Angka itu boleh diatur pemilik
/// toko, dan "jangan ingatkan" adalah jawaban yang sah.
bool masaPeringatanOmset(DateTime hari, int hariSebelum) =>
    hariSebelum > 0 && sisaHariSebelumGantiBulan(hari) <= hariSebelum;

/// Apakah [omset] masih di bawah [target].
///
/// Target nol atau kurang berarti tidak ada target, jadi tidak ada yang
/// kurang -- bukan semua orang lolos karena angkanya nol, dan bukan semua
/// orang kurang karena tidak ada yang bisa dibandingkan.
///
/// Yang diukur omsetnya, bukan jumlah unit selesai: unit kecil dan unit
/// besar sama-sama satu unit, tetapi rupiahnya berbeda jauh.
bool dibawahTargetOmset(double omset, double target) =>
    target > 0 && omset < target;

/// Selisih rupiah ke target, tidak pernah negatif.
double kurangDariTarget(double omset, double target) {
  final sisa = target - omset;
  return sisa < 0 ? 0 : sisa;
}
