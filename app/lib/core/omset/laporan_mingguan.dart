import '../data/models.dart';
import 'omset_calculator.dart';
import 'omset_providers.dart';

/// Senin pada minggu yang memuat [hari]. Minggu laporan berjalan Senin sampai
/// Minggu.
DateTime seninDari(DateTime hari) => DateTime(
  hari.year,
  hari.month,
  hari.day - (hari.weekday - DateTime.monday),
);

class HariMingguan {
  const HariMingguan({
    required this.tanggal,
    required this.masuk,
    required this.keluar,
    required this.nilaiKeluar,
    required this.omset,
  });

  final DateTime tanggal;
  final int masuk;
  final int keluar;
  final double nilaiKeluar;
  final double omset;
}

class LaporanMingguan {
  const LaporanMingguan({required this.hari, required this.omset});

  /// Tujuh hari, Senin lebih dulu.
  final List<HariMingguan> hari;

  final OmsetResult omset;

  int get masuk => hari.fold(0, (a, h) => a + h.masuk);
  int get keluar => hari.fold(0, (a, h) => a + h.keluar);
  double get nilaiKeluar => hari.fold(0, (a, h) => a + h.nilaiKeluar);
}

bool _hariSama(DateTime? a, DateTime b) =>
    a != null && a.year == b.year && a.month == b.month && a.day == b.day;

/// Masuk dan keluar dihitung seperti tab Harian, omset seperti tab Omset.
/// Rumusnya sengaja tidak dibuat baru: angka minggu ini harus bisa dicocokkan
/// dengan kedua tab itu.
LaporanMingguan hitungLaporanMingguan({
  required List<ServiceOrderEntry> nota,
  required DateTime senin,
  required ServiceSettingsRow? aturan,
}) {
  OmsetResult omset(DateTime dari, DateTime hariAkhir) => hitungOmsetPeriode(
    nota: nota,
    dari: dari,
    sampai: DateTime(
      hariAkhir.year,
      hariAkhir.month,
      hariAkhir.day,
      23,
      59,
      59,
    ),
    aturan: aturan,
  );

  final hari = [
    for (var i = 0; i < 7; i++)
      DateTime(senin.year, senin.month, senin.day + i),
  ];

  return LaporanMingguan(
    hari: [
      for (final t in hari)
        () {
          final keluar = nota.where(
            (n) =>
                (n.status == 'diambil' || n.status == 'batal') &&
                _hariSama(n.tanggalDiambil, t),
          );
          return HariMingguan(
            tanggal: t,
            masuk: nota.where((n) => _hariSama(n.tanggalMasuk, t)).length,
            keluar: keluar.length,
            nilaiKeluar: keluar.fold(0, (a, n) => a + n.biaya),
            omset: omset(t, t).omsetToko,
          );
        }(),
    ],
    omset: omset(hari.first, hari.last),
  );
}
