// Kapan sebuah kartu pelanggan diterbitkan, dan kapan tidak.
//
// Nota memuat nama dan telepon pelanggannya sebagai teks -- salinan yang
// disengaja, supaya nota yang sudah tercetak tetap cocok dengan kertasnya
// walau data pelanggannya berubah kemudian. Kartu pelanggan adalah hal
// yang terpisah, dan hanya lahir bersama nota BARU.
//
// Yang dijaga di sini pernah rusak sungguhan: menyunting nota lama --
// sekadar mengubah statusnya -- menerbitkan satu kartu pelanggan kembar
// tanpa ada yang memintanya. 3.085 nota hasil impor arsip sengaja tidak
// punya kartu sama sekali, jadi setiap satu di antaranya yang disunting
// menambah satu kartu, dan notanya berpindah menunjuk ke kartu baru itu.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/fitur.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/core/theme.dart';
import 'package:sc_management/features/service/customer_field.dart';
import 'package:sc_management/features/service/service_dialog.dart';

final _tgl = DateTime(2026, 9, 5);

const _kembar = 'Sudah ada pelanggan bernama sama:';

CustomerEntry _kartu({String nama = 'Irwan', String id = 'plg-1'}) =>
    CustomerEntry(
      id: id,
      kode: 'PLG-001',
      nama: nama,
      telp: '0812-3456-7890',
      updatedAt: DateTime(2026, 1, 1),
    );

ServiceOrderEntry _nota({String? customerId}) => ServiceOrderEntry(
  id: 'nota-1',
  noNota: 'SVR-05092628222',
  tanggalMasuk: _tgl,
  customerNama: 'Irwan',
  customerTelp: '0812-3456-7890',
  customerId: customerId,
  barangNama: 'Laptop Lenovo',
  status: 'masuk',
  updatedAt: _tgl,
);

Future<void> _lukis(
  WidgetTester tester, {
  ServiceOrderEntry? nota,
  List<CustomerEntry> pelanggan = const [],
}) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        fiturTanyaHargaProvider.overrideWithValue(false),
        customersProvider.overrideWith((ref) => Stream.value(pelanggan)),
        serviceOrdersProvider.overrideWith((ref) => Stream.value(const [])),
        partOrdersProvider.overrideWith((ref) => Stream.value(const [])),
        allBrandsProvider.overrideWith(
          (ref) => Stream.value([const Brand(id: 1, nama: 'ASUS')]),
        ),
        allProfilesProvider.overrideWith(
          (ref) => Stream.value(const <Profile>[]),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.terang(),
        home: ServiceDialog(nota: nota),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Nota baru', () {
    testWidgets('memperingatkan nama yang sudah punya kartu', (tester) async {
      await _lukis(tester, pelanggan: [_kartu()]);

      await tester.enterText(
        find.descendant(
          of: find.byType(CustomerField),
          matching: find.byType(TextFormField),
        ),
        'Irwan',
      );
      await tester.pumpAndSettle();

      // Di sini peringatannya benar: menyimpan memang akan menerbitkan
      // kartu kedua atas nama yang sama.
      expect(find.text(_kembar), findsOneWidget);
    });

    testWidgets('menyebut bahwa nama baru boleh diketik langsung', (
      tester,
    ) async {
      await _lukis(tester);

      expect(find.textContaining('atau isi nama baru'), findsOneWidget);
    });
  });

  group('Nota yang sudah tersimpan', () {
    testWidgets('tidak memperingatkan penggandaan yang tidak akan terjadi', (
      tester,
    ) async {
      // Keadaan yang paling sering: nota hasil impor arsip, tanpa
      // customer_id, sementara pelanggan bernama sama sudah punya kartu
      // dari kunjungan lain.
      await _lukis(tester, nota: _nota(), pelanggan: [_kartu()]);

      expect(find.text(_kembar), findsNothing);
    });

    testWidgets('menjelaskan bahwa namanya sudah tersimpan di nota', (
      tester,
    ) async {
      await _lukis(tester, nota: _nota(), pelanggan: [_kartu()]);

      expect(
        find.textContaining('Namanya tersimpan di nota ini'),
        findsOneWidget,
      );
      expect(find.textContaining('atau isi nama baru'), findsNothing);
    });

    testWidgets('nota yang sudah tertaut menampilkan tautannya', (
      tester,
    ) async {
      await _lukis(
        tester,
        nota: _nota(customerId: 'plg-1'),
        pelanggan: [_kartu()],
      );

      // Tautan yang sudah ada dikenali kembali dari customer_id-nya,
      // bukan dari kesamaan nama.
      expect(find.textContaining('Tertaut ke PLG-001'), findsOneWidget);
      expect(find.text(_kembar), findsNothing);
    });
  });
}
