import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// Pengaturan yang melekat pada perangkat, bukan pada data toko.
///
/// Dua hal tinggal di sini: printer dan susunan kartu di layar. Keduanya
/// sengaja tidak ikut ke server. Printer di meja depan berbeda dengan yang
/// di ruang teknisi, dan susunan kartu itu selera menata layar yang berbeda
/// tiap orang serta tiap ukuran monitor -- memaksanya sama di semua
/// perangkat hanya akan mengganggu.
///
/// Dulu ini menumpang di tabel `sync_meta` pada cerminan SQLite. Cerminannya
/// sudah dibuang, tetapi kebutuhannya tidak: yang seperti ini memang tidak
/// punya tempat di database bersama.
class Prefs {
  Prefs(this._p);

  final SharedPreferences _p;

  static Future<Prefs> buka() async =>
      Prefs(await SharedPreferences.getInstance());

  /// Perubahan disiarkan sendiri karena SharedPreferences tidak punya
  /// pemberitahuan bawaan; tanpa ini, layar yang menampilkan nilainya tidak
  /// tahu kapan harus menggambar ulang.
  final _perubahan = StreamController<String>.broadcast();

  String? baca(String kunci) => _p.getString(kunci);

  Future<void> tulis(String kunci, String nilai) async {
    await _p.setString(kunci, nilai);
    _perubahan.add(kunci);
  }

  /// Nilai sekarang, lalu tiap kali kunci itu berubah.
  Stream<String?> watch(String kunci) async* {
    yield baca(kunci);
    yield* _perubahan.stream.where((k) => k == kunci).map((_) => baca(kunci));
  }

  void dispose() => _perubahan.close();
}
