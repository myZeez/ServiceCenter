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
  String status = 'diambil',
  DateTime? diambil,
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
  tanggalDiambil: diambil ?? selesai,
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

/// Melukis tab Harian pada sebuah tanggal tertentu.
Future<void> _lukisTanggal(
  WidgetTester tester,
  DateTime tanggal,
  List<ServiceOrderEntry> data,
) async {
  await tester.binding.setSurfaceSize(const Size(1366, 768));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        serviceOrdersProvider.overrideWith((ref) => Stream.value(data)),
        tanggalHarianProvider.overrideWith((ref) => tanggal),
      ],
      child: MaterialApp(
        theme: AppTheme.terang(),
        home: const Scaffold(body: ServiceReportsView()),
      ),
    ),
  );
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
          noNota: 'SVR-09092628292',
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
        _nota(noNota: 'SVR-0001', masuk: kemarin, selesai: hari),
        _nota(noNota: 'SVR-0002', masuk: kemarin, selesai: hari, biaya: 90000),
        // Masuk hari ini dan belum keluar -- tabel kedua saja.
        _nota(noNota: 'SVR-0003', masuk: hari, status: 'proses', biaya: 0),
      ]);

      expect(tester.takeException(), isNull);
      // Jumlahnya ikut di judul tabnya, jadi tabel yang sedang tidak
      // dibuka pun tetap bisa dilihat isinya berapa.
      expect(find.text('NOTA KELUAR  (2)'), findsOneWidget);
      expect(find.text('NOTA MASUK  (1)'), findsOneWidget);
      // Tab pertama yang terbuka: nota keluar.
      expect(find.text('SVR-0001'), findsOneWidget);
    });

    testWidgets(
      'nota keluar memuat unit yang diambil atau dibatalkan lalu keluar',
      (tester) async {
        await _lukis(tester, [
          _nota(
            noNota: 'SVR-SELESAI',
            nama: 'Baru Selesai',
            masuk: _kemarin,
            selesai: _hari,
            status: 'selesai',
          ),
          _nota(
            noNota: 'SVR-DIKERJAKAN',
            nama: 'Dikerjakan Lagi',
            masuk: _kemarin,
            selesai: _hari,
            diambil: _hari,
            status: 'dikerjakan',
          ),
          _nota(
            noNota: 'SVR-DIAMBIL',
            nama: 'Sudah Diambil',
            masuk: _kemarin,
            selesai: _kemarin,
            diambil: _hari,
            status: 'diambil',
          ),
          _nota(
            noNota: 'SVR-BATAL',
            nama: 'Batal dan Keluar',
            masuk: _kemarin,
            selesai: _hari,
            diambil: _hari,
            status: 'batal',
            biaya: 0,
          ),
        ]);

        expect(find.text('NOTA KELUAR  (2)'), findsOneWidget);
        expect(find.text('Sudah Diambil'), findsOneWidget);
        expect(find.text('Batal dan Keluar'), findsOneWidget);
        expect(find.text('Baru Selesai'), findsNothing);
        expect(find.text('Dikerjakan Lagi'), findsNothing);
      },
    );
    testWidgets('nota keluar dipisah dari nota masuk', (tester) async {
      final hari = _hari;
      final kemarin = _kemarin;

      await _lukis(tester, [
        _nota(noNota: 'SVR-0001', masuk: kemarin, selesai: hari),
        _nota(noNota: 'SVR-0002', masuk: hari, status: 'proses', biaya: 0),
        // Selesai kemarin: tidak boleh muncul di tanggal hari ini.
        _nota(noNota: 'SVR-0003', masuk: kemarin, selesai: kemarin),
      ]);

      expect(find.text('2 nota  ·  Rp150.000'), findsNothing);
      expect(find.textContaining('1 nota'), findsOneWidget);
      // Selesai kemarin: tidak boleh muncul di tab mana pun hari ini.
      expect(find.text('SVR-0003'), findsNothing);

      await _bukaTabMasuk(tester);

      expect(find.text('1 unit diterima'), findsOneWidget);
      expect(find.text('SVR-0002'), findsOneWidget);
      // Kedua tabel tidak lagi bertumpuk: yang satu terbuka, yang lain
      // tidak ikut tergambar.
      expect(find.text('SVR-0001'), findsNothing);
      expect(find.text('SVR-0003'), findsNothing);
    });

    testWidgets('tanggal tanpa transaksi memberi pesan, bukan tabel kosong', (
      tester,
    ) async {
      final lama = _hari.subtract(const Duration(days: 40));
      await _lukis(tester, [_nota(noNota: 'SVR-0001', masuk: lama)]);

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Belum ada unit yang keluar'), findsOneWidget);

      await _bukaTabMasuk(tester);
      expect(find.textContaining('Belum ada unit yang masuk'), findsOneWidget);
    });
  });

  group('Keterangan harian', () {
    final hari = _hari;

    test('nota batal ditandai Cancel apa pun isinya, dengan biayanya', () {
      final gratis = _nota(
        noNota: 'SVR-0001',
        masuk: hari,
        status: 'batal',
        garansi: true,
        biaya: 0,
        keterangan: 'diambil pelanggan',
      );
      expect(ExcelExport.keteranganHarian(gratis), 'Cancel Tanpa Biaya');

      final berbiaya = _nota(
        noNota: 'SVR-0005',
        masuk: hari,
        status: 'batal',
        biaya: 50000,
      );
      expect(ExcelExport.keteranganHarian(berbiaya), 'Cancel Berbiaya');
    });

    test('nota garansi ditandai Garansi', () {
      final n = _nota(noNota: 'SVR-0002', masuk: hari, garansi: true);
      expect(ExcelExport.keteranganHarian(n), 'Garansi');
    });

    test('nota reguler memakai catatannya sendiri', () {
      final n = _nota(
        noNota: 'SVR-0003',
        masuk: hari,
        keterangan: 'Belum bayar',
      );
      expect(ExcelExport.keteranganHarian(n), 'Belum bayar');
    });

    test('nota reguler tanpa catatan menghasilkan kolom kosong', () {
      final n = _nota(noNota: 'SVR-0004', masuk: hari);
      expect(ExcelExport.keteranganHarian(n), '');
    });
  });

  // Toko tutup setiap Sabtu; berkas SVS yang dikirim ke pusat memang
  // tidak punya lembar Sabtu. Dua tabel kosong di layar terbaca seperti
  // laporan yang belum diisi, bukan seperti hari libur.
  group('Hari libur', () {
    testWidgets('Sabtu ditandai libur, tabelnya tidak ditampilkan', (
      tester,
    ) async {
      // 12 September 2026 jatuh hari Sabtu.
      await _lukisTanggal(tester, DateTime(2026, 9, 12), []);

      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('Libur. Toko tutup setiap Sabtu'),
        findsOneWidget,
      );
      expect(find.textContaining('NOTA KELUAR'), findsNothing);
      expect(find.textContaining('NOTA MASUK'), findsNothing);
    });

    testWidgets('hari kerja tidak ditandai libur', (tester) async {
      await _lukisTanggal(tester, DateTime(2026, 9, 11), []);

      expect(find.textContaining('Libur. Toko tutup'), findsNothing);
      expect(find.text('NOTA KELUAR  (0)'), findsOneWidget);
    });

    testWidgets('libur yang ternyata ada notanya tetap menampilkannya', (
      tester,
    ) async {
      // Yang tercatat lebih benar daripada yang diatur.
      final sabtu = DateTime(2026, 9, 12, 9, 0);
      await _lukisTanggal(tester, DateTime(2026, 9, 12), [
        _nota(
          noNota: 'SVR-0009',
          nama: 'Lembur',
          masuk: sabtu,
          status: 'masuk',
        ),
      ]);

      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('ditandai libur, tetapi ada nota'),
        findsOneWidget,
      );
      expect(find.text('NOTA MASUK  (1)'), findsOneWidget);
    });
  });
}
