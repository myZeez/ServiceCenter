import '../../core/data/models.dart';
import 'service_status.dart';

/// Nota atas nama [userId] yang masih di tangannya: baru masuk, sedang
/// dikerjakan, menunggu part, atau sedang dikirim ke cabang.
///
/// Urutannya dibiarkan seperti yang datang -- yang terbaru masuk di atas,
/// sama dengan halaman Servis -- supaya dua daftar itu tidak terasa
/// berlawanan.
List<ServiceOrderEntry> notaBerjalanSaya(
  List<ServiceOrderEntry> semua,
  String? userId,
) {
  if (userId == null) return const [];
  return [
    for (final n in semua)
      if (n.teknisiId == userId && ServiceStatus.sedangDikerjakan(n.status)) n,
  ];
}

/// Nota atas nama [userId] yang sudah rampung dalam tiga bulan terakhir,
/// yang terbaru selesai di atas.
///
/// Selesai di sini termasuk yang sudah diambil pelanggan -- pekerjaannya
/// sama-sama tuntas. Yang dibatalkan tidak ikut: unitnya tidak pernah
/// selesai dikerjakan.
///
/// Dasarnya tanggal selesai, bukan tanggal masuk: unit yang masuk empat
/// bulan lalu dan baru rampung kemarin adalah pekerjaan minggu ini. Nota
/// lama tanpa tanggal selesai memakai tanggal masuknya, karena tidak
/// mungkin rampung sebelum diterima.
List<ServiceOrderEntry> notaSelesaiSaya(
  List<ServiceOrderEntry> semua,
  String? userId,
  DateTime sekarang,
) {
  if (userId == null) return const [];
  final batas = tigaBulanSebelum(sekarang);

  return [
    for (final n in semua)
      if (n.teknisiId == userId &&
          (n.status == ServiceStatus.selesai ||
              n.status == ServiceStatus.diambil) &&
          !kapanSelesai(n).isBefore(batas))
        n,
  ]..sort((a, b) {
    final c = kapanSelesai(b).compareTo(kapanSelesai(a));
    return c != 0 ? c : b.tanggalMasuk.compareTo(a.tanggalMasuk);
  });
}

/// Kapan pekerjaan pada nota ini dianggap rampung. Lihat [notaSelesaiSaya].
DateTime kapanSelesai(ServiceOrderEntry n) =>
    n.tanggalSelesai ?? n.tanggalMasuk;

/// Awal hari pada tanggal yang sama tiga bulan sebelum [hari].
///
/// Tanggal 31 yang mundur ke bulan berhari 30 (atau Februari) jatuh di hari
/// terakhir bulan itu, bukan meloncat ke bulan berikutnya -- 31 Mei
/// mundur ke 28 Februari, bukan 3 Maret.
DateTime tigaBulanSebelum(DateTime hari) {
  var bulan = hari.month - 3;
  var tahun = hari.year;
  if (bulan <= 0) {
    bulan += 12;
    tahun -= 1;
  }
  final hariTerakhir = DateTime(tahun, bulan + 1, 0).day;
  return DateTime(
    tahun,
    bulan,
    hari.day > hariTerakhir ? hariTerakhir : hari.day,
  );
}
