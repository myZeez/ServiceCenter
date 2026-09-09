import 'package:flutter_test/flutter_test.dart';
import 'package:sc_management/core/nota/nomor_nota.dart';

void main() {
  final hari = DateTime(2026, 9, 4);

  group('Contoh nomor nota', () {
    test('angka urut selalu 5 digit', () {
      expect(contohNomorNota(1, hari), 'SRV-04092600001');
      expect(contohNomorNota(28177, hari), 'SRV-04092628177');
    });

    test('lima digit terakhir adalah angka urutnya sendiri', () {
      for (final n in [1, 42, 999, 28177, 99999]) {
        final nomor = contohNomorNota(n, hari);
        expect(int.parse(nomor.substring(nomor.length - 5)), n);
      }
    });

    test('tanggal ditulis ddMMyy dengan nol di depan', () {
      expect(contohNomorNota(1, DateTime(2026, 1, 7)), 'SRV-07012600001');
    });

    test('angka di atas 99999 dibiarkan tumbuh, bukan dipotong', () {
      // Nomor kepanjangan masih bisa dibaca orang; nomor yang terpotong
      // diam-diam berubah arti.
      expect(contohNomorNota(123456, hari), 'SRV-040926123456');
    });
  });

  _urutan();
}

// =====================================================================
// Urutan nomor nota
//
// Laporan toko dibaca dari kolom pertama: nomor nota, menaik, seperti
// buku. Sebelum ini urutannya dihitung dengan membandingkan seluruh
// teksnya, dan itu salah pada data yang sungguhan -- kedua kesalahannya
// ada di bawah, masing-masing dengan datanya sendiri.
// =====================================================================

void _urutan() {
  group('Urutan nomor nota', () {
    test('yang dibandingkan angka urutnya, bukan tanggalnya', () {
      // Tanggalnya ditulis DDMMYY. Dibandingkan sebagai teks, 30
      // September berdiri sebelum 1 Oktober karena "30" mendahului "01",
      // dan laporan bulanan pun pecah di pergantian bulan.
      final daftar = ['SRV-01102628300', 'SRV-30092628299']..sort(
        bandingNomorNota,
      );
      expect(daftar, ['SRV-30092628299', 'SRV-01102628300']);
    });

    test('awalan SVR- dan SRV- berbaris menurut nomornya', () {
      // 3.009 nota lama dari buku toko memakai SVR-, yang diterbitkan
      // aplikasi memakai SRV-. Sebagai teks, 'R' mendahului 'V', jadi
      // seluruh nota buatan aplikasi berbaris duluan berapa pun nomornya
      // -- persis yang terlihat di laporan: 265, 264, ... lalu 275.
      final daftar = [
        'SRV-09092628265',
        'SVR-08092628271',
        'SRV-08092628249',
        'SVR-07092628259',
      ]..sort(bandingNomorNota);

      expect(daftar, [
        'SRV-08092628249',
        'SVR-07092628259',
        'SRV-09092628265',
        'SVR-08092628271',
      ]);
    });

    test('angka urut dibaca sesudah enam angka tanggalnya', () {
      expect(urutanNota('SRV-09092628265'), 28265);
      expect(urutanNota('SVR-08082523402'), 23402);
      expect(urutanNota('SRV-040926123456'), 123456);
    });

    test('nomor yang bentuknya tidak dikenal ditaruh di belakang', () {
      expect(urutanNota('tanpa-angka'), isNull);
      expect(urutanNota('SRV-0909'), isNull);

      final daftar = ['ENTAH', 'SRV-09092628265', 'AAA']..sort(
        bandingNomorNota,
      );
      expect(daftar.first, 'SRV-09092628265');
      // Di belakang pun urutannya tetap ditentukan, bukan dibiarkan acak.
      expect(daftar, ['SRV-09092628265', 'AAA', 'ENTAH']);
    });

    test('nomor kembar tetap berurutan sama setiap kali', () {
      // Ada beberapa, sisa dari saat penghitung aplikasi tertinggal dari
      // buku. Urutan yang berubah-ubah membuat dua cetakan laporan yang
      // sama tampak berbeda.
      final a = ['SVR-08092628248', 'SRV-08092628248']..sort(bandingNomorNota);
      final b = ['SRV-08092628248', 'SVR-08092628248']..sort(bandingNomorNota);
      expect(a, b);
    });
  });
}
