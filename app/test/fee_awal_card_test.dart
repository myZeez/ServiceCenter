// Kartu fee di halaman Pengaturan dilukis betulan. Kartu setting tinggal di
// dalam grid yang bisa diubah ukurannya, jadi isinya harus tetap muat saat
// tingginya dipepetkan -- kesalahan tata letak semacam itu tidak pernah
// muncul di flutter analyze.
//
// Yang dijaga khususnya: keterangan bahwa angka di kartu ini hanya nilai
// awal. Tanpa kalimat itu, angkanya terbaca sebagai yang dibayar brand, dan
// admin tidak punya alasan membuka halaman Rekap Brand sama sekali.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/core/revenue/revenue_providers.dart';
import 'package:sc_management/core/theme.dart';
import 'package:sc_management/features/settings/revenue_cards.dart';

Future<void> _lukis(WidgetTester tester, {double tinggi = 400}) async {
  await tester.binding.setSurfaceSize(const Size(700, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        allBrandsProvider.overrideWith(
          (ref) => Stream.value([
            const Brand(id: 1, nama: 'ASUS'),
            const Brand(id: 2, nama: 'LENOVO'),
          ]),
        ),
        brandFeesProvider.overrideWith(
          (ref) => Stream.value([
            BrandFeeEntry(
              id: 1,
              brandId: 1,
              fee: 100000,
              berlakuDari: DateTime(2026, 1, 1),
            ),
          ]),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.terang(),
        home: Scaffold(
          body: SizedBox(height: tinggi, child: const BrandFeesCard()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('fee brand disebut sebagai nilai awal, bukan angka akhir', (
    tester,
  ) async {
    await _lukis(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('FEE AWAL & ATURAN PER BRAND'), findsOneWidget);
    expect(
      find.textContaining('dikoreksi di halaman Rekap Brand'),
      findsOneWidget,
    );
    expect(find.text('Rp100.000'), findsOneWidget);

    // Brand yang belum punya fee tetap harus kelihatan: tanpa nilai awal,
    // seluruh unitnya jatuh ke nol sampai dicocokkan satu per satu.
    expect(find.text('BELUM DIATUR'), findsOneWidget);
  });

  testWidgets('tetap muat saat kartunya dipepetkan', (tester) async {
    await _lukis(tester, tinggi: 190);

    expect(tester.takeException(), isNull);
    expect(find.text('FEE AWAL & ATURAN PER BRAND'), findsOneWidget);
  });
}
