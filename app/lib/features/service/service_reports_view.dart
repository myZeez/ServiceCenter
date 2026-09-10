import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/export/excel_export.dart';
import '../../core/data/models.dart';
import '../../core/nota/nomor_nota.dart';
import '../../core/omset/omset_providers.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/bento.dart';
import '../../core/widgets/swiss_widgets.dart';
import 'service_dialog.dart';
import 'service_status.dart';
import 'shipment_dialog.dart';
import 'waktu_masuk.dart';

final _rp = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);
final _tgl = DateFormat('dd/MM/yyyy');
final _tglPanjang = DateFormat('EEEE, d MMMM yyyy', 'id');
final _namaBulan = DateFormat('MMMM yyyy', 'id');

/// Laporan servis dihitung per bulan, mengikuti cara laporan ini dibaca:
/// tutup buku bulanan, bukan kuartalan seperti bagi hasil garansi.
class Bulan {
  const Bulan(this.tahun, this.bulan);

  final int tahun;
  final int bulan;

  DateTime get awal => DateTime(tahun, bulan);
  DateTime get akhir =>
      DateTime(tahun, bulan + 1).subtract(const Duration(milliseconds: 1));

  String get label => DateFormat('MMMM yyyy', 'id').format(awal);

  bool memuat(DateTime t) => !t.isBefore(awal) && !t.isAfter(akhir);

  static List<Bulan> daftar({int mundur = 24}) {
    final kini = DateTime.now();
    return [
      for (var i = 0; i < mundur; i++)
        Bulan(
          DateTime(kini.year, kini.month - i).year,
          DateTime(kini.year, kini.month - i).month,
        ),
    ];
  }
}

final bulanProvider = StateProvider<Bulan>((ref) {
  final n = DateTime.now();
  return Bulan(n.year, n.month);
});

final shipmentsProvider = StreamProvider.autoDispose<List<ShipmentEntry>>(
  (ref) => ref.watch(databaseProvider).watchShipments(),
);

class ServiceReportsView extends ConsumerWidget {
  const ServiceReportsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bulan = ref.watch(bulanProvider);

