// Daftar omset per teknisi tumbuh mengikuti jumlah orangnya.
//
// Dulu kartunya diberi tinggi tetap 320 piksel. Dengan enam orang, yang
// keempat ke bawah tidak pernah tergambar sama sekali -- dan tidak ada
// tanda apa pun di layar bahwa mereka ada. Yang membukanya menyimpulkan
// omset teknisi yang tidak terlihat itu nol, atau bahwa daftarnya rusak.
//
// Test ini melukis enam teknisi dan menuntut keenamnya ada.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/omset/omset_providers.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/features/service/service_reports_view.dart';

const _nama = ['Aris', 'Agus', 'Budi', 'Irwan', 'Reza', 'Deril'];

/// Satu nota selesai untuk tiap teknisi, nilainya menurun supaya urutannya
/// pasti dan namanya bisa dicari satu per satu.
List<ServiceOrderEntry> _nota() => [
  for (var i = 0; i < _nama.length; i++)
    ServiceOrderEntry(
      id: 'n$i',
      noNota: 'SVR-0109262810$i',
      tanggalMasuk: DateTime(2026, 9, 1, 9, 0),
      customerNama: 'Pelanggan $i',
      barangNama: 'Laptop Asus',
      teknisiId: 't$i',
      status: 'diambil',
      biaya: (600000 - i * 50000).toDouble(),
      tanggalSelesai: DateTime(2026, 9, 5),
      tanggalDiambil: DateTime(2026, 9, 5),
      tanggalLunas: DateTime(2026, 9, 5),
      updatedAt: DateTime(2026, 9, 5),
    ),
];

Future<void> _bukaTabOmset(WidgetTester tester) => _bukaTab(tester, 'OMSET');

Future<void> _bukaTab(
  WidgetTester tester,
  String tab, {
  bool depan = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(1366, 768));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        isAdminDepanProvider.overrideWithValue(depan),
        serviceOrdersProvider.overrideWith((ref) => Stream.value(_nota())),
        allProfilesProvider.overrideWith(
          (ref) => Stream.value([
            for (var i = 0; i < _nama.length; i++)
              Profile(id: 't$i', nama: _nama[i], role: 'teknisi'),
          ]),
        ),
        omsetSettingsProvider.overrideWith(
          (ref) => Stream.value(
            const ServiceSettingsRow(
              id: 1,
              targetOmset: 4000000,
              feeAdminPerNota: 0,
            ),
          ),
        ),
        shipmentsProvider.overrideWith(
          (ref) => Stream.value([
            ShipmentEntry(
              id: 'k1',
              tanggalKirim: DateTime(2026, 9, 3),
              dariCabang: 'CC PLK',
              keCabang: 'CC PBUN',
              barangNama: 'Laptop Asus X441',
              status: 'ship',
              updatedAt: DateTime(2026, 9, 3),
            ),
          ]),
        ),
        // Bulan dan tanggalnya diikat supaya hasilnya tidak berubah besok.
        bulanProvider.overrideWith((ref) => const Bulan(2026, 9)),
        tanggalHarianProvider.overrideWith((ref) => DateTime(2026, 9, 5)),
        mingguLaporanProvider.overrideWith((ref) => DateTime(2026, 8, 31)),
      ],
      child: const MaterialApp(home: Scaffold(body: ServiceReportsView())),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text(tab));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('id', null));

  testWidgets('keenam teknisi tergambar, tidak terpotong tinggi kartunya', (
    tester,
  ) async {
    await _bukaTabOmset(tester);

    expect(tester.takeException(), isNull);
    for (final n in _nama) {
      expect(find.text(n), findsOneWidget, reason: '$n tidak tergambar');
    }
  });

  testWidgets('angkanya milik masing-masing, bukan angka yang sama', (
    tester,
  ) async {
    await _bukaTabOmset(tester);

    // Nilainya sengaja dibuat menurun 50 ribu tiap orang. Kalau suatu saat
    // ada yang menyamakan angkanya -- salah indeks, atau membagi rata --
    // baris ini yang menangkapnya.
    expect(find.text('Rp600.000'), findsOneWidget);
    expect(find.text('Rp350.000'), findsOneWidget);
  });

  // -------------------------------------------------------------------
  // Kelima tab dilukis satu per satu, dan isinya dituntut benar-benar
  // tergambar -- bukan sekadar kepalanya.
  //
  // Ini pernah rusak sungguhan: satu perubahan pada kartu pembungkusnya
  // membuat Pelunasan, Keseluruhan, dan Kirim kehilangan seluruh ruang
  // vertikalnya. Kepala kartunya tetap menyebut "87 nota · Rp13.445.000",
  // jadi dari luar tampak berisi; yang hilang justru tabelnya. Test OMSET
  // di atas lulus terus, karena tab itulah satu-satunya yang diuji.
  // -------------------------------------------------------------------
  // Tiap tab punya penanda isinya sendiri: yang mendaftar nota memakai
  // nama pelanggan, Omset memakai nama teknisi, Kirim memakai nama barang
  // karena baris kirim tidak punya pelanggan.
  const penanda = {
    'HARIAN': 'Pelanggan',
    'MINGGUAN': 'TOTAL',
    'OMSET': 'Aris',
    'PELUNASAN': 'Pelanggan',
    'KESELURUHAN': 'Pelanggan',
    'KIRIM': 'Laptop Asus',
  };

  for (final e in penanda.entries) {
    testWidgets('tab ${e.key} menggambar isinya, bukan cuma kepalanya', (
      tester,
    ) async {
      await _bukaTab(tester, e.key);

      expect(tester.takeException(), isNull);
      expect(
        find.textContaining(e.value),
        findsWidgets,
        reason: 'isi tab ${e.key} tidak tergambar',
      );
    });
  }

  testWidgets('tab MINGGUAN sampai ke omset tiap teknisi', (tester) async {
    await _bukaTab(tester, 'MINGGUAN');

    expect(find.text('Rp2.850.000'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Deril'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Rp350.000'), findsOneWidget);
  });

  group('Admin meja depan', () {
    testWidgets('hanya mendapat Harian dan Omset', (tester) async {
      await _bukaTab(tester, 'OMSET', depan: true);

      expect(tester.takeException(), isNull);
      expect(find.text('HARIAN'), findsOneWidget);
      for (final tab in const [
        'MINGGUAN',
        'PELUNASAN',
        'KESELURUHAN',
        'KIRIM',
      ]) {
        expect(find.text(tab), findsNothing, reason: tab);
      }
    });

    // Admin yang mendorong omset, jadi harus tahu siapa yang masih kurang.
    testWidgets('melihat omset tiap teknisi', (tester) async {
      await _bukaTab(tester, 'OMSET', depan: true);

      expect(find.text('Rp2.850.000'), findsWidgets);
      for (final n in _nama) {
        expect(find.text(n), findsOneWidget, reason: n);
      }
    });
  });
}
