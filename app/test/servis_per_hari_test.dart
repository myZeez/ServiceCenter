// Halaman Servis dibatasi satu hari, arsip lengkapnya pindah ke halaman
// sendiri.
//
// Yang dijaga di sini bukan tampilannya melainkan satu perilaku yang
// gampang salah: batas harian TIDAK boleh ikut berlaku saat mencari.
// Orang yang mengetik nama pelanggan mencari notanya, bukan notanya hari
// ini -- dan daftar kosong karena harinya kebetulan salah adalah jawaban
// yang menyesatkan, bukan jawaban kosong.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/features/service/all_notes_view.dart';
import 'package:sc_management/features/service/service_view.dart';

ServiceOrderEntry _nota({
  required String noNota,
  required DateTime masuk,
  String nama = 'Jamal',
  String status = 'masuk',
  double biaya = 0,
}) => ServiceOrderEntry(
  id: noNota,
  noNota: noNota,
  tanggalMasuk: masuk,
  customerNama: nama,
  barangNama: 'ASUS X441',
  status: status,
  biaya: biaya,
  updatedAt: masuk,
);

final _kemarin = DateTime(2026, 9, 5);
final _hariIni = DateTime(2026, 9, 6);

final _contoh = [
  _nota(
    noNota: 'SVR-1',
    masuk: DateTime(2026, 9, 6, 14, 25),
    nama: 'Hari Ini A',
  ),
  _nota(
    noNota: 'SVR-2',
    masuk: _hariIni,
    nama: 'Hari Ini B',
    status: 'selesai',
  ),
  _nota(noNota: 'SVR-3', masuk: _kemarin, nama: 'Kemarin'),
  _nota(noNota: 'SVR-4', masuk: DateTime(2026, 1, 4), nama: 'Januari'),
];

Future<void> _lukis(WidgetTester tester, Widget layar) async {
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        serviceOrdersProvider.overrideWith((ref) => Stream.value(_contoh)),
        allProfilesProvider.overrideWith((ref) => Stream.value(const [])),
        allMetodeBayarProvider.overrideWith((ref) => Stream.value(const [])),
        customersProvider.overrideWith((ref) => Stream.value(const [])),
        partOrdersProvider.overrideWith((ref) => Stream.value(const [])),
        koneksiProvider.overrideWith((ref) => Stream.value(true)),
        // Hari diikat supaya test tidak berubah hasilnya besok pagi.
        hariServisProvider.overrideWith((ref) => _hariIni),
      ],
      child: MaterialApp(home: Scaffold(body: layar)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // Nama bulan dan hari dicetak dalam bahasa Indonesia; tanpa ini
  // DateFormat melempar galat, sama seperti di aplikasi kalau main()
  // lupa memanggilnya.
  setUpAll(() => initializeDateFormatting('id', null));

  group('saringNota', () {
    test('tanpa pencarian hanya memuat hari yang dipilih', () {
      final hasil = saringNota(_contoh, hari: _hariIni);
      expect(hasil.map((n) => n.customerNama), ['Hari Ini A', 'Hari Ini B']);
    });

    test('hari lain memuat notanya sendiri', () {
      final hasil = saringNota(_contoh, hari: _kemarin);
      expect(hasil.single.customerNama, 'Kemarin');
    });

    test('pencarian menembus batas hari', () {
      // Inilah perilaku yang paling mahal kalau salah: nota Januari harus
      // ketemu walau yang sedang dilihat hari ini.
      final hasil = saringNota(_contoh, hari: _hariIni, query: 'januari');
      expect(hasil.single.noNota, 'SVR-4');
    });

    test('pencarian dan status berlaku bersamaan', () {
      final hasil = saringNota(
        _contoh,
        hari: _hariIni,
        status: 'selesai',
        query: 'hari ini',
      );
      expect(hasil.single.customerNama, 'Hari Ini B');
    });

    test('hari yang tidak ada notanya menghasilkan kosong, bukan galat', () {
      expect(saringNota(_contoh, hari: DateTime(2026, 7, 1)), isEmpty);
    });
  });

  group('halaman Servis', () {
    testWidgets('memuat hari itu saja', (tester) async {
      await _lukis(tester, const ServiceView());

      expect(tester.takeException(), isNull);
      expect(find.text('Hari Ini A'), findsOneWidget);
      expect(find.text('Kemarin'), findsNothing);
      expect(find.text('Januari'), findsNothing);
    });

    testWidgets('menyebut jam masuknya, bukan tanggalnya saja', (tester) async {
      await _lukis(tester, const ServiceView());

      // Jamnya ikut disebut supaya lebih rinci, bukan tanggalnya saja.
      expect(find.text('06/09/26'), findsWidgets);
      expect(find.text('14:25'), findsOneWidget);
    });

    testWidgets('kosong menjelaskan bahwa halaman ini satu hari saja', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serviceOrdersProvider.overrideWith(
              (ref) => Stream.value([_contoh.last]),
            ),
            allProfilesProvider.overrideWith((ref) => Stream.value(const [])),
            allMetodeBayarProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
            customersProvider.overrideWith((ref) => Stream.value(const [])),
            partOrdersProvider.overrideWith((ref) => Stream.value(const [])),
            koneksiProvider.overrideWith((ref) => Stream.value(true)),
            hariServisProvider.overrideWith((ref) => _hariIni),
          ],
          child: const MaterialApp(home: Scaffold(body: ServiceView())),
        ),
      );
      await tester.pumpAndSettle();

      // Kosong pada satu hari bukan berarti tidak ada apa-apa, dan itu
      // harus disebut -- kalau tidak, orang akan mengira datanya hilang.
      expect(find.text('Belum ada nota hari ini'), findsOneWidget);
      expect(find.textContaining('satu hari saja'), findsOneWidget);
    });
  });

  group('halaman Semua Nota', () {
    testWidgets('memuat seluruh arsip saat bulannya dilepas', (tester) async {
      await _lukis(tester, const AllNotesView());

      expect(tester.takeException(), isNull);
      // Bawaannya bulan berjalan; melepasnya satu ketukan pada tanggalnya.
      await tester.tap(find.textContaining('SEPTEMBER'));
      await tester.pumpAndSettle();

      expect(find.text('SEMUA BULAN'), findsOneWidget);
      expect(find.text('Januari'), findsOneWidget);
      expect(find.text('Kemarin'), findsOneWidget);
      expect(find.text('Hari Ini A'), findsOneWidget);
    });

    testWidgets('menyebutkan berapa nota di seluruh arsip', (tester) async {
      await _lukis(tester, const AllNotesView());

      expect(find.textContaining('4 di seluruh arsip'), findsOneWidget);
    });
  });
}