    return DefaultTabController(
      length: 5,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s,
          vertical: AppSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'Laporan Servis',
              subtitle: 'Nota pelanggan — terpisah dari klaim garansi ke brand',
              actions: [_BulanDropdown()],
            ),
            const SizedBox(height: AppSpacing.s),
            Container(
              decoration: BoxDecoration(
                color: context.warna.permukaan,
                borderRadius: BorderRadius.circular(AppRadius.base),
                border: Border.all(color: context.warna.garisHalus),
              ),
              child: const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: 'HARIAN'),
                  Tab(text: 'OMSET'),
                  Tab(text: 'PELUNASAN'),
                  Tab(text: 'KESELURUHAN'),
                  Tab(text: 'KIRIM'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Expanded(
              child: TabBarView(
                children: [
                  const _Harian(),
                  _Omset(bulan: bulan),
                  _Pelunasan(bulan: bulan),
                  _Keseluruhan(bulan: bulan),
                  const _Kirim(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Laporan harian untuk pusat — dua tabel, keluar dan masuk
// =====================================================================

/// Tanggal yang dibuka tab Harian. Bawaannya hari kalender ini: nota
/// masuk hari ini masih terus bertambah sampai tengah malam, dan halaman
/// yang melompat ke tanggal besok jam 17.00 menyembunyikan justru nota
/// yang baru saja diketik.
final tanggalHarianProvider = StateProvider<DateTime>((ref) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
});

bool _hariSama(DateTime? a, DateTime b) =>
    a != null && a.year == b.year && a.month == b.month && a.day == b.day;

class _Harian extends ConsumerWidget {
  const _Harian();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tanggal = ref.watch(tanggalHarianProvider);
    final semua =
        ref.watch(serviceOrdersProvider).valueOrNull ??
        const <ServiceOrderEntry>[];

    // Keluar: pekerjaannya rampung hari itu. Masuk: unitnya diterima hari
    // itu. Keduanya termasuk garansi maupun reguler -- pusat membaca
    // seluruh lalu lintas unit, bukan hanya yang berbayar.
    //
    // Batasnya sengaja berbeda. Nota keluar ditutup jam 17.00: laporannya
    // dikirim ke pusat sore itu, jadi unit yang selesai sesudahnya masuk
    // laporan besok -- tanggal_selesai sudah distempel server dengan
    // aturan itu, dan dibandingkan apa adanya. Nota masuk memakai hari
    // kalender: unit yang diterima jam 19.45 diterima hari itu juga.
    final keluar =
        semua.where((n) => _hariSama(n.tanggalSelesai, tanggal)).toList()
          ..sort((a, b) => bandingNomorNota(a.noNota, b.noNota));
    final masuk =
        semua.where((n) => _hariSama(n.tanggalMasuk, tanggal)).toList()
          ..sort((a, b) => bandingNomorNota(a.noNota, b.noNota));

    final total = keluar.fold<double>(0, (a, n) => a + n.biaya);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final p = await showDatePicker(
                  context: context,
                  initialDate: tanggal,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (p != null) {
                  ref.read(tanggalHarianProvider.notifier).state = p;
                }
              },
              icon: const Icon(Icons.calendar_today, size: 15),
              label: Text(_tglPanjang.format(tanggal).toUpperCase()),
            ),
            const SizedBox(width: AppSpacing.xs),
            OutlinedButton(
              onPressed: () {
                final n = DateTime.now();
                ref.read(tanggalHarianProvider.notifier).state = DateTime(
                  n.year,
                  n.month,
                  n.day,
                );
              },
              child: const Text('HARI INI'),
            ),
            const Spacer(),
            // Yang diekspor sebulan penuh, satu tab per tanggal -- itu
            // bentuk yang dipakai pusat. Tanggal yang dipilih di layar
            // menentukan bulannya, bukan membatasi isinya.
            _TombolExport(
              label: 'EXCEL ${_namaBulan.format(tanggal).toUpperCase()}',
              aktif: semua.isNotEmpty,
              onExport: () =>
                  ExcelExport.harianBulanan(semua: semua, bulan: tanggal),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),

        // Dua tabel ini dulu bertumpuk, masing-masing separuh tinggi
        // layar. Keduanya lalu terpotong: hari yang ramai punya dua puluh
        // baris lebih di tiap tabel, dan yang terlihat cuma lima. Dua
        // daftar yang sama-sama harus digulir di dalam kotaknya sendiri
        // adalah bentuk yang paling melelahkan untuk dibaca.
        //
        // Dijadikan tab, tiap tabel mendapat seluruh tinggi yang ada.
        // Urutannya tetap keluar dulu, seperti lembar laporannya sendiri
        // dan seperti berkas Excel yang dikirim ke pusat.
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: context.warna.permukaan,
                    borderRadius: BorderRadius.circular(AppRadius.base),
                    border: Border.all(color: context.warna.garisHalus),
                  ),
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: [
                      // Jumlahnya ikut di judul tabnya: yang sedang tidak
                      // terbuka pun tetap bisa dilihat isinya berapa.
                      Tab(text: 'NOTA KELUAR  (${keluar.length})'),
                      Tab(text: 'NOTA MASUK  (${masuk.length})'),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                Expanded(
                  child: TabBarView(
                    children: [
                      _KartuHarianKeluar(keluar: keluar, total: total),
                      _KartuHarianMasuk(masuk: masuk),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Tabel nota keluar pada tab Harian.
class _KartuHarianKeluar extends StatelessWidget {
  const _KartuHarianKeluar({required this.keluar, required this.total});

  final List<ServiceOrderEntry> keluar;
  final double total;

  @override
  Widget build(BuildContext context) {
    return _Kartu(
      judul: 'Nota Keluar',
      ringkas: '${keluar.length} nota  ·  ${_rp.format(total)}',
      kosong: keluar.isEmpty,
      pesanKosong: 'Belum ada unit yang selesai pada tanggal ini.',
      child: _TabelHarian(
        kolom: const [
          (0, 'Nama', 2),
          (118, 'No Nota', 0),
          (0, 'Jenis Barang', 2),
          (0, 'Perbaikan', 3),
          (112, 'Biaya', 0),
          // Cukup lebar untuk tanggal beserta jamnya: berapa lama
          // unitnya menunggu terbaca dari sini tanpa membuka notanya.
          (120, 'Tgl Masuk', 0),
          (104, 'Keterangan', 0),
        ],
        baris: [
          for (final n in keluar)
            (
              n,
              [
                n.customerNama,
                n.noNota,
                _barang(n),
                n.perbaikan ?? '—',
                n.biaya == 0 ? 'Rp0' : _rp.format(n.biaya),
                tanggalJamMasuk(n.tanggalMasuk),
                ExcelExport.keteranganHarian(n),
              ],
            ),
        ],
      ),
    );
  }

  static String _barang(ServiceOrderEntry n) => [
    n.barangNama,
    if ((n.barangType ?? '').isNotEmpty) n.barangType!,
  ].join(' ');
}

/// Tabel nota masuk pada tab Harian.
class _KartuHarianMasuk extends StatelessWidget {
  const _KartuHarianMasuk({required this.masuk});

  final List<ServiceOrderEntry> masuk;

  @override
  Widget build(BuildContext context) {
    return _Kartu(
      judul: 'Nota Masuk',
      ringkas: '${masuk.length} unit diterima',
      kosong: masuk.isEmpty,
      pesanKosong: 'Belum ada unit yang masuk pada tanggal ini.',
      child: _TabelHarian(
        kolom: const [
          (0, 'Nama', 2),
          (118, 'No Nota', 0),
          // Jamnya ikut disebut supaya lebih rinci -- tanggalnya
          // sendiri sudah pasti tanggal tab ini, karena nota masuk
          // memakai hari kalender.
          (120, 'Masuk', 0),
          (128, 'No HP', 0),
          (0, 'Jenis Barang', 2),
          (0, 'Kerusakan', 3),
          (104, 'Pelunasan', 0),
        ],
        baris: [
          for (final n in masuk)
            (
              n,
              [
                n.customerNama,
                n.noNota,
                tanggalJamMasuk(n.tanggalMasuk),
                n.customerTelp ?? '—',
                _barang(n),
                n.keluhan ?? '—',
                n.tanggalLunas == null ? '—' : _tgl.format(n.tanggalLunas!),
              ],
            ),
        ],
      ),
    );
  }

  static String _barang(ServiceOrderEntry n) => [
    n.barangNama,
    if ((n.barangType ?? '').isNotEmpty) n.barangType!,
  ].join(' ');
}

/// Tabel sederhana untuk laporan harian. Lebar 0 berarti kolomnya berbagi
/// ruang sisa menurut angka flex-nya.
class _TabelHarian extends StatelessWidget {
  const _TabelHarian({required this.kolom, required this.baris});

  final List<(double, String, int)> kolom;
  final List<(ServiceOrderEntry, List<String>)> baris;

  @override
  Widget build(BuildContext context) {
    Widget sel(double lebar, int flex, Widget isi) {
      final padded = Padding(
        padding: const EdgeInsets.only(right: AppSpacing.s),
        child: isi,
      );
      return lebar > 0
          ? SizedBox(width: lebar, child: padded)
          : Expanded(flex: flex, child: padded);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.sm,
            6,
          ),
          child: Row(
            children: [
              for (final (lebar, judul, flex) in kolom)
                sel(
                  lebar,
                  flex,
                  Text(
                    judul.toUpperCase(),
                    overflow: TextOverflow.clip,
                    softWrap: false,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: baris.length,
            itemBuilder: (context, i) {
              final (nota, isi) = baris[i];
              return _BarisKlik(
                onTap: () => showServiceDialog(context, nota: nota),
                children: [
                  for (var k = 0; k < kolom.length; k++)
                    sel(
                      kolom[k].$1,
                      kolom[k].$3,
                      Text(
                        isi[k],
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: k == 1
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: isi[k] == '—'
                              ? context.warna.teksLembut
                              : context.warna.teks,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// =====================================================================
// Omset jasa — kartu ringkasan toko, admin, dan tiap teknisi
// =====================================================================

class _Omset extends ConsumerWidget {
  const _Omset({required this.bulan});

  final Bulan bulan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semua =
        ref.watch(serviceOrdersProvider).valueOrNull ??
        const <ServiceOrderEntry>[];
    final aturan = ref.watch(omsetSettingsProvider).valueOrNull;
    final nama = {
      for (final p
          in ref.watch(techniciansProvider).valueOrNull ?? const <Profile>[])
        p.id: p.nama,
    };

    final hasil = hitungOmsetPeriode(
      nota: semua,
      dari: bulan.awal,
      sampai: bulan.akhir,
      aturan: aturan,
    );
    final target = aturan?.targetOmset ?? 4000000;

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      children: [
        // Tinggi ditetapkan, bukan diregangkan. Di dalam daftar bergulir
        // tidak ada batas tinggi yang bisa dipakai stretch sebagai acuan,
        // dan kartunya berakhir diminta setinggi tak hingga.
        SizedBox(
          height: 190,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 2,
                child: _KartuAngka(
                  judul: 'Omset Toko',
                  nilai: _rp.format(hasil.omsetToko),
                  catatan: '${hasil.jumlahNota} nota selesai ${bulan.label}',
                  aksen: context.warna.bahaya,
                  rincian: [
                    ('Sudah masuk', _rp.format(hasil.sudahMasuk)),
                    ('Masih piutang', _rp.format(hasil.piutang)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: _KartuAngka(
                  judul: 'Omset Admin',
                  nilai: _rp.format(hasil.omsetAdmin),
                  catatan: aturan == null || aturan.feeAdminPerNota == 0
                      ? 'Fee admin belum diatur di Pengaturan'
                      : '${_rp.format(aturan.feeAdminPerNota)} × '
                            '${hasil.jumlahNota} nota',
                  aksen: context.warna.aksen,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s),

        _Kartu(
          judul: 'Omset per Teknisi',
          ringkas: 'Target ${_rp.format(target)} per orang tiap bulan',
          kosong: hasil.teknisi.isEmpty,
          pesanKosong:
              'Belum ada pekerjaan selesai atas nama teknisi di bulan ini.',
          // Satu-satunya kartu yang setinggi isinya, karena satu-satunya
          // yang dipasang di dalam daftar bergulir. Daftarnya sepanjang
          // jumlah orangnya: dipotong pada tinggi tetap, teknisi keempat
          // dan seterusnya tidak tergambar sama sekali, dan tidak ada
          // tanda apa pun bahwa mereka ada di bawah sana.
          padat: true,
          child: ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: hasil.teknisi.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, i) {
              final t = hasil.teknisi[i];
              final persen = t.persenTarget(target);
              final tercapai = persen >= 100;

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.s,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            nama[t.teknisiId] ?? '—',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${t.jumlahNota} nota',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.warna.teksLembut,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s),
                        Text(
                          _rp.format(t.omset),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Batang kemajuan dipotong di 100%: yang melampaui
                    // target ditandai lewat teksnya, bukan batang yang
                    // meluber keluar kolom.
                    Stack(
                      children: [
                        Container(height: 4, color: context.warna.teredam),
                        FractionallySizedBox(
                          widthFactor: (persen / 100).clamp(0.0, 1.0),
                          child: Container(
                            height: 4,
                            color: tercapai
                                ? context.warna.aksen
                                : context.warna.bahaya,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tercapai
                          ? 'Target tercapai · ${persen.toStringAsFixed(0)}%'
                          : '${persen.toStringAsFixed(0)}% · kurang '
                                '${_rp.format(t.kurangDariTarget(target))}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: tercapai
                            ? context.warna.aksen
                            : context.warna.teksLembut,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        if (hasil.notaTanpaTeknisi > 0) ...[
          const SizedBox(height: AppSpacing.s),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s),
            decoration: BoxDecoration(
              color: context.warna.bahaya.withValues(alpha: 0.05),
              border: Border(
                left: BorderSide(color: context.warna.bahaya, width: 3),
              ),
            ),
            child: Text(
              '${hasil.notaTanpaTeknisi} nota selesai belum ada teknisinya. '
              'Nilainya masuk omset toko, tapi tidak jatuh ke siapa pun.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: context.warna.bahaya,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _KartuAngka extends StatelessWidget {
  const _KartuAngka({
    required this.judul,
    required this.nilai,
    required this.catatan,
    required this.aksen,
    this.rincian = const [],
  });

  final String judul;
  final String nilai;
  final String catatan;
  final Color aksen;
  final List<(String, String)> rincian;

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      title: judul,
      accent: aksen,
      // Digulirkan agar rincian yang bertambah panjang tidak meluber keluar
      // kartu ketika tingginya sudah ditetapkan.
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                nilai,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.4,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(catatan, style: Theme.of(context).textTheme.labelSmall),
            if (rincian.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s),
              const Divider(),
              const SizedBox(height: 6),
              for (final (label, isi) in rincian)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Text(
                        isi,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Laporan pelunasan — dikelompokkan per tanggal lunas
// =====================================================================

class _Pelunasan extends ConsumerWidget {
  const _Pelunasan({required this.bulan});

  final Bulan bulan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semua =
        ref.watch(serviceOrdersProvider).valueOrNull ??
        const <ServiceOrderEntry>[];
    final teknisi = {
      for (final p
          in ref.watch(techniciansProvider).valueOrNull ?? const <Profile>[])
        p.id: p.nama,
    };

    // Dikelompokkan menurut tanggal LUNAS, bukan tanggal masuk: yang
    // dilaporkan di sini adalah uang yang diterima hari itu.
    final lunas =
        semua
            .where(
              (n) => n.tanggalLunas != null && bulan.memuat(n.tanggalLunas!),
            )
            .toList()
          ..sort((a, b) => b.tanggalLunas!.compareTo(a.tanggalLunas!));

    final perTanggal = <DateTime, List<ServiceOrderEntry>>{};
    for (final n in lunas) {
      final hari = DateTime(
        n.tanggalLunas!.year,
        n.tanggalLunas!.month,
        n.tanggalLunas!.day,
      );
      perTanggal.putIfAbsent(hari, () => []).add(n);
    }

    final total = lunas.fold<double>(0, (a, n) => a + n.biaya);

    return _Kartu(
      judul: 'Pelunasan ${bulan.label}',
      ringkas: '${lunas.length} nota  ·  ${_rp.format(total)}',
      aksi: _TombolExport(
        aktif: lunas.isNotEmpty,
        onExport: () => ExcelExport.pelunasan(
          nota: lunas,
          teknisi: teknisi,
          periode: bulan.label,
        ),
      ),
      kosong: lunas.isEmpty,
      pesanKosong: 'Belum ada pelunasan di bulan ini.',
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.s),
        children: [
          for (final hari in perTanggal.keys) ...[
            Container(
              width: double.infinity,
              color: context.warna.teredam,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 7,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _tglPanjang.format(hari),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Text(
                    _rp.format(
                      perTanggal[hari]!.fold<double>(0, (a, n) => a + n.biaya),
                    ),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            for (final n in perTanggal[hari]!)
              _BarisNota(
                nota: n,
                teknisi: teknisi[n.teknisiId],
                kolom: [
                  (118.0, n.noNota, true),
                  (0.0, n.customerNama, true),
                  (0.0, n.keluhan ?? '—', false),
                  (0.0, n.perbaikan ?? '—', false),
                  (96.0, teknisi[n.teknisiId] ?? '—', false),
                  (116.0, _rp.format(n.biaya), true),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

// =====================================================================
// Laporan keseluruhan — semua nota bulan berjalan
// =====================================================================

class _Keseluruhan extends ConsumerWidget {
  const _Keseluruhan({required this.bulan});

  final Bulan bulan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semua =
        ref.watch(serviceOrdersProvider).valueOrNull ??
        const <ServiceOrderEntry>[];
    final teknisi = {
      for (final p
          in ref.watch(techniciansProvider).valueOrNull ?? const <Profile>[])
        p.id: p.nama,
    };

    // Urut nomor nota, sama dengan berkas yang diekspor dari tombol di
    // kanan atas. Layar dan berkasnya harus menampilkan baris yang sama
    // pada urutan yang sama, kalau tidak yang mencocokkan keduanya
    // membandingkan dua daftar yang tidak pernah sejajar.
    final nota = semua.where((n) => bulan.memuat(n.tanggalMasuk)).toList()
      ..sort((a, b) => bandingNomorNota(a.noNota, b.noNota));

    final kodePiutang = {
      for (final m
          in ref.watch(allMetodeBayarProvider).valueOrNull ??
              const <MetodeBayar>[])
        if (m.piutang) m.kode,
    };

    final tunai = nota
        .where((n) => n.tanggalLunas != null)
        .fold<double>(0, (a, n) => a + n.biaya);
    final piutang = nota
        .where((n) => n.biaya > 0 && n.tanggalLunas == null)
        .fold<double>(0, (a, n) => a + n.biaya);

    return _Kartu(
      judul: 'Keseluruhan ${bulan.label}',
      ringkas:
          '${nota.length} nota  ·  masuk ${_rp.format(tunai)}  ·  '
          'piutang ${_rp.format(piutang)}',
      aksi: _TombolExport(
        aktif: nota.isNotEmpty,
        onExport: () => ExcelExport.keseluruhan(
          nota: nota,
          teknisi: teknisi,
          periode: bulan.label,
        ),
      ),
      kosong: nota.isEmpty,
      pesanKosong: 'Belum ada nota di bulan ini.',
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: AppSpacing.s),
        itemCount: nota.length,
        itemBuilder: (context, i) {
          final n = nota[i];
          return _BarisNota(
            nota: n,
            teknisi: teknisi[n.teknisiId],
            kolom: [
              (118.0, n.noNota, true),
              (0.0, n.customerNama, true),
              (108.0, n.customerTelp ?? '—', false),
              (
                0.0,
                [
                  n.barangNama,
                  if (n.barangType != null) n.barangType!,
                ].join(' '),
                false,
              ),
              (0.0, n.keluhan ?? '—', false),
              (92.0, teknisi[n.teknisiId] ?? '—', false),
              (116.0, _bayar(n, kodePiutang), false),
              // Perbaikan yang dikerjakan, bukan catatan status. Yang di
              // ujung baris sudah menjawab garansi dan sudah-diambil.
              (0.0, n.perbaikan ?? '—', false),
            ],
            akhiran: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (n.garansi)
                  _Tanda('GARANSI', warna: context.warna.aksen)
                else
                  const _Tanda('NON GARANSI'),
                const SizedBox(width: 4),
                ServiceStatusChip(n.status, compact: true),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Daftar kode piutang datang dari pengaturan, bukan dari kata
  /// 'piutang' yang dulu dipatok di sini: cara bayar sekarang bisa
  /// ditambah sendiri, dan yang menandai sebuah nota belum dibayar adalah
  /// centang di daftarnya — bukan namanya.
  static String _bayar(ServiceOrderEntry n, Set<String> kodePiutang) {
    if (n.biaya == 0) return '—';
    final nilai = _rp.format(n.biaya);
    if (n.tanggalLunas != null) return '$nilai LUNAS';
    if (kodePiutang.contains(n.caraBayar)) return '$nilai PIUTANG';
    return nilai;
  }
}

// =====================================================================
// Laporan kirim antar cabang
// =====================================================================

class _Kirim extends ConsumerWidget {
  const _Kirim();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kirim =
        ref.watch(shipmentsProvider).valueOrNull ?? const <ShipmentEntry>[];
    final terkirim = kirim.where((k) => k.status == 'ship').length;

    return _Kartu(
      judul: 'Pengiriman',
      ringkas: '${kirim.length} catatan  ·  $terkirim belum kembali',
      aksi: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TombolExport(
            aktif: kirim.isNotEmpty,
            onExport: () => ExcelExport.kirim(data: kirim),
          ),
          const SizedBox(width: AppSpacing.s),
          InlineAction(
            label: 'Tambah',
            onTap: () => showShipmentDialog(context),
          ),
        ],
      ),
      kosong: kirim.isEmpty,
      pesanKosong: 'Belum ada barang yang dikirim atau diterima dari cabang.',
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: AppSpacing.s),
        itemCount: kirim.length,
        itemBuilder: (context, i) {
          final k = kirim[i];
          return _BarisKlik(
            onTap: () => showShipmentDialog(context, kirim: k),
            children: [
              _Sel(width: 88, teks: _tgl.format(k.tanggalKirim)),
              _Sel(
                width: 150,
                teks: '${k.dariCabang} → ${k.keCabang}',
                tebal: true,
              ),
              _Sel(width: 96, teks: k.userNama ?? '—'),
              _Sel(
                flex: 2,
                teks: [
                  k.barangNama,
                  if (k.serialNumber != null) k.serialNumber!,
                ].join('  '),
              ),
              _Sel(flex: 2, teks: k.keluhan ?? '—'),
              _Sel(
                width: 104,
                teks: k.tanggalKembali == null
                    ? '—'
                    : _tgl.format(k.tanggalKembali!),
              ),
              SizedBox(
                width: 150,
                child: Row(
                  children: [
                    _Tanda(
                      k.status == 'ship' ? 'DIKIRIM' : 'DITERIMA',
                      warna: k.status == 'ship'
                          ? context.warna.bahaya
                          : context.warna.teks,
                    ),
                    if (k.keterangan != null) ...[
                      const SizedBox(width: 4),
                      _Tanda(k.keterangan!.replaceAll('_', ' ').toUpperCase()),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// =====================================================================
// Bagian bersama
// =====================================================================

/// Tombol ekspor beserta kabar hasilnya.
///
/// Jalur berkas ditampilkan setelah tersimpan, bukan sekadar "berhasil":
/// dialog simpan Windows sering mengarah ke folder terakhir yang dipakai,
/// dan tanpa jalurnya orang harus mencari sendiri berkasnya ke mana.
class _TombolExport extends StatefulWidget {
  const _TombolExport({
    required this.aktif,
    required this.onExport,
    this.label = 'EXCEL',
  });

  final bool aktif;
  final Future<String?> Function() onExport;
  final String label;

  @override
  State<_TombolExport> createState() => _TombolExportState();
}

class _TombolExportState extends State<_TombolExport> {
  bool _sibuk = false;

  Future<void> _jalankan() async {
    setState(() => _sibuk = true);
    try {
      final jalur = await widget.onExport();
      if (!mounted || jalur == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tersimpan di $jalur'),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal menyimpan berkas. $e')));
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sibuk) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: SizedBox(
          height: 14,
          width: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: widget.aktif ? _jalankan : null,
      icon: const Icon(Icons.table_view_outlined, size: 15),
      label: Text(widget.label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide(color: context.warna.teks, width: 1.5),
      ),
    );
  }
}

class _Kartu extends StatelessWidget {
  const _Kartu({
    required this.judul,
    required this.ringkas,
    required this.child,
    required this.kosong,
    required this.pesanKosong,
    this.aksi,
    this.padat = false,
  });

  final String judul;
  final String ringkas;
  final Widget child;
  final bool kosong;
  final String pesanKosong;
  final Widget? aksi;

  /// Kartunya setinggi isinya, bukan setinggi ruang yang tersedia.
  ///
  /// Hanya untuk kartu yang dipasang DI DALAM daftar bergulir -- di sana
  /// tidak ada ruang tersisa untuk dibagi, dan isinya tidak boleh
  /// dibungkus Expanded.
  ///
  /// Bawaannya memenuhi ruang, dan itu yang benar untuk sebagian besar
  /// pemakainya. Sempat dibalik -- "tinggi kosong berarti setinggi isi" --
  /// dan tiga tab sekaligus jadi kosong melompong: Pelunasan, Keseluruhan,
  /// dan Kirim memasang kartunya langsung sebagai isi tab tanpa menyebut
  /// tinggi, lalu daftarnya kehilangan seluruh ruang vertikalnya. Dua
  /// keadaan yang berbeda ini tidak bisa dibedakan dari satu kolom yang
  /// kebetulan kosong; ia harus disebut sendiri.
  final bool padat;

  @override
  Widget build(BuildContext context) {
    final isi = kosong
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                pesanKosong,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.warna.teksLembut, fontSize: 13),
              ),
            ),
          )
        : child;

    return SizedBox(
      // Tanpa tinggi tetap: kartu yang dipasang sebagai isi tab sudah
      // menerima batas tingginya dari sana.
      height: null,
      child: Container(
        decoration: BoxDecoration(
          color: context.warna.permukaan,
          borderRadius: BorderRadius.circular(AppRadius.base),
          border: Border.all(color: context.warna.garisHalus),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: padat ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.s,
                AppSpacing.s,
                AppSpacing.s,
              ),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: context.warna.teks, width: 1.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          judul.toUpperCase(),
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ringkas,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ?aksi,
                ],
              ),
            ),
            if (padat) isi else Expanded(child: isi),
          ],
        ),
      ),
    );
  }
}

/// Satu baris nota. Lebar 0 berarti kolomnya berbagi ruang sisa.
class _BarisNota extends StatelessWidget {
  const _BarisNota({
    required this.nota,
    required this.teknisi,
    required this.kolom,
    this.akhiran,
  });

  final ServiceOrderEntry nota;
  final String? teknisi;
  final List<(double, String, bool)> kolom;
  final Widget? akhiran;

  @override
  Widget build(BuildContext context) {
    return _BarisKlik(
      onTap: () => showServiceDialog(context, nota: nota),
      children: [
        for (final (lebar, teks, tebal) in kolom)
          if (lebar > 0)
            _Sel(width: lebar, teks: teks, tebal: tebal)
          else
            _Sel(flex: 2, teks: teks, tebal: tebal),
        ?akhiran,
      ],
    );
  }
}

class _BarisKlik extends StatefulWidget {
  const _BarisKlik({required this.onTap, required this.children});

  final VoidCallback onTap;
  final List<Widget> children;

  @override
  State<_BarisKlik> createState() => _BarisKlikState();
}

class _BarisKlikState extends State<_BarisKlik> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
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
            11,
            AppSpacing.sm,
            11,
          ),
          child: Row(children: widget.children),
        ),
      ),
    );
  }
}

class _Sel extends StatelessWidget {
  const _Sel({required this.teks, this.width, this.flex, this.tebal = false});

  final String teks;
  final double? width;
  final int? flex;
  final bool tebal;

  @override
  Widget build(BuildContext context) {
    final isi = Padding(
      padding: const EdgeInsets.only(right: AppSpacing.s),
      child: Text(
        teks,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: tebal ? FontWeight.w700 : FontWeight.w400,
          color: teks == '—' ? context.warna.teksLembut : context.warna.teks,
        ),
      ),
    );
    if (width != null) return SizedBox(width: width, child: isi);
    return Expanded(flex: flex ?? 1, child: isi);
  }
}

class _Tanda extends StatelessWidget {
  const _Tanda(this.teks, {this.warna});

  final String teks;

  /// Kosong berarti ikut warna teks lembut dari tema yang berlaku. Nilai
  /// bawaan sebuah parameter harus const, sementara warna tema baru bisa
  /// diketahui setelah ada BuildContext.
  final Color? warna;

  @override
  Widget build(BuildContext context) {
    final w = warna ?? context.warna.teksLembut;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: w),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        teks,
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: w,
        ),
      ),
    );
  }
}

class _BulanDropdown extends ConsumerWidget {
  const _BulanDropdown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daftar = Bulan.daftar();
    final kini = ref.watch(bulanProvider);

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
      decoration: BoxDecoration(
        border: Border.all(color: context.warna.teks),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: kini.label,
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
          onChanged: (v) => ref.read(bulanProvider.notifier).state = daftar
              .firstWhere((b) => b.label == v),
          items: [
            for (final b in daftar)
              DropdownMenuItem(value: b.label, child: Text(b.label)),
          ],
        ),
      ),
    );
  }
}
