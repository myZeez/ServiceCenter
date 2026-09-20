// Laporan kirim antar cabang: unit yang DITERIMA dari cabang lain.
//
// Catatan pengiriman adalah unit yang dikirim cabang ke sini untuk
// dikerjakan. Yang dibaca dari laporannya: kapan diterima, dan kapan
// dikirim balik ke cabang pengirim. Status di arsip impor tidak bisa
// dipercaya untuk itu -- hampir semua catatan bertanda 'ship' walau
// tanggal kembalinya terisi.

import 'package:excel/excel.dart' show TextCellValue;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/export/excel_export.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/core/theme.dart';
import 'package:sc_management/features/service/service_reports_view.dart';

ShipmentEntry _kirim(
  String barang, {
  String status = 'ship',
  DateTime? kembali,
  String dari = 'CC PBUN',
}) => ShipmentEntry(
  id: barang,
  tanggalKirim: DateTime(2026, 9, 1),
  dariCabang: dari,
  keCabang: 'CC PLK',
  userNama: 'GERSA',
  barangNama: barang,
  status: status,
  tanggalKembali: kembali,
  updatedAt: DateTime(2026, 9, 1),
);

void main() {
  setUpAll(() => initializeDateFormatting('id', null));

  group('Sudah dikirim balik', () {
    test('tanggal kembali terisi berarti sudah kembali, apa pun statusnya', () {
      expect(
        _kirim('A', status: 'ship', kembali: DateTime(2026, 9, 5)).sudahKembali,
        isTrue,
      );
    });

    test('status received berarti sudah kembali walau tanggalnya kosong', () {
      expect(_kirim('A', status: 'received').sudahKembali, isTrue);
    });

    test('tanpa keduanya unitnya masih di sini', () {
      expect(_kirim('A').sudahKembali, isFalse);
    });
  });

  group('Excel', () {
    test('kolom pertama adalah tanggal terima', () {
      final lembar = ExcelExport.lembarKirim(data: [_kirim('A')]);
      final judul = lembar.tabel.single.kolom.map((k) => k.judul).toList();

      expect(judul.first, 'TANGGAL TERIMA');
      expect(judul, isNot(contains('TANGGAL KIRIM')));
      expect(judul, contains('TANGGAL KEMBALI'));
    });

    test('status SHIP selama belum kembali, RETURN sesudahnya', () {
      final lembar = ExcelExport.lembarKirim(
        data: [
          _kirim('A'),
          _kirim('B', status: 'ship', kembali: DateTime(2026, 9, 5)),
          _kirim('C', status: 'received'),
        ],
      );
      final t = lembar.tabel.single;
      final i = t.kolom.indexWhere((k) => k.judul == 'STATUS');

      expect(
        [for (final r in t.baris) (r[i] as TextCellValue).value.text],
        ['SHIP', 'RETURN', 'RETURN'],
      );
    });
  });

  group('Layar', () {
    Future<void> lukis(WidgetTester tester, List<ShipmentEntry> data) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serviceOrdersProvider.overrideWith((ref) => Stream.value(const [])),
            shipmentsProvider.overrideWith((ref) => Stream.value(data)),
          ],
          child: MaterialApp(
            theme: AppTheme.terang(),
            home: const Scaffold(body: ServiceReportsView()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('KIRIM'));
      await tester.pumpAndSettle();
    }

    testWidgets('kolomnya berjudul, tanggal terima dan tanggal kembali', (
      tester,
    ) async {
      await lukis(tester, [_kirim('LAPTOP AXIOO')]);

      expect(tester.takeException(), isNull);
      expect(find.text('TERIMA'), findsOneWidget);
      expect(find.text('KEMBALI'), findsOneWidget);
      expect(find.text('DARI → KE'), findsOneWidget);
    });

    testWidgets('yang belum kembali dihitung dari tanggal, bukan status', (
      tester,
    ) async {
      await lukis(tester, [
        _kirim('A'), // masih di sini
        _kirim('B', status: 'ship', kembali: DateTime(2026, 9, 5)), // sudah
        _kirim('C', status: 'received'), // sudah
      ]);

      // Sebelumnya ketiganya bertanda 'ship' dan terhitung "belum kembali".
      expect(
        find.textContaining('3 catatan  ·  1 belum dikirim balik'),
        findsOneWidget,
      );
    });

    testWidgets('tanda status: diterima, atau dikirim balik', (tester) async {
      await lukis(tester, [
        _kirim('A'),
        _kirim('B', kembali: DateTime(2026, 9, 5)),
      ]);

      expect(find.text('DITERIMA'), findsOneWidget);
      expect(find.text('DIKIRIM BALIK'), findsOneWidget);
    });

    testWidgets('kosong menyebut unit yang diterima', (tester) async {
      await lukis(tester, const []);
      expect(
        find.text('Belum ada unit yang diterima dari cabang.'),
        findsOneWidget,
      );
    });
  });
}
