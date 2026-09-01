import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/bento.dart';

final _rp = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
final _iso = DateFormat('yyyy-MM-dd');

/// Rentang waktu perhitungan. Kuartal dipakai sebagai bawaan karena begitulah
/// bagi hasil selama ini dihitung.
class Periode {
  const Periode(this.label, this.dari, this.sampai);

  final String label;
  final DateTime dari;
  final DateTime sampai;

  static List<Periode> terakhir({int tahunKeBelakang = 2}) {
    final now = DateTime.now();
    final out = <Periode>[];

    for (var y = now.year; y >= now.year - tahunKeBelakang; y--) {
      for (var q = 4; q >= 1; q--) {
        final mulai = DateTime(y, (q - 1) * 3 + 1, 1);
        if (mulai.isAfter(now)) continue;
        // Akhir kuartal = sehari sebelum awal kuartal berikutnya.
        final akhir = DateTime(y, q * 3 + 1, 1).subtract(const Duration(days: 1));
        out.add(Periode('Q$q $y', mulai, akhir));
      }
    }
    return out;
  }
}

final periodeProvider = StateProvider<Periode>(
  (ref) => Periode.terakhir().first,
);

typedef _Rows = List<Map<String, dynamic>>;

final _ringkasan = FutureProvider.autoDispose<_Rows>(
  (ref) => _rpcRead(ref, 'ringkasan_pendapatan'),
);
final _perTeknisi = FutureProvider.autoDispose<_Rows>(
  (ref) => _rpcRead(ref, 'pendapatan_teknisi'),
);
final _perBrand = FutureProvider.autoDispose<_Rows>(
  (ref) => _rpcRead(ref, 'pendapatan_brand'),
);

Future<_Rows> _rpcRead(Ref ref, String fn) async {
  final p = ref.watch(periodeProvider);
  final res = await ref.read(supabaseProvider).rpc(
    fn,
    params: {
      'p_dari': _iso.format(p.dari),
      'p_sampai': _iso.format(p.sampai),
    },
  );
  return List<Map<String, dynamic>>.from(res as List);
}

class RevenueView extends ConsumerWidget {
  const RevenueView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periode = ref.watch(periodeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'Pendapatan',
            subtitle:
                '${DateFormat('d MMM').format(periode.dari)} — '
                '${DateFormat('d MMM yyyy').format(periode.sampai)}  ·  '
                'hanya klaim berstatus Selesai',
            actions: [
              _PeriodeDropdown(selected: periode),
              const SizedBox(width: AppSpacing.xs),
              OutlinedButton.icon(
                onPressed: () {
                  ref.invalidate(_ringkasan);
                  ref.invalidate(_perTeknisi);
                  ref.invalidate(_perBrand);
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('MUAT ULANG'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => c.maxWidth > 900
                  ? const _WideGrid()
                  : const _NarrowStack(),
            ),
          ),
        ],
      ),
    );
  }
}

class _WideGrid extends StatelessWidget {
  const _WideGrid();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        Expanded(
          flex: 4,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _TotalCard()),
              SizedBox(width: AppSpacing.s),
              Expanded(child: _SplitCard()),
              SizedBox(width: AppSpacing.s),
              Expanded(child: _BrandCard()),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.s),
        Expanded(flex: 5, child: _TechCard()),
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
        SizedBox(height: 200, child: _TotalCard()),
        SizedBox(height: AppSpacing.s),
        SizedBox(height: 230, child: _SplitCard()),
        SizedBox(height: AppSpacing.s),
        SizedBox(height: 300, child: _TechCard()),
        SizedBox(height: AppSpacing.s),
        SizedBox(height: 260, child: _BrandCard()),
        SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

