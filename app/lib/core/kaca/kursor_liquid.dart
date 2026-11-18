import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show
        AdaptiveGlass,
        GlassBodyMode,
        GlassLensModel,
        GlassQuality,
        GlassSpecularSharpness,
        LiquidGlassSettings,
        LiquidOval;

import '../warna.dart';

/// Kursor mouse berbentuk tetesan kaca cair (Liquid Glass) untuk Windows.
///
/// Melacak gerakan pointer mouse: tetesan lensa kaca mengejar posisi kursor
/// dengan pegas halus, memanjang searah kecepatan gerakan, memantulkan kilau
/// cahaya sesuai arah gerak, dan mengecil singkat saat ditekan.
///
/// Tidak menangkap event sentuhan atau pengujian widget: tetesan baru muncul
/// setelah pointer mouse benar-benar masuk/bergerak (`PointerDeviceKind.mouse`),
/// dan [Ticker] berhenti otomatis ketika posisi sudah diam agar pemakaian GPU
/// nol saat idle.
class KursorLiquid extends StatefulWidget {
  const KursorLiquid({super.key, required this.child, this.aktif = false});

  final Widget child;
  final bool aktif;

  /// Apakah kursor Liquid saat ini aktif menggantikan panah sistem.
  static bool aktifDi(BuildContext context) {
    final p = context.dependOnInheritedWidgetOfExactType<_KursorAktif>();
    return p?.aktif ?? false;
  }

  @override
  State<KursorLiquid> createState() => _KursorLiquidState();
}

class _KursorAktif extends InheritedWidget {
  const _KursorAktif({required this.aktif, required super.child});

  final bool aktif;

  @override
  bool updateShouldNotify(_KursorAktif lama) => lama.aktif != aktif;
}

