import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Palet Swiss/International Typographic Style.
///
/// Hitamnya sengaja bukan #000000 -- hitam murni terasa keras di layar dan
/// menghilangkan kesan tinta di atas kertas.
class AppColors {
  static const red = Color(0xFFD82C2C); // Signal Red - butuh perhatian
  static const black = Color(0xFF1A1A1A); // teks dan elemen utama
  static const white = Color(0xFFFFFFFF);
  static const grey = Color(0xFFA9B2B1); // teks sekunder, garis
  static const blue = Color(0xFF0033A0); // aksen kedua
  static const lightGrey = Color(0xFFF2F2F2); // latar teredam
}

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

class AppTheme {
  static ThemeData build() {
    const scheme = ColorScheme.light(
      primary: AppColors.black,
      onPrimary: AppColors.white,
      secondary: AppColors.blue,
      onSecondary: AppColors.white,
      error: AppColors.red,
      onError: AppColors.white,
      surface: AppColors.white,
      onSurface: AppColors.black,
      outline: AppColors.grey,
      surfaceContainerHighest: AppColors.lightGrey,
    );

    // Kontras bobot adalah inti gaya ini: judul tebal dan rapat, label kecil
    // dengan tracking longgar, teks isi netral.
    const text = TextTheme(
      displayLarge: TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        height: 1.05,
        color: AppColors.black,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        height: 1.1,
        color: AppColors.black,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: AppColors.black,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: AppColors.black,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.6, color: AppColors.black),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: AppColors.black),
      // Label dipakai untuk kaption dan judul kolom. Tracking positif dan
      // huruf besar membuatnya terbaca sebagai penanda, bukan isi.
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: AppColors.black,
      ),
      labelMedium: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: AppColors.black,
      ),
      labelSmall: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
        color: AppColors.grey,
      ),
    );

    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.base),
          borderSide: BorderSide(color: c, width: w),
        );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.white,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
          color: AppColors.black,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),

      // Garis 1px mengerjakan tugas yang biasanya diserahkan ke bayangan.
      cardTheme: CardThemeData(
        color: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.base),
          side: const BorderSide(color: Color(0xFFE4E7E7)),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: Color(0xFFE4E7E7),
        thickness: 1,
        space: 1,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s,
          vertical: 14,
        ),
        border: border(AppColors.grey, 1),
        enabledBorder: border(const Color(0xFFCFD5D4), 1),
        focusedBorder: border(AppColors.black, 2),
        errorBorder: border(AppColors.red, 1),
        focusedErrorBorder: border(AppColors.red, 2),
        hintStyle: const TextStyle(color: AppColors.grey, fontSize: 15),
        errorStyle: const TextStyle(
          color: AppColors.red,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.white,
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
          foregroundColor: AppColors.black,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: const BorderSide(color: AppColors.black, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.base),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.blue,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.red,
        foregroundColor: AppColors.white,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.base)),
        ),
        extendedTextStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.white,
        selectedColor: AppColors.black,
        checkmarkColor: AppColors.white,
        side: const BorderSide(color: Color(0xFFCFD5D4)),
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: AppColors.black,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: AppColors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        showCheckmark: false,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.base),
          side: const BorderSide(color: Color(0xFFE4E7E7)),
        ),
        titleTextStyle: text.titleLarge,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.black,
        contentTextStyle: const TextStyle(
          color: AppColors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.base),
        ),
      ),

      listTileTheme: const ListTileThemeData(
        titleTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.black,
        ),
        subtitleTextStyle: TextStyle(fontSize: 13, color: AppColors.grey),
      ),

      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.black,
        unselectedLabelColor: AppColors.grey,
        indicatorColor: AppColors.red,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Color(0xFFE4E7E7),
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
