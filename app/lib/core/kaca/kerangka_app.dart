import 'package:flutter/material.dart';

import '../theme.dart';
import 'kursor_liquid.dart';
import 'lapisan_kaca.dart';
import 'pesan_kaca.dart';

/// MaterialApp beserta seluruh sambungan mode kaca.
///
/// Berdiri sendiri, bukan di dalam main(), supaya pengujian memakai
/// rangkaian yang sama persis dengan yang dipakai di HP: tema kaca,
/// pengamat rute yang memburamkan lapisan tertutup, dan pembawa pesan yang
/// mengacakan snackbar. Kalau salah satunya lupa dipasang, pengujiannya
/// ikut kehilangan -- dan itu ketahuan.
class KerangkaApp extends StatelessWidget {
  const KerangkaApp({
    super.key,
    required this.home,
    this.mode = ThemeMode.system,
    this.kaca = false,
    bool? liquid,
    this.kursor = false,
  }) : liquid = liquid ?? kaca;

  final Widget home;
  final ThemeMode mode;

  /// Mode kaca penuh. Dinyalakan hanya di Android -- lihat `kacaDidukung`.
  final bool kaca;

  /// Liquid Glass pada tombol, dropdown, dan chip (Android maupun Windows).
  final bool liquid;

  /// Kursor mouse berbentuk tetesan Liquid Glass (Windows).
  final bool kursor;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Klaim Garansi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.terang(kaca: kaca, liquid: liquid, kursor: kursor),
      darkTheme: AppTheme.gelap(kaca: kaca, liquid: liquid, kursor: kursor),
      themeMode: mode,
      navigatorObservers: kaca ? [PengamatKaca.instance] : const [],
      builder: (kaca || kursor)
          ? (context, child) {
              Widget isi = child ?? const SizedBox();
              if (kaca) isi = PesanKaca(child: isi);
              if (kursor) isi = KursorLiquid(aktif: true, child: isi);
              return isi;
            }
          : null,
      home: home,
    );
  }
}
