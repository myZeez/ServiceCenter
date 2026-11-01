import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/omset/omset_providers.dart';
import '../../../core/omset/skor_omset.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/bento.dart';

const _namaBulan = [
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

String _bulanPendek(DateTime t) =>
    '${_namaBulan[t.month - 1].substring(0, 3)} ${t.year}';

String _rupiah(double nilai) =>
    'Rp${nilai.round().toString().replaceAllMapped(RegExp(r'(?=(\d{3})+(?!\d))'), (m) => '.')}';

String _persen(double p) =>
    '${p.toStringAsFixed(1).replaceAll('.', ',').replaceAll(',0', '')}%';

/// Omset bulan-bulan penuh terakhir milik pengguna yang login, dari yang
/// terlama. Paling banyak dua belas bulan.
final omsetBulananSayaProvider = Provider<List<OmsetBulan>>((ref) {
  final id = ref.watch(currentUserProvider)?.id;
  if (id == null) return const [];
  return omsetBulananTeknisi(
    nota: ref.watch(serviceOrdersProvider).valueOrNull ?? const [],
    teknisiId: id,
    kini: DateTime.now(),
    aturan: ref.watch(omsetSettingsProvider).valueOrNull,
  );
});

final _targetProvider = Provider<double>(
  (ref) => ref.watch(omsetSettingsProvider).valueOrNull?.targetOmset ?? 4000000,
);

/// Skor tiga bulan dan dua belas bulan terakhir. Keduanya diambil dari daftar
/// bulan yang sama, supaya tidak pernah berbeda pendapat soal satu bulan.
final skorSayaProvider = Provider<({SkorOmset? tigaBulan, SkorOmset? setahun})>(
  (ref) {
    final bulan = ref.watch(omsetBulananSayaProvider);
    final target = ref.watch(_targetProvider);
    return (
      tigaBulan: hitungSkorOmset(
        bulan.sublist(math.max(0, bulan.length - 3)),
        target,
      ),
      setahun: hitungSkorOmset(bulan, target),
    );
  },
);

/// Omset bulan-bulan sebelumnya, untuk tab Sudah Selesai.
///
/// Satu strip mendatar, terbaru di kiri: isi utama tab itu adalah daftar
/// nota yang sudah selesai, dan dua belas baris omset di atasnya akan
/// mendorong nota pertama ke luar layar.
class RiwayatOmsetCard extends ConsumerWidget {
  const RiwayatOmsetCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bulan = ref.watch(omsetBulananSayaProvider).reversed.toList();
    final target = ref.watch(_targetProvider);
    return BentoCard(
      title: 'Omset Bulan Sebelumnya',
      trailing: Text(
        bulan.isEmpty ? '' : '${bulan.length} BULAN',
        style: Theme.of(context).textTheme.labelSmall,
      ),
      child: bulan.isEmpty
          ? Text(
              'Belum ada bulan sebelumnya yang tercatat.',
              style: TextStyle(color: context.warna.teksLembut),
            )
          : SizedBox(
              height: 54,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: bulan.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.xs),
                itemBuilder: (_, i) =>
                    _UbinBulan(bulan: bulan[i], target: target),
              ),
            ),
    );
  }
}

class _UbinBulan extends StatelessWidget {
  const _UbinBulan({required this.bulan, required this.target});

  final OmsetBulan bulan;
  final double target;

  @override
  Widget build(BuildContext context) {
    final rasio = target <= 0 ? 0.0 : bulan.omset / target;
    // Bingkai beraksen menandai bulan yang mencapai target; bilah kemajuan
    // sengaja tidak dipakai supaya stripnya tetap pendek.
    final tercapai = rasio >= 1;
    return Container(
      width: 118,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(
          color: tercapai ? context.warna.aksen : context.warna.garisHalus,
          width: tercapai ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${_bulanPendek(bulan.bulan).toUpperCase()}  ${_persen(rasio * 100)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: tercapai ? context.warna.aksen : context.warna.teksLembut,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _rupiah(bulan.omset),
            maxLines: 1,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Isi tab Skor: skor tiga bulan dan dua belas bulan terakhir.
class SkorSaya extends ConsumerWidget {
  const SkorSaya({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skor = ref.watch(skorSayaProvider);
    final target = ref.watch(_targetProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _KartuSkor(judul: '3 Bulan Terakhir', skor: skor.tigaBulan),
        const SizedBox(height: AppSpacing.s),
        _KartuSkor(judul: '12 Bulan Terakhir', skor: skor.setahun),
        const SizedBox(height: AppSpacing.s),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text(
            'Skor = rata-rata omset bulanan dibanding target. Rata-rata '
            '${_rupiah(target)} bernilai 50%, ${_rupiah(target * 2)} ke atas '
            'bernilai 100%. Hanya bulan yang sudah lewat yang dinilai.\n'
            'Bintang 5: 90-100%  -  4: 75-89%  -  3: 60-74%  -  '
            '2: 40-59%  -  1: di bawah 40%.',
            style: TextStyle(fontSize: 11, color: context.warna.teksLembut),
          ),
        ),
      ],
    );
  }
}

class _KartuSkor extends StatelessWidget {
  const _KartuSkor({required this.judul, required this.skor});

  final String judul;
  final SkorOmset? skor;

  @override
  Widget build(BuildContext context) {
    final s = skor;
    return BentoCard(
      title: judul,
      trailing: s == null
          ? null
          : Text(
              s.bulan.length == 1
                  ? _bulanPendek(s.bulan.first.bulan).toUpperCase()
                  : '${_bulanPendek(s.bulan.first.bulan)} - '
                            '${_bulanPendek(s.bulan.last.bulan)}'
                        .toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall,
            ),
      accent: s != null && s.bintang == 5 ? context.warna.aksen : null,
      child: s == null
          ? Text(
              'Belum ada bulan penuh untuk dinilai.',
              style: TextStyle(color: context.warna.teksLembut),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _persen(s.persen),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.2,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(child: Bintang(jumlah: s.bintang)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  s.predikat.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: s.bintang == 5
                        ? context.warna.aksen
                        : context.warna.teks,
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                Container(height: 1, color: context.warna.garisHalus),
                const SizedBox(height: AppSpacing.s),
                _Rincian(
                  label: 'Rata-rata per bulan',
                  nilai: '${_rupiah(s.rataRata)}  (${s.bulan.length} bulan)',
                ),
                _Rincian(
                  label: 'Terendah',
                  nilai:
                      '${_rupiah(s.terendah.omset)}  '
                      '${_bulanPendek(s.terendah.bulan)}',
                ),
                _Rincian(
                  label: 'Tertinggi',
                  nilai:
                      '${_rupiah(s.tertinggi.omset)}  '
                      '${_bulanPendek(s.tertinggi.bulan)}',
                ),
              ],
            ),
    );
  }
}

class _Rincian extends StatelessWidget {
  const _Rincian({required this.label, required this.nilai});

  final String label;
  final String nilai;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: context.warna.teksLembut),
          ),
        ),
        Text(nilai, style: const TextStyle(fontSize: 12)),
      ],
    ),
  );
}

/// Lima bintang, [jumlah] di antaranya terisi.
class Bintang extends StatelessWidget {
  const Bintang({super.key, required this.jumlah});

  final int jumlah;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Bintang $jumlah dari 5',
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              i <= jumlah ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 24,
              color: i <= jumlah
                  ? context.warna.aksen
                  : context.warna.teksLembut,
            ),
        ],
      ),
    ),
  );
}
