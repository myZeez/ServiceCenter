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
      _nota(noNota: 'SVR-001', nama: 'Jamal'),
      _nota(noNota: 'SVR-002', nama: 'Soni', status: 'masuk'),
    ]);

    expect(tester.takeException(), isNull);
    expect(find.text('SVR-001'), findsOneWidget);
    expect(find.text('Jamal'), findsOneWidget);
    expect(find.text('Soni'), findsOneWidget);
  });

  testWidgets('saringan status menyembunyikan yang lain', (tester) async {
    await _lukis(tester, [
      _nota(noNota: 'SVR-001', nama: 'Jamal'),
      _nota(noNota: 'SVR-002', nama: 'Soni', status: 'masuk'),
    ]);

    await tester.tap(find.text('MASUK  1'));
    await tester.pumpAndSettle();

    expect(find.text('Soni'), findsOneWidget);
    expect(find.text('Jamal'), findsNothing);
  });

  testWidgets('mengetuk nota membuka lembar ubah pekerjaan', (tester) async {
    await _lukis(tester, [_nota(noNota: 'SVR-001', nama: 'Jamal')]);

    await tester.tap(find.text('Jamal'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Hanya kolom pekerjaan yang boleh disentuh teknisi.
    expect(find.text('STATUS'), findsOneWidget);
    expect(find.text('TEKNISI'), findsOneWidget);
    expect(find.text('KELUHAN PELANGGAN'), findsOneWidget);
    expect(find.text('Mati total'), findsWidgets);
    expect(find.text('PERBAIKAN'), findsOneWidget);
    expect(find.text('SIMPAN'), findsOneWidget);
    // Yang tidak boleh disentuh tidak ditampilkan sama sekali, supaya tidak
    // ada kolom yang bisa diketik lalu ditolak server.
    expect(find.text('BIAYA'), findsNothing);
    expect(find.textContaining('diubah dari meja depan'), findsOneWidget);
  });

  testWidgets('nota garansi brand menampilkan status klaim dan nota', (
    tester,
  ) async {
    final nota = ServiceOrderEntry(
      id: 'n1',
      noNota: 'SVR-009',
      tanggalMasuk: DateTime(2026, 9, 4),
      customerNama: 'Rara',
      barangNama: 'ASUS',
      keluhan: 'Mati total',
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

    // Di daftar, dua chip menjelaskan proses klaim dan posisi unit.
    expect(find.text('PART READY'), findsOneWidget);
    expect(find.text('DIKERJAKAN'), findsOneWidget);

    await tester.tap(find.text('Rara'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('STATUS NOTA'), findsOneWidget);
    expect(find.text('STATUS GARANSI'), findsOneWidget);
    expect(find.text('Dikerjakan'), findsOneWidget);
    expect(find.text('Part Ready'), findsOneWidget);

    // Teknisi menulis hasil pengecekannya di sini. Keluhan pelanggan
    // disebut sebagai pembanding, tidak disalin ke kolomnya.
    expect(find.text('KELUHAN GARANSI'), findsOneWidget);
    expect(find.text('Keluhan pelanggan: Mati total'), findsOneWidget);
  });

  testWidgets('daftar kosong tetap bisa ditarik untuk disegarkan', (
    tester,
  ) async {
    await _lukis(tester, []);

    expect(tester.takeException(), isNull);
    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.text('Belum ada nota'), findsOneWidget);
  });

  group('kotak pencarian', () {
    testWidgets('menyaring daftar menurut nama, tanpa menyentuh yang lain', (
      tester,
    ) async {
      await _lukis(tester, [
        _nota(noNota: 'SVR-001', nama: 'Jamal'),
        _nota(noNota: 'SVR-002', nama: 'Soni'),
      ]);

      await tester.enterText(find.byType(TextField), 'soni');
      await tester.pumpAndSettle();

      expect(find.text('Soni'), findsOneWidget);
      expect(find.text('Jamal'), findsNothing);
    });

    testWidgets('cukup ekor nomor notanya', (tester) async {
      await _lukis(tester, [
        _nota(noNota: 'SVR-08092628272', nama: 'Jamal'),
        _nota(noNota: 'SVR-08092628999', nama: 'Soni'),
      ]);

      await tester.enterText(find.byType(TextField), '28272');
      await tester.pumpAndSettle();

      expect(find.text('Jamal'), findsOneWidget);
      expect(find.text('Soni'), findsNothing);
    });

    testWidgets('angka di chip status ikut hasil pencarian', (tester) async {
      await _lukis(tester, [
        _nota(noNota: 'SVR-001', nama: 'Jamal'),
        _nota(noNota: 'SVR-002', nama: 'Soni', status: 'masuk'),
        _nota(noNota: 'SVR-003', nama: 'Soraya', status: 'masuk'),
      ]);
      expect(find.text('MASUK  2'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'sora');
      await tester.pumpAndSettle();

      expect(find.text('SEMUA'), findsOneWidget);
      expect(find.text('MASUK  1'), findsOneWidget);
      // Status yang tidak punya satu pun di hasil pencarian tidak ditawarkan.
      expect(find.text('DIKERJAKAN  1'), findsNothing);
    });

    testWidgets('yang tak cocok menyebutnya, bukan mengaku belum ada nota', (
      tester,
    ) async {
      await _lukis(tester, [_nota(noNota: 'SVR-001', nama: 'Jamal')]);

      await tester.enterText(find.byType(TextField), 'tidak-ada-ini');
      await tester.pumpAndSettle();

      expect(find.text('Tidak ada nota yang cocok'), findsOneWidget);
      expect(find.text('Belum ada nota'), findsNothing);
    });

    testWidgets(
      'status terpilih tidak lenyap walau hasil cari tak memilikinya',
      (tester) async {
        await _lukis(tester, [
          _nota(noNota: 'SVR-001', nama: 'Jamal'),
          _nota(noNota: 'SVR-002', nama: 'Soni', status: 'masuk'),
        ]);
        await tester.tap(find.text('MASUK  1'));
        await tester.pumpAndSettle();

        // Mencari yang tak ada di status itu: chip-nya harus tetap ada supaya
        // saringannya masih bisa dilepas.
        await tester.enterText(find.byType(TextField), 'jamal');
        await tester.pumpAndSettle();

        expect(find.text('MASUK  0'), findsOneWidget);
        expect(find.text('Tidak ada nota berstatus ini'), findsOneWidget);

        await tester.tap(find.text('SEMUA'));
        await tester.pumpAndSettle();
        expect(find.text('Jamal'), findsOneWidget);
      },
    );

    testWidgets('tombol hapus mengembalikan seluruh daftar', (tester) async {
      await _lukis(tester, [
        _nota(noNota: 'SVR-001', nama: 'Jamal'),
        _nota(noNota: 'SVR-002', nama: 'Soni'),
      ]);

      await tester.enterText(find.byType(TextField), 'soni');
      await tester.pumpAndSettle();
      expect(find.text('Jamal'), findsNothing);

      await tester.tap(find.byTooltip('Hapus kata pencarian'));
      await tester.pumpAndSettle();

      expect(find.text('Jamal'), findsOneWidget);
      expect(find.text('Soni'), findsOneWidget);
      expect(find.byTooltip('Hapus kata pencarian'), findsNothing);
    });
  });
}
