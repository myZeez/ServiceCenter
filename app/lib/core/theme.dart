import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'kaca/gaya_kaca.dart';
import 'kaca/lapisan_kaca.dart';
import 'warna.dart';

export 'kaca/gaya_kaca.dart';
export 'warna.dart';

/// Ritme spasi. Basis 8px, dengan tiga langkah besar dari spesifikasi.
class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const s = 12.0;
  static const sm = 20.0;
  static const md = 40.0;
  static const lg = 80.0;
}

class AppRadius {
  static const base = 8.0;
  static const small = 4.0;
}

/// Bayangan tidak boleh lebih berat dari ini. Swiss design tidak memakai
/// kedalaman untuk hierarki -- yang bekerja adalah grid dan tipografi.
const kSwissShadow = [
  BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
];

/// Huruf untuk angka dan kode: nomor nota, rupiah, tanggal, nomor seri.
///
/// Monospace hanya di tempat yang angkanya dibandingkan menurun. 28292 dan
/// 28293 bedanya satu digit di tengah, dan dengan lebar huruf yang sama
/// digit itu berdiri persis di atas pasangannya -- selisihnya terlihat
/// tanpa dibaca.
///
/// Sengaja tidak dipakai untuk nama pelanggan dan keluhan. Monospace lebih
/// lebar dan lebih lambat dibaca untuk kalimat, dan layar terpadat di sini
/// justru daftar nama.
///
/// Belum ada berkas fontnya di repo, jadi yang dipakai monospace bawaan
/// sistem. Taruh JetBrains Mono di `fonts/` dan daftarkan di pubspec kalau
/// ingin rupanya persis sama di Windows dan Android.
const kFontAngka = 'monospace';
const kFontAngkaCadangan = [
  'JetBrains Mono',
  'Cascadia Mono',
  'Consolas',
  'Roboto Mono',
  'monospace',
];

/// Gaya untuk sel yang isinya angka atau kode.
TextStyle gayaAngka(BuildContext context, {double? ukuran, FontWeight? tebal}) {
  final dasar = DefaultTextStyle.of(context).style;
  return dasar.copyWith(
    fontFamily: kFontAngka,
    fontFamilyFallback: kFontAngkaCadangan,
    fontSize: ukuran ?? dasar.fontSize,
    fontWeight: tebal,
    letterSpacing: 0,
  );
}

class AppTheme {
  /// Siang: Swiss/International Typographic Style, seperti sejak awal.
  ///
  /// [kaca] menyalakan mode kaca: bidang tembus pandang di atas latar
  /// berwarna, dengan buram yang berbeda-beda tebalnya. Hanya dipakai
  /// Android -- lihat `kacaDidukung`.
  static ThemeData terang({bool kaca = false}) => _susun(
    kaca ? WarnaApp.terangKaca : WarnaApp.terang,
    Brightness.light,
    kaca ? GayaKaca.terang : null,
  );

  /// Malam: abu arang berlapis dengan kontras yang tetap nyaman dibaca.
  static ThemeData gelap({bool kaca = false}) => _susun(
    kaca ? WarnaApp.gelapKaca : WarnaApp.gelap,
    Brightness.dark,
    kaca ? GayaKaca.gelap : null,
  );

