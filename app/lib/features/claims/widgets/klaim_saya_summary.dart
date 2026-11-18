import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/models.dart';
import '../../../core/providers.dart';
import '../../../core/revenue/revenue_providers.dart';
import '../../../core/status.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/bento.dart';
import '../../../core/widgets/swiss_widgets.dart';

String _tanggalRingkas(DateTime tanggal, {bool denganTahun = false}) {
  const bulan = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  return '${tanggal.day} ${bulan[tanggal.month - 1]}'
      '${denganTahun ? ' ${tanggal.year}' : ''}';
}

/// Klaim milik pengguna yang login dalam periode ringkasan yang dipilih.
final _klaimSayaProvider = Provider.autoDispose<AsyncValue<List<Claim>>>((ref) {
  final p = ref.watch(periodeProvider);
  final id = ref.watch(currentUserProvider)?.id;
  if (id == null) return const AsyncValue.data([]);

  return ref
      .watch(allClaimsProvider)
      .whenData(
        (list) => list
            .where(
              (c) =>
                  c.teknisiId == id &&
                  !c.tanggal.isBefore(p.dari) &&
                  !c.tanggal.isAfter(p.sampai),
            )
            .toList(),
      );
});

/// Ringkasan klaim teknisi yang dapat dipakai di halaman Klaim maupun
/// Pekerjaanku desktop. Pilihan periode hanya berlaku untuk ringkasan ini.
class KlaimSayaSummary extends ConsumerWidget {
  const KlaimSayaSummary({super.key, this.judul = 'Ringkasan Klaim Saya'});

  final String judul;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periode = ref.watch(periodeProvider);
    final klaim = ref.watch(_klaimSayaProvider).valueOrNull;
    final brands = ref.watch(namaBrandProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(judul, trailing: const _PeriodeDropdown()),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Klaim atas namamu yang masuk '
          '${_tanggalRingkas(periode.dari)} — '
          '${_tanggalRingkas(periode.sampai, denganTahun: true)}',
          style: TextStyle(fontSize: 12, color: context.warna.teksLembut),
        ),
        const SizedBox(height: AppSpacing.s),
        if (klaim == null)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else
          _Garansi(klaim: klaim, brands: brands),
      ],
    );
  }
}

class _Garansi extends StatelessWidget {
  const _Garansi({required this.klaim, required this.brands});

  final List<Claim> klaim;
  final Map<int, String> brands;

  @override
  Widget build(BuildContext context) {
    final selesai = klaim.where((c) => ClaimStatus.isTuntas(c.status)).toList();
    final perStatus = <String, int>{};
    for (final c in klaim) {
      perStatus.update(c.status, (v) => v + 1, ifAbsent: () => 1);
    }

    final perBrand = <int, int>{};
    for (final c in selesai) {
      perBrand.update(c.brandId, (v) => v + 1, ifAbsent: () => 1);
    }
    final urut = perBrand.keys.toList()
      ..sort((a, b) => perBrand[b]!.compareTo(perBrand[a]!));

    return BentoCard(
      title: 'Ringkasan Garansi',
      accent: context.warna.bahaya,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (context, batas) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 104,
                  child: _UnitSelesai(
                    selesai: selesai.length,
                    total: klaim.length,
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: _SelesaiPerBrand(
                    urut: urut,
                    perBrand: perBrand,
                    brands: brands,
                    lebarMaks: batas.maxWidth - 104 - AppSpacing.s,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          Container(height: 1, color: context.warna.garisHalus),
          const SizedBox(height: AppSpacing.s),
          Text('STATUS KLAIM', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          if (perStatus.isEmpty)
            Text(
              'Belum ada klaim atas namamu di periode ini.',
              style: Theme.of(context).textTheme.labelSmall,
            )
          else
            LayoutBuilder(
              builder: (context, batas) {
                final kolom = batas.maxWidth >= 560 ? 3 : 2;
                final celah = AppSpacing.xs * (kolom - 1);
                final lebar = (batas.maxWidth - celah) / kolom;
                return Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final status in ClaimStatus.all)
                      if ((perStatus[status] ?? 0) > 0)
                        SizedBox(
                          width: lebar,
                          child: _StatusRingkas(
                            status: status,
                            jumlah: perStatus[status]!,
                          ),
                        ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _UnitSelesai extends StatelessWidget {
  const _UnitSelesai({required this.selesai, required this.total});

  final int selesai;
  final int total;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '$selesai',
        style: const TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w700,
          letterSpacing: -2,
          height: 1,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        'UNIT GARANSI SELESAI',
        style: Theme.of(context).textTheme.labelSmall,
      ),
      const SizedBox(height: 3),
      Text(
        'dari $total klaim',
        style: TextStyle(fontSize: 11, color: context.warna.teksLembut),
      ),
    ],
  );
}

class _SelesaiPerBrand extends StatelessWidget {
  const _SelesaiPerBrand({
    required this.urut,
    required this.perBrand,
    required this.brands,
    required this.lebarMaks,
  });

  final List<int> urut;
  final Map<int, int> perBrand;
  final Map<int, String> brands;
  final double lebarMaks;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('SELESAI PER BRAND', style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(height: AppSpacing.xs),
      if (urut.isEmpty)
        Text(
          'Belum ada unit selesai.',
          style: TextStyle(fontSize: 11, color: context.warna.teksLembut),
        )
      else
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final id in urut)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: lebarMaks),
                child: _BrandRingkas(
                  brand: brands[id] ?? '—',
                  jumlah: perBrand[id]!,
                ),
              ),
          ],
        ),
    ],
  );
}

class _BrandRingkas extends StatelessWidget {
  const _BrandRingkas({required this.brand, required this.jumlah});

  final String brand;
  final int jumlah;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    decoration: BoxDecoration(
      border: Border.all(color: context.warna.garisHalus),
      borderRadius: BorderRadius.circular(AppRadius.small),
    ),
    child: Text(
      '$brand  $jumlah',
      softWrap: true,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}

class _StatusRingkas extends StatelessWidget {
  const _StatusRingkas({required this.status, required this.jumlah});

  final String status;
  final int jumlah;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      border: Border.all(color: context.warna.garisHalus),
      borderRadius: BorderRadius.circular(AppRadius.small),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            ClaimStatus.label(status),
            maxLines: 2,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$jumlah',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _PeriodeDropdown extends ConsumerWidget {
  const _PeriodeDropdown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = Periode.daftar();
    final selected = ref.watch(periodeProvider);

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
      decoration: BoxDecoration(
        color: context.warna.permukaan,
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(color: context.warna.teks),
      ),
      child: Center(
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selected.label,
            isDense: true,
            focusColor: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.base),
            icon: const Icon(Icons.expand_more, size: 16),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: context.warna.teks,
            ),
            onChanged: (v) => ref.read(periodeProvider.notifier).state = list
                .firstWhere((e) => e.label == v),
            items: [
              for (final p in list)
                DropdownMenuItem(value: p.label, child: Text(p.label)),
            ],
          ),
        ),
      ),
    );
  }
}
