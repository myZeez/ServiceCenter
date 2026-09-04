// Penulisan yang diterima server tetapi tidak menyentuh satu baris pun.
//
// Ada karena kasusnya terjadi: teknisi diganti dari Android, aplikasi
// bilang "Teknisi diganti", dan di laptop tidak berubah apa pun. Postgres
// menganggap UPDATE yang tidak cocok dengan satu baris pun sebagai
// berhasil -- tidak ada galat, tidak ada apa-apa.

import 'package:flutter_test/flutter_test.dart';
import 'package:sc_management/core/data/db.dart';
import 'package:sc_management/core/data/galat.dart';

void main() {
  test('gagal tulis dijelaskan, bukan disebut sebagai berhasil', () {
    final pesan = pesanGalat(const GagalTulis('klaim'));

    expect(pesan, contains('tidak tersimpan'));
    expect(pesan, contains('klaim'));
    // Harus menyebut langkah yang bisa dicoba orangnya sendiri.
    expect(pesan.toLowerCase(), contains('masuk lagi'));
  });

  test('menyebut apa yang gagal, supaya pesannya bisa dilacak', () {
    expect(pesanGalat(const GagalTulis('part')), contains('part'));
  });
}
