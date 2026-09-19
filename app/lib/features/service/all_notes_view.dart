import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/bento.dart';
import '../../core/widgets/swiss_widgets.dart';
import '../scan/scan_page.dart';
import 'service_dialog.dart';
import 'service_status.dart';
import 'waktu_masuk.dart';

final _rp = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);
final _bulanTahun = DateFormat('MMMM yyyy', 'id');

final _filterProvider = StateProvider<String?>((ref) => null);
final _cariProvider = StateProvider<String>((ref) => '');

/// Bulan yang sedang dilihat. Null berarti seluruh arsip.
final _bulanProvider = StateProvider<DateTime?>((ref) {
  final n = DateTime.now();
  return DateTime(n.year, n.month);
});

/// Arsip seluruh nota servis.
///
/// Terpisah dari halaman Servis dengan sengaja. Halaman Servis adalah alat
/// kerja meja depan -- yang masuk hari ini dan yang harus selesai hari ini
/// -- dan daftar ribuan nota sejak Januari bukan alat kerja. Ini tempat
/// mencari nota lama, dan hanya itu.
class AllNotesView extends ConsumerStatefulWidget {
  const AllNotesView({super.key});

  @override
  ConsumerState<AllNotesView> createState() => _AllNotesViewState();
}

class _AllNotesViewState extends ConsumerState<AllNotesView> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final semua =
        ref.watch(serviceOrdersProvider).valueOrNull ??
        const <ServiceOrderEntry>[];
    final status = ref.watch(_filterProvider);
    final bulan = ref.watch(_bulanProvider);
    final cari = ref.watch(_cariProvider);
    final techs = {
      for (final p
          in ref.watch(techniciansProvider).valueOrNull ?? const <Profile>[])
        p.id: p.nama,
    };

    // Kata pencarian membuka seluruh arsip, sama seperti di halaman
    // Servis: yang mengetik nomor nota mencari notanya, bukan notanya di
    // bulan yang kebetulan sedang dipilih.
    final mencari = cari.trim().isNotEmpty;
    final cakupan = [
      for (final n in semua)
        if (mencari || bulan == null || _bulanSama(n.tanggalMasuk, bulan))
          if (_cocok(n, cari)) n,
    ];

    final perStatus = <String, int>{};
    for (final n in cakupan) {
      perStatus.update(n.status, (v) => v + 1, ifAbsent: () => 1);
    }

    final tampil = [
      for (final n in cakupan)
        if (status == null || n.status == status) n,
    ];

    final nilai = tampil.fold<double>(0, (a, n) => a + n.biaya);
    final belumLunas = tampil
        .where((n) => n.biaya > 0 && n.tanggalLunas == null)
        .fold<double>(0, (a, n) => a + n.biaya);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'Semua Nota',
            subtitle: mencari
                ? 'Mencari di seluruh ${semua.length} nota  ·  '
                      '${tampil.length} ketemu'
                : '${cakupan.length} nota  ·  ${semua.length} di seluruh arsip',
            actions: [
              if (!mencari) ...[
                _PilihBulan(bulan: bulan),
                const SizedBox(width: AppSpacing.s),
              ],
              SizedBox(
                width: 300,
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: 'Cari no nota, nama, SN, telp',
                    prefixIcon: Icon(
                      Icons.search,
                      size: 17,
                      color: context.warna.teksLembut,
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 36),
                    suffixIcon: ScanFieldButton(
                      title: 'Pindai SN untuk mencari',
                      onScanned: (v) {
                        _search.text = v;
                        ref.read(_cariProvider.notifier).state = v;
                      },
                    ),
                  ),
                  onChanged: (v) => ref.read(_cariProvider.notifier).state = v,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          Row(
            children: [
              Expanded(
                child: StatTile(
                  value: '${cakupan.length}',
                  label: 'Semua',
                  selected: status == null,
                  onTap: () => ref.read(_filterProvider.notifier).state = null,
                ),
              ),
              for (final s in ServiceStatus.all) ...[
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: StatTile(
                    value: '${perStatus[s] ?? 0}',
                    label: ServiceStatus.label(s),
                    accent: ServiceStatus.color(context, s),
                    selected: status == s,
                    onTap: () => ref.read(_filterProvider.notifier).state = s,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _Ringkasan(jumlah: tampil.length, nilai: nilai, belum: belumLunas),
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
                      icon: Icons.inventory_2_outlined,
                      title: mencari
                          ? 'Tidak ada nota yang cocok'
                          : 'Tidak ada nota di bulan ini',
                      description: mencari
                          ? 'Pencarian menjangkau seluruh arsip. Coba kata '
                                'lain.'
                          : 'Pilih bulan lain di atas, atau "Semua Bulan" '
                                'untuk arsip penuh.',
                    )
                  : _Tabel(items: tampil, techs: techs),
            ),
          ),
        ],
      ),
    );
  }

  static bool _bulanSama(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  static bool _cocok(ServiceOrderEntry n, String cari) {
    final q = cari.toLowerCase().trim();
    if (q.isEmpty) return true;
    return n.noNota.toLowerCase().contains(q) ||
        n.customerNama.toLowerCase().contains(q) ||
        (n.barangSn ?? '').toLowerCase().contains(q) ||
        (n.barangNama).toLowerCase().contains(q) ||
        (n.customerTelp ?? '').contains(q);
  }
}

