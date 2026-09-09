import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/models.dart';
import '../../core/providers.dart';
import '../../core/status.dart';
import '../../core/theme.dart';
import '../../core/widgets/bento.dart';
import '../../core/widgets/swiss_widgets.dart';
import '../scan/scan_page.dart';
import 'claim_dialog.dart';
import 'widgets/claims_table.dart';

/// Halaman utama untuk layar lebar.
class ClaimsView extends ConsumerStatefulWidget {
  const ClaimsView({super.key});

  @override
  ConsumerState<ClaimsView> createState() => _ClaimsViewState();
}

class _ClaimsViewState extends ConsumerState<ClaimsView> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setQuery(String v) => ref
      .read(claimFilterProvider.notifier)
      .update((s) => s.copyWith(query: v));

  @override
  Widget build(BuildContext context) {
    final claims = ref.watch(claimsProvider).valueOrNull ?? const <Claim>[];
    final counts = ref.watch(statusCountsProvider).valueOrNull ?? const {};
    final filter = ref.watch(claimFilterProvider);
    final brands = ref.watch(brandsProvider).valueOrNull ?? const <Brand>[];
    final allBrands =
        ref.watch(allBrandsProvider).valueOrNull ?? const <Brand>[];
    final techs =
        ref.watch(techniciansProvider).valueOrNull ?? const <Profile>[];

    final total = counts.values.fold(0, (a, b) => a + b);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'Klaim Garansi',
            subtitle: '$total klaim tercatat',
            actions: [
              SizedBox(
                width: 300,
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: 'Cari nama, SN, RMA, telp',
                    prefixIcon: Icon(
                      Icons.search,
                      size: 17,
                      color: context.warna.teksLembut,
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 36),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (filter.query.isNotEmpty)
                          IconButton(
                            iconSize: 16,
                            color: context.warna.teksLembut,
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _search.clear();
                              _setQuery('');
                            },
                          ),
                        ScanFieldButton(
                          title: 'Pindai SN untuk mencari',
                          onScanned: (v) {
                            _search.text = v;
                            _setQuery(v);
                          },
                        ),
                      ],
                    ),
                  ),
                  onChanged: _setQuery,
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              FilledButton.icon(
                onPressed: () => showClaimDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('KLAIM BARU'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Ringkasan sekaligus penyaring. Angkanya menjawab "ada berapa
          // yang tunggu part" tanpa perlu membuka apa pun.
          Row(
            children: [
              Expanded(
                child: StatTile(
                  value: '$total',
                  label: 'Semua klaim',
                  selected: filter.status == null,
                  onTap: () => ref
                      .read(claimFilterProvider.notifier)
                      .update((s) => s.copyWith(clearStatus: true)),
                ),
              ),
              for (final s in ClaimStatus.all) ...[
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: StatTile(
                    value: '${counts[s] ?? 0}',
                    label: ClaimStatus.label(s),
                    accent: ClaimStatus.color(context, s),
                    selected: filter.status == s,
                    onTap: () => ref
                        .read(claimFilterProvider.notifier)
                        .update((f) => f.copyWith(status: s)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.s),

          // Brand tetap sebagai item terpisah, bukan dropdown. Jumlahnya
          // masih sedikit dan layar lebar punya ruang; satu klik lebih cepat
          // daripada buka-pilih-tutup. Memakai Wrap, jadi merek baru turun
          // ke baris berikutnya alih-alih memanjang keluar layar.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _BrandChip(
                      label: 'Semua Brand',
                      selected: filter.brandId == null,
                      onTap: () => ref
                          .read(claimFilterProvider.notifier)
                          .update((s) => s.copyWith(clearBrand: true)),
                    ),
                    for (final b in brands)
                      _BrandChip(
                        label: b.nama,
                        selected: filter.brandId == b.id,
                        onTap: () => ref
                            .read(claimFilterProvider.notifier)
                            .update((s) => s.copyWith(brandId: b.id)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              if (filter.brandId != null ||
                  filter.status != null ||
                  filter.query.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: InlineAction(
                    label: 'Hapus filter',
                    onTap: () {
                      _search.clear();
                      ref
                          .read(claimFilterProvider.notifier)
                          .update((_) => const ClaimFilter());
                    },
                  ),
                ),
              const SizedBox(width: AppSpacing.s),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${claims.length} ditampilkan',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),

          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: context.warna.permukaan,
                borderRadius: BorderRadius.circular(AppRadius.base),
                border: Border.all(color: const Color(0xFFE4E7E7)),
              ),
              clipBehavior: Clip.antiAlias,
              child: claims.isEmpty
                  ? EmptyState(
                      icon: Icons.inbox_outlined,
                      title: 'Tidak ada klaim yang cocok',
                      description:
                          'Ubah filter di atas, atau catat klaim baru.',
                      action: OutlinedButton(
                        onPressed: () => showClaimDialog(context),
                        child: const Text('CATAT KLAIM BARU'),
                      ),
                    )
                  : ClaimsTable(
                      items: claims,
                      brands: {for (final b in allBrands) b.id: b.nama},
                      technicians: {for (final p in techs) p.id: p.nama},
                      onOpen: (c) => showClaimDialog(context, claim: c),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandChip extends StatefulWidget {
  const _BrandChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_BrandChip> createState() => _BrandChipState();
}

class _BrandChipState extends State<_BrandChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        // Tanpa alignment dan tanpa tinggi tetap, kotak ini menyusut
        // mengikuti teksnya. Begitu alignment dipasang, Container justru
        // melebar memenuhi baris dan chip-nya menumpuk ke bawah.
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? context.warna.teks : context.warna.permukaan,
            border: Border.all(
              color: active
                  ? context.warna.teks
                  : (_hover ? context.warna.teks : const Color(0xFFCFD5D4)),
            ),
            borderRadius: BorderRadius.circular(AppRadius.small),
          ),
          child: Text(
            widget.label.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: active ? context.warna.permukaan : context.warna.teks,
            ),
          ),
        ),
      ),
    );
  }
}
