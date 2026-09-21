import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/bento.dart';
import '../teknisi_ringkas.dart';

String _bulanTahun(DateTime tanggal) {
  const bulan = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  return '${bulan[tanggal.month - 1]} ${tanggal.year}';
}

String _rupiah(double nilai) =>
    'Rp${nilai.round().toString().replaceAllMapped(RegExp(r'(?=(\d{3})+(?!\d))'), (m) => '.')}';

/// Omset jasa servis teknisi yang sedang login pada bulan berjalan.
///
/// Diletakkan di Servisku agar angka kerja pribadi selalu berdampingan
/// dengan daftar unit yang membentuknya. MyWorkView desktop memakai kartu
/// yang sama supaya perhitungannya tidak bercabang.
class OmsetSayaCard extends ConsumerWidget {
  const OmsetSayaCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(ringkasSayaProvider);
    if (r == null) return const SizedBox.shrink();

    final persen = (r.persenTarget / 100).clamp(0.0, 1.0);
    final kini = DateTime.now();

    return BentoCard(
      title: 'Servis Bulan Ini',
      trailing: Text(
        _bulanTahun(kini).toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall,
      ),
      accent: context.warna.aksen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('OMSET', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(
            _rupiah(r.omset),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.2,
              height: 1.1,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: persen,
              minHeight: 8,
              backgroundColor: context.warna.teredam,
              valueColor: AlwaysStoppedAnimation(
                persen >= 1 ? context.warna.aksen : context.warna.teks,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            r.kurang <= 0
                ? 'Target ${_rupiah(r.target)} sudah tercapai'
                : 'Kurang ${_rupiah(r.kurang)} dari target '
                      '${_rupiah(r.target)}',
            style: TextStyle(fontSize: 11.5, color: context.warna.teksLembut),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(height: 1, color: context.warna.garisHalus),
          const SizedBox(height: AppSpacing.s),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _AngkaBesar(
                  nilai: r.notaSelesai,
                  label: 'Unit selesai dikerjakan',
                ),
              ),
              Expanded(
                child: _AngkaBesar(
                  nilai: r.unitBerjalan,
                  label: 'Masih dikerjakan',
                  lembut: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AngkaBesar extends StatelessWidget {
  const _AngkaBesar({
    required this.nilai,
    required this.label,
    this.lembut = false,
  });

  final int nilai;
  final String label;
  final bool lembut;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '$nilai',
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.2,
          height: 1,
          color: lembut ? context.warna.teksLembut : context.warna.teks,
        ),
      ),
      const SizedBox(height: 4),
      Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
    ],
  );
}
