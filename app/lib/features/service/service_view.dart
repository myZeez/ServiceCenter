import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/models.dart';
import '../../core/hari_laporan.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/bento.dart';
import '../../core/widgets/swiss_widgets.dart';
import '../scan/scan_page.dart';
import 'service_dialog.dart';
import 'service_status.dart';
import 'teknisi_ringkas.dart';
import 'waktu_masuk.dart';

final _rp = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
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

/// Hari kerja yang sedang dilihat di halaman Servis.
///
/// Sesudah jam tutup ia sudah menunjuk hari berikutnya, dan itu memang
/// yang dibutuhkan: nota yang dibuat jam 17.30 tercatat sebagai nota
/// besok, dan halaman yang masih menampilkan hari ini akan terlihat
/// seperti baru saja menelan nota yang barusan diketik.
final hariServisProvider = StateProvider<DateTime>(
  (ref) => hariLaporanKini(ref.read(jamTutupProvider)),
);

bool _hariSama(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Nota yang tampil di halaman Servis.
///
/// Dibatasi pada satu hari, karena itulah yang dikerjakan di meja depan:
/// yang masuk hari ini dan yang harus diselesaikan hari ini. Daftar tiga
/// ribu nota sejak Januari bukan alat kerja, ia arsip -- dan arsip punya
/// halamannya sendiri.
///
/// Kecuali saat mencari. Kata pencarian membuka seluruh arsip, karena
/// orang yang mengetik "Irwan" mencari notanya, bukan notanya hari ini --
/// dan daftar kosong karena harinya kebetulan salah adalah jawaban yang
/// menyesatkan.
List<ServiceOrderEntry> saringNota(
  List<ServiceOrderEntry> semua, {
  required DateTime hari,
  String? status,
  String query = '',
  int jamTutup = jamTutupBawaan,
}) {
  final q = query.toLowerCase().trim();

  return [
    for (final n in semua)
      if ((q.isNotEmpty || hariLaporanSama(n.tanggalMasuk, hari, jamTutup)) &&
          (status == null || n.status == status) &&
          (q.isEmpty ||
              n.noNota.toLowerCase().contains(q) ||
              n.customerNama.toLowerCase().contains(q) ||
              (n.barangSn ?? '').toLowerCase().contains(q) ||
              (n.customerTelp ?? '').contains(q)))
        n,
  ];
}

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

    final hari = ref.watch(hariServisProvider);
    final jamTutup = ref.watch(jamTutupProvider);
    final mencari = filter.query.trim().isNotEmpty;

    final sekarang = DateTime.now();
    final sudahTutup = !_hariSama(
      hariLaporan(sekarang, jamTutup),
      DateTime(sekarang.year, sekarang.month, sekarang.day),
    );

    // Angka di kotak ikut cakupan daftarnya: saat mencari ia menghitung
    // seluruh arsip, saat tidak ia menghitung hari itu saja. Kotak yang
    // menghitung sesuatu yang berbeda dari daftarnya adalah cara paling
    // mudah membuat orang mengira ada nota yang hilang.
    final cakupan = saringNota(
      semua,
      hari: hari,
      query: filter.query,
      jamTutup: jamTutup,
    );
    final perStatus = <String, int>{};
    for (final n in cakupan) {
      perStatus.update(n.status, (v) => v + 1, ifAbsent: () => 1);
    }

    final tampil = saringNota(
      semua,
      hari: hari,
      status: filter.status,
      query: filter.query,
      jamTutup: jamTutup,
    );

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
                // Sesudah jam tutup halaman ini menunjuk tanggal besok.
                // Tanpa kalimatnya, yang terlihat adalah tanggal yang
                // berpindah sendiri -- dan nota yang baru saja diketik
                // seolah masuk ke hari yang salah.
                subtitle: mencari
                    ? 'Mencari di seluruh ${semua.length} nota  ·  '
                          '${tampil.length} ketemu'
                    : sudahTutup
                    ? '${cakupan.length} nota  ·  laporan tutup $jamTutup.00, '
                          'nota baru masuk hari berikutnya'
                    : '${cakupan.length} nota  ·  Ctrl+N untuk tambah',
                actions: [
                  if (!mencari) ...[
                    _PilihHari(hari: hari),
                    const SizedBox(width: AppSpacing.s),
                  ],
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

              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    final daftarNota = Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(AppRadius.base),
                        border: Border.all(color: const Color(0xFFE4E7E7)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: tampil.isEmpty
                          ? EmptyState(
                              icon: Icons.receipt_long_outlined,
                              title: mencari
                                  ? 'Tidak ada nota yang cocok'
                                  : 'Belum ada nota hari ini',
                              // Kosong pada satu hari bukan berarti tidak
                              // ada apa-apa; halaman ini memang cuma
                              // memuat satu hari, dan itu perlu disebut.
                              description: mencari
                                  ? 'Pencarian menjangkau seluruh arsip. '
                                        'Coba kata lain.'
                                  : 'Halaman ini memuat satu hari saja. '
                                        'Pindah harinya di atas, atau buka '
                                        'Semua Nota untuk arsip lengkapnya.',
                              action: OutlinedButton(
                                onPressed: () => showServiceDialog(context),
                                child: const Text('TAMBAH SERVIS'),
                              ),
                            )
                          : _Tabel(items: tampil, techs: techs),
                    );

                    // Di jendela sempit panelnya disembunyikan, bukan
                    // dipaksa muat: kolom nota yang tergencet sampai nama
                    // pelanggan terpotong lebih merugikan daripada tidak
                    // melihat beban teknisi sama sekali.
                    if (c.maxWidth < 1180) return daftarNota;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: daftarNota),
                        const SizedBox(width: AppSpacing.s),
                        const SizedBox(width: 292, child: _PanelTeknisi()),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pemilih hari: mundur, maju, dan ketuk tanggalnya untuk melompat.
///
/// Tombol maju mati saat sudah di hari ini. Nota bertanggal besok tidak
/// pernah ada, dan tombol yang selalu bisa ditekan menuju halaman kosong
/// hanya membuat orang mengira datanya hilang.
class _PilihHari extends ConsumerWidget {
  const _PilihHari({required this.hari});

  final DateTime hari;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jamTutup = ref.watch(jamTutupProvider);
    final n = DateTime.now();

    // Hari kerja, bukan hari kalender. Sesudah jam tutup keduanya berbeda,
    // dan yang dipakai halaman ini adalah hari kerjanya -- termasuk untuk
    // menentukan sampai mana tombol maju boleh melangkah.
    final iniHari = hariLaporan(n, jamTutup);
    final bisaMaju = hari.isBefore(iniHari);

    void pindah(int hariKe) => ref.read(hariServisProvider.notifier).state =
        hari.add(Duration(days: hariKe));

    final kotak = Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCFD5D4)),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Hari sebelumnya',
            iconSize: 17,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_left),
            onPressed: () => pindah(-1),
          ),
          InkWell(
            onTap: () async {
              final p = await showDatePicker(
                context: context,
                initialDate: hari,
                firstDate: DateTime(2020),
                lastDate: iniHari,
              );
              if (p != null) {
                ref.read(hariServisProvider.notifier).state = DateTime(
                  p.year,
                  p.month,
                  p.day,
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Text(
                _hariSama(hari, iniHari)
                    ? 'HARI INI'
                    : DateFormat('d MMM yyyy', 'id').format(hari).toUpperCase(),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Hari berikutnya',
            iconSize: 17,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_right),
            onPressed: bisaMaju ? () => pindah(1) : null,
          ),
        ],
      ),
    );

    // Keterangan jam tutupnya tidak ditaruh di sebelah kotak ini.
    // Menambah satu widget lagi ke baris tombol halaman ini membuat
    // tata letaknya jebol di jendela 1000 piksel -- ada test yang
    // menangkapnya. Kalimatnya pindah ke subjudul halaman, tempat orang
    // memang membaca konteks.
    return kotak;
  }
}

