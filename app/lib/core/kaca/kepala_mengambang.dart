import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassContainer, GlassQuality, LiquidRoundedRectangle;


import 'gaya_kaca.dart';
import 'liquid.dart';
import 'panel_kaca.dart';

/// Kepala daftar yang melayang di atas isinya.
///
/// Di mode kaca, kepala daftar -- kotak pencarian dan deretan saringan --
/// tidak lagi mendorong daftarnya ke bawah melainkan berdiri di atasnya.
/// Kartu yang digulir lewat di belakangnya dan terbiaskan oleh lensa kaca
/// liquid glass bening; itulah yang membuat kacanya terbaca sebagai kaca
/// cair asli, bukan sekadar warna pudar atau frosted buram.
///
/// Di luar mode kaca susunannya persis seperti sebelumnya: kepala di atas,
/// daftar di bawahnya, tidak ada yang bertumpuk. Karena itu [isi] menerima
/// berapa ruang yang harus disisakan di puncak daftar -- nol kalau memang
/// tidak ada yang menutupinya.
///
/// AppBar ikut tertutup kaca yang sama. Sempat panelnya baru dimulai di
/// bawah AppBar, dan yang terlihat adalah tepi keras di antara keduanya:
/// AppBar yang bening memperlihatkan latar berwarna, panel di bawahnya
/// berwarna lebih gelap oleh kacanya sendiri. Sekarang panelnya dimulai
/// dari puncak layar dan AppBar -- yang bening -- duduk di atasnya, jadi
/// keduanya satu bidang yang menyambung.
///
/// Syaratnya: Scaffold pemakainya harus `extendBodyBehindAppBar` selama
/// kacanya menyala, supaya isinya mulai dari puncak layar dan tahu
/// setinggi apa AppBar-nya lewat `MediaQuery.padding.top`.
class KepalaMengambang extends StatefulWidget {
  const KepalaMengambang({super.key, required this.kepala, required this.isi});

  final Widget kepala;
  final Widget Function(BuildContext context, double ruangAtas) isi;

  @override
  State<KepalaMengambang> createState() => _KepalaMengambangState();
}

class _KepalaMengambangState extends State<KepalaMengambang> {
  double _tinggi = 0;

  @override
  Widget build(BuildContext context) {
    if (context.kaca == null) {
      return Column(
        children: [
          widget.kepala,
          Expanded(child: widget.isi(context, 0)),
        ],
      );
    }

    // Setinggi AppBar beserta status bar di atasnya, kalau Scaffold-nya
    // memang memperpanjang isi ke belakang AppBar. Nol kalau tidak ada.
    final atas = MediaQuery.paddingOf(context).top;

    return Stack(
      children: [
        Positioned.fill(child: widget.isi(context, _tinggi)),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          // Liquid Glass dari paket liquid_glass_widgets: bening transparan
          // tanpa efek frosted (blur/frost 0), dengan refraksi optik shader
          // murni agar kartu dan teks yang melintas di bawahnya terbiaskan
          // seperti air/kaca cair.
          //
          // Bentuk atas dan bawah tetap lurus tanpa sudut melengkung,
          // menyatu dengan AppBar dan garis pembatas bawah.
          child: PanelKaca(
            tingkat: TingkatKaca.ringan,
            tepi: Tepi.bawah,
            transparan: true,
            tanpaBuram: true,
            child: GlassContainer(
              useOwnLayer: true,
              quality: GlassQuality.premium,
              shape: const LiquidRoundedRectangle(borderRadius: 0),
              settings: pengaturanLiquid(context, tebal: 22),
              child: _Ukur(
                onTinggi: (t) {
                  if ((t - _tinggi).abs() < 0.5) return;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _tinggi = t);
                  });
                },
                child: Padding(
                  padding: EdgeInsets.only(top: atas),
                  child: widget.kepala,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Melaporkan tinggi anaknya setiap kali ia diukur.
class _Ukur extends SingleChildRenderObjectWidget {
  const _Ukur({required this.onTinggi, required Widget super.child});

  final ValueChanged<double> onTinggi;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderUkur(onTinggi);

  @override
  void updateRenderObject(BuildContext context, _RenderUkur renderObject) {
    renderObject.onTinggi = onTinggi;
  }
}

class _RenderUkur extends RenderProxyBox {
  _RenderUkur(this.onTinggi);

  ValueChanged<double> onTinggi;

  @override
  void performLayout() {
    super.performLayout();
    onTinggi(size.height);
  }
}
