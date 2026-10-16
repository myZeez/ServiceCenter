import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../providers.dart';
import 'omset_calculator.dart';

final omsetSettingsProvider = StreamProvider<ServiceSettingsRow?>(
  (ref) => ref.watch(databaseProvider).watchServiceSettings(),
);

/// Menghitung omzet jasa satu periode dari pekerjaan yang sudah rampung.
///
/// Yang menentukan periode adalah tanggal selesai; ini mencatat nilai jasa
/// saat pekerjaan dihasilkan. Piutang ikut omzet utama dan target teknisi,
/// tetapi nominalnya tetap terpisah di [OmsetResult.piutang] agar mudah
/// ditagih dari halaman Piutang.
OmsetResult hitungOmsetPeriode({
  required List<ServiceOrderEntry> nota,
  required DateTime dari,
  required DateTime sampai,
  required ServiceSettingsRow? aturan,
}) {
  final dipakai = nota.where((n) {
    if (n.status == 'batal') return false;
    if (n.status != 'selesai' &&
        n.status != 'diambil' &&
        n.status != 'dikirim_cabang') {
      return false;
    }
    // Arsip lama kadang hanya punya tanggal diambil. Jadikan ia cadangan
    // supaya omzet historis tidak hilang hanya karena kolom selesai belum
    // tercatat pada aplikasi lama.
    final selesai = n.tanggalSelesai ?? n.tanggalDiambil ?? n.tanggalKirim;
    if (selesai == null) return false;
    return !selesai.isBefore(dari) && !selesai.isAfter(sampai);
  });

  return hitungOmset(
    nota: [
      for (final n in dipakai)
        OmsetNota(
          teknisiId: n.teknisiId,
          biaya: n.biaya,
          // Tanggal lunas pada kirim cabang adalah tanggal buku pengiriman,
          // bukan bukti kas diterima. Piutang ditentukan oleh metodenya.
          lunas: n.tanggalLunas != null && n.caraBayar != 'piutang',
        ),
    ],
    settings: OmsetSettings(
      targetTeknisi: aturan?.targetOmset ?? 4000000,
      feeAdminPerNota: aturan?.feeAdminPerNota ?? 0,
    ),
  );
}
