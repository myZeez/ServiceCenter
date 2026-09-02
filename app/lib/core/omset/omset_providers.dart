import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/database.dart';
import '../providers.dart';
import 'omset_calculator.dart';

final omsetSettingsProvider = StreamProvider<ServiceSettingsRow?>(
  (ref) => ref.watch(databaseProvider).watchServiceSettings(),
);

/// Menghitung omset satu periode dari nota yang pekerjaannya sudah selesai
/// pada rentang itu.
///
/// Yang menentukan periode adalah tanggal selesai, bukan tanggal masuk atau
/// tanggal pelunasan: omset adalah pekerjaan yang dikerjakan bulan itu.
OmsetResult hitungOmsetPeriode({
  required List<ServiceOrderEntry> nota,
  required DateTime dari,
  required DateTime sampai,
  required ServiceSettingsRow? aturan,
}) {
  final dipakai = nota.where((n) {
    final selesai = n.tanggalSelesai;
    if (selesai == null) return false;
    if (n.status == 'batal') return false;
    return !selesai.isBefore(dari) && !selesai.isAfter(sampai);
  });

  return hitungOmset(
    nota: [
      for (final n in dipakai)
        OmsetNota(
          teknisiId: n.teknisiId,
          biaya: n.biaya,
          lunas: n.tanggalLunas != null,
        ),
    ],
    settings: OmsetSettings(
      targetTeknisi: aturan?.targetOmset ?? 4000000,
      feeAdminPerNota: aturan?.feeAdminPerNota ?? 0,
    ),
  );
}