  static ThemeData _susun(WarnaApp w, Brightness terang, GayaKaca? kaca) {
    final scheme = ColorScheme(
      brightness: terang,
      primary: w.teks,
      onPrimary: w.diTeks,
      secondary: w.aksen,
      onSecondary: w.diAksen,
      error: w.bahaya,
      onError: w.diAksen,
      surface: w.permukaan,
      onSurface: w.teks,
      outline: w.garis,
      surfaceContainerHighest: w.teredam,
    );

    // Kontras bobot adalah inti gaya ini: judul tebal dan rapat, label kecil
    // dengan tracking longgar, teks isi netral.
    final text = TextTheme(
      displayLarge: TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        height: 1.05,
        color: w.teks,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        height: 1.1,
        color: w.teks,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: w.teks,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: w.teks,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.6, color: w.teks),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: w.teks),
      // Label dipakai untuk kaption dan judul kolom. Tracking positif dan
      // huruf besar membuatnya terbaca sebagai penanda, bukan isi.
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: w.teks,
      ),
      labelMedium: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: w.teks,
      ),
      labelSmall: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
        color: w.teksLembut,
      ),
    );

    OutlineInputBorder border(Color c, double t) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.base),
      borderSide: BorderSide(color: c, width: t),
    );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      extensions: [w, ?kaca],
      // Di mode kaca latar halaman bening: yang terlihat adalah LatarKaca
      // yang dipasang di dalam tiap halaman.
      scaffoldBackgroundColor: w.latar,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,

      // Dipakai menu DropdownButton sebagai latarnya. Kacanya lebih pekat
      // daripada kartu: menu berdiri sebentar di atas isi yang sedang
      // dibaca, dan yang di bawahnya tidak boleh ikut terbaca.
      canvasColor: kaca?.isiUntuk(TingkatKaca.tebal),

      appBarTheme: AppBarTheme(
        backgroundColor: w.latar,
        foregroundColor: w.teks,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
          color: w.teks,
        ),
        // Ikon baterai dan jam di Android ikut membalik, kalau tidak
        // yang di atas layar jadi abu di atas abu.
        systemOverlayStyle: terang == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),

      // Garis 1px mengerjakan tugas yang biasanya diserahkan ke bayangan.
      cardTheme: CardThemeData(
        color: w.permukaan,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.base),
          side: BorderSide(color: w.garisHalus),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: w.garisHalus,
        thickness: 1,
        space: 1,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: w.permukaan,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s,
          vertical: 14,
        ),
        border: border(w.garis, 1),
        enabledBorder: border(w.garisIsian, 1),
        focusedBorder: border(w.teks, 2),
        errorBorder: border(w.bahaya, 1),
        focusedErrorBorder: border(w.bahaya, 2),
        hintStyle: TextStyle(color: w.teksLembut, fontSize: 15),
        errorStyle: TextStyle(
          color: w.bahaya,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: w.teks,
          foregroundColor: w.diTeks,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.base),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: w.teks,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: BorderSide(color: w.teks, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.base),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: w.aksen,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: w.bahaya,
        foregroundColor: w.diAksen,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.base)),
        ),
        extendedTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: w.permukaan,
        selectedColor: w.teks,
        checkmarkColor: w.diTeks,
        side: BorderSide(color: w.garisIsian),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: w.teks,
        ),
        secondaryLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: w.diTeks,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        showCheckmark: false,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: kaca?.isiUntuk(TingkatKaca.tebal) ?? w.permukaan,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.base),
          side: BorderSide(color: kaca?.tepi ?? w.garisHalus),
        ),
        titleTextStyle: text.titleLarge,
        // Tirai dibuat lebih tipis daripada bawaan: yang memisahkan dialog
        // dari halamannya sudah buram, dan tirai pekat di atas buram
        // membuat keduanya sama-sama tidak terbaca.
        barrierColor: kaca == null ? null : const Color(0x26000000),
      ),

      bottomSheetTheme: kaca == null
          ? const BottomSheetThemeData()
          : BottomSheetThemeData(
              backgroundColor: kaca.isiUntuk(TingkatKaca.sedang),
              surfaceTintColor: Colors.transparent,
              modalBarrierColor: const Color(0x26000000),
              elevation: 0,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppRadius.base * 2),
                ),
              ),
              clipBehavior: Clip.antiAlias,
            ),

      popupMenuTheme: PopupMenuThemeData(
        color: kaca?.isiUntuk(TingkatKaca.tebal),
        surfaceTintColor: Colors.transparent,
        elevation: kaca == null ? null : 0,
        shape: kaca == null
            ? null
            : RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.base),
                side: BorderSide(color: kaca.tepi),
              ),
      ),

      datePickerTheme: DatePickerThemeData(
        backgroundColor: kaca?.isiUntuk(TingkatKaca.tebal),
        surfaceTintColor: Colors.transparent,
        elevation: kaca == null ? null : 0,
        shape: kaca == null
            ? null
            : RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.base),
                side: BorderSide(color: kaca.tepi),
              ),
      ),

      timePickerTheme: TimePickerThemeData(
        backgroundColor: kaca?.isiUntuk(TingkatKaca.tebal),
        elevation: kaca == null ? null : 0,
      ),

      // Keterangan yang muncul saat ikon ditahan. Satu-satunya lapisan
      // yang tidak bisa diberi buram -- Flutter tidak menyediakan
      // sambungannya -- jadi kacanya dibuat lebih pekat supaya tulisannya
      // tetap terbaca di atas apa pun.
      tooltipTheme: kaca == null
          ? const TooltipThemeData()
          : TooltipThemeData(
              decoration: BoxDecoration(
                color: w.teks.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              textStyle: TextStyle(fontSize: 12, color: w.diTeks),
            ),

      snackBarTheme: SnackBarThemeData(
        // Buramnya disisipkan PesanKaca; yang diatur di sini hanya
        // warnanya. Bayangan dimatikan: bayangan di bawah bidang tembus
        // pandang terlihat sebagai kaca yang kotor.
        backgroundColor: kaca == null ? w.teks : w.teks.withValues(alpha: 0.82),
        elevation: kaca == null ? null : 0,
        contentTextStyle: TextStyle(
          color: w.diTeks,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.base),
        ),
      ),

      listTileTheme: ListTileThemeData(
        titleTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: w.teks,
        ),
        subtitleTextStyle: TextStyle(fontSize: 13, color: w.teksLembut),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: w.teks,
        unselectedLabelColor: w.teksLembut,
        indicatorColor: w.bahaya,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: w.garisHalus,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
      ),

      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: kaca == null
              ? const FadeForwardsPageTransitionsBuilder()
              : TransisiKaca(
                  FadeForwardsPageTransitionsBuilder(
                    backgroundColor: kaca.dasar,
                  ),
                ),
          TargetPlatform.windows: const FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
