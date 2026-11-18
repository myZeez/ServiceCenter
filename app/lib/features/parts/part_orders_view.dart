import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/models.dart';
import '../../core/export/excel_export.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/bento.dart';
import '../../core/widgets/swiss_widgets.dart';
import 'gudang_dialog.dart';
import 'hitung_harga.dart';
import 'part_dialog.dart';
import 'part_status.dart';
import 'parts_view.dart';
import 'tanya_harga_dari_nota.dart';

final _rp = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);
final _tgl = DateFormat('dd/MM/yy');

final _pesananFilterProvider = StateProvider<PartFilter>(
  (ref) => const PartFilter(),
);

/// Kelompok pesanan, supaya yang sudah selesai tidak bercampur dengan yang
/// belum. Batal berdiri sendiri: ia bukan "belum selesai" dan bukan selesai.
enum KelompokPesanan {
  semua('Semua', [
    PartTahap.dipesan,
    PartTahap.dipasang,
    PartTahap.selesai,
    PartTahap.batal,
  ]),
  belum('Belum Selesai', [PartTahap.dipesan, PartTahap.dipasang]),
  selesai('Selesai', [PartTahap.selesai]),
  batal('Batal', [PartTahap.batal]);

  const KelompokPesanan(this.label, this.tahap);

  final String label;
  final List<String> tahap;
}

final _kelompokProvider = StateProvider<KelompokPesanan>(
  (ref) => KelompokPesanan.semua,
);

/// Yang tampil di halaman pemesanan: yang sudah lewat DP, ditambah yang batal
/// sesudah DP dibayar. Tanya harga yang batal sebelum ada DP bukan pesanan.
List<PartOrder> pesananPemesanan(List<PartOrder> semua) => [
  for (final p in semua)
    if (PartTahap.sesudahDp.contains(p.tahap) ||
        (p.tahap == PartTahap.batal && p.tanggalDp != null))
      p,
];

List<PartOrder> pesananKelompok(List<PartOrder> semua, KelompokPesanan k) => [
  for (final p in semua)
    if (k.tahap.contains(p.tahap)) p,
];

/// Bulan yang dilihat, tanggal 1-nya. Kosong berarti bulan terbaru.
///
/// Laporan ke pusat dibuat per bulan, seperti PERIODE di sheet lama, jadi
/// halaman ini selalu memperlihatkan satu bulan dan bulan itulah yang
/// menentukan isi berkas Excel yang dikirim.
final _bulanPesananProvider = StateProvider<DateTime?>((ref) => null);

const _namaBulan = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

String _labelBulan(DateTime b) => '${_namaBulan[b.month - 1]} ${b.year}';

/// Tanggal yang dipakai mengelompokkan pesanan per bulan: tanggal DP, sama
/// dengan kolom pertama sheet pemesanan. Yang belum punya DP memakai
/// tanggal orangnya bertanya.
DateTime _tanggalPesanan(PartOrder p) => p.tanggalDp ?? p.tanggal;

/// Bulan-bulan yang punya pesanan, terbaru lebih dulu.
List<DateTime> bulanPesanan(List<PartOrder> semua) {
  final set = <DateTime>{
    for (final p in semua)
      DateTime(_tanggalPesanan(p).year, _tanggalPesanan(p).month),
  };
  return set.toList()..sort((a, b) => b.compareTo(a));
}

