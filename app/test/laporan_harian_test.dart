// Tab HARIAN pernah punya saudara yang gagal tampil sama sekali: tab OMSET
// sempat kosong karena sebuah Row diberi tinggi tak terbatas di dalam
// daftar bergulir. Galatnya tidak muncul di flutter analyze maupun di test
// perhitungan -- hanya terlihat kalau widget-nya benar-benar dilukis.
//
// Test ini melukis tab HARIAN pada ukuran jendela sungguhan dan gagal
// begitu ada satu saja galat tata letak.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:sc_management/core/export/excel_export.dart';
import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/theme.dart';
import 'package:sc_management/features/service/service_reports_view.dart';
import 'package:sc_management/core/providers.dart' show serviceOrdersProvider;

ServiceOrderEntry _nota({
  required String noNota,
  required DateTime masuk,
  DateTime? selesai,
  String nama = 'Budi',
  String status = 'selesai',
  double biaya = 150000,
  bool garansi = false,
  String? keterangan,
}) => ServiceOrderEntry(
  id: noNota,
  noNota: noNota,
  tanggalMasuk: masuk,
  customerNama: nama,
  customerTelp: '081234567890',
  barangNama: 'Oppo',
  barangType: 'A16',
  keluhan: 'Mati total',
  perbaikan: 'Ganti IC power',
  garansi: garansi,
  status: status,
  biaya: biaya,
  tanggalSelesai: selesai,
  keterangan: keterangan,
  updatedAt: masuk,
);

/// Tanggal yang dipakai seluruh berkas ini.
///
/// Tetap, bukan DateTime.now(): tes yang hasilnya bergantung pada jam
/// berapa ia dijalankan akan lulus pagi dan gagal malam, dan yang diuji
/// di sini isi dan tata letaknya, bukan jamnya.
final _hari = DateTime(2026, 9, 6, 9, 0);
final _kemarin = DateTime(2026, 9, 5, 9, 0);

Future<void> _lukis(WidgetTester tester, List<ServiceOrderEntry> data) async {
  await tester.binding.setSurfaceSize(const Size(1366, 768));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        serviceOrdersProvider.overrideWith((ref) => Stream.value(data)),
        tanggalHarianProvider.overrideWith(
          (ref) => DateTime(_hari.year, _hari.month, _hari.day),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.terang(),
        home: const Scaffold(body: ServiceReportsView()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Kedua tabel harian punya tabnya sendiri. Sebelum tabnya dibuka,
/// isinya memang belum tergambar sama sekali -- itu yang membuatnya tidak
/// lagi berbagi tinggi layar dengan tabel di sebelahnya.
Future<void> _bukaTabMasuk(WidgetTester tester) async {
  await tester.tap(find.textContaining('NOTA MASUK'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('id', null));

  group('Batas hari nota masuk', () {
    testWidgets('nota masuk malam tetap di tab hari itu', (tester) async {
      // Unit yang diterima jam 19.45 diterima hari itu juga. Jam tutup
      // 17.00 hanya milik nota keluar; nota masuk yang ikut digeser
      // lenyap dari tab hari ini tepat saat admin baru saja mengetiknya.
      await _lukis(tester, [
        _nota(
          noNota: 'SRV-09092628292',
          nama: 'Joe Topan',
          status: 'masuk',
          masuk: DateTime(_hari.year, _hari.month, _hari.day, 19, 45),
        ),
      ]);
      await _bukaTabMasuk(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Joe Topan'), findsOneWidget);
    });
  });

  group('Tab harian', () {
    testWidgets('terlukis penuh tanpa galat tata letak', (tester) async {
      final hari = _hari;
      final kemarin = _kemarin;

      await _lukis(tester, [
        // Keluar hari ini -- masuk kemarin, jadi ikut tabel pertama saja.
        _nota(noNota: 'SRV-0001', masuk: kemarin, selesai: hari),
        _nota(noNota: 'SRV-0002', masuk: kemarin, selesai: hari, biaya: 90000),
        // Masuk hari ini dan belum keluar -- tabel kedua saja.
        _nota(noNota: 'SRV-0003', masuk: hari, status: 'proses', biaya: 0),
      ]);

      expect(tester.takeException(), isNull);
      // Jumlahnya ikut di judul tabnya, jadi tabel yang sedang tidak
      // dibuka pun tetap bisa dilihat isinya berapa.
      expect(find.text('NOTA KELUAR  (2)'), findsOneWidget);
      expect(find.text('NOTA MASUK  (1)'), findsOneWidget);
      // Tab pertama yang terbuka: nota keluar.
      expect(find.text('SRV-0001'), findsOneWidget);
    });

    testWidgets('nota keluar dipisah dari nota masuk', (tester) async {
      final hari = _hari;
      final kemarin = _kemarin;

      await _lukis(tester, [
        _nota(noNota: 'SRV-0001', masuk: kemarin, selesai: hari),
        _nota(noNota: 'SRV-0002', masuk: hari, status: 'proses', biaya: 0),
        // Selesai kemarin: tidak boleh muncul di tanggal hari ini.
        _nota(noNota: 'SRV-0003', masuk: kemarin, selesai: kemarin),
      ]);

      expect(find.text('2 nota  ·  Rp150.000'), findsNothing);
      expect(find.textContaining('1 nota'), findsOneWidget);
      // Selesai kemarin: tidak boleh muncul di tab mana pun hari ini.
      expect(find.text('SRV-0003'), findsNothing);

      await _bukaTabMasuk(tester);

      expect(find.text('1 unit diterima'), findsOneWidget);
      expect(find.text('SRV-0002'), findsOneWidget);
      // Kedua tabel tidak lagi bertumpuk: yang satu terbuka, yang lain
      // tidak ikut tergambar.
      expect(find.text('SRV-0001'), findsNothing);
      expect(find.text('SRV-0003'), findsNothing);
    });

    testWidgets('tanggal tanpa transaksi memberi pesan, bukan tabel kosong', (
      tester,
    ) async {
      final lama = _hari.subtract(const Duration(days: 40));
      await _lukis(tester, [_nota(noNota: 'SRV-0001', masuk: lama)]);

      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('Belum ada unit yang selesai'),
        findsOneWidget,
      );

      await _bukaTabMasuk(tester);
      expect(find.textContaining('Belum ada unit yang masuk'), findsOneWidget);
    });
  });

  group('Keterangan harian', () {
    final hari = _hari;

    test('nota batal ditandai Cancel apa pun isinya', () {
      final n = _nota(
        noNota: 'SRV-0001',
        masuk: hari,
        status: 'batal',
        garansi: true,
        keterangan: 'diambil pelanggan',
      );
      expect(ExcelExport.keteranganHarian(n), 'Cancel');
    });

    test('nota garansi ditandai Garansi', () {
      final n = _nota(noNota: 'SRV-0002', masuk: hari, garansi: true);
      expect(ExcelExport.keteranganHarian(n), 'Garansi');
    });

    test('nota reguler memakai catatannya sendiri', () {
      final n = _nota(
        noNota: 'SRV-0003',
        masuk: hari,
        keterangan: 'Belum bayar',
      );
      expect(ExcelExport.keteranganHarian(n), 'Belum bayar');
    });

    test('nota reguler tanpa catatan menghasilkan kolom kosong', () {
      final n = _nota(noNota: 'SRV-0004', masuk: hari);
      expect(ExcelExport.keteranganHarian(n), '');
    });
  });
}
