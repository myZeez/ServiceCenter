import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/galat.dart';
import '../../core/data/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/bento.dart';
import '../../core/widgets/swiss_widgets.dart';
import 'service_dialog.dart';
import 'service_status.dart';
import 'waktu_masuk.dart';

final _rp = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);
final _bulanTahun = DateFormat('MMMM yyyy', 'id');

/// Pilihan "belum ada teknisi". Bukan id siapa pun -- id profil selalu
/// uuid, jadi teks kosong tidak mungkin bertabrakan.
const belumAdaTeknisi = '';

/// Kelompok status yang bisa disaring di halaman ini.
///
/// Lebih kasar daripada status nota, dengan sengaja: yang ingin diketahui
/// di sini adalah "apa yang masih dipegangnya" dan "apa yang sudah
/// rampung", bukan perbedaan Masuk dan Dikerjakan.
enum KelompokKerja {
  berjalan('Masih Dikerjakan'),
  selesai('Selesai'),
  diambil('Sudah Diambil'),
  batal('Batal');

  const KelompokKerja(this.label);
  final String label;

  bool cocok(String status) => switch (this) {
    berjalan => ServiceStatus.sedangDikerjakan(status),
    selesai => status == ServiceStatus.selesai,
    diambil => status == ServiceStatus.diambil,
    batal => status == ServiceStatus.batal,
  };
}

