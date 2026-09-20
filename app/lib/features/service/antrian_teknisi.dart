import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import 'teknisi_ringkas.dart';

final _rp = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);

/// Satu orang di antrian pemberian unit hari ini.
class AntrianTeknisi {
  const AntrianTeknisi({required this.ringkas, required this.notaHariIni});

  final RingkasTeknisi ringkas;

  /// Nota yang masuk HARI INI atas namanya. Yang dibatalkan tidak dihitung:
  /// unit yang batal tidak menghasilkan pekerjaan, jadi orangnya tetap
  /// terhitung belum dapat kerja.
  final int notaHariIni;

  Profile get teknisi => ringkas.teknisi;

  bool get belumDapatKerja => notaHariIni == 0;

  /// Omsetnya bulan ini masih di bawah target -- diukur rupiah, bukan unit.
  bool get perluPushOmset => ringkas.dibawahTarget;

  /// Empat tingkat, yang paling perlu diberi unit di tingkat 0:
  ///
  ///   0  belum dapat kerja hari ini, dan omsetnya masih kurang
  ///   1  belum dapat kerja hari ini
  ///   2  sudah dapat kerja, tetapi omsetnya masih kurang
  ///   3  sudah dapat kerja, dan omsetnya sudah cukup
  ///
  /// Belum dapat kerja didahulukan di atas omset yang kurang: orang yang
  /// seharian duduk tanpa unit adalah yang paling terasa, dan yang omsetnya
  /// kurang tetapi sudah memegang unit hari ini sedang dikejar oleh
  /// pekerjaan itu sendiri.
  int get tingkat => (belumDapatKerja ? 0 : 2) + (perluPushOmset ? 0 : 1);
}

/// Antrian pemberian unit untuk [hari].
///
/// Dihitung ulang dari nota setiap kali dipanggil, dan yang dihitung hanya
/// nota yang masuk pada [hari] -- jadi antriannya kembali kosong sendiri
/// begitu tanggalnya berganti, tanpa ada yang perlu menyetel ulang apa pun.
///
/// Urutan di dalam satu tingkat: yang paling sedikit menerima nota hari
/// ini, lalu omset terendah, lalu nama (supaya urutannya tidak berubah-ubah
/// di antara dua orang yang sama persis).
List<AntrianTeknisi> susunAntrian({
  required Iterable<RingkasTeknisi> ringkas,
  required Iterable<ServiceOrderEntry> nota,
  required DateTime hari,
}) {
  final hariIni = <String, int>{};
  for (final n in nota) {
    final id = n.teknisiId;
    if (id == null || n.status == 'batal') continue;
    final m = n.tanggalMasuk;
    if (m.year != hari.year || m.month != hari.month || m.day != hari.day) {
      continue;
    }
    hariIni.update(id, (v) => v + 1, ifAbsent: () => 1);
  }

  return [
    for (final r in ringkas)
      AntrianTeknisi(ringkas: r, notaHariIni: hariIni[r.teknisi.id] ?? 0),
  ]..sort((a, b) {
    final tingkat = a.tingkat.compareTo(b.tingkat);
    if (tingkat != 0) return tingkat;
    final beban = a.notaHariIni.compareTo(b.notaHariIni);
    if (beban != 0) return beban;
    final omset = a.ringkas.omset.compareTo(b.ringkas.omset);
    if (omset != 0) return omset;
    return a.teknisi.nama.toLowerCase().compareTo(b.teknisi.nama.toLowerCase());
  });
}

/// Antrian pemberian unit, di formulir servis baru.
///
/// Yang muncul di atas adalah yang sebaiknya diberi unit berikutnya: belum
/// dapat kerja hari ini, dan omsetnya masih perlu didorong. Mengetuk sebuah
/// nama langsung memilihnya sebagai teknisi nota ini.
///
/// Ini saran, bukan aturan -- menu Teknisi di bawahnya tetap bebas dipakai.
/// Unit yang butuh keahlian tertentu tidak menunggu antrian.
class AntrianTeknisiPanel extends ConsumerStatefulWidget {
  const AntrianTeknisiPanel({
    super.key,
    required this.terpilih,
    required this.onPilih,
  });

  final String? terpilih;
  final ValueChanged<String> onPilih;

  @override
  ConsumerState<AntrianTeknisiPanel> createState() =>
      _AntrianTeknisiPanelState();
}

/// Baris yang ditampilkan sebelum "lihat semua". Antrian yang panjang
/// mendorong formulirnya keluar layar, dan yang dicari hanya beberapa
/// nama teratas.
const _barisAwal = 4;

class _AntrianTeknisiPanelState extends ConsumerState<AntrianTeknisiPanel> {
  bool _semua = false;

  @override
  Widget build(BuildContext context) {
    final antrian = susunAntrian(
      ringkas: ref.watch(ringkasTeknisiProvider),
      nota:
          ref.watch(serviceOrdersProvider).valueOrNull ??
          const <ServiceOrderEntry>[],
      hari: DateTime.now(),
    );
    if (antrian.isEmpty) return const SizedBox.shrink();

    final w = context.warna;
    final tampil = _semua ? antrian : antrian.take(_barisAwal).toList();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: w.garisHalus),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s,
              AppSpacing.xs,
              AppSpacing.s,
              4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ANTRIAN HARI INI',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  'Yang belum dapat kerja hari ini dan omsetnya masih kurang '
                  'didahulukan. Kembali kosong tiap hari.',
                  style: TextStyle(fontSize: 11, color: w.teksLembut),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (var i = 0; i < tampil.length; i++)
            _BarisAntrian(
              urut: i + 1,
              a: tampil[i],
              berikutnya: i == 0,
              dipilih: tampil[i].teknisi.id == widget.terpilih,
              onTap: () => widget.onPilih(tampil[i].teknisi.id),
            ),
          if (antrian.length > _barisAwal)
            InkWell(
              onTap: () => setState(() => _semua = !_semua),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s,
                  vertical: 6,
                ),
                child: Text(
                  _semua
                      ? 'TAMPILKAN SEDIKIT'
                      : 'LIHAT SEMUA (${antrian.length})',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: w.aksen,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BarisAntrian extends StatelessWidget {
  const _BarisAntrian({
    required this.urut,
    required this.a,
    required this.berikutnya,
    required this.dipilih,
    required this.onTap,
  });

  final int urut;
  final AntrianTeknisi a;
  final bool berikutnya;
  final bool dipilih;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = context.warna;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: dipilih ? w.aksen.withValues(alpha: 0.08) : null,
          border: Border(
            left: BorderSide(
              color: dipilih ? w.aksen : Colors.transparent,
              width: 3,
            ),
            bottom: BorderSide(color: w.garisHalus),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 20,
              child: Text(
                '$urut',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: w.teksLembut,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          a.teknisi.nama,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (berikutnya) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          color: w.aksen,
                          child: Text(
                            'BERIKUTNYA',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: w.permukaan,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 8,
                    runSpacing: 1,
                    children: [
                      if (a.belumDapatKerja)
                        Text(
                          'BELUM DAPAT KERJA HARI INI',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: w.aksen,
                          ),
                        )
                      else
                        Text(
                          '${a.notaHariIni} nota hari ini',
                          style: TextStyle(fontSize: 10.5, color: w.teksLembut),
                        ),
                      if (a.perluPushOmset)
                        Text(
                          'PUSH OMSET · kurang ${_rp.format(a.ringkas.kurang)}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: w.bahaya,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (dipilih) Icon(Icons.check_circle, size: 16, color: w.aksen),
          ],
        ),
      ),
    );
  }
}
