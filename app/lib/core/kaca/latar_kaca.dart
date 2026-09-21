import 'package:flutter/material.dart';

import 'gaya_kaca.dart';

/// Latar yang dilihat lewat semua kaca di atasnya: satu warna dasar dengan
/// beberapa bola cahaya besar yang lembut.
///
/// Ada karena kaca menuntutnya. Bidang tembus pandang di atas putih polos
/// tetap terlihat putih polos -- yang membuat kaca terbaca sebagai kaca
/// adalah warna yang berubah pelan di belakangnya.
///
/// Dipasang di dalam SETIAP halaman, bukan sekali di belakang semuanya.
/// Halaman yang tembus pandang akan saling menampakkan isi saat berpindah,
/// dan yang terlihat adalah dua halaman bertumpuk. Dengan latarnya masing-
/// masing, tiap halaman menutup halaman di bawahnya seperti biasa.
class LatarKaca extends StatelessWidget {
  const LatarKaca({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final kaca = context.kaca;
    if (kaca == null) return child;

    return CustomPaint(
      painter: _PelukisLatar(kaca),
      // Latarnya tidak pernah berubah selama temanya tetap, jadi ia
      // dilukis sekali lalu disimpan -- tanpa ini ia ikut digambar ulang
      // setiap kali daftar di atasnya bergulir.
      isComplex: true,
      willChange: false,
      child: child,
    );
  }
}

class _PelukisLatar extends CustomPainter {
  const _PelukisLatar(this.kaca);

  final GayaKaca kaca;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = kaca.dasar);

    final sisi = size.longestSide;
    for (final (warna, letak, jari) in kaca.bola) {
      final pusat = Offset(letak.dx * size.width, letak.dy * size.height);
      final r = jari * sisi;
      canvas.drawCircle(
        pusat,
        r,
        Paint()
          ..shader = RadialGradient(colors: [warna, warna.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: pusat, radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(_PelukisLatar lama) => lama.kaca != kaca;
}
