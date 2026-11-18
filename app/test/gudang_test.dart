// Role gudang: melihat pesanan part beserta modalnya, dan mengisi data
// pembelian. Kunci sebenarnya ada di server; yang dijaga di sini adalah
// yang dilihat orang -- gudang tidak ditawari formulir yang akan ditolak,
// dan yang tidak berhak tidak melihat modal.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/export/excel_export.dart';
import 'package:sc_management/core/peran.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/features/parts/gudang_dialog.dart';
import 'package:sc_management/features/parts/part_orders_view.dart';
import 'package:sc_management/features/parts/part_status.dart';
import 'package:sc_management/features/shell/admin_shell.dart';

PartOrder _pesanan(
  String id, {
  String nama = 'JAMAL',
  DateTime? dp,
  double? harga = 500000,
  String? po,
  String tahap = PartTahap.dipesan,
}) => PartOrder(
  id: id,
  tanggal: DateTime(2026, 9, 1),
  customerNama: nama,
  barangType: 'LAPTOP ASUS X441',
  partReq: 'KEYBOARD',
  tahap: tahap,
  harga: harga,
  dp: 0,
  noPo: po,
  tanggalDp: dp ?? DateTime(2026, 10, 5),
  updatedAt: DateTime(2026, 10, 5),
);

