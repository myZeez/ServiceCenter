import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Kapsul kaca buram: isi yang melayang di atas daftar yang bergulir di
/// belakangnya.
///
/// Buramnya sengaja sedang -- cukup untuk membuat tulisan di belakangnya
/// tidak mengganggu, tidak sampai membuat daftarnya jadi bercak. Cahaya
/// dalamnya tipis, hanya menyapu tepi supaya bentuknya terbaca sebagai
/// kaca, bukan bingkai.
///
/// Tinggi ditentukan pemakainya; lengkungnya selalu setengah tinggi, jadi
/// bentuknya kapsul berapa pun tingginya.
class KapsulKaca extends StatelessWidget {
  const KapsulKaca({super.key, required this.child, this.buram = 10});

  final Widget child;

  /// Simpangan baku buramnya, dalam piksel.
  final double buram;

  @override
  Widget build(BuildContext context) {
    final w = context.warna;
    final gelap = Theme.of(context).brightness == Brightness.dark;

    // Siang: kaca putih di atas halaman putih, jadi yang membuatnya
    // terlihat adalah garis tepi dan bayangan. Malam: kaca biru tua yang
    // tepinya disapu cahaya putih tipis.
    final isi = w.permukaan.withValues(alpha: gelap ? 0.52 : 0.5);
    final kilau = Colors.white.withValues(alpha: gelap ? 0.2 : 0.75);
    final tepi = gelap
        ? Colors.white.withValues(alpha: 0.14)
        : w.teks.withValues(alpha: 0.1);
    final bayangan = Colors.black.withValues(alpha: gelap ? 0.42 : 0.13);

    return CustomPaint(
      painter: _PelukisBayangan(bayangan),
      child: ClipRRect(
        // Lebih besar dari setengah tinggi mana pun; RRect menjepitnya
        // menjadi setengah tinggi, dan itulah kapsulnya.
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: buram, sigmaY: buram),
          child: CustomPaint(
            painter: _PelukisKaca(isi: isi, kilau: kilau, tepi: tepi),
            child: child,
          ),
        ),
      ),
    );
  }
}

RRect _kapsul(Size size) => RRect.fromRectAndRadius(
  Offset.zero & size,
  Radius.circular(size.height / 2),
);

/// Bayangan yang hanya jatuh di LUAR kapsul.
///
/// BoxShadow biasa juga melukis di bawah bagian dalam bentuknya. Pada isi
/// yang tembus pandang itu terlihat sebagai kaca yang keruh keabuan --
/// kebalikan dari yang dicari.
class _PelukisBayangan extends CustomPainter {
  const _PelukisBayangan(this.warna);

  final Color warna;

  @override
  void paint(Canvas canvas, Size size) {
    final kapsul = _kapsul(size);
    final luar = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect((Offset.zero & size).inflate(80))
      ..addRRect(kapsul);

    canvas
      ..save()
      ..clipPath(luar)
      ..drawRRect(
        kapsul.shift(const Offset(0, 4)),
        Paint()
          ..color = warna
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_PelukisBayangan lama) => lama.warna != warna;
}

class _PelukisKaca extends CustomPainter {
  const _PelukisKaca({
    required this.isi,
    required this.kilau,
    required this.tepi,
  });

  final Color isi;
  final Color kilau;
  final Color tepi;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final kapsul = _kapsul(size);

    canvas.drawRRect(kapsul, Paint()..color = isi);

    canvas
      ..save()
      ..clipRRect(kapsul);

    // Sapuan cahaya dari atas, yang memudar sebelum sampai tengah.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            kilau.withValues(alpha: kilau.a * 0.35),
            Colors.transparent,
          ],
          stops: const [0, 0.55],
        ).createShader(rect),
    );

    // Cahaya dalam: garis di tepi yang dikaburkan. Separuh tebalnya jatuh
    // di luar kapsul dan terpotong, jadi yang tersisa hanya pendar tipis
    // ke arah dalam.
    canvas
      ..drawRRect(
        kapsul,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = kilau
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      )
      ..restore();

    canvas.drawRRect(
      kapsul.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = tepi,
    );
  }

  @override
  bool shouldRepaint(_PelukisKaca lama) =>
      lama.isi != isi || lama.kilau != kilau || lama.tepi != tepi;
}
