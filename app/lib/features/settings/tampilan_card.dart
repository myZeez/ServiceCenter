import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/bento.dart';
import '../../core/widgets/swiss_widgets.dart';

/// Terang atau gelap.
///
/// Melekat pada perangkat, bukan pada akun. Komputer meja depan berdiri di
/// ruangan berlampu sepanjang hari; HP teknisi ikut dibawa ke ruang
/// belakang yang remang, dan nota masih dibuat lewat jam tujuh malam.
/// Memaksa keduanya sama tidak menolong siapa pun.
///
/// Karena itu bawaannya "ikut sistem": Windows dan Android sudah punya
/// jadwal terang-gelapnya sendiri, dan yang sudah menyetelnya di sana tidak
/// perlu menyetelnya lagi di sini.
class TampilanCard extends ConsumerWidget {
  const TampilanCard({super.key});

  static const _pilihan = [
    (ThemeMode.system, 'Ikut Sistem', 'Mengikuti setelan Windows atau HP'),
    (ThemeMode.light, 'Terang', 'Putih, seperti kertas'),
    (ThemeMode.dark, 'Gelap', 'Biru tua, untuk ruangan remang dan malam'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(modeTemaProvider).valueOrNull ?? ThemeMode.system;

    return BentoCard(
      title: 'Tampilan',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            LabeledField(
              label: 'Mode Warna',
              hint:
                  'Pilihan ini hanya berlaku di perangkat ini. Perangkat lain '
                  'punya setelannya sendiri.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (nilai, nama, keterangan) in _pilihan)
                    _Baris(
                      nama: nama,
                      keterangan: keterangan,
                      terpilih: mode == nilai,
                      onPilih: () => simpanModeTema(ref, nilai),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s),

            // Contoh kecil, bukan sekadar kalimat. Warna paling susah
            // dibayangkan dari namanya, dan yang memilih di sini justru
            // sedang berada di salah satu dari keduanya.
            const _Contoh(),
            const SizedBox(height: AppSpacing.s),

            Text(
              'Warna status tetap punya arti yang sama di kedua mode: '
              'oranye atau biru untuk yang masih berjalan, merah untuk yang '
              'perlu ditagih, hijau untuk garansi. Yang berubah hanya '
              'terangnya, bukan artinya.',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Baris extends StatelessWidget {
  const _Baris({
    required this.nama,
    required this.keterangan,
    required this.terpilih,
    required this.onPilih,
  });

  final String nama;
  final String keterangan;
  final bool terpilih;
  final VoidCallback onPilih;

  @override
  Widget build(BuildContext context) {
    final w = context.warna;

    return InkWell(
      onTap: onPilih,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Icon(
              terpilih
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 18,
              color: terpilih ? w.aksen : w.teksLembut,
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nama,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: terpilih ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  Text(
                    keterangan,
                    style: TextStyle(fontSize: 11, color: w.teksLembut),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sepotong tampilan mode gelap, dilukis dengan paletnya sendiri.
///
/// Sengaja tidak ikut tema yang sedang berlaku: gunanya justru
/// memperlihatkan yang BELUM dipilih. Kalau ia ikut tema, di mode terang
/// ia jadi kotak putih yang tidak menjelaskan apa pun.
class _Contoh extends StatelessWidget {
  const _Contoh();

  @override
  Widget build(BuildContext context) {
    const w = WarnaApp.gelap;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s),
      decoration: BoxDecoration(
        color: w.latar,
        border: Border.all(color: w.garis),
        borderRadius: BorderRadius.circular(AppRadius.base),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SRV-09092628292',
            style: TextStyle(
              fontFamily: kFontAngka,
              fontFamilyFallback: kFontAngkaCadangan,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: w.teks,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Joe Topan — Laptop Axioo',
            style: TextStyle(fontSize: 11, color: w.teksLembut),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              _Tanda('GARANSI', w.garansi),
              const SizedBox(width: AppSpacing.xxs),
              _Tanda('PIUTANG', w.bahaya),
              const SizedBox(width: AppSpacing.xxs),
              _Tanda('DIKERJAKAN', w.aksen),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tanda extends StatelessWidget {
  const _Tanda(this.teks, this.warna);

  final String teks;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: warna),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        teks,
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: warna,
        ),
      ),
    );
  }
}