Future<void> _lukis(
  WidgetTester tester, {
  required List<PartOrder> pesanan,
  List<PartCost> modal = const [],
  bool gudang = true,
  bool admin = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(1500, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        isGudangProvider.overrideWithValue(gudang),
        isAdminProvider.overrideWithValue(admin),
        partOrdersProvider.overrideWith((ref) => Stream.value(pesanan)),
        partCostsProvider.overrideWith((ref) => Stream.value(modal)),
        partSettingsProvider.overrideWith((ref) => Stream.value(null)),
        allProfilesProvider.overrideWith((ref) => Stream.value(const [])),
        customersProvider.overrideWith((ref) => Stream.value(const [])),
        serviceOrdersProvider.overrideWith((ref) => Stream.value(const [])),
        allMetodeBayarProvider.overrideWith((ref) => Stream.value(const [])),
      ],
      child: const MaterialApp(home: Scaffold(body: PartOrdersView())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('peran gudang', () {
    test('namanya', () {
      expect(Peran.label('gudang'), 'Gudang');
    });

    test(
      'menunya hanya pesanan part, tanpa bergantung pada fitur tanya harga',
      () {
        for (final ada in [true, false]) {
          expect(menuUntuk(Peran.gudang, adaPart: ada).map((b) => b.label), [
            'Pemesanan Part',
          ]);
        }
      },
    );

    ProviderContainer sebagai(String peran) {
      final c = ProviderContainer(
        overrides: [
          currentProfileProvider.overrideWithValue(
            Profile(id: 'saya', nama: 'Saya', role: peran),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('gudang bukan admin, tapi boleh membaca modal', () {
      final c = sebagai(Peran.gudang);

      expect(c.read(isGudangProvider), isTrue);
      expect(c.read(isAdminProvider), isFalse);
      expect(c.read(isSuperAdminProvider), isFalse);
      expect(c.read(hakModalProvider), isTrue);
    });

    test('admin dan super admin membaca modal, teknisi tidak', () {
      expect(sebagai(Peran.admin).read(hakModalProvider), isTrue);
      expect(sebagai(Peran.superAdmin).read(hakModalProvider), isTrue);
      expect(sebagai(Peran.teknisi).read(hakModalProvider), isFalse);
      expect(sebagai(Peran.adminSc).read(hakModalProvider), isFalse);
    });

    test('gudang tidak muncul sebagai pilihan teknisi', () async {
      final c = ProviderContainer(
        overrides: [
          allProfilesProvider.overrideWith(
            (ref) => Stream.value(const [
              Profile(id: 'b', nama: 'Budi', role: 'teknisi'),
              Profile(id: 'g', nama: 'Gudang', role: 'gudang'),
              Profile(id: 's', nama: 'Super', role: 'super_admin'),
            ]),
          ),
        ],
      );
      addTearDown(c.dispose);
      await c.read(allProfilesProvider.future);

      expect(c.read(techniciansProvider).valueOrNull!.map((p) => p.nama), [
        'Budi',
      ]);
      expect(c.read(pengerjaProvider).map((p) => p.nama), ['Budi']);
    });
  });

  group('bulan pesanan', () {
    final semua = [
      _pesanan('1', dp: DateTime(2026, 10, 5)),
      _pesanan('2', dp: DateTime(2026, 10, 28)),
      _pesanan('3', dp: DateTime(2026, 9, 30)),
      _pesanan('4', dp: DateTime(2025, 12, 31)),
    ];

    test('daftar bulan terbaru lebih dulu, tanpa kembar', () {
      expect(bulanPesanan(semua), [
        DateTime(2026, 10),
        DateTime(2026, 9),
        DateTime(2025, 12),
      ]);
    });

    test('pesanan dikelompokkan menurut tanggal DP', () {
      expect(pesananBulan(semua, DateTime(2026, 10)).map((p) => p.id), [
        '1',
        '2',
      ]);
      expect(pesananBulan(semua, null).length, 4);
    });

    test('yang belum ada DP memakai tanggal tanya', () {
      final p = PartOrder(
        id: 'x',
        tanggal: DateTime(2026, 3, 3),
        customerNama: 'A',
        partReq: 'LCD',
        tahap: PartTahap.dipesan,
        updatedAt: DateTime(2026, 3, 3),
      );

      expect(pesananBulan([p], DateTime(2026, 3)).length, 1);
    });
  });

  group('halaman pemesanan', () {
    testWidgets('gudang melihat HPP, untung, dan No PO', (tester) async {
      await _lukis(
        tester,
        pesanan: [_pesanan('1', po: 'IDD7M10008')],
        modal: const [PartCost(partOrderId: '1', hpp: 310000)],
      );

      expect(tester.takeException(), isNull);
      expect(find.text('HPP'), findsOneWidget);
      expect(find.text('Rp310.000'), findsOneWidget);
      expect(find.text('Rp190.000'), findsOneWidget);
      expect(find.text('IDD7M10008'), findsOneWidget);
    });

    testWidgets('yang tidak berhak membaca modal tidak melihat kolomnya', (
      tester,
    ) async {
      await _lukis(
        tester,
        pesanan: [_pesanan('1')],
        gudang: false,
        admin: false,
        modal: const [PartCost(partOrderId: '1', hpp: 310000)],
      );

      expect(find.text('HPP'), findsNothing);
      expect(find.text('Rp310.000'), findsNothing);
    });

    testWidgets('gudang membuka data pembelian, bukan formulir tanya harga', (
      tester,
    ) async {
      await _lukis(
        tester,
        pesanan: [_pesanan('1', nama: 'JAMAL')],
        modal: const [PartCost(partOrderId: '1', hpp: 310000)],
      );

      await tester.tap(find.text('JAMAL'));
      await tester.pumpAndSettle();

      expect(find.text('Data pembelian part'), findsOneWidget);
      expect(find.text('HPP (MODAL)'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('NO PO'),
        ),
        findsOneWidget,
      );
      // Yang bukan urusan gudang tidak ditawarkan.
      expect(find.text('USER DP'), findsNothing);
      expect(find.text('HARGA JUAL'), findsNothing);
    });

    testWidgets('selalu satu bulan, dimulai dari yang terbaru', (tester) async {
      await _lukis(
        tester,
        pesanan: [
          _pesanan('1', nama: 'OKTOBER', dp: DateTime(2026, 10, 5)),
          _pesanan('2', nama: 'SEPTEMBER', dp: DateTime(2026, 9, 5)),
        ],
      );

      expect(find.text('OKTOBER'), findsOneWidget);
      expect(find.text('SEPTEMBER'), findsNothing);
      expect(find.text('SEMUA BULAN'), findsNothing);
      expect(find.text('OKTOBER 2026'), findsOneWidget);
    });

    testWidgets('bulan dipilih dari daftar atau digeser dengan panah', (
      tester,
    ) async {
      await _lukis(
        tester,
        pesanan: [
          _pesanan('1', nama: 'OKTOBER', dp: DateTime(2026, 10, 5)),
          _pesanan('2', nama: 'SEPTEMBER', dp: DateTime(2026, 9, 5)),
        ],
      );

      await tester.tap(find.byTooltip('Bulan sebelumnya'));
      await tester.pumpAndSettle();
      expect(find.text('OKTOBER'), findsNothing);
      expect(find.text('SEPTEMBER'), findsOneWidget);

      await tester.tap(find.byTooltip('Bulan berikutnya'));
      await tester.pumpAndSettle();
      expect(find.text('OKTOBER'), findsOneWidget);

      await tester.tap(find.text('OKTOBER 2026'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SEPTEMBER 2026').last);
      await tester.pumpAndSettle();
      expect(find.text('SEPTEMBER'), findsOneWidget);
      expect(find.text('OKTOBER'), findsNothing);
    });
  });

  group('kelompok pesanan', () {
    final campur = [
      _pesanan('1', nama: 'ANDI', tahap: PartTahap.dipesan),
      _pesanan('2', nama: 'BUDI', tahap: PartTahap.dipasang),
      _pesanan('3', nama: 'CINDY', tahap: PartTahap.selesai),
      _pesanan('4', nama: 'DEDI', tahap: PartTahap.batal),
      _pesanan('5', nama: 'EKO', tahap: PartTahap.konfirmasi),
    ];

    test('batal sesudah DP ikut, tanya harga yang belum DP tidak', () {
      final tanpaDp = PartOrder(
        id: '9',
        tanggal: DateTime(2026, 9, 1),
        customerNama: 'BATAL SEBELUM DP',
        partReq: 'LCD',
        tahap: PartTahap.batal,
        updatedAt: DateTime(2026, 9, 1),
      );

      final hasil = pesananPemesanan([...campur, tanpaDp]);

      expect(hasil.map((p) => p.id), ['1', '2', '3', '4']);
    });

    test('belum selesai = dipesan dan dipasang, tanpa selesai dan batal', () {
      expect(pesananKelompok(campur, KelompokPesanan.belum).map((p) => p.id), [
        '1',
        '2',
      ]);
      expect(
        pesananKelompok(campur, KelompokPesanan.selesai).map((p) => p.id),
        ['3'],
      );
      expect(pesananKelompok(campur, KelompokPesanan.batal).map((p) => p.id), [
        '4',
      ]);
    });

    test('tiap pesanan masuk tepat satu kelompok, semua memuat semuanya', () {
      final dasar = pesananPemesanan(campur);
      final satuan = [
        KelompokPesanan.belum,
        KelompokPesanan.selesai,
        KelompokPesanan.batal,
      ];

      expect(
        satuan.fold<int>(0, (a, k) => a + pesananKelompok(dasar, k).length),
        dasar.length,
      );
      expect(
        pesananKelompok(dasar, KelompokPesanan.semua).length,
        dasar.length,
      );
    });

    testWidgets('kartu kelompok memisahkan yang selesai dan yang belum', (
      tester,
    ) async {
      await _lukis(tester, pesanan: campur);

      expect(find.text('ANDI'), findsOneWidget);
      expect(find.text('CINDY'), findsOneWidget);
      expect(find.text('DEDI'), findsOneWidget);
      expect(find.text('EKO'), findsNothing);

      await tester.tap(find.text('BELUM SELESAI'));
      await tester.pumpAndSettle();
      expect(find.text('ANDI'), findsOneWidget);
      expect(find.text('BUDI'), findsOneWidget);
      expect(find.text('CINDY'), findsNothing);
      expect(find.text('DEDI'), findsNothing);

      await tester.tap(find.text('SELESAI').first);
      await tester.pumpAndSettle();
      expect(find.text('ANDI'), findsNothing);
      expect(find.text('CINDY'), findsOneWidget);

      await tester.tap(find.text('BATAL').first);
      await tester.pumpAndSettle();
      expect(find.text('DEDI'), findsOneWidget);
      expect(find.text('CINDY'), findsNothing);
    });

    testWidgets('dua tombol ekspor: sesuai tampilan dan lengkap', (
      tester,
    ) async {
      await _lukis(tester, pesanan: campur);

      expect(find.text('EXCEL TAMPILAN'), findsOneWidget);
      expect(find.text('EXCEL LENGKAP'), findsOneWidget);
    });

    test('lembar ekspor bisa diberi nama sendiri', () {
      final l = ExcelExport.lembarPart(
        pesanan: campur,
        teknisi: const {},
        modal: const {},
        periode: 'Lengkap - SELESAI',
        namaLembar: 'SELESAI',
      );

      expect(l.nama, 'SELESAI');
    });
  });

  group('dialog pembelian', () {
    testWidgets('HPP terisi dari modal dan untung dihitung', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            partCostsProvider.overrideWith(
              (ref) =>
                  Stream.value(const [PartCost(partOrderId: '1', hpp: 310000)]),
            ),
          ],
          child: MaterialApp(
            home: GudangPembelianDialog(pesanan: _pesanan('1', po: 'PO-1')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, '310000'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'PO-1'), findsOneWidget);
      expect(find.text('Untung Rp190.000'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, '310000'),
        '400000',
      );
      await tester.pump();
      expect(find.text('Untung Rp100.000'), findsOneWidget);
    });
  });
}