bool _bulanSama(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

bool _cocokCari(ServiceOrderEntry n, String cari) {
  final q = cari.toLowerCase().trim();
  if (q.isEmpty) return true;
  return n.noNota.toLowerCase().contains(q) ||
      n.customerNama.toLowerCase().contains(q) ||
      (n.barangSn ?? '').toLowerCase().contains(q) ||
      n.barangNama.toLowerCase().contains(q) ||
      (n.customerTelp ?? '').contains(q);
}

/// Jumlah nota tiap pengerja pada bulan terpilih. Nota tanpa teknisi
/// dihitung di bawah [belumAdaTeknisi].
///
/// [bulan] kosong berarti seluruh arsip.
Map<String, int> hitungPerTeknisi(
  Iterable<ServiceOrderEntry> semua, {
  DateTime? bulan,
}) {
  final hasil = <String, int>{};
  for (final n in semua) {
    if (bulan != null && !_bulanSama(n.tanggalMasuk, bulan)) continue;
    hasil.update(
      n.teknisiId ?? belumAdaTeknisi,
      (v) => v + 1,
      ifAbsent: () => 1,
    );
  }
  return hasil;
}

/// Nota milik satu pengerja -- atau yang belum punya pengerja sama sekali.
///
/// Kata pencarian melepas batas bulannya, sama seperti di Semua Nota:
/// yang mengetik nomor nota mencari notanya, bukan notanya di bulan yang
/// kebetulan sedang dipilih. Batas pengerjanya tetap berlaku.
List<ServiceOrderEntry> notaMilik(
  Iterable<ServiceOrderEntry> semua, {
  required String teknisi,
  DateTime? bulan,
  String cari = '',
  KelompokKerja? kelompok,
}) {
  final mencari = cari.trim().isNotEmpty;
  return [
    for (final n in semua)
      if ((n.teknisiId ?? belumAdaTeknisi) == teknisi &&
          (mencari || bulan == null || _bulanSama(n.tanggalMasuk, bulan)) &&
          _cocokCari(n, cari) &&
          (kelompok == null || kelompok.cocok(n.status)))
        n,
  ];
}

final _teknisiProvider = StateProvider<String>((ref) => belumAdaTeknisi);
final _kelompokProvider = StateProvider<KelompokKerja?>((ref) => null);
final _cariProvider = StateProvider<String>((ref) => '');

/// Bulan yang sedang dilihat. Bawaannya seluruh arsip: nota tanpa teknisi
/// tersebar sejak Januari, dan yang dicari justru semuanya.
final _bulanProvider = StateProvider<DateTime?>((ref) => null);

/// Nota per pengerja, dan nota yang belum punya pengerja.
///
/// Dua kebutuhan, satu halaman, karena keduanya pertanyaan yang sama dari
/// arah berlawanan: "Budi mengerjakan apa saja" dan "yang ini dikerjakan
/// siapa". Pengerjanya bisa langsung dipilih dari barisnya -- nota yang
/// diberi pengerja pindah dari daftar "Belum Ada Teknisi" ke daftar
/// orangnya, tanpa membuka formulir nota satu per satu.
class KerjaTeknisiView extends ConsumerStatefulWidget {
  const KerjaTeknisiView({super.key});

  @override
  ConsumerState<KerjaTeknisiView> createState() => _KerjaTeknisiViewState();
}

class _KerjaTeknisiViewState extends ConsumerState<KerjaTeknisiView> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(_cariProvider);
  }

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
    final teknisi = ref.watch(_teknisiProvider);
    final kelompok = ref.watch(_kelompokProvider);
    final bulan = ref.watch(_bulanProvider);
    final cari = ref.watch(_cariProvider);
    final mencari = cari.trim().isNotEmpty;

    final pengerja = ref.watch(pengerjaProvider);
    final profil =
        ref.watch(allProfilesProvider).valueOrNull ?? const <Profile>[];
    final nama = {for (final p in profil) p.id: p.nama};

    final jumlah = hitungPerTeknisi(semua, bulan: bulan);

    // Pengerja aktif selalu tampil, walau bulan ini kosong. Yang sudah
    // tidak aktif hanya tampil kalau memang punya nota di bulan ini --
    // pekerjaannya tetap miliknya, dan harus tetap bisa dilihat.
    final orang = [
      for (final p in pengerja) p.id,
      for (final id in jumlah.keys)
        if (id != belumAdaTeknisi && !pengerja.any((p) => p.id == id)) id,
    ];

    final milik = notaMilik(semua, teknisi: teknisi, bulan: bulan, cari: cari);
    final tampil = [
      for (final n in milik)
        if (kelompok == null || kelompok.cocok(n.status)) n,
    ];

    final perKelompok = {
      for (final k in KelompokKerja.values)
        k: milik.where((n) => k.cocok(n.status)).length,
    };
    final nilai = tampil.fold<double>(0, (a, n) => a + n.biaya);
    final belumLunas = tampil
        .where((n) => n.biaya > 0 && n.tanggalLunas == null)
        .fold<double>(0, (a, n) => a + n.biaya);

    final namaTerpilih = teknisi == belumAdaTeknisi
        ? 'Belum ada teknisi'
        : (nama[teknisi] ?? 'Pengguna terhapus');

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'Kerja Teknisi',
            subtitle: mencari
                ? 'Mencari di seluruh nota $namaTerpilih  ·  '
                      '${tampil.length} ketemu'
                : '${jumlah[belumAdaTeknisi] ?? 0} nota belum ada '
                      'teknisinya  ·  '
                      '${bulan == null ? 'seluruh arsip' : _bulanTahun.format(bulan)}',
            actions: [
              if (!mencari) ...[
                _PilihBulan(bulan: bulan),
                const SizedBox(width: AppSpacing.s),
              ],
              SizedBox(
                width: 280,
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
                  ),
                  onChanged: (v) => ref.read(_cariProvider.notifier).state = v,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          _BarisTile(
            children: [
              StatTile(
                value: '${jumlah[belumAdaTeknisi] ?? 0}',
                label: 'Belum Ada Teknisi',
                accent: context.warna.bahaya,
                selected: teknisi == belumAdaTeknisi,
                onTap: () =>
                    ref.read(_teknisiProvider.notifier).state = belumAdaTeknisi,
              ),
              for (final id in orang)
                StatTile(
                  value: '${jumlah[id] ?? 0}',
                  label: nama[id] ?? 'Pengguna terhapus',
                  selected: teknisi == id,
                  onTap: () => ref.read(_teknisiProvider.notifier).state = id,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),

          Row(
            children: [
              _ChipKelompok(
                label: 'SEMUA  ${milik.length}',
                aktif: kelompok == null,
                onTap: () => ref.read(_kelompokProvider.notifier).state = null,
              ),
              for (final k in KelompokKerja.values)
                _ChipKelompok(
                  label: '${k.label.toUpperCase()}  ${perKelompok[k]}',
                  aktif: kelompok == k,
                  onTap: () => ref.read(_kelompokProvider.notifier).state = k,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
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
                      icon: teknisi == belumAdaTeknisi
                          ? Icons.task_alt
                          : Icons.engineering_outlined,
                      title: mencari
                          ? 'Tidak ada nota yang cocok'
                          : teknisi == belumAdaTeknisi
                          ? 'Semua nota sudah ada teknisinya'
                          : '$namaTerpilih belum punya nota di sini',
                      description: mencari
                          ? 'Pencarian menjangkau seluruh nota $namaTerpilih. '
                                'Coba kata lain.'
                          : 'Pilih bulan lain di atas, atau "Semua Bulan" '
                                'untuk arsip penuh.',
                    )
                  : _Tabel(items: tampil, pengerja: pengerja, nama: nama),
            ),
          ),
        ],
      ),
    );
  }
}

