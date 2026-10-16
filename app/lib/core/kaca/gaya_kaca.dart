import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Seberapa tebal kacanya.
///
/// Makin tinggi sebuah bidang melayang di atas yang lain, makin tebal
/// kacanya: yang di belakangnya makin kabur, dan warnanya makin pekat.
/// Bidang yang dekat dengan isinya cukup berembun tipis; dialog yang
/// meminta seluruh perhatian menutup halamannya rapat-rapat.
enum TingkatKaca {
  /// Kartu dan panel yang menempel di latar.
  tipis,

  /// Kepala daftar yang melayang di atas kartu yang digulir, dan menu
  /// pilihan: halaman di belakang menu diburamkan setipis ini.
  ringan,

  /// Dock, lembar bawah, dan snackbar.
  sedang,

  /// Dialog: halaman di belakangnya diburamkan setebal ini.
  tebal,
}

/// Gaya kaca yang sedang berlaku. Hanya ada di tema Android; di Windows
/// tidak dipasang sama sekali, dan [KacaKonteks.kaca] mengembalikan null.
///
/// Semua yang menggambar kaca bertanya ke sini dulu. Karena itu cukup satu
/// sakelar -- tema -- untuk menyalakan atau mematikan seluruhnya.
@immutable
class GayaKaca extends ThemeExtension<GayaKaca> {
  const GayaKaca({
    required this.dasar,
    required this.isi,
    required this.tepi,
    required this.bayangan,
    required this.bola,
    required this.pekat,
  });

  /// Warna dasar latar kaca, di bawah bola-bola cahayanya.
  final Color dasar;

  /// Warna bidang kaca sebelum dibuat tembus pandang.
  final Color isi;

  /// Garis tepi bidang kaca yang melayang.
  final Color tepi;

  /// Bayangan di luar bidang kaca yang melayang.
  final Color bayangan;

  /// Bola-bola cahaya di latar: warna dan letaknya, sebagai pecahan lebar
  /// dan tinggi layar, beserta jari-jarinya sebagai pecahan sisi terpanjang.
  final List<(Color, Offset, double)> bola;

  /// Kepekatan isi kaca per tingkat, 0..1.
  final Map<TingkatKaca, double> pekat;

  /// Simpangan baku buram per tingkat, dalam piksel.
  static double sigma(TingkatKaca t) => switch (t) {
    TingkatKaca.tipis => 6,
    TingkatKaca.ringan => 12,
    TingkatKaca.sedang => 16,
    TingkatKaca.tebal => 20,
  };

  /// Warna isi bidang kaca pada tingkat [t].
  Color isiUntuk(TingkatKaca t) => isi.withValues(alpha: pekat[t] ?? 0.6);

  static const terang = GayaKaca(
    dasar: Color(0xFFEDF1F6),
    isi: Color(0xFFFFFFFF),
    tepi: Color(0x1F1A1A1A),
    bayangan: Color(0x24000000),
    bola: [
      (Color(0x2E0033A0), Offset(0.05, 0.08), 0.62),
      (Color(0x241B8A4B), Offset(0.98, 0.62), 0.55),
      (Color(0x1A5AA9E6), Offset(0.35, 1.02), 0.5),
    ],
    pekat: {
      TingkatKaca.tipis: 0.58,
      TingkatKaca.ringan: 0.62,
      TingkatKaca.sedang: 0.66,
      TingkatKaca.tebal: 0.78,
    },
  );

  static const gelap = GayaKaca(
    dasar: Color(0xFF171717),
    isi: Color(0xFF242424),
    tepi: Color(0x24FFFFFF),
    bayangan: Color(0x66000000),
    bola: [
      (Color(0x263A3A3A), Offset(0.0, 0.05), 0.7),
      (Color(0x18F0A13A), Offset(1.0, 0.7), 0.5),
      (Color(0x143A3A3A), Offset(0.3, 1.05), 0.45),
    ],
    pekat: {
      TingkatKaca.tipis: 0.62,
      TingkatKaca.ringan: 0.66,
      TingkatKaca.sedang: 0.7,
      TingkatKaca.tebal: 0.8,
    },
  );

  @override
  GayaKaca copyWith({
    Color? dasar,
    Color? isi,
    Color? tepi,
    Color? bayangan,
    List<(Color, Offset, double)>? bola,
    Map<TingkatKaca, double>? pekat,
  }) => GayaKaca(
    dasar: dasar ?? this.dasar,
    isi: isi ?? this.isi,
    tepi: tepi ?? this.tepi,
    bayangan: bayangan ?? this.bayangan,
    bola: bola ?? this.bola,
    pekat: pekat ?? this.pekat,
  );

  @override
  GayaKaca lerp(covariant GayaKaca? lain, double t) {
    if (lain == null) return this;
    // Bola dan kepekatan tidak dilerp: keduanya berpindah sekaligus saat
    // tema berganti, dan peralihan setengah jalan di antaranya tidak
    // pernah terlihat -- latarnya sudah tertutup halaman yang berganti.
    final dekat = t < 0.5 ? this : lain;
    return GayaKaca(
      dasar: Color.lerp(dasar, lain.dasar, t)!,
      isi: Color.lerp(isi, lain.isi, t)!,
      tepi: Color.lerp(tepi, lain.tepi, t)!,
      bayangan: Color.lerp(bayangan, lain.bayangan, t)!,
      bola: dekat.bola,
      pekat: dekat.pekat,
    );
  }
}

extension KacaKonteks on BuildContext {
  /// Gaya kaca yang berlaku, atau null kalau kaca tidak dinyalakan.
  GayaKaca? get kaca => Theme.of(this).extension<GayaKaca>();
}

/// Apakah perangkat ini memakai kaca. Hanya Android -- di Windows, meja
/// depan membaca tabel padat seharian, dan kaca hanya membuatnya lebih
/// sulit dibaca.
bool get kacaDidukung => defaultTargetPlatform == TargetPlatform.android;
