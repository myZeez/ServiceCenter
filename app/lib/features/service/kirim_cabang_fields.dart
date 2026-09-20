import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/swiss_widgets.dart';
import 'service_status.dart';

final _tglTampil = DateFormat('dd-MM-yyyy');

/// Lebar minimum agar cabang dan tanggal bisa berdampingan. Di bawahnya --
/// lembar ubah di HP -- keduanya ditumpuk: labelnya tidak punya tempat untuk
/// menyusut, dan meluap.
const _lebarBerdampingan = 460.0;

/// Hari ini sebagai tanggal kalender, tanpa jam. Tanggal kirim adalah hari
/// unitnya keluar dari toko -- hari kalender, bukan hari laporan yang
/// bergeser sesudah jam tutup dan melompati hari libur.
DateTime hariIniKalender([DateTime? saat]) {
  final s = saat ?? DateTime.now();
  return DateTime(s.year, s.month, s.day);
}

/// Cabang tujuan dan tanggal kirim, yang hanya berlaku untuk status
/// Dikirim ke Cabang.
///
/// Dipakai di formulir nota (desktop) dan lembar ubah pekerjaan (HP), supaya
/// keduanya menuliskan hal yang sama dengan cara yang sama.
///
/// Tanggalnya sudah terisi hari ini saat status dipilih, dan bisa diubah:
/// unit yang dikirim kemarin tetapi baru dicatat hari ini tidak boleh
/// tercatat terkirim hari ini.
class KirimCabangFields extends ConsumerWidget {
  const KirimCabangFields({
    super.key,
    required this.cabang,
    required this.tanggal,
    required this.onCabang,
    required this.onTanggal,
  });

  final String? cabang;
  final DateTime tanggal;
  final ValueChanged<String?> onCabang;
  final ValueChanged<DateTime> onTanggal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daftar = ref.watch(cabangProvider);

    // Cabang yang tercatat di nota tetap menjadi pilihan walau sudah
    // dihapus dari daftar di Pengaturan: dropdown yang nilainya tidak ada
    // di antara pilihannya melempar galat, dan nota lama harus tetap
    // menyebut cabang yang sebenarnya.
    final pilihan = [
      ...daftar,
      if (cabang != null && cabang!.isNotEmpty && !daftar.contains(cabang))
        cabang!,
    ];

    final w = context.warna;

    final kolomCabang = LabeledField(
      label: 'Cabang Tujuan',
      required: true,
      child: DropdownButtonFormField<String>(
        initialValue: cabang,
        isExpanded: true,
        hint: const Text('Pilih cabang'),
        items: [
          for (final c in pilihan) DropdownMenuItem(value: c, child: Text(c)),
        ],
        validator: (v) => v == null ? 'Pilih cabang tujuan' : null,
        onChanged: onCabang,
      ),
    );

    final kolomTanggal = LabeledField(
      label: 'Tanggal Dikirim',
      child: OutlinedButton(
        onPressed: () async {
          final p = await showDatePicker(
            context: context,
            initialDate: tanggal,
            firstDate: DateTime(2020),
            lastDate: hariIniKalender().add(const Duration(days: 365)),
          );
          if (p != null) onTanggal(hariIniKalender(p));
        },
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          side: BorderSide(color: w.garisIsian, width: 1),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s,
            vertical: 13,
          ),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _tglTampil.format(tanggal),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: w.teks,
            ),
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, batas) => batas.maxWidth >= _lebarBerdampingan
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: kolomCabang),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(flex: 2, child: kolomTanggal),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    kolomCabang,
                    const SizedBox(height: AppSpacing.s),
                    kolomTanggal,
                  ],
                ),
        ),

        // Kalimat yang akan dibaca di nota dan laporan, ditampilkan sebelum
        // disimpan -- yang salah cabang atau salah tanggal terlihat di sini,
        // bukan tiga hari kemudian di laporan.
        if (cabang != null && cabang!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s),
            decoration: BoxDecoration(
              color: w.aksen.withValues(alpha: 0.05),
              border: Border(left: BorderSide(color: w.aksen, width: 3)),
            ),
            child: Text(
              ServiceStatus.keteranganKirim(cabang!, tanggal),
              style: TextStyle(fontSize: 13, color: w.teks),
            ),
          ),
        ],
      ],
    );
  }
}
