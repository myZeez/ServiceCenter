/// Jam tutup nota keluar bila pengaturannya belum terbaca.
///
/// Dipakai juga di server sebagai bawaan kolom store_settings.tutup_jam.
/// Dua tempat, satu angka -- kalau berbeda, yang terlihat adalah nota yang
/// jatuh ke hari berbeda tergantung siapa yang menghitungnya.
const jamTutupBawaan = 17;

/// Hari kerja yang menaungi sebuah saat, untuk nota keluar.
///
/// Laporan nota keluar ditutup jam 17.00 dan dikirim ke pusat; unit yang
/// selesai atau dilunasi sesudahnya tidak mungkin ikut di dalamnya, jadi
/// ia tercatat di laporan hari berikutnya. Server menjalankan aturan yang
/// sama waktu menstempel tanggal_selesai dan tanggal_lunas.
///
/// Tidak untuk nota masuk. Unit yang diterima jam 19.45 diterima hari itu
/// juga, dan nota masuk memakai hari kalender biasa.
///
/// Batasnya menyertakan jam tutupnya sendiri: tepat 17.00 laporannya sudah
/// ditutup, jadi nota jam 17.00 sudah masuk besok.
///
/// Hari libur tidak punya laporan, jadi bukan tujuan: yang jatuh di sana
/// bergeser ke hari kerja berikutnya. Nota yang selesai Jumat jam 18.00
/// masuk laporan Minggu, bukan Sabtu -- Sabtu tidak punya lembar, dan nota
/// yang dicap di sana tidak akan pernah terbaca oleh pusat.
DateTime hariLaporan(
  DateTime saat, [
  int jamTutup = jamTutupBawaan,
  Set<int> libur = hariLiburBawaan,
]) {
  var hari = DateTime(saat.year, saat.month, saat.day);
  // 24 berarti tidak ada pergeseran jam sama sekali -- hari kalender biasa.
  if (jamTutup < 24 && saat.hour >= jamTutup) {
    hari = DateTime(hari.year, hari.month, hari.day + 1);
  }
  // Tujuh hari hanya penjaga: pengaturan yang meliburkan semuanya tidak
  // boleh membuat perhitungan ini tidak pernah berhenti.
  for (var i = 0; i < 7 && hariLibur(hari, libur); i++) {
    hari = DateTime(hari.year, hari.month, hari.day + 1);
  }
  return hari;
}

/// Hari toko tutup bila pengaturannya belum terbaca: Sabtu.
///
/// Sama dengan bawaan kolom store_settings.hari_libur. Dua tempat, satu
/// daftar -- kalau berbeda, yang terlihat adalah tab Sabtu yang muncul di
/// ekspor sebagian orang dan tidak di ekspor yang lain.
const hariLiburBawaan = <int>{DateTime.saturday};

/// Apakah [hari] jatuh pada hari toko tutup.
///
/// [libur] memuat nomor hari ISO, sama seperti DateTime.weekday: 1 Senin
/// sampai 7 Minggu.
bool hariLibur(DateTime hari, [Set<int> libur = hariLiburBawaan]) =>
    libur.contains(hari.weekday);

/// Apakah [saat] jatuh pada hari kerja [hari].
///
/// [hari] dibandingkan sebagai tanggal apa adanya: ia sudah merupakan hari
/// kerja, bukan sebuah saat yang perlu digeser lagi.
bool hariLaporanSama(
  DateTime saat,
  DateTime hari, [
  int jamTutup = jamTutupBawaan,
  Set<int> libur = hariLiburBawaan,
]) {
  final h = hariLaporan(saat, jamTutup, libur);
  return h.year == hari.year && h.month == hari.month && h.day == hari.day;
}
