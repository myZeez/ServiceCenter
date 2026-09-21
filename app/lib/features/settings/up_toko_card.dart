import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/data/galat.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/bento.dart';
import '../../core/widgets/swiss_widgets.dart';

final _persen = NumberFormat('#,##0.#', 'id_ID');

/// Pilihan persentase yang ditawarkan saat menetapkan harga part.
///
/// Ada di sini, bukan dikunci di kode, karena angkanya mengikuti keadaan
/// pasar. Yang menjaga toko harus bisa mengubahnya saat itu juga — bukan
/// menunggu aplikasi dibangun ulang.
class UpTokoCard extends ConsumerStatefulWidget {
  const UpTokoCard({super.key});

  @override
  ConsumerState<UpTokoCard> createState() => _UpTokoCardState();
}

class _UpTokoCardState extends ConsumerState<UpTokoCard> {
  final _baru = TextEditingController();

  /// Salinan yang sedang disunting. Null berarti belum pernah dibaca dari
  /// server; sesudah itu daftar inilah yang dipercaya, supaya isian yang
  /// sedang diketik tidak tertimpa tiap kali alirannya berdenyut.
  List<double>? _pilihan;
  double? _bawaan;

  bool _busy = false;

  @override
  void dispose() {
    _baru.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    final pilihan = _pilihan;
    if (pilihan == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(databaseProvider).simpanPartSettings({
        'up_toko_pilihan': pilihan,
        // Bawaan yang tidak ada di daftarnya akan tampil sebagai dropdown
        // kosong di formulir harga; dirapikan di sini supaya keadaan itu
        // tidak pernah sampai ke sana.
        'up_toko_bawaan': pilihan.contains(_bawaan)
            ? _bawaan
            : (pilihan.isEmpty ? 0 : pilihan.first),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilihan up toko tersimpan')),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(pesanGalat(e))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(pesanGalat(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _tambah() {
    final v = double.tryParse(_baru.text.trim().replaceAll(',', '.'));
    if (v == null || v < 0) return;

    final daftar = [...?_pilihan];
    if (daftar.contains(v)) return;

    daftar.add(v);
    daftar.sort();
    setState(() {
      _pilihan = daftar;
      _bawaan ??= v;
      _baru.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tersimpan = ref.watch(partSettingsProvider).valueOrNull;
    if (_pilihan == null && tersimpan != null) {
      _pilihan = [...tersimpan.upTokoPilihan];
      _bawaan = tersimpan.upTokoBawaan;
    }

    final pilihan = _pilihan ?? const <double>[];

    return BentoCard(
      title: 'Up Toko Penjualan Part',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: context.warna.aksen.withValues(alpha: 0.05),
                border: Border(
                  left: BorderSide(color: context.warna.aksen, width: 3),
                ),
              ),
              child: Text(
                'Persentase dihitung di atas modal. Modal Rp 100.000 dengan '
                'up 20% dijual Rp 120.000.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: context.warna.aksen,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s),

            const SectionLabel('Pilihan'),
            const SizedBox(height: AppSpacing.s),
            if (pilihan.isEmpty)
              Text(
                'Belum ada pilihan. Formulir harga akan memakai 10/15/20 '
                'sampai daftar ini diisi.',
                style: Theme.of(context).textTheme.labelSmall,
              )
            else
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final p in pilihan)
                    _Chip(
                      persen: p,
                      bawaan: p == _bawaan,
                      onJadikanBawaan: () => setState(() => _bawaan = p),
                      onHapus: () => setState(() {
                        final sisa = [...pilihan]..remove(p);
                        _pilihan = sisa;
                        if (_bawaan == p) {
                          _bawaan = sisa.isEmpty ? null : sisa.first;
                        }
                      }),
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Ketuk sebuah angka untuk menjadikannya bawaan — itu yang '
              'terpilih sendiri saat tanya harga baru dibuat.',
              style: Theme.of(context).textTheme.labelSmall,
            ),

            const SizedBox(height: AppSpacing.s),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: LabeledField(
                    label: 'Tambah Persentase',
                    child: TextField(
                      controller: _baru,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: const InputDecoration(suffixText: '%'),
                      onSubmitted: (_) => _tambah(),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                OutlinedButton(onPressed: _tambah, child: const Text('TAMBAH')),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _busy || _pilihan == null ? null : _simpan,
                child: _busy
                    ? SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.warna.kertas,
                        ),
                      )
                    : const Text('SIMPAN'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.persen,
    required this.bawaan,
    required this.onJadikanBawaan,
    required this.onHapus,
  });

  final double persen;
  final bool bawaan;
  final VoidCallback onJadikanBawaan;
  final VoidCallback onHapus;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onJadikanBawaan,
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpacing.s, 6, 4, 6),
        decoration: BoxDecoration(
          color: bawaan ? context.warna.teks : Colors.transparent,
          border: Border.all(
            color: bawaan ? context.warna.teks : context.warna.garisIsian,
          ),
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_persen.format(persen)}%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: bawaan ? context.warna.kertas : context.warna.teks,
              ),
            ),
            if (bawaan) ...[
              const SizedBox(width: 6),
              Text(
                'BAWAAN',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: context.warna.kertas,
                ),
              ),
            ],
            IconButton(
              tooltip: 'Hapus pilihan ini',
              iconSize: 14,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
              color: bawaan ? context.warna.kertas : context.warna.teksLembut,
              icon: const Icon(Icons.close),
              onPressed: onHapus,
            ),
          ],
        ),
      ),
    );
  }
}
