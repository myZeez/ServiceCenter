import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'gaya_kaca.dart';
import 'latar_kaca.dart';

/// Mencatat apa yang sedang menutupi apa.
///
/// Dialog, lembar bawah, menu pilihan, dan pemilih tanggal semuanya rute
/// yang ditumpuk di atas rute lain. Yang tertutup diburamkan -- itulah yang
/// membuat panel di atasnya terbaca sebagai kaca, dan itu berlaku untuk
/// setiap rute tanpa satu pun tempat pemanggilan perlu diubah. Menu pilihan
/// yang ditambahkan besok ikut terlayani.
///
/// Satu-satunya yang harus dikerjakan di tempat lain adalah memasang
/// [LapisanKaca] di isi rute yang bisa tertutup: halaman (lewat
/// [TransisiKaca]) serta dialog dan lembar (lewat bantuan di
/// `overlay_kaca.dart`).
class PengamatKaca extends NavigatorObserver {
  PengamatKaca._();

  /// Satu untuk seluruh aplikasi: dipasang di MaterialApp.
  static final PengamatKaca instance = PengamatKaca._();

  final Map<Route<dynamic>, Kabut> _kabut = {};

  /// Kabut yang menutupi [rute]. Dibuat kalau belum ada, supaya isi rute
  /// bisa mulai mendengarkan sebelum ada apa pun yang menutupinya.
  Kabut? untuk(Route<dynamic>? rute) {
    if (rute == null) return null;
    return _kabut.putIfAbsent(rute, Kabut.new);
  }

  /// Seberapa tebal sebuah rute menutupi yang di bawahnya.
  ///
  /// Dialog menuntut seluruh perhatian; lembar bawah menyisakan halamannya
  /// sebagai sandaran; menu pilihan hanya numpang sebentar dan tidak perlu
  /// menghapus isi di belakangnya.
  static TingkatKaca tingkatUntuk(Route<dynamic> rute) => switch (rute) {
    ModalBottomSheetRoute() => TingkatKaca.sedang,
    RawDialogRoute() => TingkatKaca.tebal,
    _ => TingkatKaca.ringan,
  };

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Halaman menutupi halaman dengan caranya sendiri (lihat TransisiKaca):
    // yang diurus di sini hanya yang melayang di atas halaman.
    if (previousRoute == null || route is! PopupRoute) return;
    final animasi = route.animation;
    if (animasi == null) return;
    untuk(previousRoute)!.tambah(route, animasi, tingkatUntuk(route));
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Penutupnya dilepas sendiri begitu animasinya habis mundur, supaya
    // buramnya ikut memudar dan tidak hilang mendadak.
    _kabut.remove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _kabut.remove(route)?.bersihkan();
    untuk(previousRoute)?.hapus(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute == null) return;
    _kabut.remove(oldRoute)?.bersihkan();
    for (final k in _kabut.values) {
      k.hapus(oldRoute);
    }
  }

  /// Dipakai pengujian: melupakan semuanya.
  @visibleForTesting
  void lupakan() {
    for (final k in _kabut.values) {
      k.bersihkan();
    }
    _kabut.clear();
  }
}

/// Apa saja yang sedang menutupi satu rute, dan seberapa jauh.
class Kabut extends ChangeNotifier {
  final List<_Penutup> _penutup = [];

  void tambah(Route<dynamic> rute, Animation<double> animasi, TingkatKaca t) {
    final p = _Penutup(rute, animasi, t);
    _penutup.add(p);
    animasi.addListener(notifyListeners);
    animasi.addStatusListener(p.pantau);
    p.selesai = () {
      animasi.removeListener(notifyListeners);
      animasi.removeStatusListener(p.pantau);
      _penutup.remove(p);
      notifyListeners();
    };
    notifyListeners();
  }

  void hapus(Route<dynamic> rute) {
    for (final p in [..._penutup]) {
      if (p.rute == rute) p.selesai?.call();
    }
  }

  void bersihkan() {
    for (final p in [..._penutup]) {
      p.selesai?.call();
    }
  }

  /// Simpangan baku buram untuk isi rute ini, mengikuti penutup yang
  /// paling tebal. Nol berarti tidak ada yang menutupinya.
  double sigma() {
    var s = 0.0;
    for (final p in _penutup) {
      s = math.max(s, GayaKaca.sigma(p.tingkat) * p.animasi.value.clamp(0, 1));
    }
    return s;
  }
}

class _Penutup {
  _Penutup(this.rute, this.animasi, this.tingkat);

  final Route<dynamic> rute;
  final Animation<double> animasi;
  final TingkatKaca tingkat;
  void Function()? selesai;

  void pantau(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) selesai?.call();
  }
}

/// Isi sebuah rute yang ikut memburam saat ada yang menutupinya.
///
/// Buramnya dinaikkan pelan mengikuti animasi penutupnya, bukan disilangkan
/// dengan salinan buram dirinya sendiri: yang kedua meninggalkan bayangan
/// ganda selama peralihan.
class LapisanKaca extends StatefulWidget {
  const LapisanKaca({super.key, required this.child});

  final Widget child;

  @override
  State<LapisanKaca> createState() => _LapisanKacaState();
}

class _LapisanKacaState extends State<LapisanKaca> {
  static final _diam = ValueNotifier<int>(0);
  Kabut? _kabut;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _kabut = PengamatKaca.instance.untuk(ModalRoute.of(context));
  }

  @override
  Widget build(BuildContext context) {
    final kaca = context.kaca;

    return ListenableBuilder(
      listenable: kaca == null ? _diam : (_kabut ?? _diam),
      builder: (context, child) => KabutKaca(
        sigma: kaca == null ? 0 : (_kabut?.sigma() ?? 0),
        child: child!,
      ),
      child: widget.child,
    );
  }
}

/// Isi yang sedang diburamkan sebanyak [sigma]. Nol berarti jernih, dan
/// saat itu tidak ada lapisan gambar yang dibuat sama sekali.
///
/// Berdiri sendiri supaya pengujian bisa membaca tebalnya langsung;
/// ImageFilter tidak membuka lagi angka yang dipakainya.
class KabutKaca extends StatelessWidget {
  const KabutKaca({super.key, required this.sigma, required this.child});

  final double sigma;
  final Widget child;

  @override
  Widget build(BuildContext context) => ImageFiltered(
    enabled: sigma > 0.05,
    imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
    child: child,
  );
}

/// Peralihan halaman bawaan, ditambah dua hal yang dibutuhkan kaca: latar
/// kaca di dalam tiap halaman, dan buram saat ada yang menutupinya.
///
/// Peralihannya sendiri tidak diubah sedikit pun -- yang dibungkus hanya
/// isinya.
class TransisiKaca extends PageTransitionsBuilder {
  const TransisiKaca(this.dasar);

  final PageTransitionsBuilder dasar;

  @override
  Duration get transitionDuration => dasar.transitionDuration;

  @override
  Duration get reverseTransitionDuration => dasar.reverseTransitionDuration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      dasar.delegatedTransition;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => dasar.buildTransitions(
    route,
    context,
    animation,
    secondaryAnimation,
    LapisanKaca(child: LatarKaca(child: child)),
  );
}
