/// Riwayat omset bulanan dan skor teknisi.
///
/// Skor (keputusan Budi, 19 Oktober 2026): rata-rata omset bulanan dibagi
/// dua kali target. Target minimum (Rp4.000.000 saat ini, diatur di
/// Pengaturan) bernilai 50%, dua kali target bernilai 100%, dan lebih dari itu
/// tetap 100%. Kalau targetnya dinaikkan, standar skornya ikut naik.
///
/// Rumus "rata-rata dibagi bulan terbaiknya sendiri" sempat ditimbang dan
/// ditolak: yang terukur jadi kestabilan, bukan prestasi -- dengan data
/// Januari-September 2026, teknisi yang omsetnya paling kecil justru mendapat
/// skor tertinggi.
library;

import '../data/models.dart';
import 'omset_providers.dart';

/// Omset satu teknisi dalam satu bulan kalender.
class OmsetBulan {
  const OmsetBulan({
    required this.bulan,
    required this.omset,
    required this.jumlahNota,
  });

  /// Tanggal 1 bulannya.
  final DateTime bulan;
  final double omset;
  final int jumlahNota;
}

/// Bulan-bulan penuh terakhir milik [teknisiId], dari yang terlama.
///
/// Bulan berjalan tidak ikut: belum selesai, dan memasukkannya akan selalu
/// menurunkan rata-rata. Bulan sebelum teknisi itu punya nota pertama juga
/// tidak ikut -- data sistem baru ada sejak Januari 2026, dan teknisi baru
/// tidak boleh dihitung nol untuk bulan sebelum ia bekerja. Bulan aktif yang
/// omsetnya kosong tetap dihitung nol.
///
/// Angka tiap bulan dihitung lewat [hitungOmsetPeriode], kalkulator yang sama
/// dengan kartu Servis Bulan Ini dan laporan: satu angka, satu rumus.
List<OmsetBulan> omsetBulananTeknisi({
  required List<ServiceOrderEntry> nota,
  required String teknisiId,
  required DateTime kini,
  required ServiceSettingsRow? aturan,
  int jumlahBulan = 12,
}) {
  DateTime? pertama;
  for (final n in nota) {
    if (n.teknisiId != teknisiId || !_dihitung(n.status)) continue;
    final t = n.tanggalSelesai ?? n.tanggalDiambil ?? n.tanggalKirim;
    if (t == null) continue;
    if (pertama == null || t.isBefore(pertama)) pertama = t;
  }
  if (pertama == null) return const [];

  final bulanIni = DateTime(kini.year, kini.month);
  final awalJendela = DateTime(kini.year, kini.month - jumlahBulan);
  final awalAktif = DateTime(pertama.year, pertama.month);
  var bulan = awalAktif.isAfter(awalJendela) ? awalAktif : awalJendela;

  final milikNya = [
    for (final n in nota)
      if (n.teknisiId == teknisiId) n,
  ];
  final hasil = <OmsetBulan>[];
  while (bulan.isBefore(bulanIni)) {
    final sesudah = DateTime(bulan.year, bulan.month + 1);
    final r = hitungOmsetPeriode(
      nota: milikNya,
      dari: bulan,
      sampai: sesudah.subtract(const Duration(milliseconds: 1)),
      aturan: aturan,
    );
    final t = r.teknisi.where((x) => x.teknisiId == teknisiId);
    hasil.add(
      OmsetBulan(
        bulan: bulan,
        omset: t.isEmpty ? 0 : t.single.omset,
        jumlahNota: t.isEmpty ? 0 : t.single.jumlahNota,
      ),
    );
    bulan = sesudah;
  }
  return hasil;
}

bool _dihitung(String status) =>
    status == 'selesai' || status == 'diambil' || status == 'dikirim_cabang';

/// Skor beberapa bulan.
class SkorOmset {
  const SkorOmset({
    required this.bulan,
    required this.target,
    required this.rataRata,
    required this.terendah,
    required this.tertinggi,
    required this.persen,
    required this.bintang,
  });

  /// Bulan yang dinilai, dari yang terlama.
  final List<OmsetBulan> bulan;
  final double target;
  final double rataRata;
  final OmsetBulan terendah;
  final OmsetBulan tertinggi;

  /// 0 sampai 100.
  final double persen;

  /// 1 sampai 5.
  final int bintang;

  String get predikat => predikatBintang(bintang);
}

/// Skor dari [bulan], atau null bila belum ada satu pun bulan penuh.
SkorOmset? hitungSkorOmset(List<OmsetBulan> bulan, double target) {
  if (bulan.isEmpty) return null;
  final rata = bulan.fold(0.0, (s, b) => s + b.omset) / bulan.length;
  var rendah = bulan.first, tinggi = bulan.first;
  for (final b in bulan) {
    // Seri dipecahkan oleh bulan yang lebih baru.
    if (b.omset <= rendah.omset) rendah = b;
    if (b.omset >= tinggi.omset) tinggi = b;
  }
  final persen = persenSkor(rata, target);
  return SkorOmset(
    bulan: List.unmodifiable(bulan),
    target: target,
    rataRata: rata,
    terendah: rendah,
    tertinggi: tinggi,
    persen: persen,
    bintang: bintangDariPersen(persen),
  );
}

/// Rata-rata omset terhadap dua kali target, 0 sampai 100.
double persenSkor(double rataRata, double target) {
  if (target <= 0) return 0;
  return (rataRata / (2 * target) * 100).clamp(0, 100).toDouble();
}

/// 90-100% bintang 5, 75-89% bintang 4, 60-74% bintang 3, 40-59% bintang 2,
/// di bawahnya bintang 1. Batasnya dibandingkan setelah dibulatkan ke satu
/// desimal, angka yang memang terlihat di layar -- 89,96% tampil sebagai
/// 90,0% dan harus berbintang 5.
int bintangDariPersen(double persen) {
  final p = (persen * 10).round() / 10;
  if (p >= 90) return 5;
  if (p >= 75) return 4;
  if (p >= 60) return 3;
  if (p >= 40) return 2;
  return 1;
}

String predikatBintang(int bintang) => switch (bintang) {
  5 => 'Teknisi terbaik',
  4 => 'Sangat baik',
  3 => 'Baik',
  2 => 'Cukup',
  _ => 'Perlu ditingkatkan',
};
