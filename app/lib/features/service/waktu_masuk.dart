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
/// Jamnya baru benar-benar dibutuhkan sejak hari kerja berganti jam
/// 17.00. Sebuah nota bisa muncul di bawah tanggal 7 sementara kertasnya
/// tertulis 6, dan tanpa jamnya yang membaca akan mengira notanya salah
/// tempat -- atau lebih buruk, mengira aplikasinya keliru menghitung.
/// Dengan jam 18.30 tertulis di sebelahnya, alasannya terbaca sendiri.
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
        style: const TextStyle(fontSize: 13, color: context.warna.teks),
      ),
      Text(
        _jam.format(saat),
        style: const TextStyle(
          fontSize: 11,
          height: 1.35,
          color: context.warna.teksLembut,
        ),
      ),
    ],
  );
}