class _KursorLiquidState extends State<KursorLiquid>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);

  bool _terlihat = false;
  bool _ditekan = false;
  Offset _target = Offset.zero;
  Offset _pos = Offset.zero;
  Offset _kecepatan = Offset.zero;
  double _tekanFaktor = 0;
  Duration? _waktuLalu;

  @override
  void didUpdateWidget(KursorLiquid lama) {
    super.didUpdateWidget(lama);
    if (!widget.aktif && _terlihat) {
      _terlihat = false;
      _hentikanTicker();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _mulaiTicker() {
    if (_ticker.isActive) return;
    _waktuLalu = null;
    _ticker.start();
  }

  void _hentikanTicker() {
    if (_ticker.isActive) _ticker.stop();
    _waktuLalu = null;
  }

  void _tick(Duration elapsed) {
    final dt = _waktuLalu == null
        ? 0.016
        : ((elapsed - _waktuLalu!).inMicroseconds / 1e6).clamp(0.001, 0.05);
    _waktuLalu = elapsed;

    // Pegas responsif (~42 rad/s): mengejar posisi mouse cepat agar klik tetap
    // presisi tanpa rasa tertinggal, tetapi masih cukup cair untuk peregangan.
    final tPos = 1 - math.exp(-dt * 42);
    final tEfek = 1 - math.exp(-dt * 18);

    final posBaru = Offset.lerp(_pos, _target, tPos)!;
    final delta = _target - posBaru;
    _kecepatan = delta / dt;
    _pos = posBaru;

    final targetTekan = _ditekan ? 1.0 : 0.0;
    _tekanFaktor += (targetTekan - _tekanFaktor) * tEfek;

    final diam =
        delta.distance < 0.2 && (_tekanFaktor - targetTekan).abs() < 0.005;

    if (mounted) setState(() {});

    if (diam) {
      _pos = _target;
      _kecepatan = Offset.zero;
      _tekanFaktor = targetTekan;
      _hentikanTicker();
    }
  }

  void _gerak(PointerEvent e) {
    if (!widget.aktif || e.kind != PointerDeviceKind.mouse) return;
    _target = e.position;
    if (!_terlihat) {
      _terlihat = true;
      _pos = _target;
    }
    _mulaiTicker();
  }

  void _tekan(PointerDownEvent e) {
    if (!widget.aktif || e.kind != PointerDeviceKind.mouse) return;
    _target = e.position;
    _ditekan = true;
    _mulaiTicker();
  }

  void _lepas(PointerEvent e) {
    if (!widget.aktif || e.kind != PointerDeviceKind.mouse) return;
    _ditekan = false;
    _mulaiTicker();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.aktif) {
      return _KursorAktif(aktif: false, child: widget.child);
    }

    return _KursorAktif(
      aktif: true,
      child: MouseRegion(
        opaque: false,
        cursor: SystemMouseCursors.none,
        onExit: (_) {
          if (_terlihat) setState(() => _terlihat = false);
          _hentikanTicker();
        },
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerHover: _gerak,
          onPointerMove: _gerak,
          onPointerDown: _tekan,
          onPointerUp: _lepas,
          onPointerCancel: _lepas,
          child: Stack(
            fit: StackFit.expand,
            children: [widget.child, if (_terlihat) _lukisTetesan(context)],
          ),
        ),
      ),
    );
  }

  Widget _lukisTetesan(BuildContext context) {
    final w = context.warna;
    final gelap = Theme.of(context).brightness == Brightness.dark;

    // Ukuran tetesan mengecil singkat ketika mouse ditekan.
    final diameter = 26.0 * (1.0 - 0.14 * _tekanFaktor);

    // Peregangan searah gerakan seperti setetes cairan di atas kaca.
    final laju = _kecepatan.distance;
    final sudut = laju > 8 ? math.atan2(_kecepatan.dy, _kecepatan.dx) : 0.0;
    final regang = (laju / 1400).clamp(0.0, 0.42);
    final skalaX = 1.0 + regang;
    final skalaY = 1.0 / math.sqrt(skalaX);

    // Sudut kilau tepi ikut bergeser saat pointer menyapu layar.
    final sudutCahaya =
        (gelap ? -math.pi / 2 : math.pi / 2) +
        (_kecepatan.dx / 900).clamp(-0.9, 0.9);

    final ukuranKotak = diameter * 1.6;

    return Positioned(
      left: _pos.dx - ukuranKotak / 2,
      top: _pos.dy - ukuranKotak / 2,
      width: ukuranKotak,
      height: ukuranKotak,
      child: IgnorePointer(
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: sudut,
                child: Transform.scale(
                  scaleX: skalaX,
                  scaleY: skalaY,
                  child: Transform.rotate(
                    angle: -sudut,
                    child: SizedBox(
                      width: diameter,
                      height: diameter,
                      child: AdaptiveGlass(
                        useOwnLayer: true,
                        isInteractive: true,
                        quality: GlassQuality.premium,
                        shape: const LiquidOval(),
                        glowIntensity: _tekanFaktor * 0.55,
                        settings: LiquidGlassSettings(
                          glassColor: gelap
                              ? WarnaLiquid.tetesanGelap
                              : WarnaLiquid.tetesanTerang,
                          thickness: 20,
                          blur: 0.4,
                          frost: 0,
                          frostOpacity: 0,
                          refractiveIndex: 1.38,
                          lensModel: GlassLensModel.paraxial,
                          chromaticAberration: 0.04,
                          saturation: 1.4,
                          lightAngle: sudutCahaya,
                          lightIntensity: 1.0,
                          fresnelStrength: 0.75,
                          specularSharpness: GlassSpecularSharpness.sharp,
                          rimLight: 1.15,
                          rimShade: 0.75,
                          edgeAbsorption: 0.03,
                          shadowElevation: 0,
                          bodyMode: GlassBodyMode.clear,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              ),
              // Titik inti tajam agar klik pada sel tabel/ikon sempit tetap akurat.
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _ditekan ? w.aksen : w.teks,
                  border: Border.all(
                    color: w.kertas.withValues(alpha: 0.9),
                    width: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
