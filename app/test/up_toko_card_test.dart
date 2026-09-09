// Kartu pengaturan persentase up toko.
//
// Diuji dengan melukisnya, bukan hanya menghitungnya: kartu ini menyunting
// salinan di layar sebelum menyimpannya, dan salinan yang tertimpa tiap
// kali aliran datanya berdenyut adalah cacat yang hanya kelihatan saat
// dipakai.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/features/settings/up_toko_card.dart';

Future<void> _lukis(WidgetTester tester, PartSettingsRow? aturan) async {
  await tester.binding.setSurfaceSize(const Size(600, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        partSettingsProvider.overrideWith((ref) => Stream.value(aturan)),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SizedBox(height: 700, child: UpTokoCard())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('menampilkan pilihan yang tersimpan', (tester) async {
    await _lukis(
      tester,
      const PartSettingsRow(upTokoPilihan: [10, 15, 20], upTokoBawaan: 15),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('UP TOKO PENJUALAN PART'), findsOneWidget);
    expect(find.text('10%'), findsOneWidget);
    expect(find.text('15%'), findsOneWidget);
    expect(find.text('20%'), findsOneWidget);
  });

  testWidgets('menandai mana yang jadi bawaan', (tester) async {
    await _lukis(
      tester,
      const PartSettingsRow(upTokoPilihan: [10, 20], upTokoBawaan: 20),
    );

    expect(find.text('BAWAAN'), findsOneWidget);
  });

  testWidgets('mengetuk sebuah angka memindahkan bawaannya', (tester) async {
    await _lukis(
      tester,
      const PartSettingsRow(upTokoPilihan: [10, 20], upTokoBawaan: 20),
    );

    await tester.tap(find.text('10%'));
    await tester.pumpAndSettle();

    // Bawaannya tetap satu, tetapi sekarang menempel di angka yang lain.
    expect(find.text('BAWAAN'), findsOneWidget);
    expect(
      find.ancestor(of: find.text('BAWAAN'), matching: find.byType(Row)),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: find.ancestor(of: find.text('10%'), matching: find.byType(Row)),
        matching: find.text('BAWAAN'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('menambah persentase dan mengurutkannya', (tester) async {
    await _lukis(
      tester,
      const PartSettingsRow(upTokoPilihan: [20], upTokoBawaan: 20),
    );

    await tester.enterText(find.byType(TextField), '12.5');
    await tester.tap(find.text('TAMBAH'));
    await tester.pumpAndSettle();

    expect(find.text('12,5%'), findsOneWidget);
    expect(find.text('20%'), findsOneWidget);
  });

  testWidgets('angka yang sudah ada tidak digandakan', (tester) async {
    await _lukis(
      tester,
      const PartSettingsRow(upTokoPilihan: [20], upTokoBawaan: 20),
    );

    await tester.enterText(find.byType(TextField), '20');
    await tester.tap(find.text('TAMBAH'));
    await tester.pumpAndSettle();

    expect(find.text('20%'), findsOneWidget);
  });

  testWidgets('membuang bawaan memindahkan bawaannya ke yang tersisa', (
    tester,
  ) async {
    await _lukis(
      tester,
      const PartSettingsRow(upTokoPilihan: [10, 20], upTokoBawaan: 20),
    );

    // Tombol silang pada chip 20% -- yang sedang jadi bawaan.
    await tester.tap(
      find.descendant(
        of: find.ancestor(of: find.text('20%'), matching: find.byType(Row)),
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('20%'), findsNothing);
    // Tanpa pemindahan ini, dropdown harga akan terlihat kosong padahal
    // pilihannya masih ada.
    expect(find.text('BAWAAN'), findsOneWidget);
  });

  testWidgets('daftar kosong menjelaskan apa yang akan dipakai sementara', (
    tester,
  ) async {
    await _lukis(
      tester,
      const PartSettingsRow(upTokoPilihan: [], upTokoBawaan: 10),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('10/15/20'), findsOneWidget);
  });

  testWidgets('simpan terkunci sebelum pengaturannya terbaca', (tester) async {
    await _lukis(tester, null);

    final tombol = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'SIMPAN'),
    );
    expect(tombol.onPressed, isNull);
  });
}
