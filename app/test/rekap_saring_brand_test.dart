// Halaman Rekap (bukan Rekap Brand): penyaring brand.
//
// Rekap memuat empat kartu -- ringkasan status, klaim per brand, teknisi
// per brand, riwayat pindah teknisi -- dan semuanya harus ikut menyempit
// ke satu brand saat brand itu dipilih. Yang dijaga: penyaringnya tidak
// membuang baris brand lain yang namanya mirip, dan yang ditampilkan
// saat "semua brand" tidak berubah dari sebelumnya.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/core/theme.dart';
import 'package:sc_management/features/reports/reports_view.dart';

Claim _klaim(String id, int brandId, {String status = 'proses'}) => Claim(
  id: id,
  tanggal: DateTime(2026, 9, 1),
  brandId: brandId,
  namaPelanggan: 'P$id',
  sn: 'SN$id',
  jenis: 'brand',
  status: status,
  createdBy: 'a',
  createdAt: DateTime(2026, 9, 1),
  updatedAt: DateTime(2026, 9, 1),
);

final _klaim6 = [
  _klaim('1', 1),
  _klaim('2', 1, status: 'selesai'),
  _klaim('3', 1, status: 'selesai'),
  _klaim('4', 2),
  _klaim('5', 2, status: 'batal'),
  _klaim('6', 3),
];

final _perBrand = [
  {'brand': 'ASUS', 'kuartal': '2026-07-01', 'jumlah_klaim': 3},
  {'brand': 'MSI', 'kuartal': '2026-07-01', 'jumlah_klaim': 2},
  {'brand': 'ACER', 'kuartal': '2026-07-01', 'jumlah_klaim': 1},
];

final _perTeknisi = [
  {
    'brand': 'ASUS',
    'teknisi': 'Budi',
    'kuartal': '2026-07-01',
    'jumlah_dikerjakan': 3,
  },
  {
    'brand': 'MSI',
    'teknisi': 'Agus',
    'kuartal': '2026-07-01',
    'jumlah_dikerjakan': 2,
  },
];

final _pindah = [
  {
    'brand': 'ASUS',
    'no_perbaikan': 'IDD-ASUS-1',
    'sn': 'S1',
    'dari_teknisi': null,
    'ke_teknisi': 'Reza',
    'diubah_oleh': 'admin',
    'diubah_pada': '2026-09-01T02:00:00Z',
  },
  {
    'brand': 'MSI',
    'no_perbaikan': 'IDD-MSI-1',
    'sn': 'S2',
    'dari_teknisi': 'Irwan',
    'ke_teknisi': 'Reza',
    'diubah_oleh': 'admin',
    'diubah_pada': '2026-09-02T02:00:00Z',
  },
];

