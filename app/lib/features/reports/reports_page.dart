import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Rekap dibaca langsung dari view di Postgres, bukan dihitung di aplikasi.
/// Ini bagian yang di sistem lama butuh rumus di file Excel terpisah.
final _brandReportProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await ref
      .watch(supabaseProvider)
      .from('v_rekap_brand_kuartal')
      .select()
      .order('kuartal', ascending: false);
  return List<Map<String, dynamic>>.from(rows);
});

final _technicianReportProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await ref
      .watch(supabaseProvider)
      .from('v_rekap_teknisi_brand')
      .select()
      .order('kuartal', ascending: false);
  return List<Map<String, dynamic>>.from(rows);
});

final _reassignmentProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await ref
      .watch(supabaseProvider)
      .from('v_riwayat_pindah_teknisi')
      .select()
      .limit(100);
  return List<Map<String, dynamic>>.from(rows);
});

String _quarterLabel(String isoDate) {
  final d = DateTime.parse(isoDate);
  return 'Q${((d.month - 1) ~/ 3) + 1} ${d.year}';
}

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rekap'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Per Brand'),
              Tab(text: 'Per Teknisi'),
              Tab(text: 'Riwayat Pindah'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _BrandReport(),
            _TechnicianReport(),
            _ReassignmentLog(),
          ],
        ),
      ),
    );
  }
}

/// Pembungkus yang menangani loading, error, dan data kosong secara seragam.
class _AsyncTable extends StatelessWidget {
  const _AsyncTable({required this.value, required this.builder});

  final AsyncValue<List<Map<String, dynamic>>> value;
  final Widget Function(List<Map<String, dynamic>>) builder;

  @override
  Widget build(BuildContext context) => value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 40),
                const SizedBox(height: 12),
                const Text('Rekap perlu koneksi internet.'),
                const SizedBox(height: 4),
                Text(
                  '$e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        data: (rows) => rows.isEmpty
            ? const Center(child: Text('Belum ada data.'))
            : builder(rows),
      );
}

/// Tabel silang: baris = brand, kolom = kuartal.
class _BrandReport extends ConsumerWidget {
  const _BrandReport();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _AsyncTable(
      value: ref.watch(_brandReportProvider),
      builder: (rows) {
        final quarters = <String>{};
        final byBrand = <String, Map<String, int>>{};

        for (final r in rows) {
          final q = _quarterLabel(r['kuartal'] as String);
          final brand = r['brand'] as String;
          quarters.add(q);
          byBrand.putIfAbsent(brand, () => {})[q] = r['jumlah_klaim'] as int;
        }

        final qList = quarters.toList();
        final brandList = byBrand.keys.toList()..sort();

        return SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                const DataColumn(label: Text('Brand')),
                for (final q in qList) DataColumn(label: Text(q), numeric: true),
                const DataColumn(label: Text('Total'), numeric: true),
              ],
              rows: [
                for (final b in brandList)
                  DataRow(cells: [
                    DataCell(Text(b)),
                    for (final q in qList)
                      DataCell(Text('${byBrand[b]![q] ?? 0}')),
                    DataCell(
                      Text(
                        '${byBrand[b]!.values.fold(0, (a, v) => a + v)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ]),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Tabel silang: baris = teknisi, kolom = brand.
class _TechnicianReport extends ConsumerWidget {
  const _TechnicianReport();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _AsyncTable(
      value: ref.watch(_technicianReportProvider),
      builder: (rows) {
        final brands = <String>{};
        final byTech = <String, Map<String, int>>{};

        for (final r in rows) {
          final tech = r['teknisi'] as String;
          final brand = r['brand'] as String;
          brands.add(brand);
          final m = byTech.putIfAbsent(tech, () => {});
          m[brand] = (m[brand] ?? 0) + (r['jumlah_dikerjakan'] as int);
        }

        final brandList = brands.toList()..sort();
        final techList = byTech.keys.toList()..sort();

        return SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                const DataColumn(label: Text('Teknisi')),
                for (final b in brandList)
                  DataColumn(label: Text(b), numeric: true),
                const DataColumn(label: Text('Total'), numeric: true),
              ],
              rows: [
                for (final t in techList)
                  DataRow(cells: [
                    DataCell(Text(t)),
                    for (final b in brandList)
                      DataCell(Text('${byTech[t]![b] ?? 0}')),
                    DataCell(
                      Text(
                        '${byTech[t]!.values.fold(0, (a, v) => a + v)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ]),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Siapa memindahkan klaim ke siapa. Dasar penyelesaian kalau ada
/// perselisihan bagi hasil.
class _ReassignmentLog extends ConsumerWidget {
  const _ReassignmentLog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _AsyncTable(
      value: ref.watch(_reassignmentProvider),
      builder: (rows) => ListView.separated(
        itemCount: rows.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final r = rows[i];
          final at = DateTime.parse(r['diubah_pada'] as String).toLocal();
          return ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: Text(
              '${r['dari_teknisi'] ?? 'Belum ditugaskan'} → ${r['ke_teknisi'] ?? '-'}',
            ),
            subtitle: Text(
              '${r['brand']} · ${r['no_perbaikan'] ?? r['sn']}\n'
              'Diubah oleh ${r['diubah_oleh']} · '
              '${at.day}/${at.month}/${at.year} ${at.hour}:${at.minute.toString().padLeft(2, '0')}',
            ),
            isThreeLine: true,
          );
        },
      ),
    );
  }
}