/// Pesanan pada satu bulan; null mengembalikan semuanya.
List<PartOrder> pesananBulan(List<PartOrder> semua, DateTime? bulan) {
  if (bulan == null) return semua;
  return [
    for (final p in semua)
      if (_tanggalPesanan(p).year == bulan.year &&
          _tanggalPesanan(p).month == bulan.month)
        p,
  ];
}

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

    final gudang = ref.watch(isGudangProvider);
    final bisaModal = ref.watch(hakModalProvider);
    final bulan = ref.watch(_bulanPesananProvider);
    final modal = {
      if (bisaModal)
        for (final m
            in ref.watch(partCostsProvider).valueOrNull ?? const <PartCost>[])
          m.partOrderId: m,
    };
    final kelompok = ref.watch(_kelompokProvider);
    final dasar = pesananPemesanan(semua);
    final daftarBulan = bulanPesanan(dasar);
    // Selalu satu bulan: yang dipilih, atau yang terbaru bila belum memilih
    // (atau bulan pilihannya tidak lagi punya pesanan).
    final bulanDipilih = bulan != null && daftarBulan.contains(bulan)
        ? bulan
        : (daftarBulan.isEmpty ? null : daftarBulan.first);
    final dalamBulan = pesananBulan(dasar, bulanDipilih);
    final urutBulan = bulanDipilih == null
        ? -1
        : daftarBulan.indexOf(bulanDipilih);

    // Jumlah tiap kelompok mengikuti bulan yang dipilih, bukan saringan
    // lain: yang ingin diketahui "berapa yang belum selesai bulan ini".
    final perKelompok = {
      for (final k in KelompokPesanan.values)
        k: pesananKelompok(dalamBulan, k).length,
    };
    final berjalan = pesananKelompok(dalamBulan, kelompok);

    final perTahap = <String, int>{};
    for (final p in berjalan) {
      perTahap.update(p.tahap, (v) => v + 1, ifAbsent: () => 1);
    }

    final tampil = saringPesanan(
      berjalan,
      hanyaTahap: kelompok.tahap,
      tahap: filter.tahap,
      query: filter.query,
    );
    final tahapDipilih =
        filter.tahap != null && kelompok.tahap.contains(filter.tahap)
        ? filter.tahap
        : null;
    final caraBayar = {
      for (final m
          in ref.watch(allMetodeBayarProvider).valueOrNull ??
              const <MetodeBayar>[])
        m.kode: m.nama,
    };
    final labelBulan = bulanDipilih == null
        ? 'Belum ada pesanan'
        : _labelBulan(bulanDipilih);
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
            subtitle:
                '${berjalan.length} pesanan  ·  ${kelompok.label}  ·  $labelBulan',
            actions: [
              // Daftar bulan terbaru lebih dulu, jadi "sebelumnya" adalah indeks
              // yang lebih besar.
              IconButton(
                tooltip: 'Bulan sebelumnya',
                onPressed: urutBulan >= 0 && urutBulan < daftarBulan.length - 1
                    ? () => ref.read(_bulanPesananProvider.notifier).state =
                          daftarBulan[urutBulan + 1]
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: context.warna.permukaan,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  border: Border.all(color: context.warna.garisIsian),
                ),
                child: Center(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<DateTime>(
                      value: bulanDipilih,
                      isDense: true,
                      focusColor: Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.base),
                      hint: const Text('PERIODE'),
                      items: [
                        for (final b in daftarBulan)
                          DropdownMenuItem(
                            value: b,
                            child: Text(_labelBulan(b).toUpperCase()),
                          ),
                      ],
                      onChanged: (v) =>
                          ref.read(_bulanPesananProvider.notifier).state = v,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Bulan berikutnya',
                onPressed: urutBulan > 0
                    ? () => ref.read(_bulanPesananProvider.notifier).state =
                          daftarBulan[urutBulan - 1]
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
              const SizedBox(width: AppSpacing.s),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: 'Cari nama, part, tipe, SN',
                    prefixIcon: Icon(
                      Icons.search,
                      size: 17,
                      color: context.warna.teksLembut,
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 36),
                  ),
                  onChanged: (v) => ref
                      .read(_pesananFilterProvider.notifier)
                      .update((s) => s.copyWith(query: v)),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              // Dua berkas, dengan maksud berbeda. "Sesuai tampilan" persis yang
              // sedang terlihat: bulan, kelompok, dan pencarian sudah
              // menyatakan potongan mana yang dilihat, dan berkas yang
              // isinya berbeda dari layar adalah cara paling mudah salah
              // kirim laporan. "Lengkap" tidak peduli kelompok dan pencarian:
              // satu bulan penuh, satu lembar tiap kelompok.
              TombolExport(
                label: 'EXCEL TAMPILAN',
                aktif: tampil.isNotEmpty,
                onExport: () => ExcelExport.part(
                  pesanan: tampil,
                  teknisi: techs,
                  modal: modal,
                  caraBayar: caraBayar,
                  periode: [
                    labelBulan,
                    kelompok.label,
                    if (tahapDipilih != null) PartTahap.label(tahapDipilih),
                  ].join(' '),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              TombolExport(
                label: 'EXCEL LENGKAP',
                aktif: dalamBulan.isNotEmpty,
                onExport: () => ExcelExport.partLengkap(
                  kelompok: {
                    for (final k in KelompokPesanan.values)
                      k.label.toUpperCase(): pesananKelompok(dalamBulan, k),
                  },
                  teknisi: techs,
                  modal: modal,
                  caraBayar: caraBayar,
                  periode: labelBulan,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Kelompok dulu: selesai dan belum tidak boleh bercampur. Kartu
          // tahap di bawahnya hanya merinci kelompok yang sedang dipilih.
          Row(
            children: [
              for (final k in KelompokPesanan.values) ...[
                if (k != KelompokPesanan.values.first)
                  const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: StatTile(
                    value: '${perKelompok[k]}',
                    label: k.label,
                    selected: kelompok == k,
                    onTap: () {
                      ref.read(_kelompokProvider.notifier).state = k;
                      ref
                          .read(_pesananFilterProvider.notifier)
                          .update((s) => s.copyWith(clear: true));
                    },
                  ),
                ),
              ],
            ],
          ),
          if (kelompok.tahap.length > 1) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                for (final t in kelompok.tahap) ...[
                  if (t != kelompok.tahap.first)
                    const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: StatTile(
                      value: '${perTahap[t] ?? 0}',
                      label: PartTahap.label(t),
                      accent: PartTahap.color(context, t),
                      selected: tahapDipilih == t,
                      onTap: () => ref
                          .read(_pesananFilterProvider.notifier)
                          .update(
                            (f) => tahapDipilih == t
                                ? f.copyWith(clear: true)
                                : f.copyWith(tahap: t),
                          ),
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          _Ringkasan(ringkas),
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
                      icon: Icons.local_shipping_outlined,
                      title: berjalan.isEmpty
                          ? (kelompok == KelompokPesanan.semua
                                ? 'Belum ada pesanan berjalan'
                                : 'Tidak ada pesanan ${kelompok.label.toLowerCase()}')
                          : 'Tidak ada yang cocok',
                      description: berjalan.isEmpty
                          ? 'Pesanan dimulai dari halaman Tanya Harga: buka '
                                'barisnya, lalu tekan USER DP.'
                          : 'Ubah saringan atau kata pencarian di atas.',
                    )
                  : _Tabel(
                      items: tampil,
                      techs: techs,
                      modal: modal,
                      gudang: gudang,
                    ),
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
        color: context.warna.permukaan,
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(color: context.warna.garisHalus),
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
          color: merah ? context.warna.bahaya : context.warna.teks,
        ),
      ),
    ],
  );
}

