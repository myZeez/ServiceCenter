import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/models.dart';
import '../../core/omset/omset_providers.dart';
import '../../core/providers.dart';
import 'service_status.dart';
import 'service_view.dart' show serviceOrdersProvider;

/// Beban dan hasil seorang teknisi pada bulan berjalan.
class RingkasTeknisi {
  const RingkasTeknisi({
    required this.teknisi,
    required this.unitBerjalan,
    required this.notaSelesai,
    required this.omset,
    required this.target,
  });

  final Profile teknisi;

  /// Unit yang masih dipegangnya: sudah diterima, belum tuntas.
  final int unitBerjalan;

  /// Nota yang pekerjaannya rampung bulan ini.
  final int notaSelesai;

  /// Jasa kotor yang dihasilkan bulan ini. Ini yang diukur terhadap target
  /// -- bukan bayaran yang diterimanya, dan bukan pula uang yang sudah
  /// masuk kas.
  final double omset;

  final double target;

  double get persenTarget => target <= 0 ? 0 : (omset / target * 100);
  double get kurang => (target - omset).clamp(0, double.infinity);
}

/// Ringkasan tiap teknisi aktif, terbanyak omsetnya di depan.
///
/// Omsetnya dihitung ulang lewat kalkulator yang sama dengan laporan, bukan
/// dijumlahkan sendiri di sini. Dua rumus untuk satu angka adalah cara
/// paling cepat membuat dua layar tidak sepakat.
final ringkasTeknisiProvider = Provider<List<RingkasTeknisi>>((ref) {
  final nota =
      ref.watch(serviceOrdersProvider).valueOrNull ??
      const <ServiceOrderEntry>[];
  final orang = ref.watch(techniciansProvider).valueOrNull ?? const <Profile>[];
  final aturan = ref.watch(omsetSettingsProvider).valueOrNull;

  final kini = DateTime.now();
  final hasil = hitungOmsetPeriode(
    nota: nota,
    dari: DateTime(kini.year, kini.month),
    sampai: DateTime(
      kini.year,
      kini.month + 1,
    ).subtract(const Duration(milliseconds: 1)),
    aturan: aturan,
  );
  final omset = {for (final t in hasil.teknisi) t.teknisiId: t};

  final berjalan = <String, int>{};
  for (final n in nota) {
    final id = n.teknisiId;
    if (id == null) continue;
    if (!ServiceStatus.sedangDikerjakan(n.status)) continue;
    berjalan.update(id, (v) => v + 1, ifAbsent: () => 1);
  }

  return [
    for (final p in orang)
      RingkasTeknisi(
        teknisi: p,
        unitBerjalan: berjalan[p.id] ?? 0,
        notaSelesai: omset[p.id]?.jumlahNota ?? 0,
        omset: omset[p.id]?.omset ?? 0,
        target: aturan?.targetOmset ?? 4000000,
      ),
  ]..sort((a, b) {
    // Yang sedang memegang unit didahulukan; di antara yang sama, yang
    // omsetnya lebih besar di depan.
    final beban = b.unitBerjalan.compareTo(a.unitBerjalan);
    return beban != 0 ? beban : b.omset.compareTo(a.omset);
  });
});

/// Ringkasan milik pengguna yang sedang login. Null bila dia bukan teknisi
/// atau datanya belum sampai.
final ringkasSayaProvider = Provider<RingkasTeknisi?>((ref) {
  final id = ref.watch(currentUserProvider)?.id;
  if (id == null) return null;
  for (final r in ref.watch(ringkasTeknisiProvider)) {
    if (r.teknisi.id == id) return r;
  }
  return null;
});
