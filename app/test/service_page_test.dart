// Halaman servis di layar sempit.
//
// Ada karena halaman ini sebelumnya hanya dibuat untuk layar lebar, jadi
// teknisi yang memegang unitnya tidak punya satu pun cara menandai
// pekerjaannya selesai dari HP.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/features/service/service_page.dart';

ServiceOrderEntry _nota({
  required String noNota,
  String nama = 'Budi',
  String status = 'dikerjakan',
  String? teknisi = 't1',
  double biaya = 0,
}) => ServiceOrderEntry(
  id: noNota,
  noNota: noNota,
  tanggalMasuk: DateTime(2026, 9, 4),
  customerNama: nama,
  barangNama: 'ASUS',
  barangType: 'X441',
  keluhan: 'Mati total',
  teknisiId: teknisi,
  status: status,
  biaya: biaya,
  updatedAt: DateTime(2026, 9, 4),
);

Future<void> _lukis(WidgetTester tester, List<ServiceOrderEntry> nota) async {
  await tester.binding.setSurfaceSize(const Size(400, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        serviceOrdersProvider.overrideWith((ref) => Stream.value(nota)),
        allProfilesProvider.overrideWith(
          (ref) => Stream.value([
            const Profile(id: 't1', nama: 'Reza', role: 'teknisi'),
          ]),
        ),
        koneksiProvider.overrideWith((ref) => Stream.value(true)),
      ],
      child: const MaterialApp(home: ServicePage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('menampilkan antrean nota', (tester) async {
    await _lukis(tester, [
      _nota(noNota: 'SRV-001', nama: 'Jamal'),
      _nota(noNota: 'SRV-002', nama: 'Soni', status: 'masuk'),
    ]);

    expect(tester.takeException(), isNull);
    expect(find.text('SRV-001'), findsOneWidget);
    expect(find.text('Jamal'), findsOneWidget);
    expect(find.text('Soni'), findsOneWidget);
  });

  testWidgets('saringan status menyembunyikan yang lain', (tester) async {
    await _lukis(tester, [
      _nota(noNota: 'SRV-001', nama: 'Jamal'),
      _nota(noNota: 'SRV-002', nama: 'Soni', status: 'masuk'),
    ]);

    await tester.tap(find.text('MASUK  1'));
    await tester.pumpAndSettle();

    expect(find.text('Soni'), findsOneWidget);
    expect(find.text('Jamal'), findsNothing);
  });

  testWidgets('mengetuk nota membuka lembar ubah pekerjaan', (tester) async {
    await _lukis(tester, [_nota(noNota: 'SRV-001', nama: 'Jamal')]);

    await tester.tap(find.text('Jamal'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Hanya kolom pekerjaan yang boleh disentuh teknisi.
    expect(find.text('STATUS'), findsOneWidget);
    expect(find.text('TEKNISI'), findsOneWidget);
    expect(find.text('PERBAIKAN'), findsOneWidget);
    expect(find.text('SIMPAN'), findsOneWidget);
    // Yang tidak boleh disentuh tidak ditampilkan sama sekali, supaya tidak
    // ada kolom yang bisa diketik lalu ditolak server.
    expect(find.text('BIAYA'), findsNothing);
    expect(find.textContaining('diubah dari meja depan'), findsOneWidget);
  });

  testWidgets('nota garansi brand memakai status klaimnya', (tester) async {
    final nota = ServiceOrderEntry(
      id: 'n1',
      noNota: 'SRV-009',
      tanggalMasuk: DateTime(2026, 9, 4),
      customerNama: 'Rara',
      barangNama: 'ASUS',
      teknisiId: 't1',
      status: 'dikerjakan',
      garansi: true,
      claimId: 'k1',
      updatedAt: DateTime(2026, 9, 4),
    );

    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serviceOrdersProvider.overrideWith((ref) => Stream.value([nota])),
          allProfilesProvider.overrideWith(
            (ref) => Stream.value([
              const Profile(id: 't1', nama: 'Reza', role: 'teknisi'),
            ]),
          ),
          allClaimsProvider.overrideWith(
            (ref) => Stream.value([
              Claim(
                id: 'k1',
                tanggal: DateTime(2026, 9, 4),
                brandId: 1,
                namaPelanggan: 'Rara',
                sn: 'SN1',
                status: 'part_ready',
                createdBy: 'a',
                createdAt: DateTime(2026, 9, 4),
                updatedAt: DateTime(2026, 9, 4),
              ),
            ]),
          ),
          allBrandsProvider.overrideWith(
            (ref) => Stream.value([const Brand(id: 1, nama: 'ASUS')]),
          ),
          koneksiProvider.overrideWith((ref) => Stream.value(true)),
        ],
        child: const MaterialApp(home: ServicePage()),
      ),
    );
    await tester.pumpAndSettle();

    // Di daftar, chip-nya membaca status klaim, bukan "Dikerjakan".
    expect(find.text('PART READY'), findsOneWidget);

    await tester.tap(find.text('Rara'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('STATUS GARANSI'), findsOneWidget);
    expect(find.text('Part Ready'), findsOneWidget);
  });

  testWidgets('daftar kosong tetap bisa ditarik untuk disegarkan', (
    tester,
  ) async {
    await _lukis(tester, []);

    expect(tester.takeException(), isNull);
    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.text('Belum ada nota'), findsOneWidget);
  });
}