class _Tabel extends StatelessWidget {
  const _Tabel({
    required this.items,
    required this.techs,
    required this.modal,
    required this.gudang,
  });

  final List<PartOrder> items;
  final Map<String, String> techs;
  final Map<String, PartCost> modal;
  final bool gudang;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final tampilTeknisi = c.maxWidth >= 1020;
        // Modal, untung, dan nomor PO: hanya untuk yang berhak membaca
        // modal, dan hanya bila lebarnya cukup.
        final tampilModal = modal.isNotEmpty || gudang;
        final lebarModal = tampilModal && c.maxWidth >= 1280;

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
                  const Expanded(flex: 4, child: TableHeader('Part Req')),
                  if (tampilTeknisi)
                    const SizedBox(width: 92, child: TableHeader('Teknisi')),
                  if (lebarModal) ...const [
                    SizedBox(width: 104, child: TableHeader('HPP')),
                    SizedBox(width: 104, child: TableHeader('Untung')),
                    SizedBox(width: 116, child: TableHeader('No PO')),
                  ],
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
                  tampilModal: lebarModal,
                  hpp: modal[items[i].id]?.hpp,
                  gudang: gudang,
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
    required this.tampilModal,
    required this.hpp,
    required this.gudang,
  });

  final PartOrder pesanan;
  final String? teknisi;
  final bool tampilTeknisi;
  final bool tampilModal;
  final double? hpp;
  final bool gudang;

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
        // Gudang membuka data pembeliannya saja; admin membuka formulir utuh.
        onTap: () => widget.gudang
            ? showGudangPembelian(context, p)
            : showPartDialog(context, pesanan: p),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _hover ? context.warna.teredam : context.warna.permukaan,
            border: Border(
              bottom: BorderSide(color: context.warna.garisHalus),
              left: BorderSide(
                color: _hover
                    ? context.warna.bahaya
                    : (rawan ? context.warna.bahaya : Colors.transparent),
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
                child: Text(_tgl.format(_tanggalPesanan(p)), style: _sel),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        p.customerNama,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      NomorNotaTanyaHarga(p.serviceOrderId),
                    ],
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
                        ? _sel.copyWith(color: context.warna.teksLembut)
                        : _sel,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (widget.tampilModal) ...[
                SizedBox(
                  width: 104,
                  child: Text(
                    widget.hpp == null ? '—' : _rp.format(widget.hpp),
                    style: widget.hpp == null
                        ? _sel.copyWith(color: context.warna.teksLembut)
                        : _sel,
                  ),
                ),
                SizedBox(
                  width: 104,
                  child: Text(
                    widget.hpp == null || p.harga == null
                        ? '—'
                        : _rp.format(p.harga! - widget.hpp!),
                    style: _sel,
                  ),
                ),
                SizedBox(
                  width: 116,
                  child: Text(
                    p.noPo ?? '—',
                    style: p.noPo == null
                        ? _sel.copyWith(color: context.warna.teksLembut)
                        : _sel.copyWith(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              SizedBox(
                width: 104,
                child: Text(
                  p.harga == null ? '—' : _rp.format(p.harga),
                  style: _sel,
                ),
              ),
              SizedBox(
                width: 104,
                child: Text(p.dp == 0 ? '—' : _rp.format(p.dp), style: _sel),
              ),
              SizedBox(
                width: 104,
                child: Text(
                  p.sisa == 0 ? 'LUNAS' : _rp.format(p.sisa),
                  style: _sel.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: p.sisa == 0 ? 10 : 13,
                    letterSpacing: p.sisa == 0 ? 0.7 : 0,
                    color: p.sisa == 0
                        ? context.warna.teksLembut
                        : context.warna.bahaya,
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

/// Warnanya sengaja tidak disebut: yang tidak menyebut warna mewarisi
/// warna teks dari tema yang sedang berlaku, dan itulah yang membuat sel
/// ini benar di terang maupun gelap.
const _sel = TextStyle(fontSize: 13);
