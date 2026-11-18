// Admin meja depan hanya mengatur perangkatnya sendiri dan mengimpor data.
//
// Kartu lain tetap ditolak server kalau dicoba, tapi admin yang melihatnya
// akan mengisi form yang tidak pernah bisa tersimpan.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sc_management/core/providers.dart';
import 'package:sc_management/features/settings/print_cards.dart';
import 'package:sc_management/features/settings/settings_view.dart';
import 'package:sc_management/features/settings/tampilan_card.dart';

void main() {
  for (final ukuran in const [Size(1366, 768), Size(600, 900)]) {
    testWidgets('admin di layar ${ukuran.width.toInt()} piksel', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(ukuran);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [isAdminDepanProvider.overrideWithValue(true)],
          child: const MaterialApp(home: Scaffold(body: SettingsView())),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('IMPOR SQL'), findsOneWidget);
      expect(find.byType(PrinterCard), findsOneWidget);
      expect(find.byType(TampilanCard, skipOffstage: false), findsOneWidget);
      for (final milikSuperAdmin in const [
        'PENGGUNA',
        'BRAND',
        'JENIS PART',
        'CARA BAYAR',
        'UBAH LAYOUT',
      ]) {
        expect(find.text(milikSuperAdmin), findsNothing);
      }
    });
  }
}
