// Laporan mingguan memakai rumus tab Harian dan tab Omset.
//
// Dua angka untuk hal yang sama di dua tab adalah cara tercepat membuat
// laporan tidak dipercaya, jadi yang diuji di sini terutama batasnya: minggu
// berjalan Senin sampai Minggu, dan nota batal keluar tanpa menambah omset.

import 'package:flutter_test/flutter_test.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/export/excel_export.dart';
import 'package:sc_management/core/omset/laporan_mingguan.dart';

const _aturan = ServiceSettingsRow(
  id: 1,
  targetOmset: 4000000,
  feeAdminPerNota: 0,
);

ServiceOrderEntry _nota(
  String id, {
  required DateTime masuk,
  String status = 'masuk',
  double biaya = 0,
  DateTime? selesai,
  DateTime? keluar,
  String? teknisi,
}) => ServiceOrderEntry(
  id: id,
  noNota: 'SVR-0109262$id',
  tanggalMasuk: masuk,
  customerNama: 'Pelanggan $id',
  barangNama: 'Laptop',
  teknisiId: teknisi,
  status: status,
  biaya: biaya,
  tanggalSelesai: selesai,
  tanggalDiambil: keluar,
  updatedAt: masuk,
);

void main() {
  final senin = DateTime(2026, 10, 26);

  group('seninDari', () {
    test('tiap hari dalam seminggu kembali ke Senin yang sama', () {
      for (var i = 0; i < 7; i++) {
        expect(seninDari(DateTime(2026, 10, 26 + i, 15, 30)), senin);
      }
    });

    test('Senin berikutnya sudah minggu baru', () {
      expect(seninDari(DateTime(2026, 11, 2)), DateTime(2026, 11, 2));
    });

    test('minggu yang melewati pergantian bulan', () {
      expect(seninDari(DateTime(2026, 11, 1)), senin);
    });
  });

  group('hitungLaporanMingguan', () {
    test('selalu tujuh hari, Senin lebih dulu', () {
      final l = hitungLaporanMingguan(
        nota: const [],
        senin: senin,
        aturan: _aturan,
      );

      expect(l.hari.length, 7);
      expect(l.hari.first.tanggal, senin);
      expect(l.hari.last.tanggal, DateTime(2026, 11, 1));
      expect(l.masuk, 0);
      expect(l.keluar, 0);
      expect(l.omset.omsetToko, 0);
    });

    test('masuk dan keluar jatuh pada harinya masing-masing', () {
      final l = hitungLaporanMingguan(
        nota: [
          _nota('1', masuk: DateTime(2026, 10, 26, 9)),
          _nota(
            '2',
            masuk: DateTime(2026, 10, 20),
            status: 'diambil',
            biaya: 100000,
            selesai: DateTime(2026, 10, 27),
            keluar: DateTime(2026, 10, 28),
            teknisi: 't1',
          ),
        ],
        senin: senin,
        aturan: _aturan,
      );

      expect(l.hari[0].masuk, 1);
      expect(l.masuk, 1);
      expect(l.hari[1].omset, 100000);
      expect(l.hari[2].keluar, 1);
      expect(l.hari[2].nilaiKeluar, 100000);
      expect(l.omset.omsetToko, 100000);
      expect(l.omset.teknisi.single.teknisiId, 't1');
    });

    test('batal keluar dari toko tanpa menambah omset', () {
      final l = hitungLaporanMingguan(
        nota: [
          _nota(
            '1',
            masuk: DateTime(2026, 10, 20),
            status: 'batal',
            biaya: 50000,
            selesai: DateTime(2026, 10, 27),
            keluar: DateTime(2026, 10, 27),
          ),
        ],
        senin: senin,
        aturan: _aturan,
      );

      expect(l.keluar, 1);
      expect(l.omset.omsetToko, 0);
    });

    test('nota di luar minggu ini tidak ikut', () {
      final l = hitungLaporanMingguan(
        nota: [
          _nota(
            '1',
            masuk: DateTime(2026, 10, 25),
            status: 'diambil',
            biaya: 100000,
            selesai: DateTime(2026, 10, 25),
            keluar: DateTime(2026, 10, 25),
          ),
          _nota(
            '2',
            masuk: DateTime(2026, 11, 2),
            status: 'diambil',
            biaya: 100000,
            selesai: DateTime(2026, 11, 2),
            keluar: DateTime(2026, 11, 2),
          ),
        ],
        senin: senin,
        aturan: _aturan,
      );

      expect(l.masuk, 0);
      expect(l.keluar, 0);
      expect(l.omset.omsetToko, 0);
    });

    test('hari terakhir ikut dihitung sampai akhir harinya', () {
      final l = hitungLaporanMingguan(
        nota: [
          _nota(
            '1',
            masuk: DateTime(2026, 10, 30),
            status: 'selesai',
            biaya: 75000,
            selesai: DateTime(2026, 11, 1),
          ),
        ],
        senin: senin,
        aturan: _aturan,
      );

      expect(l.hari.last.omset, 75000);
      expect(l.omset.omsetToko, 75000);
    });

    test('total tujuh hari sama dengan total seminggu', () {
      final l = hitungLaporanMingguan(
        nota: [
          for (var i = 0; i < 7; i++)
            _nota(
              '$i',
              masuk: DateTime(2026, 10, 20),
              status: 'diambil',
              biaya: 10000.0 * (i + 1),
              selesai: DateTime(2026, 10, 26 + i),
              keluar: DateTime(2026, 10, 26 + i),
            ),
        ],
        senin: senin,
        aturan: _aturan,
      );

      expect(l.hari.fold<double>(0, (a, h) => a + h.omset), l.omset.omsetToko);
    });
  });

  test('ekspor satu tab per tanggal, hari libur tidak diterbitkan', () {
    final lembar = ExcelExport.lembarHarianMingguan(
      semua: const [],
      senin: senin,
      libur: const {DateTime.saturday},
    );

    expect(lembar.map((l) => l.nama), ['26', '27', '28', '29', '30', '1']);
  });
}