/// Beban dan hasil tiap teknisi bulan ini, di sisi kanan daftar nota.
///
/// Ditaruh di halaman servis, bukan di laporan: yang dijawabnya pertanyaan
/// harian -- siapa yang sedang penuh, siapa yang bisa diberi unit
/// berikutnya -- dan itu diputuskan di meja depan, bukan saat tutup buku.
///
/// Bentuknya daftar menurun, bukan kartu berjajar: jumlah teknisi bisa
/// bertambah, dan yang berjajar mendatar akan terpotong di tepi kanan
/// begitu orangnya lebih dari lima.
class _PanelTeknisi extends ConsumerWidget {
  const _PanelTeknisi();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daftar = ref.watch(ringkasTeknisiProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(color: const Color(0xFFE4E7E7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.s,
              AppSpacing.sm,
              AppSpacing.s,
            ),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.black, width: 1.5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'TEKNISI',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                Text(
                  'BULAN INI',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          Expanded(
            child: daftar.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Text(
                        'Belum ada teknisi aktif.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: daftar.length,
                    itemBuilder: (context, i) => _BarisTeknisi(daftar[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BarisTeknisi extends StatelessWidget {
  const _BarisTeknisi(this.r);

  final RingkasTeknisi r;

  @override
  Widget build(BuildContext context) {
    // Merah hanya saat antreannya menumpuk, supaya warnanya masih berarti
    // sesuatu ketika muncul.
    final penuh = r.unitBerjalan >= 5;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 9,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEFF1F1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  r.teknisi.nama,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${_rp.format(r.omset)}  ·  ${r.notaSelesai} selesai',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          // Lebar tetap supaya angkanya berderet rapi ke bawah, tidak
          // bergeser mengikuti panjang nama di sebelahnya.
          SizedBox(
            width: 54,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${r.unitBerjalan}',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    letterSpacing: -0.5,
                    color: penuh ? AppColors.red : AppColors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text('UNIT', style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
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
