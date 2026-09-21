import 'dart:ui';

import 'package:flutter/material.dart';

import '../warna.dart';
import 'gaya_kaca.dart';

/// Bidang kaca: yang di belakangnya dikaburkan setebal [tingkat], lalu
/// ditutup warna tembus pandang dan garis tepi tipis.
///
/// Tanpa pendar dan tanpa sapuan cahaya -- kacanya polos. Bentuknya dijaga
/// garis tepi dan, bila diminta, bayangan di luarnya.
///
/// Di luar mode kaca (Windows) ia menjadi bidang padat biasa: warna
/// permukaan, garis tepi halus, dan bayangan yang sama. Jadi yang memakainya
/// tidak perlu bertanya dulu kacanya menyala atau tidak.
class PanelKaca extends StatelessWidget {
  const PanelKaca({
    super.key,
    required this.child,
    this.tingkat = TingkatKaca.tipis,
    this.radius = BorderRadius.zero,
    this.bayangan = false,
    this.tepi = Tepi.keliling,
    this.transparan = false,
  });

  final Widget child;
  final TingkatKaca tingkat;
  final BorderRadius radius;

  /// Bayangan lembut di luar bidang, untuk yang melayang di atas isi.
  final bool bayangan;

  final Tepi tepi;

  /// Menahan tint bidang, tetapi tetap memburamkan isi di belakangnya.
  /// Cocok untuk kepala daftar yang hanya butuh pemisah dan blur, bukan
  /// blok warna tambahan di atas latar kaca.
  final bool transparan;

  @override
  Widget build(BuildContext context) {
    final kaca = context.kaca;
    final w = context.warna;
    final warnaTepi = kaca?.tepi ?? w.garisHalus;

    final garis = switch (tepi) {
      Tepi.keliling => Border.all(color: warnaTepi),
      Tepi.bawah => Border(bottom: BorderSide(color: warnaTepi)),
      Tepi.atas => Border(top: BorderSide(color: warnaTepi)),
      Tepi.tanpa => null,
    };
    // Garis yang tidak mengelilingi tidak boleh digabung dengan lengkungan
    // -- BoxDecoration menolaknya. Garis sebagian hanya dipakai bidang
    // bersudut siku (kepala daftar, lembar), jadi lengkungannya dilepas.
    final lengkung = tepi == Tepi.keliling || tepi == Tepi.tanpa
        ? radius
        : null;

    Widget bidang;
    if (kaca == null) {
      bidang = DecoratedBox(
        decoration: BoxDecoration(
          color: w.permukaan,
          borderRadius: lengkung,
          border: garis,
        ),
        child: child,
      );
      if (radius != BorderRadius.zero) {
        bidang = ClipRRect(borderRadius: radius, child: bidang);
      }
    } else {
      final s = GayaKaca.sigma(tingkat);
      bidang = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: s, sigmaY: s),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: transparan ? Colors.transparent : kaca.isiUntuk(tingkat),
              borderRadius: lengkung,
              border: garis,
            ),
            child: child,
          ),
        ),
      );
    }

    if (!bayangan) return bidang;
    return CustomPaint(
      painter: PelukisBayanganLuar(
        radius: radius,
        warna: kaca?.bayangan ?? const Color(0x14000000),
      ),
      child: bidang,
    );
  }
}

/// Di sisi mana garis tepi bidang kaca digambar.
enum Tepi { keliling, bawah, atas, tanpa }

/// Bayangan yang hanya jatuh di LUAR bidang.
///
/// BoxShadow biasa juga melukis di bawah bagian dalam bentuknya. Pada isi
/// yang tembus pandang itu terlihat sebagai kaca yang keruh keabuan --
/// kebalikan dari yang dicari.
class PelukisBayanganLuar extends CustomPainter {
  const PelukisBayanganLuar({required this.radius, required this.warna});

  final BorderRadius radius;
  final Color warna;

  @override
  void paint(Canvas canvas, Size size) {
    final bentuk = radius.toRRect(Offset.zero & size);
    final luar = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect((Offset.zero & size).inflate(80))
      ..addRRect(bentuk);

    canvas
      ..save()
      ..clipPath(luar)
      ..drawRRect(
        bentuk.shift(const Offset(0, 4)),
        Paint()
          ..color = warna
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(PelukisBayanganLuar lama) =>
      lama.warna != warna || lama.radius != radius;
}
