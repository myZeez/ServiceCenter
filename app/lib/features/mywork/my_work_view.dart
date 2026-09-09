import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/models.dart';
import '../../core/providers.dart';
import '../../core/revenue/revenue_providers.dart';
import '../../core/status.dart';
import '../../core/theme.dart';
import '../../core/widgets/bento.dart';
import '../service/teknisi_ringkas.dart';

final _rpOmset = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);

/// Klaim garansi milik pengguna yang sedang login pada periode terpilih.
///
/// Tidak ada angka rupiah pada bagian klaim: aturan akses di server menahan
/// fee brand supaya tidak pernah sampai ke perangkat teknisi. Yang berangka
/// hanya omset jasa servis, dan itu memang haknya sendiri.
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
        const _OmsetServis(),

        BentoCard(
          title: 'Unit Selesai',
          accent: context.warna.bahaya,
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

/// Omset jasa servis milik teknisi yang sedang login, bulan berjalan.
///
/// Terpisah dari kartu klaim di bawahnya, dan memang harus terpisah: yang
/// ini jasa yang dibayar pelanggan, yang itu unit garansi yang fee-nya
/// datang dari brand. Dua kantong berbeda yang tidak saling memotong.
class _OmsetServis extends ConsumerWidget {
  const _OmsetServis();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(ringkasSayaProvider);
    // Admin dan operator tidak punya target; kartunya tidak ditampilkan
    // sama sekali daripada memperlihatkan nol yang tidak berarti apa-apa.
    if (r == null) return const SizedBox.shrink();

    final persen = (r.persenTarget / 100).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: BentoCard(
        title: 'Omset Servis Bulan Ini',
        accent: context.warna.aksen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _rpOmset.format(r.omset),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.2,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${r.notaSelesai} NOTA SELESAI  ·  '
              '${r.unitBerjalan} UNIT DIKERJAKAN',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: AppSpacing.s),

            // Batangnya memakai tinggi penuh, bukan garis tipis: ini angka
            // yang dicari orang begitu membuka halaman, dan harus terbaca
            // sekilas tanpa mendekatkan layar.
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
                  ? 'Target ${_rpOmset.format(r.target)} sudah tercapai'
                  : 'Kurang ${_rpOmset.format(r.kurang)} dari target '
                        '${_rpOmset.format(r.target)}',
              style: const TextStyle(fontSize: 11.5, color: context.warna.teksLembut),
            ),
          ],
        ),
      ),
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
        border: Border.all(color: context.warna.teks),
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
    );
  }
}
