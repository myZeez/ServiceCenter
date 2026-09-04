import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/models.dart';
import '../../core/providers.dart';
import '../../core/revenue/revenue_providers.dart';
import '../../core/status.dart';
import '../../core/theme.dart';
import '../../core/widgets/bento.dart';

/// Klaim milik pengguna yang sedang login pada periode terpilih.
///
/// Tidak ada angka rupiah di sini: aturan akses di server menahan fee brand
/// supaya tidak pernah sampai ke perangkat teknisi.
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

class MyWorkView extends ConsumerWidget {
  const MyWorkView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periode = ref.watch(periodeProvider);
    final klaim = ref.watch(_klaimSayaProvider).valueOrNull;
    final profile = ref.watch(currentProfileProvider);
    final brands = {
      for (final b
          in ref.watch(allBrandsProvider).valueOrNull ?? const <Brand>[])
        b.id: b.nama,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'Pekerjaanku',
            subtitle: profile == null
                ? null
                : '${profile.nama}  ·  '
                    '${DateFormat('d MMM').format(periode.dari)} — '
                    '${DateFormat('d MMM yyyy').format(periode.sampai)}',
            actions: const [_PeriodeDropdown()],
          ),
          const SizedBox(height: AppSpacing.s),
          Expanded(
            child: klaim == null
                ? const Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _Isi(klaim: klaim, brands: brands),
          ),
        ],
      ),
    );
  }
}

class _Isi extends StatelessWidget {
  const _Isi({required this.klaim, required this.brands});

  final List<Claim> klaim;
  final Map<int, String> brands;

  @override
  Widget build(BuildContext context) {
    final selesai = klaim.where((c) => c.status == ClaimStatus.close).toList();

    final perStatus = <String, int>{};
    for (final c in klaim) {
      perStatus.update(c.status, (v) => v + 1, ifAbsent: () => 1);
    }

    // Hanya unit selesai yang dihitung per brand: itulah yang menjadi dasar
    // bagi hasil, dan itu pula yang ingin diketahui teknisi.
    final perBrand = <int, int>{};
    for (final c in selesai) {
      perBrand.update(c.brandId, (v) => v + 1, ifAbsent: () => 1);
    }

    final urut = perBrand.keys.toList()
      ..sort((a, b) => perBrand[b]!.compareTo(perBrand[a]!));
    final tertinggi = urut.isEmpty ? 1 : perBrand[urut.first]!;

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      children: [
        BentoCard(
          title: 'Unit Selesai',
          accent: AppColors.red,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${selesai.length}',
                style: const TextStyle(
                  fontSize: 46,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -2,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'DARI ${klaim.length} KLAIM ATAS NAMAMU',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s),

        BentoCard(
          title: 'Status Pekerjaan',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final s in ClaimStatus.all)
                if ((perStatus[s] ?? 0) > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Row(
                      children: [
                        StatusChip(s, compact: true),
                        const Spacer(),
                        Text(
                          '${perStatus[s]}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              if (perStatus.isEmpty)
                Text(
                  'Belum ada klaim atas namamu di periode ini.',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s),

        BentoCard(
          title: 'Unit Selesai per Brand',
          child: urut.isEmpty
              ? Text(
                  'Belum ada unit yang selesai di periode ini.',
                  style: Theme.of(context).textTheme.labelSmall,
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final id in urut)
                      BentoBarRow(
                        label: brands[id] ?? '—',
                        value: '${perBrand[id]} unit',
                        // Dibandingkan terhadap brand terbanyak, bukan
                        // terhadap total: yang ingin terlihat adalah brand
                        // mana yang paling banyak dikerjakan.
                        fraction: perBrand[id]! / tertinggi,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
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
        border: Border.all(color: AppColors.black),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected.label,
          isDense: true,
          focusColor: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.base),
          icon: const Icon(Icons.expand_more, size: 16),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: AppColors.black,
          ),
          onChanged: (v) => ref.read(periodeProvider.notifier).state =
              list.firstWhere((e) => e.label == v),
          items: [
            for (final p in list)
              DropdownMenuItem(value: p.label, child: Text(p.label)),
          ],
        ),
      ),
    );
  }
}
