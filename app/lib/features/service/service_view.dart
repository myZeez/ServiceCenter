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
import 'service_dialog.dart';
import 'service_status.dart';
import 'teknisi_ringkas.dart';

final _rp = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);
final _tgl = DateFormat('dd/MM/yy');

final serviceOrdersProvider =
    StreamProvider.autoDispose<List<ServiceOrderEntry>>(
      (ref) => ref.watch(databaseProvider).watchServiceOrders(),
    );

class ServiceFilter {
  const ServiceFilter({this.status, this.query = ''});
  final String? status;
  final String query;

  ServiceFilter copyWith({String? status, String? query, bool clear = false}) =>
      ServiceFilter(
        status: clear ? null : (status ?? this.status),
        query: query ?? this.query,
      );
}

final serviceFilterProvider = StateProvider<ServiceFilter>(
  (ref) => const ServiceFilter(),
);

class ServiceView extends ConsumerStatefulWidget {
  const ServiceView({super.key});

  @override
  ConsumerState<ServiceView> createState() => _ServiceViewState();
}

class _ServiceViewState extends ConsumerState<ServiceView> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setQuery(String v) => ref
      .read(serviceFilterProvider.notifier)
      .update((s) => s.copyWith(query: v));

  @override
  Widget build(BuildContext context) {
    final semua =
        ref.watch(serviceOrdersProvider).valueOrNull ??
        const <ServiceOrderEntry>[];
    final filter = ref.watch(serviceFilterProvider);
    final techs = {
      for (final p
          in ref.watch(techniciansProvider).valueOrNull ?? const <Profile>[])
        p.id: p.nama,
    };

    final perStatus = <String, int>{};
    for (final n in semua) {
      perStatus.update(n.status, (v) => v + 1, ifAbsent: () => 1);
    }

    final q = filter.query.toLowerCase().trim();
    final tampil = semua.where((n) {
      if (filter.status != null && n.status != filter.status) return false;
      if (q.isEmpty) return true;
      return n.noNota.toLowerCase().contains(q) ||
          n.customerNama.toLowerCase().contains(q) ||
          (n.barangSn ?? '').toLowerCase().contains(q) ||
          (n.customerTelp ?? '').contains(q);
    }).toList();

    // Ctrl+N membuka formulir tanpa memindahkan tangan ke tetikus. Fokus
    // diambil otomatis agar pintasannya hidup begitu halaman terbuka, bukan
    // setelah ada yang diklik lebih dulu.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            showServiceDialog(context),
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
                title: 'Servis',
                subtitle:
                    '${semua.length} nota tercatat  ·  Ctrl+N untuk tambah',
                actions: [
                  SizedBox(
                    width: 300,
                    child: TextField(
                      controller: _search,
                      decoration: InputDecoration(
                        hintText: 'Cari no nota, nama, SN, telp',
                        prefixIcon: const Icon(
                          Icons.search,
                          size: 17,
                          color: AppColors.grey,
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
                    onPressed: () => showServiceDialog(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('TAMBAH SERVIS'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      value: '${semua.length}',
                      label: 'Semua nota',
                      selected: filter.status == null,
                      onTap: () => ref
                          .read(serviceFilterProvider.notifier)
                          .update((s) => s.copyWith(clear: true)),
                    ),
                  ),
                  for (final s in ServiceStatus.all) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: StatTile(
                        value: '${perStatus[s] ?? 0}',
                        label: ServiceStatus.label(s),
                        accent: ServiceStatus.color(s),
                        selected: filter.status == s,
                        onTap: () => ref
                            .read(serviceFilterProvider.notifier)
                            .update((f) => f.copyWith(status: s)),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.s),

              const _BarisTeknisi(),

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
                          icon: Icons.receipt_long_outlined,
                          title: semua.isEmpty
                              ? 'Belum ada nota'
                              : 'Tidak ada nota yang cocok',
                          description: semua.isEmpty
                              ? 'Nota dibuat saat pelanggan menyerahkan unitnya.'
                              : 'Ubah filter atau kata pencarian di atas.',
                          action: OutlinedButton(
                            onPressed: () => showServiceDialog(context),
                            child: const Text('TAMBAH SERVIS'),
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

/// Beban dan hasil tiap teknisi bulan ini.
///
/// Ditaruh di halaman servis, bukan di laporan: yang dijawabnya adalah
/// pertanyaan harian -- siapa yang sedang penuh, siapa yang bisa diberi
/// unit berikutnya -- dan itu diputuskan di meja depan, bukan saat tutup
/// buku.
class _BarisTeknisi extends ConsumerWidget {
  const _BarisTeknisi();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daftar = ref.watch(ringkasTeknisiProvider);
    if (daftar.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: SizedBox(
        height: 96,
        // Digulir mendatar, bukan dibagi rata: jumlah teknisi bisa bertambah,
        // dan kartu yang menyempit sampai angkanya terpotong lebih buruk
        // daripada kartu yang harus digeser.
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: daftar.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
          itemBuilder: (context, i) => _KartuTeknisi(daftar[i]),
        ),
      ),
    );
  }
}

class _KartuTeknisi extends StatelessWidget {
  const _KartuTeknisi(this.r);

  final RingkasTeknisi r;

  @override
  Widget build(BuildContext context) {
    final penuh = r.unitBerjalan >= 5;

    return Container(
      width: 228,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(color: const Color(0xFFE4E7E7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            r.teknisi.nama.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${r.unitBerjalan}',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                  height: 1,
                  // Merah hanya saat antreannya menumpuk, supaya warnanya
                  // masih berarti sesuatu ketika muncul.
                  color: penuh ? AppColors.red : AppColors.black,
                ),
              ),
              const SizedBox(width: 5),
              // Flexible, bukan Text telanjang: anak sebuah Row tidak punya
              // batas lebar, jadi label yang sedikit lebih panjang -- atau
              // ukuran huruf sistem yang dinaikkan -- akan meluber keluar
              // kartu alih-alih dipotong.
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    'unit dikerjakan',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
            ],
          ),
          Text(
            '${_rp.format(r.omset)}  ·  ${r.notaSelesai} selesai',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Tabel extends StatelessWidget {
  const _Tabel({required this.items, required this.techs});

  final List<ServiceOrderEntry> items;
  final Map<String, String> techs;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final lebar = c.maxWidth;
        final tampilTelp = lebar >= 1180;
        final tampilTeknisi = lebar >= 900;
        final tampilBiaya = lebar >= 780;

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
                  const SizedBox(width: 118, child: _H('No Nota')),
                  const SizedBox(width: 76, child: _H('Masuk')),
                  const Expanded(flex: 3, child: _H('Pelanggan')),
                  if (tampilTelp) const SizedBox(width: 108, child: _H('Telp')),
                  const Expanded(flex: 3, child: _H('Barang')),
                  if (tampilTeknisi)
                    const SizedBox(width: 92, child: _H('Teknisi')),
                  if (tampilBiaya)
                    const SizedBox(width: 116, child: _H('Biaya')),
                  const SizedBox(width: 116, child: _H('Status')),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: AppSpacing.s),
                itemCount: items.length,
                itemBuilder: (context, i) => _Baris(
                  nota: items[i],
                  teknisi: techs[items[i].teknisiId],
                  tampilTelp: tampilTelp,
                  tampilTeknisi: tampilTeknisi,
                  tampilBiaya: tampilBiaya,
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
    required this.tampilBiaya,
  });

  final ServiceOrderEntry nota;
  final String? teknisi;
  final bool tampilTelp;
  final bool tampilTeknisi;
  final bool tampilBiaya;

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
            color: _hover ? AppColors.lightGrey : AppColors.white,
            border: Border(
              bottom: const BorderSide(color: Color(0xFFE4E7E7)),
              left: BorderSide(
                color: _hover ? AppColors.red : Colors.transparent,
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
                width: 118,
                child: Row(
                  children: [
                    if (n.garansi)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.verified_outlined,
                          size: 12,
                          color: AppColors.blue,
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
              SizedBox(
                width: 76,
                child: Text(_tgl.format(n.tanggalMasuk), style: _sel),
              ),
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
                        ? _sel.copyWith(color: AppColors.grey)
                        : _sel,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (widget.tampilBiaya)
                SizedBox(
                  width: 116,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.biaya == 0 ? '—' : _rp.format(n.biaya),
                        style: _sel.copyWith(fontWeight: FontWeight.w600),
                      ),
                      // Piutang perlu terlihat sekilas: itu uang yang sudah
                      // jadi hak toko tetapi belum masuk.
                      if (belumLunas)
                        const Text(
                          'BELUM LUNAS',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: AppColors.red,
                          ),
                        ),
                    ],
                  ),
                ),
              SizedBox(
                width: 116,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ServiceStatusChip(n.status, compact: true),
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

class _H extends StatelessWidget {
  const _H(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    overflow: TextOverflow.clip,
    softWrap: false,
    style: const TextStyle(
      fontSize: 9.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 1,
      color: AppColors.black,
    ),
  );
}
