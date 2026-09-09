import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/bento.dart';
import '../../core/widgets/swiss_widgets.dart';
import '../scan/scan_page.dart';
import 'part_dialog.dart';
import 'part_status.dart';

final _rp = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);
final _tgl = DateFormat('dd/MM/yy');

class PartFilter {
  const PartFilter({this.tahap, this.query = ''});

  final String? tahap;
  final String query;

  PartFilter copyWith({String? tahap, String? query, bool clear = false}) =>
      PartFilter(
        tahap: clear ? null : (tahap ?? this.tahap),
        query: query ?? this.query,
      );
}

final partFilterProvider = StateProvider<PartFilter>(
  (ref) => const PartFilter(),
);

/// Menyaring dan mengurutkan daftar pesanan.
///
/// Dipisah dari widget-nya supaya bisa diuji tanpa melukis apa pun. Salah
/// saring di sini berarti sebuah unit menghilang dari layar tanpa satu pun
/// tanda bahwa ia pernah ada.
List<PartOrder> saringPesanan(
  List<PartOrder> semua, {
  String? tahap,
  String query = '',
  List<String>? hanyaTahap,
}) {
  final q = query.toLowerCase().trim();

  return [
    for (final p in semua)
      if ((hanyaTahap == null || hanyaTahap.contains(p.tahap)) &&
          (tahap == null || p.tahap == tahap) &&
          (q.isEmpty ||
              p.customerNama.toLowerCase().contains(q) ||
              p.partReq.toLowerCase().contains(q) ||
              (p.barangType ?? '').toLowerCase().contains(q) ||
              (p.barangSn ?? '').toLowerCase().contains(q) ||
              (p.customerTelp ?? '').contains(q)))
        p,
  ];
}

/// Meja tanya harga: seluruh permintaan part, apa pun tahapnya, sejak
/// pertama kali ditanyakan sampai jauh setelah tuntas.
///
/// Inilah daftar lengkapnya, dan ia tidak pernah menyusut. Halaman
/// Pemesanan Part di sebelahnya bukan salinan melainkan saringannya --
/// baris yang sudah lewat DP. Satu catatan, dua sudut pandang.
class PartsView extends ConsumerStatefulWidget {
  const PartsView({super.key});

  @override
  ConsumerState<PartsView> createState() => _PartsViewState();
}

