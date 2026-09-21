import 'dart:ui';

import 'package:flutter/material.dart';

import 'gaya_kaca.dart';

/// Pembawa pesan yang mengacakan setiap snackbar menjadi kaca.
///
/// Snackbar bukan rute, jadi [PengamatKaca] tidak melihatnya, dan tidak ada
/// satu pun setelan tema yang bisa menyisipkan buram ke dalamnya. Yang bisa
/// dilakukan cuma satu: memotongnya di jalan. Setiap `showSnackBar` di
/// seluruh aplikasi -- semuanya lewat ScaffoldMessenger -- melewati kelas
/// ini, jadi tidak ada pemanggilan yang perlu diubah dan tidak ada yang
/// bisa terlewat.
///
/// Dipasang di MaterialApp.builder, di bawah pembawa pesan bawaan
/// MaterialApp, supaya yang ditemukan Scaffold adalah yang ini.
class PesanKaca extends ScaffoldMessenger {
  const PesanKaca({super.key, required super.child});

  @override
  ScaffoldMessengerState createState() => _PesanKacaState();
}

class _PesanKacaState extends ScaffoldMessengerState {
  @override
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackBar(
    SnackBar snackBar, {
    AnimationStyle? snackBarAnimationStyle,
  }) => super.showSnackBar(
    context.kaca == null ? snackBar : _berkaca(snackBar),
    snackBarAnimationStyle: snackBarAnimationStyle,
  );

  /// Salinan snackbar yang isinya dibungkus buram.
  ///
  /// Buramnya diletakkan di dalam isi, tetapi yang dikaburkan adalah
  /// seluruh bidang snackbar: BackdropFilter bekerja sampai batas potongan
  /// terdekat, dan snackbar memotong isinya sesuai bentuknya sendiri. Jadi
  /// tombol URUNGKAN di ujung kanan ikut berdiri di atas kaca yang sama.
  SnackBar _berkaca(SnackBar s) {
    final sigma = GayaKaca.sigma(TingkatKaca.sedang);
    return SnackBar(
      key: s.key,
      content: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: s.content,
      ),
      backgroundColor: s.backgroundColor,
      elevation: s.elevation,
      margin: s.margin,
      padding: s.padding,
      width: s.width,
      shape: s.shape,
      hitTestBehavior: s.hitTestBehavior,
      behavior: s.behavior,
      action: s.action,
      actionOverflowThreshold: s.actionOverflowThreshold,
      showCloseIcon: s.showCloseIcon,
      closeIconColor: s.closeIconColor,
      duration: s.duration,
      persist: s.persist,
      onVisible: s.onVisible,
      dismissDirection: s.dismissDirection,
      clipBehavior: s.clipBehavior,
    );
  }
}
