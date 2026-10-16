// Urutan laporan harian: berbiaya, piutang, garansi, cancel.
//
// Aturan dari pemilik toko. Yang dijaga: setiap nota masuk kelompok yang
// benar (termasuk kasus perbatasan), urutan di dalam kelompok tetap menurut
// nomor nota, dan layar serta Excel memakai urutan yang sama.

import 'package:excel/excel.dart' show TextCellValue;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/export/excel_export.dart';
import 'package:sc_management/core/nota/urutan_harian.dart';
import 'package:sc_management/core/providers.dart' show serviceOrdersProvider;
import 'package:sc_management/core/theme.dart';
import 'package:sc_management/features/service/service_reports_view.dart';

final _hari = DateTime(2026, 9, 8);

ServiceOrderEntry _nota(
  String no, {
  double biaya = 0,
  DateTime? lunas,
  bool garansi = false,
  String status = 'diambil',
  String nama = 'Pelanggan',
}) => ServiceOrderEntry(
  id: no,
  noNota: no,
  tanggalMasuk: DateTime(2026, 9, 1),
  customerNama: nama,
  barangNama: 'Laptop',
  garansi: garansi,
  status: status,
  biaya: biaya,
  tanggalLunas: lunas,
  tanggalSelesai: _hari,
  tanggalDiambil: _hari,
  updatedAt: DateTime(2026, 9, 8),
);

