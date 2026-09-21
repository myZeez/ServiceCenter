import 'package:flutter/material.dart';

import '../theme.dart';
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
  });

  final Widget home;
  final ThemeMode mode;

  /// Mode kaca. Dinyalakan hanya di Android -- lihat `kacaDidukung`.
  final bool kaca;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Klaim Garansi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.terang(kaca: kaca),
      darkTheme: AppTheme.gelap(kaca: kaca),
      themeMode: mode,
      navigatorObservers: kaca ? [PengamatKaca.instance] : const [],
      builder: kaca
          ? (context, child) => PesanKaca(child: child ?? const SizedBox())
          : null,
      home: home,
    );
  }
}
