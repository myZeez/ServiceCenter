import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/models.dart';
import '../../core/providers.dart';
import '../../core/revenue/revenue_calculator.dart';
import '../../core/revenue/revenue_providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/bento.dart';

final _rp = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);

class RevenueView extends ConsumerWidget {
  const RevenueView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periode = ref.watch(periodeProvider);
    final hasil = ref.watch(revenueResultProvider);

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
                '${DateFormat('d MMM yyyy').format(periode.sampai)}'
                '  ·  hanya klaim berstatus Selesai',
            actions: const [_PeriodeDropdown()],
          ),
          const SizedBox(height: AppSpacing.s),
          Expanded(
            child: hasil == null
                ? const Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, c) => c.maxWidth > 900
                        ? _WideGrid(hasil)
                        : _NarrowStack(hasil),
                  ),
          ),
        ],
      ),
    );
  }
}

class _WideGrid extends StatelessWidget {
  const _WideGrid(this.hasil);

  final RevenueResult hasil;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 4,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _TotalCard(hasil)),
              const SizedBox(width: AppSpacing.s),
              Expanded(child: _SplitCard(hasil)),
              const SizedBox(width: AppSpacing.s),
              Expanded(child: _BrandCard(hasil)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        Expanded(flex: 5, child: _TechCard(hasil)),
      ],
    );
  }
}

class _NarrowStack extends StatelessWidget {
  const _NarrowStack(this.hasil);

  final RevenueResult hasil;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SizedBox(height: 210, child: _TotalCard(hasil)),
        const SizedBox(height: AppSpacing.s),
        SizedBox(height: 230, child: _SplitCard(hasil)),
        const SizedBox(height: AppSpacing.s),
        SizedBox(height: 300, child: _TechCard(hasil)),
        const SizedBox(height: AppSpacing.s),
        SizedBox(height: 260, child: _BrandCard(hasil)),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard(this.hasil);

  final RevenueResult hasil;

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      title: 'Total Pendapatan',
      accent: context.warna.bahaya,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _rp.format(hasil.totalNilai),
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
            '${hasil.totalUnit} UNIT SELESAI',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          // Kekurangan data diangkat terang-terangan: keduanya membuat
          // angka di atas lebih kecil dari yang seharusnya.
          if (hasil.unitTanpaFee > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            _Warning(
              '${hasil.unitTanpaFee} unit brand-nya belum punya fee, '
              'jadi dihitung nol.',
            ),
          ],
          if (hasil.unitTanpaTeknisi > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            _Warning(
              '${hasil.unitTanpaTeknisi} unit belum ada teknisinya, '
              'jadi bagiannya tidak jatuh ke siapa pun.',
            ),
          ],
        ],
      ),
    );
  }
}

class _SplitCard extends StatelessWidget {
  const _SplitCard(this.hasil);

  final RevenueResult hasil;

  @override
  Widget build(BuildContext context) {
    final total = hasil.totalNilai;

    Widget baris(String label, int nilai, Color c) => BentoBarRow(
      label: label,
      value: _rp.format(nilai),
      fraction: total == 0 ? 0 : nilai / total,
      color: c,
    );

    return BentoCard(
      title: 'Pembagian',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          baris('Toko', hasil.bagianToko, context.warna.teks),
          baris('Admin', hasil.bagianAdmin, context.warna.aksen),
          baris('Teknisi', hasil.bagianTeknisi, context.warna.bahaya),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Diatur di Pengaturan → Bagi Hasil',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _TechCard extends ConsumerWidget {
  const _TechCard(this.hasil);

  final RevenueResult hasil;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nama = {
      for (final p
          in ref.watch(techniciansProvider).valueOrNull ?? const <Profile>[])
        p.id: p.nama,
    };
    final sisa = hasil.teknisiBelumDialokasikan;

    return BentoCard(
      title: 'Pendapatan Teknisi',
      padding: EdgeInsets.zero,
      trailing: sisa > 0
          ? Text(
              '${_rp.format(sisa)} belum dialokasikan',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: context.warna.bahaya,
              ),
            )
          : null,
      child: hasil.teknisi.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Text(
                  'Belum ada klaim selesai atas nama teknisi di periode ini.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.warna.teksLembut,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          : Column(
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
                      SizedBox(width: 64, child: _Head('Unit', right: true)),
                      SizedBox(width: 124, child: _Head('Nilai', right: true)),
                      SizedBox(width: 72, child: _Head('Porsi', right: true)),
                      SizedBox(
                        width: 134,
                        child: _Head('Pendapatan', right: true),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: hasil.teknisi.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, i) {
                      final t = hasil.teknisi[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 11,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                nama[t.teknisiId] ?? '—',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 64, child: _Num('${t.unit}')),
                            SizedBox(
                              width: 124,
                              child: _Num(_rp.format(t.nilai), muted: true),
                            ),
                            SizedBox(
                              width: 72,
                              child: _Num(
                                '${t.porsi.toStringAsFixed(1)}%',
                                muted: true,
                              ),
                            ),
                            SizedBox(
                              width: 134,
                              child: _Num(_rp.format(t.pendapatan), bold: true),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _BrandCard extends ConsumerWidget {
  const _BrandCard(this.hasil);

  final RevenueResult hasil;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nama = {
      for (final b
          in ref.watch(allBrandsProvider).valueOrNull ?? const <Brand>[])
        b.id: b.nama,
    };

    return BentoCard(
      title: 'Per Brand',
      padding: EdgeInsets.zero,
      child: hasil.brands.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Text(
                  'Belum ada klaim selesai di periode ini.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.warna.teksLembut,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              itemCount: hasil.brands.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, i) {
                final b = hasil.brands[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nama[b.brandId] ?? '—',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                            Text(
                              '${b.unit} unit  ·  @${_rp.format(b.feeRataRata)}',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _rp.format(b.nilai),
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
    );
  }
}

// =====================================================================

class _PeriodeDropdown extends ConsumerWidget {
  const _PeriodeDropdown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = Periode.daftar();
    final selected = ref.watch(periodeProvider);

    return Container(
      height: 36,
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

class _Warning extends StatelessWidget {
  const _Warning(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.xs),
    decoration: BoxDecoration(
      color: context.warna.bahaya.withValues(alpha: 0.05),
      border: Border(left: BorderSide(color: context.warna.bahaya, width: 3)),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, height: 1.4, color: context.warna.bahaya),
    ),
  );
}

class _Head extends StatelessWidget {
  const _Head(this.text, {this.right = false});

  final String text;
  final bool right;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    textAlign: right ? TextAlign.right : TextAlign.left,
    style: TextStyle(
      fontSize: 9.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.9,
      color: context.warna.teksLembut,
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
      color: muted ? context.warna.teksLembut : context.warna.teks,
    ),
  );
}
