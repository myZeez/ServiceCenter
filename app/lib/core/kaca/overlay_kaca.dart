import 'package:flutter/material.dart';

import 'lapisan_kaca.dart';

/// Tirai bawaan showGeneralDialog, disebut di sini karena dipakai sebagai
/// nilai bawaan parameter -- dan nilai bawaan harus konstan.
const kBarrierColor = Color(0x80000000);

/// Dialog, lembar bawah, dan dialog umum -- selalu lewat sini.
///
/// Bedanya dengan memanggil showDialog langsung cuma satu: isinya dibungkus
/// [LapisanKaca], supaya dialog itu sendiri ikut memburam saat ada menu
/// pilihan atau pemilih tanggal yang terbuka di atasnya. Halaman di
/// bawahnya sudah diurus [PengamatKaca] tanpa diminta.
///
/// Dikumpulkan di satu berkas supaya bisa dipastikan tidak ada yang
/// terlewat -- ada pengujian yang menolak pemanggilan langsung di tempat
/// lain (lihat `test/kaca_cakupan_test.dart`).
Future<T?> tampilkanDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
}) => showDialog<T>(
  context: context,
  builder: (c) => LapisanKaca(child: builder(c)),
  barrierDismissible: barrierDismissible,
  barrierColor: barrierColor,
  useRootNavigator: useRootNavigator,
  routeSettings: routeSettings,
);

/// Dialog dengan peralihan sendiri. Dipakai formulir besar di layar lebar.
Future<T?> tampilkanDialogUmum<T>({
  required BuildContext context,
  required RoutePageBuilder pageBuilder,
  RouteTransitionsBuilder? transitionBuilder,
  Color barrierColor = kBarrierColor,
  bool barrierDismissible = false,
  String? barrierLabel,
  Duration transitionDuration = const Duration(milliseconds: 200),
}) => showGeneralDialog<T>(
  context: context,
  pageBuilder: (c, animasi, sekunder) =>
      LapisanKaca(child: pageBuilder(c, animasi, sekunder)),
  transitionBuilder: transitionBuilder,
  barrierColor: barrierColor,
  barrierDismissible: barrierDismissible,
  barrierLabel: barrierLabel,
  transitionDuration: transitionDuration,
);

/// Lembar yang naik dari bawah layar.
Future<T?> tampilkanLembar<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  Color? backgroundColor,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: isScrollControlled,
  backgroundColor: backgroundColor,
  builder: (c) => LapisanKaca(child: builder(c)),
);