class _PilihBulan extends ConsumerWidget {
  const _PilihBulan({required this.bulan});

  final DateTime? bulan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = DateTime.now();
    final iniBulan = DateTime(n.year, n.month);
    final bisaMaju = bulan != null && bulan!.isBefore(iniBulan);

    void pindah(int ke) {
      final b = bulan;
      if (b == null) return;
      ref.read(_bulanProvider.notifier).state = DateTime(b.year, b.month + ke);
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.warna.garisIsian),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Bulan sebelumnya',
            iconSize: 17,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_left),
            onPressed: bulan == null ? null : () => pindah(-1),
          ),
          InkWell(
            // Mengetuk tanggalnya melepas batas bulannya sama sekali.
            // Arsip penuh memang kadang yang dicari, dan itu satu ketukan.
            onTap: () => ref.read(_bulanProvider.notifier).state = bulan == null
                ? iniBulan
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Text(
                bulan == null
                    ? 'SEMUA BULAN'
                    : _bulanTahun.format(bulan!).toUpperCase(),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Bulan berikutnya',
            iconSize: 17,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_right),
            onPressed: bisaMaju ? () => pindah(1) : null,
          ),
        ],
      ),
    );
  }
}

class _Ringkasan extends StatelessWidget {
  const _Ringkasan({
    required this.jumlah,
    required this.nilai,
    required this.belum,
  });

  final int jumlah;
  final double nilai;
  final double belum;

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
          Expanded(child: _Angka('Nota Tampil', '$jumlah')),
          Expanded(child: _Angka('Nilai Jasa', _rp.format(nilai))),
          Expanded(
            child: _Angka('Belum Lunas', _rp.format(belum), merah: belum > 0),
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
  const _Tabel({required this.items, required this.techs});

  final List<ServiceOrderEntry> items;
  final Map<String, String> techs;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final tampilTelp = c.maxWidth >= 1180;
        final tampilTeknisi = c.maxWidth >= 900;

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
                  const SizedBox(width: 132, child: TableHeader('No Nota')),
                  const SizedBox(width: 76, child: TableHeader('Masuk')),
                  const Expanded(flex: 3, child: TableHeader('Pelanggan')),
                  if (tampilTelp)
                    const SizedBox(width: 108, child: TableHeader('Telp')),
                  const Expanded(flex: 3, child: TableHeader('Barang')),
                  if (tampilTeknisi)
                    const SizedBox(width: 92, child: TableHeader('Teknisi')),
                  const SizedBox(width: 116, child: TableHeader('Biaya')),
                  const SizedBox(width: 116, child: TableHeader('Status')),
                ],
              ),
            ),
            Expanded(
              // Ribuan baris: dibangun sesuai kebutuhan, bukan sekaligus.
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: AppSpacing.s),
                itemCount: items.length,
                itemBuilder: (context, i) => _Baris(
                  nota: items[i],
                  teknisi: techs[items[i].teknisiId],
                  tampilTelp: tampilTelp,
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
    required this.nota,
    required this.teknisi,
    required this.tampilTelp,
    required this.tampilTeknisi,
  });

  final ServiceOrderEntry nota;
  final String? teknisi;
  final bool tampilTelp;
  final bool tampilTeknisi;

  @override
  State<_Baris> createState() => _BarisState();
}

class _BarisState extends State<_Baris> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.nota;
    final belumLunas = n.biaya > 0 && n.tanggalLunas == null;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => showServiceDialog(context, nota: n),
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
                width: 132,
                child: Row(
                  children: [
                    if (n.garansi)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.verified_outlined,
                          size: 12,
                          color: context.warna.aksen,
                        ),
                      ),
                    Flexible(
                      child: Text(
                        n.noNota,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 76, child: SelMasuk(n.tanggalMasuk)),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.s),
                  child: Text(
                    n.customerNama,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (widget.tampilTelp)
                SizedBox(
                  width: 108,
                  child: Text(n.customerTelp ?? '—', style: _sel),
                ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.s),
                  child: Text(
                    [
                      n.barangNama,
                      if (n.barangType != null) n.barangType!,
                    ].join('  '),
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
              SizedBox(
                width: 116,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.biaya == 0 ? '—' : _rp.format(n.biaya),
                      style: _sel.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (belumLunas)
                      Text(
                        'BELUM LUNAS',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: context.warna.bahaya,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: 116,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: StatusNotaChip(n, compact: true),
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
