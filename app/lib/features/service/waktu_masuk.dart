import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';

final _tgl = DateFormat('dd/MM/yy');
final _jam = DateFormat('HH:mm');

/// Tanggal masuk beserta jamnya, dalam satu baris teks.
///
/// Dipakai di tempat yang isinya memang sudah berupa kalimat: kartu di
/// layar HP, kepala dialog nota, daftar pilihan nota.
String tanggalJamMasuk(DateTime saat) =>
    '${_tgl.format(saat)} ${_jam.format(saat)}';

/// Sel kolom "Masuk" pada tabel nota: tanggal di atas, jam di bawahnya.
///
/// Jamnya ikut disebut supaya lebih rinci: di tabel nota keluar, jarak
/// antara jam masuk dan hari selesainya adalah berapa lama unit itu
/// menunggu, dan itu terbaca tanpa membuka notanya.
///
/// Bertumpuk, bukan berdampingan, supaya lebar kolomnya tidak berubah.
/// Kolom yang melebar mendorong nama pelanggan terpotong, dan nama yang
/// terpotong lebih merugikan daripada baris yang sedikit lebih tinggi.
class SelMasuk extends StatelessWidget {
  const SelMasuk(this.saat, {super.key});

  final DateTime saat;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        _tgl.format(saat),
        style: TextStyle(fontSize: 13, color: context.warna.teks),
      ),
      Text(
        _jam.format(saat),
        style: TextStyle(
          fontSize: 11,
          height: 1.35,
          color: context.warna.teksLembut,
        ),
      ),
    ],
  );
}
