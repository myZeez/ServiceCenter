import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/models.dart';
import '../../core/omset/omset_providers.dart';
import '../../core/omset/peringatan_omset.dart';
import '../../core/providers.dart';
import 'service_status.dart';

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
  double get kurang => kurangDariTarget(omset, target);

  /// Masih di bawah target omset bulan ini. Diukur dengan rupiah, bukan
  /// jumlah unit selesai: dua unit besar bisa melampaui lima unit kecil.
  bool get dibawahTarget => dibawahTargetOmset(omset, target);
}

/// Ringkasan tiap teknisi aktif, YANG OMSETNYA TERENDAH DI DEPAN.
///
/// Urutannya sengaja begitu: yang paling tertinggal dari target adalah yang
/// paling perlu diberi unit berikutnya, dan yang paling perlu perhatian
/// ditaruh di atas, bukan di ujung daftar yang harus digulir untuk
/// menemukannya. Sebelumnya urutannya menurut jumlah unit yang dipegang --
/// yang paling penuh di depan -- dan itu menjawab pertanyaan yang salah.
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
    // Omset terendah di depan. Yang sama persis (mis. dua-duanya Rp0)
    // diurutkan menurut nama, supaya urutannya tidak berubah-ubah setiap
    // kali datanya dimuat ulang.
    final omset = a.omset.compareTo(b.omset);
    return omset != 0 ? omset : _menurutNama(a.teknisi, b.teknisi);
  });
});

/// Menurut nama tanpa membedakan huruf besar dan kecil: "admin" ditulis dengan
/// huruf kecil dan "Aris" dengan huruf besar, dan dibandingkan apa adanya
/// yang pertama jatuh ke paling belakang.
int _menurutNama(Profile a, Profile b) =>
    a.nama.toLowerCase().compareTo(b.nama.toLowerCase());

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
