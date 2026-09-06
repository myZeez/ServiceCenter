/// Jam tutup laporan harian bila pengaturannya belum terbaca.
///
/// Dipakai juga di server sebagai bawaan kolom store_settings.tutup_jam.
/// Dua tempat, satu angka -- kalau berbeda, yang terlihat adalah nota yang
/// jatuh ke hari berbeda tergantung siapa yang menghitungnya.
const jamTutupBawaan = 17;

/// Hari kerja yang menaungi sebuah saat.
///
/// Hari di toko tidak berganti tengah malam. Laporan harian ditutup jam
/// 17.00 dan dikirim ke pusat; unit yang masuk sesudahnya tidak mungkin
/// ikut di dalamnya, jadi ia tercatat sebagai unit hari berikutnya --
/// persis seperti yang dilakukan orang di meja depan dengan buku
/// catatannya sejak sebelum ada aplikasi ini.
///
/// Batasnya menyertakan jam tutupnya sendiri: tepat 17.00 laporannya sudah
/// ditutup, jadi nota jam 17.00 sudah masuk besok.
DateTime hariLaporan(DateTime saat, [int jamTutup = jamTutupBawaan]) {
  final hari = DateTime(saat.year, saat.month, saat.day);
  // 24 berarti tidak ada pergeseran sama sekali -- hari kalender biasa.
  if (jamTutup >= 24 || saat.hour < jamTutup) return hari;
  return DateTime(saat.year, saat.month, saat.day + 1);
}

/// Apakah [saat] jatuh pada hari kerja [hari].
///
/// [hari] dibandingkan sebagai tanggal apa adanya: ia sudah merupakan hari
/// kerja, bukan sebuah saat yang perlu digeser lagi.
bool hariLaporanSama(
  DateTime saat,
  DateTime hari, [
  int jamTutup = jamTutupBawaan,
]) {
  final h = hariLaporan(saat, jamTutup);
  return h.year == hari.year && h.month == hari.month && h.day == hari.day;
}

/// Hari kerja yang sedang berjalan sekarang.
DateTime hariLaporanKini([int jamTutup = jamTutupBawaan]) =>
    hariLaporan(DateTime.now(), jamTutup);