void main() {
  setUpAll(() => initializeDateFormatting('id', null));

  group('Kelompok', () {
    test('servis berbayar yang sudah lunas', () {
      expect(
        kelompokHarian(_nota('SVR-1', biaya: 150000, lunas: _hari)),
        KelompokHarian.berbiaya,
      );
    });

    test('ada tagihan tetapi belum lunas adalah piutang', () {
      expect(
        kelompokHarian(_nota('SVR-1', biaya: 150000)),
        KelompokHarian.piutang,
      );
    });

    test('unit garansi', () {
      expect(
        kelompokHarian(_nota('SVR-1', garansi: true)),
        KelompokHarian.garansi,
      );
    });

    test('nota batal', () {
      expect(
        kelompokHarian(_nota('SVR-1', status: 'batal')),
        KelompokHarian.cancel,
      );
    });

    test('batal mengalahkan garansi, dan garansi mengalahkan tagihan', () {
      // Batal tanpa biaya tetap Cancel walau notanya bergaransi.
      expect(
        kelompokHarian(_nota('SVR-1', status: 'batal', garansi: true)),
        KelompokHarian.cancel,
      );
      // Batal yang dikenai biaya mengikuti uangnya -- bergaransi atau tidak.
      expect(
        kelompokHarian(
          _nota('SVR-1', status: 'batal', garansi: true, biaya: 50000),
        ),
        KelompokHarian.piutang,
      );
      // Garansi yang dikenai biaya layanan tambahan tetap terbaca Garansi,
      // sama seperti di kolom keterangan.
      expect(
        kelompokHarian(_nota('SVR-1', garansi: true, biaya: 50000)),
        KelompokHarian.garansi,
      );
    });

    test('pembatalan tanpa biaya adalah Cancel', () {
      expect(
        kelompokHarian(_nota('SVR-1', status: 'batal', biaya: 0)),
        KelompokHarian.cancel,
      );
    });

    test('pembatalan berbiaya mengikuti uangnya, bukan katanya', () {
      // Biaya cek yang sudah dibayar adalah uang yang benar-benar masuk;
      // menaruhnya di Cancel menyembunyikannya di antara baris yang tidak
      // menghasilkan apa-apa.
      expect(
        kelompokHarian(
          _nota('SVR-1', status: 'batal', biaya: 80000, lunas: _hari),
        ),
        KelompokHarian.berbiaya,
      );
      // Belum dibayar: tagihan, sama seperti servis biasa.
      expect(
        kelompokHarian(_nota('SVR-1', status: 'batal', biaya: 80000)),
        KelompokHarian.piutang,
      );
    });

    test('servis biasa tanpa tagihan ikut kelompok pertama', () {
      expect(kelompokHarian(_nota('SVR-1')), KelompokHarian.berbiaya);
    });
  });

  group('Urutan', () {
    final campur = [
      _nota('SVR-08092628305', status: 'batal'),
      _nota('SVR-08092628301', garansi: true),
      _nota('SVR-08092628304', biaya: 90000), // piutang
      _nota('SVR-08092628303', biaya: 200000, lunas: _hari),
      _nota('SVR-08092628300', status: 'batal', garansi: true),
      _nota('SVR-08092628302', biaya: 100000, lunas: _hari),
      _nota('SVR-08092628299', garansi: true),
      _nota('SVR-08092628306', biaya: 50000), // piutang
      // Batal berbiaya yang sudah dibayar: kelompok berbiaya, bukan Cancel.
      _nota('SVR-08092628307', status: 'batal', biaya: 30000, lunas: _hari),
    ];

    test('berbiaya, piutang, garansi, cancel', () {
      final urut = [...campur]..sort(bandingHarian);
      expect(urut.map((n) => n.noNota.substring(12)), [
        '302', '303', '307', // berbiaya (307: batal yang dikenai biaya)
        '304', '306', // piutang
        '299', '301', // garansi
        '300', '305', // cancel
      ]);
    });

    test('di dalam kelompok tetap menurut nomor nota, bukan teks', () {
      // 30 September mendahului 1 Oktober kalau dibandingkan sebagai teks.
      final urut = [
        _nota('SVR-01102628300', biaya: 10000, lunas: _hari),
        _nota('SVR-30092628299', biaya: 10000, lunas: _hari),
      ]..sort(bandingHarian);
      expect(urut.map((n) => n.noNota), ['SVR-30092628299', 'SVR-01102628300']);
    });
  });

  group('Excel', () {
    test('tabel nota keluar memakai urutan kelompok', () {
      final campur = [
        _nota('SVR-08092628301', garansi: true, nama: 'C'),
        _nota('SVR-08092628304', biaya: 90000, nama: 'B'),
        _nota('SVR-08092628303', biaya: 200000, lunas: _hari, nama: 'A'),
      ];
      final lembar = ExcelExport.lembarHarian(semua: campur, tanggal: _hari);
      final nama = lembar.tabel.first.baris
          .map((r) => (r.first as TextCellValue).value.text)
          .toList();

      expect(nama, ['A', 'B', 'C']);
    });
    test('tabel nota keluar memuat unit yang sudah keluar', () {
      final lembar = ExcelExport.lembarHarian(
        semua: [
          _nota('SVR-DIAMBIL', nama: 'Diambil'),
          _nota('SVR-SELESAI', status: 'selesai', nama: 'Selesai'),
          _nota('SVR-BATAL', status: 'batal', nama: 'Batal'),
          _nota('SVR-DIKERJAKAN', status: 'dikerjakan', nama: 'Dikerjakan'),
        ],
        tanggal: _hari,
      );
      final nama = lembar.tabel.first.baris
          .map((r) => (r.first as TextCellValue).value.text)
          .toList();

      expect(nama, ['Diambil', 'Batal']);
    });
  });

  group('Layar', () {
    testWidgets('nota keluar tampil dalam urutan yang sama', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final campur = [
        _nota('SVR-08092628301', garansi: true, nama: 'Cici'),
        _nota('SVR-08092628304', biaya: 90000, nama: 'Beni'),
        _nota('SVR-08092628303', biaya: 200000, lunas: _hari, nama: 'Andi'),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serviceOrdersProvider.overrideWith((ref) => Stream.value(campur)),
            tanggalHarianProvider.overrideWith((ref) => _hari),
          ],
          child: MaterialApp(
            theme: AppTheme.terang(),
            home: const Scaffold(body: ServiceReportsView()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      double y(String nama) => tester.getTopLeft(find.text(nama).first).dy;
      expect(y('Andi'), lessThan(y('Beni')));
      expect(y('Beni'), lessThan(y('Cici')));
    });
  });
}
