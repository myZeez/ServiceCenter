// Hitungan uang penjualan part.
//
// Diuji lebih dulu dan lebih rapat daripada bagian mana pun di fitur ini:
// harga yang meleset sedikit tidak pernah terlihat di layar, dan baru
// ketahuan saat kas bulanan tidak cocok.

import 'package:flutter_test/flutter_test.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/features/parts/hitung_harga.dart';

PartOrder _pesanan({double? harga, double dp = 0, double sisa = 0}) =>
    PartOrder(
      id: 'p1',
      tanggal: DateTime(2026, 9, 5),
      customerNama: 'Jamal',
      partReq: 'KEYBOARD',
      tahap: 'dipesan',
      harga: harga,
      dp: dp,
      sisa: sisa,
      updatedAt: DateTime(2026, 9, 5),
    );

void main() {
  group('harga jual', () {
    test('persentase dihitung di atas modal, bukan dipotong dari harga', () {
      // Contoh yang dipakai pemilik toko sendiri: modal 100rb, ambil 20%.
      expect(hargaJual(100000, 20), 120000);
      expect(hargaJual(100000, 10), 110000);
    });

    test('up nol berarti dijual sama dengan modalnya', () {
      expect(hargaJual(85000, 0), 85000);
    });

    test('pecahan tidak dibulatkan diam-diam', () {
      expect(hargaJual(137000, 10), closeTo(150700, 0.001));
    });
  });

  group('membaca persentase mundur dari harga', () {
    test('mengembalikan angka yang sama dengan yang dipakai menghitung', () {
      expect(upPersenDari(100000, 120000), closeTo(20, 0.0001));
    });

    test('harga yang dibulatkan menghasilkan persentase yang sedikit lain', () {
      // Inilah gunanya angka ini diperlihatkan: sesudah dibulatkan ke atas,
      // yang tercatat bukan lagi 10% persis, dan layar harus jujur soal itu.
      expect(upPersenDari(137000, 151000), closeTo(10.219, 0.001));
    });

    test('modal nol tidak punya persentase', () {
      expect(upPersenDari(0, 50000), isNull);
      expect(upPersenDari(-1, 50000), isNull);
    });
  });

  test('margin adalah selisih harga dan modal', () {
    expect(margin(100000, 120000), 20000);
    // Dijual di bawah modal tetap dilaporkan apa adanya, bukan dipangkas
    // jadi nol: jualan rugi yang disembunyikan tidak akan pernah dibetulkan.
    expect(margin(100000, 90000), -10000);
  });

  test('sisa tagihan memakai rumus yang sama dengan kolom di Postgres', () {
    expect(sisaTagihan(120000, 50000), 70000);
    expect(sisaTagihan(120000, 120000), 0);
  });

  group('ringkasan sekumpulan pesanan', () {
    test('menjumlahkan harga, DP, dan sisa', () {
      final r = ringkasPesanan([
        _pesanan(harga: 120000, dp: 50000, sisa: 70000),
        _pesanan(harga: 80000, dp: 80000, sisa: 0),
      ]);

      expect(r.jumlah, 2);
      expect(r.harga, 200000);
      expect(r.dp, 130000);
      expect(r.sisa, 70000);
    });

    test(
      'pesanan yang harganya belum ada dihitung sebagai nol, bukan galat',
      () {
        final r = ringkasPesanan([_pesanan(), _pesanan(harga: 50000)]);

        expect(r.jumlah, 2);
        expect(r.harga, 50000);
        expect(r.sisa, 0);
      },
    );

    test('daftar kosong menghasilkan nol, bukan galat', () {
      final r = ringkasPesanan(const []);
      expect(r.jumlah, 0);
      expect(r.harga, 0);
      expect(r.sisa, 0);
    });
  });
}
