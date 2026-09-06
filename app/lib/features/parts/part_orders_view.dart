import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/models.dart';
import '../../core/export/excel_export.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/bento.dart';
import '../../core/widgets/swiss_widgets.dart';
import 'hitung_harga.dart';
import 'part_dialog.dart';
import 'part_status.dart';
import 'parts_view.dart';

final _rp = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);
final _tgl = DateFormat('dd/MM/yy');

final _pesananFilterProvider = StateProvider<PartFilter>(
  (ref) => const PartFilter(),
);

/// Pesanan part yang sudah berjalan: sudah ada DP, tinggal menunggu
/// barangnya, dipasang, lalu dilunasi.
///
/// Bukan tabel kedua. Isinya baris yang sama dengan Tanya Harga, disaring
/// pada tahap yang sudah lewat DP -- dan diberi tiga kolom yang tidak ada
/// gunanya sebelum uang berpindah tangan.
class PartOrdersView extends ConsumerStatefulWidget {
  const PartOrdersView({super.key});

  @override
  ConsumerState<PartOrdersView> createState() => _PartOrdersViewState();
}

class _PartOrdersViewState extends ConsumerState<PartOrdersView> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final semua =
        ref.watch(partOrdersProvider).valueOrNull ?? const <PartOrder>[];
    final filter = ref.watch(_pesananFilterProvider);
    final techs = {
      for (final p
          in ref.watch(techniciansProvider).valueOrNull ?? const <Profile>[])
        p.id: p.nama,
    };

    final berjalan = saringPesanan(semua, hanyaTahap: PartTahap.sesudahDp);

    final perTahap = <String, int>{};
    for (final p in berjalan) {
      perTahap.update(p.tahap, (v) => v + 1, ifAbsent: () => 1);
    }

    final tampil = saringPesanan(
      semua,
      hanyaTahap: PartTahap.sesudahDp,
      tahap: filter.tahap,
      query: filter.query,
    );
    final ringkas = ringkasPesanan(tampil);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'Pemesanan Part',
            subtitle: '${berjalan.length} pesanan berjalan',
            actions: [
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    hintText: 'Cari nama, part, tipe, SN',
                    prefixIcon: Icon(
                      Icons.search,
                      size: 17,
                      color: AppColors.grey,
                    ),
                    prefixIconConstraints: BoxConstraints(minWidth: 36),
                  ),
                  onChanged: (v) => ref
                      .read(_pesananFilterProvider.notifier)
                      .update((s) => s.copyWith(query: v)),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              // Mengekspor persis yang sedang tampil, bukan seluruh tabel:
              // saringan di atas sudah menyatakan potongan mana yang
              // sedang dilihat, dan berkas yang isinya berbeda dari layar
              // adalah cara paling mudah salah kirim laporan.
              TombolExport(
                aktif: tampil.isNotEmpty,
                onExport: () => ExcelExport.part(
                  pesanan: tampil,
                  teknisi: techs,
                  modal: {
                    for (final m
                        in ref.read(partCostsProvider).valueOrNull ??
                            const <PartCost>[])
                      m.partOrderId: m,
                  },
                  periode: filter.tahap == null
                      ? 'Semua Pesanan'
                      : PartTahap.label(filter.tahap!),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          Row(
            children: [
              Expanded(
                child: StatTile(
                  value: '${berjalan.length}',
                  label: 'Semua',
                  selected: filter.tahap == null,
                  onTap: () => ref
                      .read(_pesananFilterProvider.notifier)
                      .update((s) => s.copyWith(clear: true)),
                ),
              ),
              for (final t in PartTahap.sesudahDp) ...[
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: StatTile(
                    value: '${perTahap[t] ?? 0}',
                    label: PartTahap.label(t),
                    accent: PartTahap.color(t),
                    selected: filter.tahap == t,
                    onTap: () => ref
                        .read(_pesananFilterProvider.notifier)
                        .update((f) => f.copyWith(tahap: t)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _Ringkasan(ringkas),
          const SizedBox(height: AppSpacing.s),

          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppRadius.base),
                border: Border.all(color: const Color(0xFFE4E7E7)),
              ),
              clipBehavior: Clip.antiAlias,
              child: tampil.isEmpty
                  ? EmptyState(
                      icon: Icons.local_shipping_outlined,
                      title: berjalan.isEmpty
                          ? 'Belum ada pesanan berjalan'
                          : 'Tidak ada yang cocok',
                      description: berjalan.isEmpty
                          ? 'Pesanan dimulai dari halaman Tanya Harga: buka '
                                'barisnya, lalu tekan USER DP.'
                          : 'Ubah saringan atau kata pencarian di atas.',
                    )
                  : _Tabel(items: tampil, techs: techs),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiga angka uang untuk daftar yang sedang tampil.
///
/// Sengaja mengikuti saringan, bukan seluruh tabel: yang ingin diketahui
/// biasanya "berapa yang belum dibayar dari yang sudah terpasang", dan itu
/// hanya terjawab kalau angkanya ikut menyempit bersama daftarnya.
class _Ringkasan extends StatelessWidget {
  const _Ringkasan(this.r);

  final RingkasPesanan r;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(color: const Color(0xFFE4E7E7)),
      ),
      child: Row(
        children: [
          Expanded(child: _Angka('Nilai Pesanan', _rp.format(r.harga))),
          Expanded(child: _Angka('DP Masuk', _rp.format(r.dp))),
          Expanded(
            child: _Angka(
              'Sisa Tagihan',
              _rp.format(r.sisa),
              merah: r.sisa > 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _Angka extends StatelessWidget {
  const _Angka(this.label, this.nilai, {this.merah = false});

  final String label;
  final String nilai;
  final bool merah;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(height: 2),
      Text(
        nilai,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: merah ? AppColors.red : AppColors.black,
        ),
      ),
    ],
  );
}

class _Tabel extends StatelessWidget {
  const _Tabel({required this.items, required this.techs});

  final List<PartOrder> items;
  final Map<String, String> techs;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final tampilTeknisi = c.maxWidth >= 1020;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.black, width: 1.5),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.s,
                AppSpacing.sm,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  const SizedBox(width: 72, child: TableHeader('Tanggal')),
                  const Expanded(flex: 3, child: TableHeader('Pelanggan')),
                  const Expanded(flex: 4, child: TableHeader('Part Req')),
                  if (tampilTeknisi)
                    const SizedBox(width: 92, child: TableHeader('Teknisi')),
                  const SizedBox(width: 104, child: TableHeader('Harga')),
                  const SizedBox(width: 104, child: TableHeader('DP User')),
                  const SizedBox(width: 104, child: TableHeader('Sisa')),
                  const SizedBox(width: 124, child: TableHeader('Tahap')),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: AppSpacing.s),
                itemCount: items.length,
                itemBuilder: (context, i) => _Baris(
                  pesanan: items[i],
                  teknisi: techs[items[i].teknisiId],
                  tampilTeknisi: tampilTeknisi,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Baris extends StatefulWidget {
  const _Baris({
    required this.pesanan,
    required this.teknisi,
    required this.tampilTeknisi,
  });

  final PartOrder pesanan;
  final String? teknisi;
  final bool tampilTeknisi;

  @override
  State<_Baris> createState() => _BarisState();
}

class _BarisState extends State<_Baris> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.pesanan;

    // Part sudah menempel di unit pelanggan sementara uangnya belum penuh.
    // Ini satu-satunya keadaan di halaman ini yang benar-benar bisa
    // merugikan toko kalau terlewat, jadi ia yang diberi tanda.
    final rawan = p.tahap == PartTahap.dipasang && p.sisa > 0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => showPartDialog(context, pesanan: p),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _hover ? AppColors.lightGrey : AppColors.white,
            border: Border(
              bottom: const BorderSide(color: Color(0xFFE4E7E7)),
              left: BorderSide(
                color: _hover
                    ? AppColors.red
                    : (rawan ? AppColors.red : Colors.transparent),
                width: 3,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm - 3,
            13,
            AppSpacing.sm,
            13,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                child: Text(_tgl.format(p.tanggal), style: _sel),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.s),
                  child: Text(
                    p.customerNama,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.s),
                  child: Text(
                    p.partReq,
                    style: _sel,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (widget.tampilTeknisi)
                SizedBox(
                  width: 92,
                  child: Text(
                    widget.teknisi ?? '—',
                    style: widget.teknisi == null
                        ? _sel.copyWith(color: AppColors.grey)
                        : _sel,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              SizedBox(
                width: 104,
                child: Text(
                  p.harga == null ? '—' : _rp.format(p.harga),
                  style: _sel,
                ),
              ),
              SizedBox(
                width: 104,
                child: Text(
                  p.dp == 0 ? '—' : _rp.format(p.dp),
                  style: _sel,
                ),
              ),
              SizedBox(
                width: 104,
                child: Text(
                  p.sisa == 0 ? 'LUNAS' : _rp.format(p.sisa),
                  style: _sel.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: p.sisa == 0 ? 10 : 13,
                    letterSpacing: p.sisa == 0 ? 0.7 : 0,
                    color: p.sisa == 0 ? AppColors.grey : AppColors.red,
                  ),
                ),
              ),
              SizedBox(
                width: 124,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: PartTahapChip(p.tahap, compact: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _sel = TextStyle(fontSize: 13, color: AppColors.black);
