// Klaim yang lahir dari nota servis yang sudah ada.
//
// Alurnya datang dari kejadian yang berulang di toko: unit masuk sebagai
// servis biasa, teknisi membongkarnya, dan baru di situ ketahuan unitnya
// masih bergaransi. Yang berdiri di depan formulir ini teknisi dengan HP
// di tangan, bukan admin dengan berkas nota -- jadi yang ia punya cuma
// nama seperti tertulis di nota.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/core/theme.dart';
import 'package:sc_management/features/claims/claim_form_page.dart';
import 'package:sc_management/features/claims/widgets/kolom_nota.dart';

final _tgl = DateTime(2026, 9, 4);

ServiceOrderEntry _nota({String? claimId, String id = 'nota-1'}) =>
    ServiceOrderEntry(
      id: id,
      noNota: 'SVR-04092628168',
      tanggalMasuk: _tgl,
      customerNama: 'UDIN SAPUTRA',
      customerTelp: '081255500011',
      barangNama: 'Laptop Asus',
      barangType: 'X441BA',
      barangSn: 'X1Y2Z3',
      keluhan: 'NO POWER',
      teknisiId: 't1',
      status: 'dikerjakan',
      garansi: claimId != null,
      claimId: claimId,
      updatedAt: _tgl,
    );

Future<void> _lukis(
  WidgetTester tester, {
  List<ServiceOrderEntry> nota = const [],
}) async {
  await tester.binding.setSurfaceSize(const Size(500, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        allBrandsProvider.overrideWith(
          (ref) => Stream.value(const [
            Brand(id: 1, nama: 'ASUS'),
            Brand(id: 2, nama: 'HP'),
          ]),
        ),
        allProfilesProvider.overrideWith(
          (ref) => Stream.value(const [
            Profile(id: 't1', nama: 'Reza Teknisi', role: 'teknisi'),
          ]),
        ),
        allPartTypesProvider.overrideWith(
          (ref) => Stream.value(const <PartType>[]),
        ),
        serviceOrdersProvider.overrideWith((ref) => Stream.value(nota)),
        currentUserProvider.overrideWithValue(null),
      ],
      child: MaterialApp(theme: AppTheme.build(), home: const ClaimFormPage()),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _kolomNama => find.descendant(
  of: find.byType(KolomNota),
  matching: find.byType(TextFormField),
);

Future<void> _ketik(WidgetTester tester, String teks) async {
  await tester.enterText(_kolomNama, teks);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mengetik nama memunculkan notanya, lengkap dengan nomornya', (
    tester,
  ) async {
    await _lukis(tester, nota: [_nota()]);
    await _ketik(tester, 'udin');

    // Nomor nota, unit, dan tanggalnya sekaligus: satu orang bisa punya
    // beberapa unit di meja pada waktu yang sama.
    expect(find.textContaining('SVR-04092628168'), findsOneWidget);
    expect(find.textContaining('Laptop Asus X441BA'), findsOneWidget);
  });

  testWidgets('memilihnya menarik data notanya ke dalam klaim', (tester) async {
    await _lukis(tester, nota: [_nota()]);
    await _ketik(tester, 'udin');

    await tester.tap(find.textContaining('SVR-04092628168'));
    await tester.pumpAndSettle();

    // Identitas unitnya diambil dari nota, karena di situlah kebenarannya.
    expect(find.text('UDIN SAPUTRA'), findsWidgets);
    expect(find.text('081255500011'), findsWidgets);
    expect(find.text('X1Y2Z3'), findsWidgets);
    expect(find.text('NO POWER'), findsWidgets);
    // Brand ditebak dari sebutan unitnya, teknisi dibawa dari notanya.
    expect(find.text('ASUS'), findsWidgets);
    expect(find.text('Reza Teknisi'), findsWidgets);
  });

  testWidgets('menyebutkan lebih dulu apa yang akan terjadi pada notanya', (
    tester,
  ) async {
    await _lukis(tester, nota: [_nota()]);
    await _ketik(tester, 'udin');
    await tester.tap(find.textContaining('SVR-04092628168'));
    await tester.pumpAndSettle();

    // Perubahan yang merembet ke layar lain harus terbaca di tempat orang
    // memutuskannya, bukan muncul sebagai kejutan sesudahnya.
    expect(find.text('Tertaut ke nota SVR-04092628168'), findsOneWidget);
    expect(find.textContaining('ditandai bergaransi'), findsOneWidget);
  });

  testWidgets('tautannya bisa dilepas tanpa mengosongkan yang sudah benar', (
    tester,
  ) async {
    await _lukis(tester, nota: [_nota()]);
    await _ketik(tester, 'udin');
    await tester.tap(find.textContaining('SVR-04092628168'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Lepas tautan nota'));
    await tester.pumpAndSettle();

    expect(find.text('Tertaut ke nota SVR-04092628168'), findsNothing);
    // Yang dibatalkan hubungannya ke nota itu, bukan data yang sudah
    // terlanjur benar.
    expect(find.text('X1Y2Z3'), findsWidgets);
  });

  testWidgets('nota yang klaimnya sudah ada tidak ditawarkan', (tester) async {
    await _lukis(tester, nota: [_nota(claimId: 'klaim-lama')]);
    await _ketik(tester, 'udin');

    expect(find.textContaining('SVR-04092628168'), findsNothing);
  });

  testWidgets('tanpa nota yang cocok, formulirnya tetap bisa diisi biasa', (
    tester,
  ) async {
    // Tidak semua klaim lahir dari nota. Yang tidak menemukan apa-apa
    // harus tetap bisa mengetik namanya sendiri.
    await _lukis(tester, nota: [_nota()]);
    await _ketik(tester, 'orang lain');

    expect(find.textContaining('SVR-04092628168'), findsNothing);
    expect(find.text('orang lain'), findsWidgets);
  });
}
