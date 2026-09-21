import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/kaca/overlay_kaca.dart';
import '../../core/omset/omset_providers.dart';
import '../../core/omset/peringatan_omset.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../service/teknisi_ringkas.dart';

final _rp = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);

/// Sudah diputuskan untuk aplikasi yang sedang berjalan ini -- ditampilkan,
/// atau memang tidak perlu. Hidup selama proses aplikasinya, jadi begitu
/// aplikasi dibuka lagi ia kembali false dan peringatannya diperiksa ulang.
final peringatanOmsetSudahProvider = StateProvider<bool>((ref) => false);

/// Hari yang dipakai untuk menentukan masa peringatan. Dipisah supaya bisa
/// diganti saat diuji.
final hariPeringatanProvider = Provider<DateTime>((ref) => DateTime.now());

/// Membungkus layar utama dan, SETIAP KALI aplikasi dibuka, mengingatkan
/// admin siapa saja yang omsetnya masih di bawah target -- selama masa
/// peringatan, yaitu beberapa hari terakhir sebelum ganti bulan.
///
/// Hanya admin: yang membagi pekerjaan dan bisa mendorong omset adalah
/// admin. Teknisi melihat omsetnya sendiri di Pekerjaanku.
///
/// Sekali per aplikasi dibuka, bukan tiap berpindah halaman. Peringatan
/// yang muncul lagi setiap kali halaman berganti berhenti dibaca sejak
/// kali ketiga.
class PeringatanOmsetPembuka extends ConsumerStatefulWidget {
  const PeringatanOmsetPembuka({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PeringatanOmsetPembuka> createState() =>
      _PeringatanOmsetPembukaState();
}

class _PeringatanOmsetPembukaState
    extends ConsumerState<PeringatanOmsetPembuka> {
  void _periksa() {
    if (!mounted || ref.read(peringatanOmsetSudahProvider)) return;
    // Ditandai lebih dulu: pemeriksaannya berjalan setelah frame, dan
    // frame berikutnya bisa datang sebelum dialognya sempat muncul.
    ref.read(peringatanOmsetSudahProvider.notifier).state = true;

    final aturan = ref.read(omsetSettingsProvider).valueOrNull;
    final hari = ref.read(hariPeringatanProvider);
    final hariSebelum =
        aturan?.hariPeringatanOmset ?? hariPeringatanOmsetBawaan;

    if (!masaPeringatanOmset(hari, hariSebelum)) return;

    // Sudah terurut dari omset terendah.
    final kurang = [
      for (final r in ref.read(ringkasTeknisiProvider))
        if (r.dibawahTarget) r,
    ];
    if (kurang.isEmpty) return;

    tampilkanDialog<void>(
      context: context,
      builder: (_) => _DialogPeringatanOmset(
        kurang: kurang,
        sisaHari: sisaHariSebelumGantiBulan(hari),
        target: kurang.first.target,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Menunggu semua yang dibutuhkan sampai: siapa yang login, nota, dan
    // aturan omset. Peringatan yang dihitung dari data yang belum lengkap
    // menyebut semua orang kurang, lalu menghilang begitu datanya datang.
    final siap =
        ref.watch(isAdminProvider) &&
        ref.watch(serviceOrdersProvider).hasValue &&
        ref.watch(omsetSettingsProvider).hasValue &&
        ref.watch(allProfilesProvider).hasValue;

    if (siap && !ref.watch(peringatanOmsetSudahProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _periksa());
    }

    return widget.child;
  }
}

class _DialogPeringatanOmset extends StatelessWidget {
  const _DialogPeringatanOmset({
    required this.kurang,
    required this.sisaHari,
    required this.target,
  });

  final List<RingkasTeknisi> kurang;
  final int sisaHari;
  final double target;

  @override
  Widget build(BuildContext context) {
    final w = context.warna;

    return AlertDialog(
      backgroundColor: w.permukaan,
      title: Text(
        'OMSET BULAN INI',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sisaHari <= 1
                  ? 'Hari terakhir bulan ini.'
                  : 'Sisa $sisaHari hari sebelum ganti bulan.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: w.bahaya,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${kurang.length} teknisi masih di bawah target '
              '${_rp.format(target)}, dari yang paling tertinggal:',
              style: TextStyle(fontSize: 12.5, color: w.teksLembut),
            ),
            const SizedBox(height: AppSpacing.s),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final r in kurang)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: w.garisHalus),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.teknisi.nama,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '${_rp.format(r.omset)}  ·  '
                                    '${r.persenTarget.round()}% dari target',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: w.teksLembut,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'KURANG',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                                Text(
                                  _rp.format(r.kurang),
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: w.bahaya,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              'Beri mereka unit lebih dulu — antriannya ada di Servis Baru.',
              style: TextStyle(fontSize: 11.5, color: w.teksLembut),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('MENGERTI'),
        ),
      ],
    );
  }
}
