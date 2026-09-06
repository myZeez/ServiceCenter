// Pencarian nota dari formulir klaim, dan tebakan brandnya.
//
// Keduanya keluaran murni dari satu daftar, jadi bisa diuji tanpa server
// sama sekali -- dan memang di sinilah aturannya harus dikunci, bukan di
// widget yang memakainya.

import 'package:flutter_test/flutter_test.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/features/claims/cari_nota.dart';

ServiceOrderEntry _n(
  String id, {
  required String nama,
  String noNota = 'SVR-01092628001',
  String barang = 'Laptop Asus',
  String? type,
  String? sn,
  String? telp,
  String status = 'dikerjakan',
  String? claimId,
  DateTime? masuk,
}) => ServiceOrderEntry(
  id: id,
  noNota: noNota,
  tanggalMasuk: masuk ?? DateTime(2026, 9, 1),
  customerNama: nama,
  customerTelp: telp,
  barangNama: barang,
  barangType: type,
  barangSn: sn,
  claimId: claimId,
  garansi: claimId != null,
  status: status,
  updatedAt: DateTime(2026, 9, 1),
);

void main() {
  group('Mencari nota untuk diklaimkan', () {
    test('kosong selama belum ada yang diketik', () {
      final semua = [_n('1', nama: 'Udin')];
      expect(cariNota(semua, ''), isEmpty);
      expect(cariNota(semua, '   '), isEmpty);
    });

    test('nama dicocokkan sepotong, tanpa peduli huruf besar kecil', () {
      final semua = [_n('1', nama: 'UDIN SAPUTRA'), _n('2', nama: 'Rahmat')];

      expect(cariNota(semua, 'udin').single.id, '1');
      expect(cariNota(semua, 'SAPUT').single.id, '1');
    });

    test('nomor nota, nomor seri, unit dan telepon ikut dicari', () {
      // Teknisi mencari dengan apa pun yang ada di tangannya. Kalau yang
      // terbaca cuma stiker SN, nama pelanggannya justru yang tidak ia
      // ketahui.
      final semua = [
        _n('1', nama: 'Udin', noNota: 'SVR-04092628168', sn: 'X1Y2Z3'),
        _n('2', nama: 'Rahmat', telp: '081255500011', type: 'X441BA'),
      ];

      expect(cariNota(semua, '28168').single.id, '1');
      expect(cariNota(semua, 'x1y2').single.id, '1');
      expect(cariNota(semua, '555000').single.id, '2');
      expect(cariNota(semua, 'x441').single.id, '2');
    });

    test('nota yang klaimnya sudah ada tidak ditawarkan lagi', () {
      // Satu nota yang menunjuk dua klaim membuat sinkronisasi status di
      // server tarik-menarik, dan yang kalah adalah unit yang statusnya
      // berubah sendiri tanpa ada yang menyentuhnya.
      final semua = [
        _n('1', nama: 'Udin'),
        _n('2', nama: 'Udin', claimId: 'klaim-lama'),
      ];

      expect(cariNota(semua, 'udin').map((n) => n.id), ['1']);
    });

    test('yang batal tetap muncul, tidak disembunyikan', () {
      // Menyembunyikannya hanya memindahkan kebingungan: yang mencari
      // tahu notanya ada, tidak menemukannya, dan tidak pernah diberi
      // tahu kenapa. Statusnya ditampilkan di daftar pilihan.
      final semua = [_n('1', nama: 'Udin', status: 'batal')];
      expect(cariNota(semua, 'udin').single.id, '1');
    });

    test('yang terbaru di atas', () {
      final semua = [
        _n('lama', nama: 'Udin', masuk: DateTime(2026, 7, 1)),
        _n('baru', nama: 'Udin', masuk: DateTime(2026, 9, 4)),
        _n('tengah', nama: 'Udin', masuk: DateTime(2026, 8, 2)),
      ];

      expect(cariNota(semua, 'udin').map((n) => n.id), [
        'baru',
        'tengah',
        'lama',
      ]);
    });

    test('daftarnya dibatasi, karena muat di layar HP', () {
      final semua = [
        for (var i = 0; i < 30; i++)
          _n('$i', nama: 'Udin', masuk: DateTime(2026, 9, 1)),
      ];

      expect(cariNota(semua, 'udin').length, 8);
      expect(cariNota(semua, 'udin', batas: 3).length, 3);
    });
  });

  group('Menebak brand dari sebutan unit di nota', () {
    const brands = [
      Brand(id: 1, nama: 'ASUS'),
      Brand(id: 2, nama: 'HP'),
      Brand(id: 3, nama: 'LENOVO'),
    ];

    test('menemukan yang disebut, apa pun huruf besar kecilnya', () {
      expect(tebakBrand(brands, 'Laptop Asus X441BA')?.id, 1);
      expect(tebakBrand(brands, 'LENOVO IDEAPAD')?.id, 3);
    });

    test('sebagai kata utuh, bukan potongan di tengah kata', () {
      // Tanpa aturan ini "HP" tercocokkan di dalam "SHARP", dan klaimnya
      // berangkat ke brand yang keliru.
      expect(tebakBrand(brands, 'MONITOR SHARP 24'), isNull);
      expect(tebakBrand(brands, 'Laptop Hp 14')?.id, 2);
    });

    test('menyerah kalau cocoknya lebih dari satu', () {
      // Bawaan yang salah lebih buruk daripada kolom kosong: kolom kosong
      // menuntut dipilih, tebakan yang salah tampak sudah benar.
      expect(tebakBrand(brands, 'ASUS TUKAR TAMBAH LENOVO'), isNull);
    });

    test('tidak menebak apa-apa dari unit yang tidak dikenali', () {
      expect(tebakBrand(brands, 'Laptop Axioo Mybook'), isNull);
      expect(tebakBrand(brands, ''), isNull);
    });
  });
}