class _TotalCard extends ConsumerWidget {
  const _TotalCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BentoCard(
      title: 'Total Pendapatan',
      accent: AppColors.red,
      child: _Async(
        value: ref.watch(_ringkasan),
        builder: (rows) {
          final r = rows.first;
          final tanpaFee = (r['unit_tanpa_fee'] as num).toInt();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _rp.format(r['total_nilai'] as num),
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.5,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${r['total_unit']} UNIT SELESAI',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              if (tanpaFee > 0) ...[
                const SizedBox(height: AppSpacing.s),
                // Diangkat terang-terangan: klaim tanpa fee membuat total
                // terlihat lebih kecil dari yang sebenarnya.
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  decoration: const BoxDecoration(
                    color: Color(0x0DD82C2C),
                    border: Border(
                      left: BorderSide(color: AppColors.red, width: 3),
                    ),
                  ),
                  child: Text(
                    '$tanpaFee unit brand-nya belum punya fee, '
                    'jadi dihitung nol.',
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: AppColors.red,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SplitCard extends ConsumerWidget {
  const _SplitCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BentoCard(
      title: 'Pembagian',
      child: _Async(
        value: ref.watch(_ringkasan),
        builder: (rows) {
          final r = rows.first;
          final total = (r['total_nilai'] as num).toDouble();

          Widget baris(String label, String key, Color c) {
            final v = (r[key] as num).toDouble();
            return BentoBarRow(
              label: label,
              value: _rp.format(v),
              fraction: total == 0 ? 0 : v / total,
              color: c,
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              baris('Toko', 'bagian_toko', AppColors.black),
              baris('Admin', 'bagian_admin', AppColors.blue),
              baris('Teknisi', 'bagian_teknisi', AppColors.red),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Persentase diatur di Pengaturan → Bagi Hasil',
                style: Theme.of(context).textTheme.labelSmall,
              ),
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
      title: 'Pendapatan Teknisi',
      padding: EdgeInsets.zero,
      child: _Async(
        value: ref.watch(_perTeknisi),
        emptyText: 'Belum ada klaim selesai atas nama teknisi di periode ini.',
        builder: (rows) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.sm,
                6,
              ),
              child: Row(
                children: [
                  Expanded(child: _Head('Teknisi')),
                  SizedBox(width: 70, child: _Head('Unit', right: true)),
                  SizedBox(width: 130, child: _Head('Nilai', right: true)),
                  SizedBox(width: 80, child: _Head('Porsi', right: true)),
                  SizedBox(width: 140, child: _Head('Pendapatan', right: true)),
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
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            r['nama'] as String,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(
                          width: 70,
                          child: _Num('${r['unit']}'),
                        ),
                        SizedBox(
                          width: 130,
                          child: _Num(_rp.format(r['nilai'] as num), muted: true),
                        ),
                        SizedBox(
                          width: 80,
                          child: _Num('${r['porsi']}%', muted: true),
                        ),
                        SizedBox(
                          width: 140,
                          child: _Num(
                            _rp.format(r['pendapatan'] as num),
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
        ),
      ),
    );
  }
}

class _BrandCard extends ConsumerWidget {
  const _BrandCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BentoCard(
      title: 'Per Brand',
      padding: EdgeInsets.zero,
      child: _Async(
        value: ref.watch(_perBrand),
        emptyText: 'Belum ada klaim selesai di periode ini.',
        builder: (rows) => ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (context, i) {
            final r = rows[i];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r['brand'] as String,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                        Text(
                          '${r['unit']} unit  ·  @${_rp.format(r['fee_satuan'] as num)}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _rp.format(r['nilai'] as num),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
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

class _PeriodeDropdown extends ConsumerWidget {
  const _PeriodeDropdown({required this.selected});

  final Periode selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = Periode.terakhir();

    return Container(
      height: 36,
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
          onChanged: (v) {
            final p = list.firstWhere((e) => e.label == v);
            ref.read(periodeProvider.notifier).state = p;
          },
          items: [
            for (final p in list)
              DropdownMenuItem(value: p.label, child: Text(p.label)),
          ],
        ),
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head(this.text, {this.right = false});

  final String text;
  final bool right;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
          color: AppColors.grey,
        ),
      );
}

class _Num extends StatelessWidget {
  const _Num(this.text, {this.bold = false, this.muted = false});

  final String text;
  final bool bold;
  final bool muted;

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 13,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: muted ? AppColors.grey : AppColors.black,
        ),
      );
}

class _Async extends StatelessWidget {
  const _Async({
    required this.value,
    required this.builder,
    this.emptyText = 'Belum ada data.',
  });

  final AsyncValue<_Rows> value;
  final Widget Function(_Rows) builder;
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
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  size: 20,
                  color: AppColors.grey,
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Perlu koneksi',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Perhitungan dijalankan di server.',
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
                    style: const TextStyle(color: AppColors.grey, fontSize: 13),
                  ),
                ),
              )
            : builder(rows),
      );
}
