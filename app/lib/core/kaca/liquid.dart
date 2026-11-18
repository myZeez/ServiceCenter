import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show
        AdaptiveGlass,
        GlassBodyMode,
        GlassLensModel,
        GlassQuality,
        GlassSpecularSharpness,
        LiquidGlassSettings,
        LiquidOval;

import '../theme.dart';

/// Pengaturan Liquid Glass untuk kepala, dock, dan tombol navigasi atas: kaca
/// BENING, bukan berembun.
///
/// Beda dengan preset `ios26Light`/`ios27Light` bawaan paket yang berembun
/// (`frost: 14`, putih susu) -- di sini `frost` dimatikan dan `blur` dibuat
/// tipis, sehingga yang terlihat adalah pembiasan di tepi lensa (bevel),
/// kilau tepi (`rimLight`), dan warna isi yang jernih.
LiquidGlassSettings pengaturanLiquid(
  BuildContext context, {
  double tebal = 28,
  Color? tint,
  double blur = 2.5,
  double rimLight = 1.0,
  double rimShade = 0.6,
  double lightIntensity = 0.9,
}) {
  final gelap = Theme.of(context).brightness == Brightness.dark;
  final warnaDasar =
      tint ?? (gelap ? WarnaLiquid.tintGelap : WarnaLiquid.tintTerang);

  return LiquidGlassSettings(
    glassColor: warnaDasar,
    thickness: tebal,
    blur: blur,
    frost: 0,
    frostOpacity: 0,
    refractiveIndex: 1.32,
    lensModel: GlassLensModel.paraxial,
    chromaticAberration: 0.03,
    saturation: 1.35,
    lightAngle: gelap ? -1.5707963267948966 : 1.5707963267948966,
    lightIntensity: lightIntensity,
    fresnelStrength: 0.6,
    specularSharpness: GlassSpecularSharpness.sharp,
    rimLight: rimLight,
    rimShade: rimShade,
    edgeAbsorption: 0.03,
    shadowElevation: 0,
    bodyMode: GlassBodyMode.clear,
  );
}

/// Kualitas shader yang aman dan mulus di setiap platform.
GlassQuality kualitasLiquid(BuildContext context, {bool utama = false}) {
  if (utama && defaultTargetPlatform == TargetPlatform.android) {
    return GlassQuality.premium;
  }
  return GlassQuality.standard;
}

/// Tombol ikon kaca cair bundar pada bilah atas (mis. tombol kembali dan tutup).
///
/// Dipakai lewat `ActionIconThemeData` pada `ThemeData` ketika `liquid` menyala
/// (Android/Web) agar tombol kembali di AppBar mempertahankan tampilan kaca cair
/// yang serasi dengan tombol menu titik tiga, tanpa menyentuh `IconButton` di
/// dalam formulir atau daftar.
class TombolIkonLiquid extends StatelessWidget {
  const TombolIkonLiquid({
    super.key,
    required this.icon,
    this.ukuran = 36,
    this.ukuranIkon = 20,
  });

  final IconData icon;
  final double ukuran;
  final double ukuranIkon;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final tint = gelap ? WarnaLiquid.ikonGelap : WarnaLiquid.ikonTerang;

    return SizedBox(
      width: ukuran,
      height: ukuran,
      child: AdaptiveGlass(
        useOwnLayer: true,
        isInteractive: true,
        quality: kualitasLiquid(context, utama: true),
        shape: const LiquidOval(),
        settings: pengaturanLiquid(
          context,
          tebal: 18,
          tint: tint,
          blur: 2.0,
          rimLight: 1.05,
          rimShade: 0.5,
        ),
        child: Center(
          child: Icon(icon, size: ukuranIkon, color: context.warna.teks),
        ),
      ),
    );
  }
}
