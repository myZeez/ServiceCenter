// Tarik-untuk-segarkan di daftar klaim HP.
//
// Ada karena kasusnya pernah terjadi: status klaim diubah dari Windows,
// dan di Android tidak berubah sama sekali. Websocket yang diputus sistem
// saat aplikasi ditidurkan tidak melempar galat apa pun -- alirannya hanya
// berhenti mengirim, dan layar membeku tanpa satu pun tanda bahwa isinya
// sudah basi.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/core/theme.dart';
import 'package:sc_management/features/claims/claims_page.dart';

Claim _klaim(String id) => Claim(
  id: id,
  tanggal: DateTime(2026, 9, 4),
  brandId: 1,
  namaPelanggan: 'Budi',
  sn: 'SN$id',
  status: 'open',
  createdBy: 'adm',
  createdAt: DateTime(2026, 9, 4),
  updatedAt: DateTime(2026, 9, 4),
);

Future<void> _lukis(WidgetTester tester, List<Claim> klaim) async {
  await tester.binding.setSurfaceSize(const Size(400, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(null),
        allClaimsProvider.overrideWith((ref) => Stream.value(klaim)),
        allPartsProvider.overrideWith((ref) => Stream.value([])),
        allBrandsProvider.overrideWith(
          (ref) => Stream.value([const Brand(id: 1, nama: 'ASUS')]),
        ),
        allProfilesProvider.overrideWith((ref) => Stream.value([])),
        // Halaman utama memantau nota untuk lencana Servisku di dock.
        serviceOrdersProvider.overrideWith((ref) => Stream.value([])),
        koneksiProvider.overrideWith((ref) => Stream.value(true)),
      ],
      child: MaterialApp(theme: AppTheme.terang(), home: const ClaimsPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('daftar klaim bisa ditarik untuk disegarkan', (tester) async {
    await _lukis(tester, [_klaim('1'), _klaim('2')]);

    expect(tester.takeException(), isNull);
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });

  testWidgets('daftar kosong tetap bisa ditarik', (tester) async {
    // Justru saat daftarnya kosong orang paling ingin mencoba menyegarkan --
    // dan RefreshIndicator hanya bekerja di atas sesuatu yang bisa digulir.
    await _lukis(tester, []);

    expect(tester.takeException(), isNull);
    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.text('Belum ada klaim'), findsOneWidget);

    final gulir = find.descendant(
      of: find.byType(RefreshIndicator),
      matching: find.byType(Scrollable),
    );
    expect(gulir, findsOneWidget);
  });
}