class _PartsViewState extends ConsumerState<PartsView> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setQuery(String v) =>
      ref.read(partFilterProvider.notifier).update((s) => s.copyWith(query: v));

  @override
  Widget build(BuildContext context) {
    final semua =
        ref.watch(partOrdersProvider).valueOrNull ?? const <PartOrder>[];
    final filter = ref.watch(partFilterProvider);
    final techs = {
      for (final p
          in ref.watch(techniciansProvider).valueOrNull ?? const <Profile>[])
        p.id: p.nama,
    };

    // Halaman ini memuat SEMUANYA, tahap apa pun -- termasuk yang sudah
    // dibayar dan sudah tuntas.
    //
    // Sempat dibatasi sampai batas DP saja, meniru sheet lama yang memang
    // berhenti di situ. Itu salah membaca sebabnya: di sheet, baris yang
    // jadi dipesan tetap tinggal di Tanya Harga, dan yang ada di Pemesanan
    // adalah SALINANNYA. Membuang salinannya benar; ikut membuang barisnya
    // dari sini berarti membuang riwayatnya -- pertanyaan "dulu unit ini
    // pernah ditanyakan harganya berapa" jadi tidak bisa dijawab.
    //
    // Pemesanan Part tetap saringan atas tabel yang sama; ia hanya
    // menyempit ke yang uangnya sudah berpindah.
    final perTahap = <String, int>{};
    for (final p in semua) {
      perTahap.update(p.tahap, (v) => v + 1, ifAbsent: () => 1);
    }

    final tampil = saringPesanan(
      semua,
      tahap: filter.tahap,
      query: filter.query,
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            showPartDialog(context),
      },
      child: Focus(
        autofocus: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s,
            vertical: AppSpacing.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Tanya Harga',
                subtitle:
                    '${semua.length} permintaan tercatat  ·  Ctrl+N untuk '
                    'tambah',
                actions: [
                  SizedBox(
                    width: 300,
                    child: TextField(
                      controller: _search,
                      decoration: InputDecoration(
                        hintText: 'Cari nama, part, tipe, SN',
                        prefixIcon: Icon(
                          Icons.search,
                          size: 17,
                          color: context.warna.teksLembut,
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 36,
                        ),
                        suffixIcon: ScanFieldButton(
                          title: 'Pindai SN untuk mencari',
                          onScanned: (v) {
                            _search.text = v;
                            _setQuery(v);
                          },
                        ),
                      ),
                      onChanged: _setQuery,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  FilledButton.icon(
                    onPressed: () => showPartDialog(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('TANYA HARGA'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      value: '${semua.length}',
                      label: 'Semua',
                      selected: filter.tahap == null,
                      onTap: () => ref
                          .read(partFilterProvider.notifier)
                          .update((s) => s.copyWith(clear: true)),
                    ),
                  ),
                  for (final t in PartTahap.all) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: StatTile(
                        value: '${perTahap[t] ?? 0}',
                        label: PartTahap.pendek(t),
                        accent: PartTahap.color(context, t),
                        selected: filter.tahap == t,
                        onTap: () => ref
                            .read(partFilterProvider.notifier)
                            .update((f) => f.copyWith(tahap: t)),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.s),

              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: context.warna.permukaan,
                    borderRadius: BorderRadius.circular(AppRadius.base),
                    border: Border.all(color: context.warna.garisHalus),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: tampil.isEmpty
                      ? EmptyState(
                          icon: Icons.request_quote_outlined,
                          title: semua.isEmpty
                              ? 'Belum ada permintaan part'
                              : 'Tidak ada yang cocok',
                          description: semua.isEmpty
                              ? 'Dicatat saat pelanggan menanyakan harga '
                                    'part unit non-garansi.'
                              : 'Ubah saringan atau kata pencarian di atas.',
                          action: OutlinedButton(
                            onPressed: () => showPartDialog(context),
                            child: const Text('TANYA HARGA'),
                          ),
                        )
                      : _Tabel(items: tampil, techs: techs),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tabel extends StatelessWidget {
  const _Tabel({required this.items, required this.techs});

  final List<PartOrder> items;
  final Map<String, String> techs;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final lebar = c.maxWidth;
        final tampilCatatan = lebar >= 1240;
        final tampilUnit = lebar >= 1080;
        final tampilTeknisi = lebar >= 900;
        final tampilHarga = lebar >= 760;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: context.warna.teks, width: 1.5),
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
                  if (tampilUnit)
                    const Expanded(flex: 3, child: TableHeader('Unit')),
                  const Expanded(flex: 4, child: TableHeader('Part Req')),
                  if (tampilCatatan)
                    const Expanded(flex: 3, child: TableHeader('Catatan')),
                  if (tampilTeknisi)
                    const SizedBox(width: 92, child: TableHeader('Teknisi')),
                  if (tampilHarga)
                    const SizedBox(width: 112, child: TableHeader('Harga')),
                  const SizedBox(width: 132, child: TableHeader('Status')),
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
                  tampilUnit: tampilUnit,
                  tampilCatatan: tampilCatatan,
                  tampilTeknisi: tampilTeknisi,
                  tampilHarga: tampilHarga,
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
    required this.tampilUnit,
    required this.tampilCatatan,
    required this.tampilTeknisi,
    required this.tampilHarga,
  });

  final PartOrder pesanan;
  final String? teknisi;
  final bool tampilUnit;
  final bool tampilCatatan;
  final bool tampilTeknisi;
  final bool tampilHarga;

  @override
  State<_Baris> createState() => _BarisState();
}

class _BarisState extends State<_Baris> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.pesanan;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => showPartDialog(context, pesanan: p),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _hover ? context.warna.teredam : context.warna.permukaan,
            border: Border(
              bottom: BorderSide(color: context.warna.garisHalus),
              left: BorderSide(
                color: _hover ? context.warna.bahaya : Colors.transparent,
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
              if (widget.tampilUnit)
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.s),
                    child: Text(
                      p.barangType ?? '—',
                      style: _sel,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        p.partReq,
                        style: _sel,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (p.keterangan != null)
                        Text(
                          p.keterangan!.toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                    ],
                  ),
                ),
              ),
              if (widget.tampilCatatan)
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.s),
                    child: Text(
                      p.catatan ?? '—',
                      maxLines: 2,
                      style: p.catatan == null
                          ? _sel.copyWith(color: context.warna.teksLembut)
                          : _sel.copyWith(fontSize: 12),
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
                        ? _sel.copyWith(color: context.warna.teksLembut)
                        : _sel,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (widget.tampilHarga)
                SizedBox(
                  width: 112,
                  child: Text(
                    p.harga == null ? '—' : _rp.format(p.harga),
                    style: _sel.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              SizedBox(
                width: 132,
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

/// Warnanya sengaja tidak disebut: yang tidak menyebut warna mewarisi
/// warna teks dari tema yang sedang berlaku, dan itulah yang membuat sel
/// ini benar di terang maupun gelap.
const _sel = TextStyle(fontSize: 13);
