// Halaman Kerja Teknisi, dan status garansi yang tampil di nota.
//
// Penyaringnya keluaran murni dari daftar nota, jadi diuji tanpa server.
// Yang dijaga: nota tanpa teknisi tidak tercecer ke daftar siapa pun, dan
// pencarian tidak terkurung bulan yang kebetulan sedang dipilih.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/features/service/kerja_teknisi_view.dart';
import 'package:sc_management/features/service/service_status.dart';

ServiceOrderEntry _nota(
  String no, {
  String? teknisi,
  DateTime? masuk,
  String status = 'dikerjakan',
  String nama = 'Pelanggan',
  String? claimId,
  bool garansi = false,
}) => ServiceOrderEntry(
  id: no,
  noNota: no,
  tanggalMasuk: masuk ?? DateTime(2026, 9, 4),
  customerNama: nama,
  barangNama: 'LAPTOP',
  teknisiId: teknisi,
  status: status,
  claimId: claimId,
  garansi: garansi,
  updatedAt: DateTime(2026, 9, 4),
);

Claim _klaim(String id, {String status = 'open', String jenis = 'brand'}) =>
    Claim(
      id: id,
      tanggal: DateTime(2026, 9, 4),
      brandId: 1,
      namaPelanggan: 'Pelanggan',
      sn: 'SN1',
      jenis: jenis,
      status: status,
      createdBy: 'a',
      createdAt: DateTime(2026, 9, 4),
      updatedAt: DateTime(2026, 9, 4),
    );

void main() {
  group('hitungPerTeknisi', () {
    test('nota tanpa teknisi dihitung terpisah', () {
      final h = hitungPerTeknisi([
        _nota('1', teknisi: 'budi'),
        _nota('2', teknisi: 'budi'),
        _nota('3'),
        _nota('4', teknisi: 'aris'),
      ]);
      expect(h, {'budi': 2, belumAdaTeknisi: 1, 'aris': 1});
    });

    test('bulan membatasi hitungannya', () {
      final h = hitungPerTeknisi([
        _nota('1', teknisi: 'budi', masuk: DateTime(2026, 8, 30)),
        _nota('2', teknisi: 'budi', masuk: DateTime(2026, 9, 1)),
        _nota('3', masuk: DateTime(2026, 1, 5)),
      ], bulan: DateTime(2026, 9));
      expect(h, {'budi': 1});
    });
  });

  group('notaMilik', () {
    final semua = [
      _nota('SVR-1', teknisi: 'budi', masuk: DateTime(2026, 8, 3)),
      _nota('SVR-2', teknisi: 'budi', status: 'diambil'),
      _nota('SVR-3', nama: 'Jamal'),
      _nota('SVR-4', masuk: DateTime(2026, 1, 12), nama: 'Jamal'),
      _nota('SVR-5', teknisi: 'aris'),
    ];

    test('belum ada teknisi hanya memuat yang teknisinya kosong', () {
      final l = notaMilik(semua, teknisi: belumAdaTeknisi);
      expect(l.map((n) => n.noNota), ['SVR-3', 'SVR-4']);
    });

    test('satu teknisi hanya memuat notanya sendiri', () {
      final l = notaMilik(semua, teknisi: 'budi');
      expect(l.map((n) => n.noNota), ['SVR-1', 'SVR-2']);
    });

    test('bulan menyaring menurut tanggal masuk', () {
      final l = notaMilik(semua, teknisi: 'budi', bulan: DateTime(2026, 9));
      expect(l.map((n) => n.noNota), ['SVR-2']);
    });

    test('pencarian melepas batas bulan, tidak batas teknisi', () {
      final l = notaMilik(
        semua,
        teknisi: belumAdaTeknisi,
        bulan: DateTime(2026, 9),
        cari: 'jamal',
      );
      expect(l.map((n) => n.noNota), ['SVR-3', 'SVR-4']);
    });

    test('kelompok status', () {
      expect(
        notaMilik(
          semua,
          teknisi: 'budi',
          kelompok: KelompokKerja.berjalan,
        ).map((n) => n.noNota),
        ['SVR-1'],
      );
      expect(
        notaMilik(
          semua,
          teknisi: 'budi',
          kelompok: KelompokKerja.diambil,
        ).map((n) => n.noNota),
        ['SVR-2'],
      );
    });
  });

  group('halaman', () {
    Future<void> lukis(WidgetTester tester, List<ServiceOrderEntry> nota) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serviceOrdersProvider.overrideWith((ref) => Stream.value(nota)),
            allProfilesProvider.overrideWith(
              (ref) => Stream.value([
                const Profile(id: 'budi', nama: 'Budi', role: 'teknisi'),
                const Profile(id: 'aris', nama: 'Aris', role: 'teknisi'),
              ]),
            ),
            allClaimsProvider.overrideWith((ref) => Stream.value(const [])),
            allBrandsProvider.overrideWith((ref) => Stream.value(const [])),
          ],
          child: const MaterialApp(home: Scaffold(body: KerjaTeknisiView())),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('dibuka pada nota yang belum ada teknisinya', (tester) async {
      await lukis(tester, [
        _nota('SVR-1', teknisi: 'budi', nama: 'Jamal'),
        _nota('SVR-2', nama: 'Soni'),
      ]);

      expect(tester.takeException(), isNull);
      expect(find.text('Soni'), findsOneWidget);
      expect(find.text('Jamal'), findsNothing);
      // Barisnya menawarkan pilihan teknisi, bukan tanda strip.
      expect(find.text('PILIH TEKNISI'), findsOneWidget);
    });

    testWidgets('memilih nama menampilkan deretan pekerjaannya', (
      tester,
    ) async {
      await lukis(tester, [
        _nota('SVR-1', teknisi: 'budi', nama: 'Jamal'),
        _nota('SVR-2', teknisi: 'budi', nama: 'Rara'),
        _nota('SVR-3', teknisi: 'aris', nama: 'Soni'),
      ]);

      await tester.tap(find.text('BUDI'));
      await tester.pumpAndSettle();

      expect(find.text('Jamal'), findsOneWidget);
      expect(find.text('Rara'), findsOneWidget);
      expect(find.text('Soni'), findsNothing);
    });
  });

  group('StatusNotaChip', () {
    Future<void> lukis(
      WidgetTester tester,
      ServiceOrderEntry nota,
      List<Claim> klaim,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allClaimsProvider.overrideWith((ref) => Stream.value(klaim)),
            allBrandsProvider.overrideWith(
              (ref) => Stream.value([const Brand(id: 1, nama: 'ASUS')]),
            ),
          ],
          child: MaterialApp(home: Scaffold(body: StatusNotaChip(nota))),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('nota garansi brand memakai status klaimnya', (tester) async {
      await lukis(
        tester,
        _nota('SVR-1', garansi: true, claimId: 'k1'),
        [_klaim('k1', status: 'ship_pusat')],
      );
      expect(find.text('SHIP ASUS PUSAT'), findsOneWidget);
    });

    testWidgets('garansi toko tetap memakai status nota', (tester) async {
      await lukis(
        tester,
        _nota('SVR-1', garansi: true, claimId: 'k1', status: 'selesai'),
        [_klaim('k1', status: 'selesai', jenis: 'toko')],
      );
      expect(find.text('SELESAI'), findsOneWidget);
    });

    testWidgets('servis reguler tetap memakai status nota', (tester) async {
      await lukis(tester, _nota('SVR-1', status: 'diambil'), const []);
      expect(find.text('SUDAH DIAMBIL'), findsOneWidget);
    });
  });
}
