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
      tanggalLunas: DateTime(2026, 9, 5),
      updatedAt: DateTime(2026, 9, 5),
    ),
];

Future<void> _bukaTabOmset(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1366, 768));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
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
        // Bulannya diikat supaya hasilnya tidak berubah bulan depan.
        bulanProvider.overrideWith((ref) => const Bulan(2026, 9)),
      ],
      child: const MaterialApp(home: Scaffold(body: ServiceReportsView())),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('OMSET'));
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
}
