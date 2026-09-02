/// Penyusun perintah ESC/POS.
///
/// Sengaja hanya memakai perintah teks dasar yang didukung hampir semua
/// mekanisme Epson, termasuk yang impact seperti M-188D. Tidak ada gambar,
/// tidak ada logo raster: keduanya membuat printer impact bekerja berpuluh
/// detik untuk satu nota.
library;

import 'dart:convert';

enum Rata { kiri, tengah, kanan }

class EscPos {
  EscPos({this.lebar = 32});

  /// Jumlah karakter per baris. Kertas 57,5mm pada M-188D memuat sekitar 32
  /// karakter di font standar; angka pastinya bergantung font yang aktif di
  /// printer, karena itu bisa diatur dari Pengaturan dan dipastikan lewat
  /// cetak percobaan.
  final int lebar;

  final List<int> _buf = [];

  List<int> selesai() => List.unmodifiable(_buf);

  // --- perintah dasar --------------------------------------------------

  EscPos mulai() {
    _buf.addAll([0x1B, 0x40]); // ESC @ : kembalikan ke setelan awal
    return this;
  }

  EscPos rata(Rata r) {
    _buf.addAll([0x1B, 0x61, r.index]);
    return this;
  }

  EscPos tebal(bool aktif) {
    _buf.addAll([0x1B, 0x45, aktif ? 1 : 0]);
    return this;
  }

  EscPos besar(bool aktif) {
    // ESC ! dengan bit tinggi+lebar ganda.
    _buf.addAll([0x1B, 0x21, aktif ? 0x30 : 0x00]);
    return this;
  }

  EscPos baris([String teks = '']) {
    _buf.addAll(_sandi(teks));
    _buf.add(0x0A);
    return this;
  }

  EscPos kosong([int jumlah = 1]) {
    for (var i = 0; i < jumlah; i++) {
      _buf.add(0x0A);
    }
    return this;
  }

  EscPos garis([String karakter = '-']) => baris(karakter * lebar);

  EscPos potong() {
    // Banyak mekanisme impact tidak punya pemotong; perintah ini diabaikan
    // dengan aman oleh yang tidak mendukungnya.
    _buf.addAll([0x1D, 0x56, 0x01]);
    return this;
  }

  // --- tata letak ------------------------------------------------------

  /// Label di kiri, nilai di kanan, dipisah titik-titik bila muat.
  EscPos pasangan(String label, String nilai) {
    final sisa = lebar - label.length - nilai.length;
    if (sisa >= 1) return baris('$label${' ' * sisa}$nilai');

    // Tidak muat satu baris: nilai turun ke bawah, menjorok ke kanan.
    baris(label);
    return baris(nilai.padLeft(lebar));
  }

  /// Judul kolom kiri lalu isinya, dipakai untuk kolom yang isinya panjang.
  EscPos kolom(String label, String? isi) {
    if (isi == null || isi.trim().isEmpty) return this;
    final awalan = '$label: ';
    for (final b in _bungkus(awalan + isi.trim(), lebar)) {
      baris(b);
    }
    return this;
  }

  EscPos tengah(String teks, {bool tebalkan = false, bool besarkan = false}) {
    rata(Rata.tengah);
    if (tebalkan) tebal(true);
    if (besarkan) besar(true);
    for (final b in _bungkus(teks, besarkan ? lebar ~/ 2 : lebar)) {
      baris(b);
    }
    if (besarkan) besar(false);
    if (tebalkan) tebal(false);
    return rata(Rata.kiri);
  }

  /// Memecah teks panjang menjadi beberapa baris tanpa memotong kata.
  static List<String> _bungkus(String teks, int lebar) {
    final hasil = <String>[];
    var sekarang = '';

    for (final kata in teks.split(RegExp(r'\s+'))) {
      if (kata.isEmpty) continue;

      if (sekarang.isEmpty) {
        sekarang = kata;
      } else if (sekarang.length + 1 + kata.length <= lebar) {
        sekarang = '$sekarang $kata';
      } else {
        hasil.add(sekarang);
        sekarang = kata;
      }

      // Kata tunggal yang lebih panjang dari satu baris -- misalnya nomor
      // seri -- dipotong paksa, kalau tidak akan hilang di tepi kertas.
      while (sekarang.length > lebar) {
        hasil.add(sekarang.substring(0, lebar));
        sekarang = sekarang.substring(lebar);
      }
    }

    if (sekarang.isNotEmpty) hasil.add(sekarang);
    return hasil.isEmpty ? [''] : hasil;
  }

  /// Printer nota memakai tabel karakter satu byte. Karakter di luar itu
  /// diganti agar tidak keluar sebagai simbol acak.
  static List<int> _sandi(String teks) {
    final bersih = teks
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('·', '.')
        .replaceAll('×', 'x')
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '');
    return latin1.encode(bersih);
  }
}