void main() {
  group('hitungStatusKlaim', () {
    test('tanpa brand menghitung semuanya', () {
      expect(hitungStatusKlaim(_klaim6), {
        'proses': 3,
        'selesai': 2,
        'batal': 1,
      });
    });

    test('dengan brand hanya menghitung klaim brand itu', () {
      expect(hitungStatusKlaim(_klaim6, brandId: 1), {
        'proses': 1,
        'selesai': 2,
      });
      expect(hitungStatusKlaim(_klaim6, brandId: 2), {'proses': 1, 'batal': 1});
    });

    test('brand tanpa klaim menghasilkan daftar kosong, bukan galat', () {
      expect(hitungStatusKlaim(_klaim6, brandId: 99), isEmpty);
    });
  });

  group('saringMenurutBrand', () {
    test('tanpa brand mengembalikan semuanya', () {
      expect(saringMenurutBrand(_perBrand, null), _perBrand);
    });

    test('hanya baris brand itu, tanpa peduli huruf besar kecil', () {
      expect(saringMenurutBrand(_perBrand, 'asus').map((r) => r['brand']), [
        'ASUS',
      ]);
      expect(saringMenurutBrand(_perBrand, ' MSI ').map((r) => r['brand']), [
        'MSI',
      ]);
    });

    test('nama yang mirip tidak ikut terbawa', () {
      // "AS" bukan "ASUS"; pencocokan sebagian akan membawa keduanya.
      expect(saringMenurutBrand(_perBrand, 'AS'), isEmpty);
    });

    test('baris tanpa nama brand tidak membuat galat', () {
      expect(
        saringMenurutBrand([
          {'brand': null},
          {'jumlah': 1},
        ], 'ASUS'),
        isEmpty,
      );
    });
  });

  group('Halaman', () {
    Future<void> lukis(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allClaimsProvider.overrideWith((ref) => Stream.value(_klaim6)),
            allBrandsProvider.overrideWith(
              (ref) => Stream.value(const [
                Brand(id: 1, nama: 'ASUS'),
                Brand(id: 2, nama: 'MSI'),
                Brand(id: 3, nama: 'ACER'),
              ]),
            ),
            rekapBrandKuartalProvider.overrideWith((ref) async => _perBrand),
            rekapTeknisiBrandProvider.overrideWith((ref) async => _perTeknisi),
            riwayatPindahTeknisiProvider.overrideWith((ref) async => _pindah),
          ],
          child: MaterialApp(
            theme: AppTheme.terang(),
            home: const Scaffold(body: ReportsView()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> pilihBrand(WidgetTester tester, String nama) async {
      await tester.tap(find.byType(DropdownButton<int?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(nama).last);
      await tester.pumpAndSettle();
    }

    testWidgets('bawaannya semua brand, seperti sebelumnya', (tester) async {
      await lukis(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('SEMUA BRAND'), findsOneWidget);
      expect(find.text('6'), findsWidgets); // total klaim
      expect(find.text('TOTAL KLAIM'), findsOneWidget);
      // Ketiga brand ada di kartu Klaim per Brand.
      expect(find.text('ASUS'), findsWidgets);
      expect(find.text('MSI'), findsWidgets);
      expect(find.text('ACER'), findsWidgets);
    });

    testWidgets('memilih brand menyempitkan keempat kartu', (tester) async {
      await lukis(tester);
      await pilihBrand(tester, 'MSI');

      expect(tester.takeException(), isNull);

      // Ringkasan: klaim MSI saja (2 dari 6).
      expect(find.text('TOTAL KLAIM  ·  MSI'), findsOneWidget);
      expect(find.text('2'), findsWidgets);

      // Klaim per Brand: hanya baris MSI.
      expect(find.text('ASUS'), findsNothing);
      expect(find.text('ACER'), findsNothing);

      // Teknisi per Brand: hanya Agus yang mengerjakan MSI.
      expect(find.text('Agus'), findsOneWidget);
      expect(find.text('Budi'), findsNothing);

      // Riwayat pindah: hanya yang MSI.
      expect(find.textContaining('IDD-MSI-1'), findsOneWidget);
      expect(find.textContaining('IDD-ASUS-1'), findsNothing);
    });

    testWidgets('brand tanpa data menjelaskan kosongnya, menyebut brandnya', (
      tester,
    ) async {
      await lukis(tester);
      await pilihBrand(tester, 'ACER');

      expect(tester.takeException(), isNull);
      expect(
        find.text('Belum ada teknisi yang mengerjakan klaim ACER.'),
        findsOneWidget,
      );
      expect(
        find.text('Belum ada klaim ACER yang berpindah teknisi.'),
        findsOneWidget,
      );
    });

    testWidgets('kembali ke semua brand memulihkan seluruh kartu', (
      tester,
    ) async {
      await lukis(tester);
      await pilihBrand(tester, 'MSI');
      await pilihBrand(tester, 'SEMUA BRAND');

      expect(find.text('TOTAL KLAIM'), findsOneWidget);
      expect(find.text('Budi'), findsWidgets);
      expect(find.textContaining('IDD-ASUS-1'), findsOneWidget);
    });

    testWidgets('di layar sempit penyaringnya pindah ke bawah kepala', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(420, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allClaimsProvider.overrideWith((ref) => Stream.value(_klaim6)),
            allBrandsProvider.overrideWith(
              (ref) => Stream.value(const [Brand(id: 1, nama: 'ASUS')]),
            ),
            rekapBrandKuartalProvider.overrideWith((ref) async => _perBrand),
            rekapTeknisiBrandProvider.overrideWith((ref) async => _perTeknisi),
            riwayatPindahTeknisiProvider.overrideWith((ref) async => _pindah),
          ],
          child: MaterialApp(
            theme: AppTheme.terang(),
            home: const Scaffold(body: ReportsView()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('SEMUA BRAND'), findsOneWidget);
    });
  });
}
