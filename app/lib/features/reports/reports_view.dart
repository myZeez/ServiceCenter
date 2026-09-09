import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/status.dart';
import '../../core/theme.dart';
import '../../core/widgets/bento.dart';

/// Rekap dibaca dari view di Postgres, bukan dihitung ulang di aplikasi.
/// Inilah bagian yang di sistem lama butuh rumus di file Excel terpisah.
final _brandReport = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) async => List<Map<String, dynamic>>.from(
    await ref
        .watch(supabaseProvider)
        .from('v_rekap_brand_kuartal')
        .select()
        .order('kuartal', ascending: false),
  ),
);

final _techReport = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) async => List<Map<String, dynamic>>.from(
    await ref
        .watch(supabaseProvider)
        .from('v_rekap_teknisi_brand')
        .select()
        .order('kuartal', ascending: false),
  ),
);

final _reassignments = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) async => List<Map<String, dynamic>>.from(
    await ref
        .watch(supabaseProvider)
        .from('v_riwayat_pindah_teknisi')
        .select()
        .limit(50),
  ),
);

String _quarter(String isoDate) {
  final d = DateTime.parse(isoDate);
  return 'Q${((d.month - 1) ~/ 3) + 1} ${d.year}';
}

class ReportsView extends ConsumerWidget {
  const ReportsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'Rekap',
            subtitle: 'Ringkasan klaim per brand, kuartal, dan teknisi',
            actions: [
              OutlinedButton.icon(
                onPressed: () {
                  ref.invalidate(_brandReport);
                  ref.invalidate(_techReport);
                  ref.invalidate(_reassignments);
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('MUAT ULANG'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) =>
                  c.maxWidth > 900 ? const _WideGrid() : const _NarrowStack(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Susunan bento: dua baris, kolom kiri lebih lebar. Sengaja tidak tiga
/// kolom sama besar -- ukuran yang berbeda memberi tahu mana yang utama.
class _WideGrid extends StatelessWidget {
  const _WideGrid();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Expanded(
          flex: 5,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 2, child: _BrandCard()),
              SizedBox(width: AppSpacing.s),
              Expanded(child: _SummaryCard()),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.s),
        Expanded(
          flex: 4,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 2, child: _TechCard()),
              SizedBox(width: AppSpacing.s),
              Expanded(child: _ReassignCard()),
            ],
          ),
        ),
      ],
    );
  }
}

class _NarrowStack extends StatelessWidget {
  const _NarrowStack();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        SizedBox(height: 260, child: _SummaryCard()),
        SizedBox(height: AppSpacing.s),
        SizedBox(height: 320, child: _BrandCard()),
        SizedBox(height: AppSpacing.s),
        SizedBox(height: 320, child: _TechCard()),
        SizedBox(height: AppSpacing.s),
        SizedBox(height: 340, child: _ReassignCard()),
        SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

/// Ringkasan yang dihitung di aplikasi dari klaim yang sedang ditampilkan.
class _SummaryCard extends ConsumerWidget {
  const _SummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(statusCountsProvider).valueOrNull ?? const {};
    final total = counts.values.fold(0, (a, b) => a + b);

    return BentoCard(
      title: 'Ringkasan',
      accent: context.warna.bahaya,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$total',
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w700,
              letterSpacing: -2,
              height: 1,
            ),
          ),
          Text('TOTAL KLAIM', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: AppSpacing.s),
          const Divider(),
          const SizedBox(height: AppSpacing.s),
          for (final s in ClaimStatus.all)
            BentoBarRow(
              label: ClaimStatus.label(s),
              value: '${counts[s] ?? 0}',
              fraction: total == 0 ? 0 : (counts[s] ?? 0) / total,
              color: ClaimStatus.color(context, s),
            ),
        ],
      ),
    );
  }
}

class _BrandCard extends ConsumerWidget {
  const _BrandCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BentoCard(
      title: 'Klaim per Brand',
      padding: EdgeInsets.zero,
      child: _AsyncBody(
        value: ref.watch(_brandReport),
        emptyText: 'Rekap terisi setelah ada klaim tercatat.',
        builder: (rows) {
          final quarters = <String>{};
          final byBrand = <String, Map<String, int>>{};

          for (final r in rows) {
            final q = _quarter(r['kuartal'] as String);
            quarters.add(q);
            byBrand.putIfAbsent(r['brand'] as String, () => {})[q] =
                r['jumlah_klaim'] as int;
          }

          final qs = quarters.toList();
          final names = byBrand.keys.toList()
            ..sort(
              (a, b) => byBrand[b]!.values
                  .fold(0, (x, y) => x + y)
                  .compareTo(byBrand[a]!.values.fold(0, (x, y) => x + y)),
            );

          return _PivotTable(
            firstColumn: 'Brand',
            columns: qs,
            rows: [
              for (final n in names)
                (label: n, values: [for (final q in qs) byBrand[n]![q] ?? 0]),
            ],
          );
        },
      ),
    );
  }
}

