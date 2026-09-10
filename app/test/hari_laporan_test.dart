// Nota keluar ditutup jam 17.00; nota masuk memakai hari kalender.
//
// Aturannya sepele dibaca dan mudah salah dipasang: satu tanda lebih-dari
// yang keliru menggeser seluruh laporan sehari penuh, dan yang menemukannya
// adalah pusat, bukan yang membuatnya. Memasangnya di sisi yang salah sama
// mahalnya -- nota masuk sempat ikut digeser, dan unit yang diterima jam
// 19.45 lenyap dari halaman hari itu.

import 'package:flutter_test/flutter_test.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/hari_laporan.dart';
import 'package:sc_management/features/service/service_view.dart';
import 'package:sc_management/features/service/waktu_masuk.dart';

ServiceOrderEntry _nota(DateTime masuk, {String id = 'n'}) => ServiceOrderEntry(
  id: id,
  noNota: id,
  tanggalMasuk: masuk,
  customerNama: 'Udin',
  barangNama: 'Laptop Asus',
  status: 'masuk',
  updatedAt: masuk,
);

void main() {
  group('Hari kerja', () {
    test('sebelum jam tutup, harinya hari itu juga', () {
      expect(hariLaporan(DateTime(2026, 9, 6, 16, 59)), DateTime(2026, 9, 6));
      expect(hariLaporan(DateTime(2026, 9, 6, 8, 0)), DateTime(2026, 9, 6));
    });

    test('tepat jam tutup sudah masuk besok', () {
      // Laporannya ditutup PADA jam itu, jadi nota jam 17.00 tidak lagi
      // sempat ikut. Batas yang meleset satu menit di sini akan terlihat
      // sebagai satu nota yang selalu jatuh di laporan yang salah.
      expect(hariLaporan(DateTime(2026, 9, 6, 17, 0)), DateTime(2026, 9, 7));
    });

    test('sesudah jam tutup masuk besok', () {
      expect(hariLaporan(DateTime(2026, 9, 6, 21, 30)), DateTime(2026, 9, 7));
      // Termasuk yang lewat tengah malam: jam 00.30 tanggal 7 tetap
      // laporan tanggal 7, bukan 8.
      expect(hariLaporan(DateTime(2026, 9, 7, 0, 30)), DateTime(2026, 9, 7));
    });

    test('menyeberangi akhir bulan dan akhir tahun', () {
      expect(hariLaporan(DateTime(2026, 9, 30, 18, 0)), DateTime(2026, 10, 1));
      expect(hariLaporan(DateTime(2026, 12, 31, 18, 0)), DateTime(2027, 1, 1));
    });

    test('jam tutup 24 berarti hari kalender biasa', () {
      // Jalan keluar kalau tokonya berhenti memakai aturan ini.
      expect(
        hariLaporan(DateTime(2026, 9, 6, 23, 59), 24),
        DateTime(2026, 9, 6),
      );
    });

    test('jam tutup lain ikut berlaku', () {
      expect(
        hariLaporan(DateTime(2026, 9, 6, 15, 0), 14),
        DateTime(2026, 9, 7),
      );
      expect(
        hariLaporan(DateTime(2026, 9, 6, 13, 0), 14),
        DateTime(2026, 9, 6),
      );
    });

    test('membandingkan saat dengan sebuah hari kerja', () {
      // Harinya dibandingkan apa adanya: ia sudah hari kerja, bukan saat
      // yang perlu digeser sekali lagi.
      expect(
        hariLaporanSama(DateTime(2026, 9, 6, 18, 0), DateTime(2026, 9, 7)),
        isTrue,
      );
      expect(
        hariLaporanSama(DateTime(2026, 9, 6, 18, 0), DateTime(2026, 9, 6)),
        isFalse,
      );
    });
  });

  group('Tanggal beserta jamnya', () {
    test('ditulis 24 jam, dengan nol di depan', () {
      // Jam 9 pagi yang tercetak "9:05" berdampingan dengan "18:30" akan
      // membuat kolomnya bergerigi, dan jam 12 malam tanpa penanda AM/PM
      // hanya jelas kalau formatnya memang 24 jam.
      expect(tanggalJamMasuk(DateTime(2026, 9, 6, 9, 5)), '06/09/26 09:05');
      expect(tanggalJamMasuk(DateTime(2026, 9, 6, 18, 30)), '06/09/26 18:30');
      expect(tanggalJamMasuk(DateTime(2026, 9, 6, 0, 0)), '06/09/26 00:00');
    });
  });

  group('Halaman Servis memakai hari kalender', () {
    final sore = _nota(DateTime(2026, 9, 6, 9, 0), id: 'pagi');
    final malam = _nota(DateTime(2026, 9, 6, 19, 30), id: 'malam');
    final akhir = _nota(DateTime(2026, 9, 6, 23, 59), id: 'akhir');
    final lewat = _nota(DateTime(2026, 9, 7, 0, 0), id: 'lewat');

    test('nota malam tetap di hari diterimanya', () {
      // Jam tutup 17.00 milik nota keluar. Unit yang diterima jam 19.30
      // diterima hari itu juga, dan halaman yang menyembunyikannya sampai
      // besok membuat nota yang baru diketik seolah hilang.
      expect(
        saringNota([
          sore,
          malam,
          akhir,
          lewat,
        ], hari: DateTime(2026, 9, 6)).map((n) => n.id),
        ['pagi', 'malam', 'akhir'],
      );
    });

    test('batasnya tengah malam, bukan semenit sebelumnya', () {
      expect(
        saringNota([
          sore,
          malam,
          akhir,
          lewat,
        ], hari: DateTime(2026, 9, 7)).map((n) => n.id),
        ['lewat'],
      );
    });

    test('pencarian tetap membuka seluruh arsip, tanpa peduli harinya', () {
      // Yang mengetik "udin" mencari notanya, bukan notanya hari ini.
      expect(
        saringNota(
          [sore, malam],
          hari: DateTime(2026, 1, 1),
          query: 'udin',
        ).length,
        2,
      );
    });
  });
}
