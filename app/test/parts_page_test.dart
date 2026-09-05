// Halaman part di layar sempit.
//
// Yang diuji terutama bukan tampilannya melainkan batasnya: teknisi tidak
// boleh ditawari tahap yang pasti ditolak server. Kolom yang bisa diketik
// lalu ditolak diam-diam adalah cacat yang paling lama tidak ketahuan,
// karena tidak ada galat -- hanya perubahan yang tidak pernah tersimpan.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/features/parts/parts_page.dart';

PartOrder _pesanan({
  required String id,
  String nama = 'Jamal',
  String tahap = 'dipesan',
  String? stok = 'ready',
  double? harga = 120000,
}) => PartOrder(
  id: id,
  tanggal: DateTime(2026, 9, 4),
  customerNama: nama,
  barangType: 'ASUS X441',
  partReq: 'KEYBOARD',
  teknisiId: 't1',
  stok: stok,
  tahap: tahap,
  harga: harga,
  updatedAt: DateTime(2026, 9, 4),
);

Future<void> _lukis(
  WidgetTester tester,
  List<PartOrder> pesanan, {
  bool admin = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        partOrdersProvider.overrideWith((ref) => Stream.value(pesanan)),
        partCostsProvider.overrideWith((ref) => Stream.value(const [])),
        allProfilesProvider.overrideWith(
          (ref) => Stream.value([
            const Profile(id: 't1', nama: 'Reza', role: 'teknisi'),
          ]),
        ),
        isAdminProvider.overrideWithValue(admin),
        koneksiProvider.overrideWith((ref) => Stream.value(true)),
      ],
      child: const MaterialApp(home: PartsPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('menampilkan antrean part', (tester) async {
    await _lukis(tester, [
      _pesanan(id: '1', nama: 'Jamal'),
      _pesanan(id: '2', nama: 'Soni', tahap: 'tanya', harga: null),
    ]);

    expect(tester.takeException(), isNull);
    expect(find.text('Jamal'), findsOneWidget);
    expect(find.text('Soni'), findsOneWidget);
    expect(find.text('KEYBOARD'), findsNWidgets(2));
  });

  testWidgets('saringan tahap menyembunyikan yang lain', (tester) async {
    await _lukis(tester, [
      _pesanan(id: '1', nama: 'Jamal'),
      _pesanan(id: '2', nama: 'Soni', tahap: 'tanya', harga: null),
    ]);

    await tester.tap(find.text('TANYA HARGA  1'));
    await tester.pumpAndSettle();

    expect(find.text('Soni'), findsOneWidget);
    expect(find.text('Jamal'), findsNothing);
  });

  testWidgets('harga jual terlihat, modal tidak pernah dikirim ke sini', (
    tester,
  ) async {
    await _lukis(tester, [_pesanan(id: '1')]);

    expect(find.text('Rp120.000'), findsOneWidget);
    expect(find.textContaining('HPP'), findsNothing);
  });

  testWidgets('teknisi hanya ditawari menandai part terpasang', (
    tester,
  ) async {
    await _lukis(tester, [_pesanan(id: '1', tahap: 'dipesan')]);

    await tester.tap(find.text('Jamal'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('PART SUDAH DIPASANG'), findsOneWidget);
    // Tahap penuh, harga, dan DP tidak ditawarkan sama sekali: semuanya
    // akan ditolak trigger di server.
    expect(find.text('TAHAP'), findsNothing);
    expect(find.text('HARGA JUAL'), findsNothing);
    expect(find.text('DP USER'), findsNothing);
    expect(find.textContaining('diatur dari meja depan'), findsOneWidget);
  });

  testWidgets('teknisi tidak ditawari apa pun pada tahap yang bukan haknya', (
    tester,
  ) async {
    await _lukis(tester, [_pesanan(id: '1', tahap: 'tanya', harga: null)]);

    await tester.tap(find.text('Jamal'));
    await tester.pumpAndSettle();

    // Belum dipesan berarti belum ada yang bisa dipasang.
    expect(find.text('PART SUDAH DIPASANG'), findsNothing);
    expect(find.text('STOK'), findsOneWidget);
    expect(find.text('CATATAN'), findsOneWidget);
  });

  testWidgets('admin mendapat tahap penuh', (tester) async {
    await _lukis(tester, [_pesanan(id: '1')], admin: true);

    await tester.tap(find.text('Jamal'));
    await tester.pumpAndSettle();

    expect(find.text('TAHAP'), findsOneWidget);
    expect(find.text('PART SUDAH DIPASANG'), findsNothing);
  });

  testWidgets('daftar kosong tetap bisa ditarik untuk disegarkan', (
    tester,
  ) async {
    await _lukis(tester, const []);

    expect(tester.takeException(), isNull);
    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.text('Belum ada pesanan part'), findsOneWidget);
  });
}