/// Deretan kotak yang mengisi lebar penuh, dan turun ke baris berikutnya
/// begitu kotaknya terlalu sempit untuk dibaca. Jumlah pengguna bisa
/// bertambah kapan saja; yang tidak boleh terjadi adalah nama yang
/// terpotong jadi tiga huruf.
class _BarisTile extends StatelessWidget {
  const _BarisTile({required this.children});

  final List<Widget> children;

  static const _jarak = AppSpacing.xs;
  static const _lebarMin = 128.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final n = children.length;
        final perBaris = math.max(
          1,
          math.min(n, ((c.maxWidth + _jarak) / (_lebarMin + _jarak)).floor()),
        );
        final lebar = (c.maxWidth - _jarak * (perBaris - 1)) / perBaris;
        return Wrap(
          spacing: _jarak,
          runSpacing: _jarak,
          children: [
            for (final w in children) SizedBox(width: lebar, child: w),
          ],
        );
      },
    );
  }
}

class _ChipKelompok extends StatelessWidget {
  const _ChipKelompok({
    required this.label,
    required this.aktif,
    required this.onTap,
  });

  final String label;
  final bool aktif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.small),
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: aktif ? context.warna.teks : context.warna.permukaan,
            border: Border.all(
              color: aktif ? context.warna.teks : context.warna.garisIsian,
            ),
            borderRadius: BorderRadius.circular(AppRadius.small),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: aktif ? context.warna.kertas : context.warna.teks,
            ),
          ),
        ),
      ),
    );
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
            // Satu ketukan berpindah antara seluruh arsip dan bulan ini.
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
  const _Tabel({
    required this.items,
    required this.pengerja,
    required this.nama,
  });

  final List<ServiceOrderEntry> items;
  final List<Profile> pengerja;
  final Map<String, String> nama;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final tampilKeluhan = c.maxWidth >= 1080;

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
                  const Expanded(flex: 3, child: TableHeader('Barang')),
                  if (tampilKeluhan)
                    const Expanded(flex: 3, child: TableHeader('Keluhan')),
                  const SizedBox(width: 110, child: TableHeader('Biaya')),
                  const SizedBox(width: 128, child: TableHeader('Status')),
                  const SizedBox(width: 150, child: TableHeader('Teknisi')),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: AppSpacing.s),
                itemCount: items.length,
                itemBuilder: (context, i) => _Baris(
                  // Kunci per nota: baris yang baru saja diberi teknisi
                  // lenyap dari daftar, dan tanpa kunci keadaan hover-nya
                  // berpindah ke nota di bawahnya.
                  key: ValueKey(items[i].id),
                  nota: items[i],
                  pengerja: pengerja,
                  nama: nama,
                  tampilKeluhan: tampilKeluhan,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Baris extends ConsumerStatefulWidget {
  const _Baris({
    super.key,
    required this.nota,
    required this.pengerja,
    required this.nama,
    required this.tampilKeluhan,
  });

  final ServiceOrderEntry nota;
  final List<Profile> pengerja;
  final Map<String, String> nama;
  final bool tampilKeluhan;

  @override
  ConsumerState<_Baris> createState() => _BarisState();
}

class _BarisState extends ConsumerState<_Baris> {
  bool _hover = false;
  bool _menyimpan = false;

  /// Memberi nota ini pengerja, langsung dari barisnya.
  ///
  /// Yang dikirim hanya kolom teknisi. Status, biaya, dan kolom lain tidak
  /// ikut, jadi tidak ada yang bisa tertimpa oleh daftar yang sedang
  /// terbuka sejak beberapa menit lalu.
  Future<void> _tunjuk(String? id) async {
    final n = widget.nota;
    final lama = n.teknisiId;
    if (id == lama) return;

    setState(() => _menyimpan = true);
    final messenger = ScaffoldMessenger.of(context);
    final db = ref.read(databaseProvider);
    try {
      await db.ubahNota(n.id, {'teknisi_id': id});
    } catch (e) {
      if (mounted) setState(() => _menyimpan = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(pesanGalat(e)),
          duration: const Duration(seconds: 8),
        ),
      );
      return;
    }
    if (mounted) setState(() => _menyimpan = false);

    // Yang lama disingkirkan dulu: dua nota yang dipilih berurutan tidak
    // perlu menumpuk dua pemberitahuan yang masing-masing menunggu
    // gilirannya, dan tombol URUNGKAN yang tersisa memang hanya berlaku
    // untuk pilihan yang terakhir.
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${n.noNota} → ${id == null ? 'tanpa teknisi' : (widget.nama[id] ?? '—')}',
          ),
          // Barisnya langsung pindah ke daftar orang lain begitu disimpan,
          // jadi salah pilih tidak bisa dibetulkan dari baris yang sama.
          // Jalan pulangnya di sini.
          //
          // persist dimatikan dengan sengaja. Flutter membuat SnackBar yang
          // punya tombol aksi bertahan sampai ditekan dan mengabaikan
          // durasinya; tanpa ini pemberitahuan menempel selamanya, dan
          // semua pemberitahuan sesudahnya (tersimpan, galat) antre di
          // belakangnya tanpa pernah tampil.
          duration: const Duration(seconds: 8),
          persist: false,
          action: SnackBarAction(
            label: 'URUNGKAN',
            onPressed: () async {
              try {
                await db.ubahNota(n.id, {'teknisi_id': lama});
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text(pesanGalat(e))));
              }
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.nota;
    final belumLunas = n.biaya > 0 && n.tanggalLunas == null;

    // Pengerja yang sudah dinonaktifkan tetap ikut sebagai pilihan saat
    // memang dialah yang tercatat: dropdown yang nilainya tidak ada di
    // antara pilihannya melempar galat.
    final pilihan = [
      ...widget.pengerja,
      if (n.teknisiId != null &&
          !widget.pengerja.any((p) => p.id == n.teknisiId))
        Profile(
          id: n.teknisiId!,
          nama: widget.nama[n.teknisiId] ?? 'Pengguna terhapus',
          role: '',
          aktif: false,
        ),
    ];

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
            8,
            AppSpacing.sm,
            8,
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
              if (widget.tampilKeluhan)
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.s),
                    child: Text(
                      n.keluhan ?? '—',
                      style: _sel.copyWith(color: context.warna.teksLembut),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              SizedBox(
                width: 110,
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
                width: 128,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: StatusNotaChip(n, compact: true),
                ),
              ),
              SizedBox(
                width: 150,
                child: _menyimpan
                    ? const Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _PilihTeknisi(
                        nilai: n.teknisiId,
                        pilihan: pilihan,
                        onPilih: _tunjuk,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PilihTeknisi extends StatelessWidget {
  const _PilihTeknisi({
    required this.nilai,
    required this.pilihan,
    required this.onPilih,
  });

  final String? nilai;
  final List<Profile> pilihan;
  final ValueChanged<String?> onPilih;

  @override
  Widget build(BuildContext context) {
    final kosong = nilai == null;

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        border: Border.all(
          color: kosong ? context.warna.bahaya : context.warna.garisIsian,
        ),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: nilai,
          isExpanded: true,
          isDense: true,
          focusColor: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.base),
          icon: const Icon(Icons.expand_more, size: 16),
          hint: Text(
            'PILIH TEKNISI',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: context.warna.bahaya,
            ),
          ),
          style: TextStyle(fontSize: 12.5, color: context.warna.teks),
          onChanged: pilihan.isEmpty ? null : onPilih,
          items: [
            for (final p in pilihan)
              DropdownMenuItem(
                value: p.id,
                child: Text(p.nama, overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
      ),
    );
  }
}

/// Warnanya sengaja tidak disebut: yang tidak menyebut warna mewarisi
/// warna teks dari tema yang sedang berlaku, dan itulah yang membuat sel
/// ini benar di terang maupun gelap.
const _sel = TextStyle(fontSize: 13);