class _TechCard extends ConsumerWidget {
  const _TechCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BentoCard(
      title: 'Teknisi per Brand',
      padding: EdgeInsets.zero,
      child: _AsyncBody(
        value: ref.watch(_techReport),
        emptyText: 'Belum ada pekerjaan yang tercatat atas nama teknisi.',
        builder: (rows) {
          final brands = <String>{};
          final byTech = <String, Map<String, int>>{};

          for (final r in rows) {
            final brand = r['brand'] as String;
            brands.add(brand);
            final m = byTech.putIfAbsent(r['teknisi'] as String, () => {});
            m[brand] = (m[brand] ?? 0) + (r['jumlah_dikerjakan'] as int);
          }

          final bs = brands.toList()..sort();
          final names = byTech.keys.toList()
            ..sort(
              (a, b) => byTech[b]!.values
                  .fold(0, (x, y) => x + y)
                  .compareTo(byTech[a]!.values.fold(0, (x, y) => x + y)),
            );

          return _PivotTable(
            firstColumn: 'Teknisi',
            columns: bs,
            rows: [
              for (final n in names)
                (label: n, values: [for (final b in bs) byTech[n]![b] ?? 0]),
            ],
          );
        },
      ),
    );
  }
}

class _ReassignCard extends ConsumerWidget {
  const _ReassignCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BentoCard(
      title: 'Riwayat Pindah Teknisi',
      padding: EdgeInsets.zero,
      child: _AsyncBody(
        value: ref.watch(_reassignments),
        emptyText: 'Belum ada klaim yang berpindah teknisi.',
        builder: (rows) => ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (context, i) {
            final r = rows[i];
            final at = DateTime.parse(r['diubah_pada'] as String).toLocal();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${r['brand']}  ${r['no_perbaikan'] ?? r['sn']}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${r['dari_teknisi'] ?? 'Belum ditugaskan'}',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.warna.teksLembut,
                            decoration: TextDecoration.lineThrough,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Icon(
                          Icons.arrow_forward,
                          size: 12,
                          color: context.warna.bahaya,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          '${r['ke_teknisi'] ?? '—'}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'oleh ${r['diubah_oleh']} · ${at.day}/${at.month}/${at.year}',
                    style: TextStyle(fontSize: 11, color: context.warna.teksLembut),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// =====================================================================

class _AsyncBody extends StatelessWidget {
  const _AsyncBody({
    required this.value,
    required this.builder,
    required this.emptyText,
  });

  final AsyncValue<List<Map<String, dynamic>>> value;
  final Widget Function(List<Map<String, dynamic>>) builder;
  final String emptyText;

  @override
  Widget build(BuildContext context) => value.when(
    loading: () => const Center(
      child: SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
    // Satu-satunya bagian aplikasi yang memang butuh koneksi: angkanya
    // dihitung oleh database, bukan oleh perangkat.
    error: (e, _) => Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 22,
              color: context.warna.teksLembut,
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Perlu koneksi',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              'Angka rekap dihitung di server.',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    ),
    data: (rows) => rows.isEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Text(
                emptyText,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.warna.teksLembut, fontSize: 13),
              ),
            ),
          )
        : builder(rows),
  );
}

typedef _PivotRow = ({String label, List<int> values});

/// Tabel silang ringkas: kolom pertama nama, sisanya angka, plus total.
class _PivotTable extends StatelessWidget {
  const _PivotTable({
    required this.firstColumn,
    required this.columns,
    required this.rows,
  });

  final String firstColumn;
  final List<String> columns;
  final List<_PivotRow> rows;

  @override
  Widget build(BuildContext context) {
    const numWidth = 62.0;

    Widget cell(String text, {bool head = false, bool bold = false}) => Text(
      text,
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: head ? 9.5 : 13,
        fontWeight: head || bold ? FontWeight.w700 : FontWeight.w400,
        letterSpacing: head ? 0.9 : 0,
        color: head ? context.warna.teksLembut : context.warna.teks,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.sm,
            6,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  firstColumn.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              for (final c in columns)
                SizedBox(
                  width: numWidth,
                  child: cell(c.toUpperCase(), head: true),
                ),
              SizedBox(width: numWidth, child: cell('TOTAL', head: true)),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, i) {
              final r = rows[i];
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 9,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    for (final v in r.values)
                      SizedBox(
                        width: numWidth,
                        child: cell(v == 0 ? '—' : '$v'),
                      ),
                    SizedBox(
                      width: numWidth,
                      child: cell(
                        '${r.values.fold(0, (a, b) => a + b)}',
                        bold: true,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
