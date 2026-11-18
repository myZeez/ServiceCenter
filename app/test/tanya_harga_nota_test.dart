// Tanya harga selalu lahir dari nota servis dan tertaut kembali ke sana,
// seperti klaim garansi. Yang dijaga di sini: tidak ada lagi jalan membuat
// tanya harga tanpa nota, data nota ikut terbawa, dan dari tanya harga ada
// jalan kembali ke notanya.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/fitur.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/features/parts/part_dialog.dart';
import 'package:sc_management/features/parts/part_status.dart';
import 'package:sc_management/features/parts/parts_view.dart';
import 'package:sc_management/features/parts/tanya_harga_dari_nota.dart';

ServiceOrderEntry _nota(
  String id, {
  String nama = 'JAMAL',
  String barang = 'Laptop Asus',
  String? type = 'X441BA',
  String? sn = 'SN123',
  String status = 'dikerjakan',
  String? teknisi = 't1',
}) => ServiceOrderEntry(
  id: id,
  noNota: 'SVR-0111262$id',
  tanggalMasuk: DateTime(2026, 11, 1),
  customerNama: nama,
  customerTelp: '0812',
  customerId: 'c$id',
  barangNama: barang,
  barangType: type,
  barangSn: sn,
  teknisiId: teknisi,
  status: status,
  biaya: 0,
  updatedAt: DateTime(2026, 11, 1),
);

PartOrder _tanyaHarga(String notaId, {String tahap = PartTahap.harga}) =>
    PartOrder(
      id: 'p$notaId',
      tanggal: DateTime(2026, 11, 2),
      customerNama: 'JAMAL',
      partReq: 'LCD 14 SLIM',
      tahap: tahap,
      serviceOrderId: notaId,
      updatedAt: DateTime(2026, 11, 2),
    );

List<Override> _dasar({
  List<ServiceOrderEntry> nota = const [],
  List<PartOrder> pesanan = const [],
}) => [
  partOrdersProvider.overrideWith((ref) => Stream.value(pesanan)),
  partCostsProvider.overrideWith((ref) => Stream.value(const [])),
  partSettingsProvider.overrideWith((ref) => Stream.value(null)),
  allProfilesProvider.overrideWith(
    (ref) =>
        Stream.value(const [Profile(id: 't1', nama: 'Reza', role: 'teknisi')]),
  ),
  customersProvider.overrideWith((ref) => Stream.value(const [])),
  serviceOrdersProvider.overrideWith((ref) => Stream.value(nota)),
  koneksiProvider.overrideWith((ref) => Stream.value(true)),
];

Future<void> _lukis(
  WidgetTester tester,
  Widget layar, {
  List<ServiceOrderEntry> nota = const [],
  List<PartOrder> pesanan = const [],
}) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: _dasar(nota: nota, pesanan: pesanan),
      child: MaterialApp(home: Scaffold(body: layar)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('fitur tanya harga menyala', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);

    expect(c.read(fiturTanyaHargaProvider), isTrue);
  });

  group('AwalTanyaHarga.dariNota', () {
    test('membawa pelanggan, unit, SN, dan teknisinya', () {
      final a = AwalTanyaHarga.dariNota(_nota('1'));

      expect(a.notaId, '1');
      expect(a.customerNama, 'JAMAL');
      expect(a.customerTelp, '0812');
      expect(a.customerId, 'c1');
      expect(a.barangType, 'Laptop Asus X441BA');
      expect(a.barangSn, 'SN123');
      expect(a.teknisiId, 't1');
    });

    test('tipe kosong tidak meninggalkan spasi', () {
      final a = AwalTanyaHarga.dariNota(_nota('1', type: null));

      expect(a.barangType, 'Laptop Asus');
    });
  });

  group('saringNotaTanyaHarga', () {
    final semua = [
      _nota('1'),
      _nota('2', nama: 'SARI', sn: 'ABC999'),
      _nota('3', status: 'batal'),
    ];

    test('nota batal tidak ditawarkan', () {
      expect(saringNotaTanyaHarga(semua, '').map((n) => n.id), ['1', '2']);
    });

    test('mencari nomor, nama, barang, dan SN', () {
      expect(saringNotaTanyaHarga(semua, 'sari').map((n) => n.id), ['2']);
      expect(saringNotaTanyaHarga(semua, 'abc999').map((n) => n.id), ['2']);
      expect(saringNotaTanyaHarga(semua, '0111262').length, 2);
      expect(saringNotaTanyaHarga(semua, 'asus').length, 2);
    });

    test('daftar dibatasi', () {
      final banyak = [for (var i = 0; i < 100; i++) _nota('$i')];

      expect(saringNotaTanyaHarga(banyak, '').length, 40);
      expect(saringNotaTanyaHarga(banyak, '', batas: 5).length, 5);
    });
  });

  group('halaman Tanya Harga', () {
    testWidgets('bisa dari nota atau dicatat manual', (tester) async {
      await _lukis(tester, const PartsView());

      expect(find.text('DARI NOTA'), findsWidgets);
      expect(find.text('MANUAL'), findsWidgets);
    });

    testWidgets('manual: formulir kosong, nota bisa ditautkan belakangan', (
      tester,
    ) async {
      await _lukis(tester, const PartsView(), nota: [_nota('1')]);

      await tester.tap(find.text('MANUAL').first);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('BUKA NOTA'), findsNothing);
      expect(find.text('NOTA SERVIS UNTUK JASA PASANG'), findsOneWidget);
    });

    testWidgets('nomor nota asal tampil di barisnya', (tester) async {
      await _lukis(
        tester,
        const PartsView(),
        nota: [_nota('1')],
        pesanan: [_tanyaHarga('1')],
      );

      expect(find.text('SVR-01112621'), findsOneWidget);
    });

    testWidgets('tanya harga lama tanpa nota tidak memuat nomor', (
      tester,
    ) async {
      await _lukis(
        tester,
        const PartsView(),
        pesanan: [
          PartOrder(
            id: 'x',
            tanggal: DateTime(2026, 9, 1),
            customerNama: 'LAMA',
            partReq: 'KEYBOARD',
            tahap: PartTahap.foto,
            updatedAt: DateTime(2026, 9, 1),
          ),
        ],
      );

      expect(tester.takeException(), isNull);
      expect(find.text('LAMA'), findsOneWidget);
    });

    testWidgets('memilih nota membuka formulir yang terisi dari nota', (
      tester,
    ) async {
      await _lukis(tester, const PartsView(), nota: [_nota('1')]);

      await tester.tap(find.text('DARI NOTA').first);
      await tester.pumpAndSettle();
      expect(find.text('Pilih nota servis'), findsOneWidget);

      await tester.tap(find.textContaining('SVR-01112621'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Nota SVR-01112621'), findsOneWidget);
      expect(find.text('BUKA NOTA'), findsOneWidget);
      expect(find.text('JAMAL'), findsWidgets);
    });

    testWidgets('nota yang sudah punya tanya harga membuka yang itu', (
      tester,
    ) async {
      await _lukis(
        tester,
        const PartsView(),
        nota: [_nota('1')],
        pesanan: [_tanyaHarga('1')],
      );

      await tester.tap(find.text('DARI NOTA').first);
      await tester.pumpAndSettle();
      // Tahapnya terlihat di daftar pilihan, jadi tidak membuat yang kedua.
      expect(find.byType(PartTahapChip), findsWidgets);

      await tester.tap(find.textContaining('SVR-01112621').last);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'LCD 14 SLIM'), findsOneWidget);
    });

    testWidgets('pencarian menyaring daftar pilihan', (tester) async {
      await _lukis(
        tester,
        const PartsView(),
        nota: [
          _nota('1'),
          _nota('2', nama: 'SARI'),
        ],
      );

      await tester.tap(find.text('DARI NOTA').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'sari');
      await tester.pumpAndSettle();

      expect(find.textContaining('SARI'), findsOneWidget);
      expect(find.textContaining('JAMAL'), findsNothing);
    });
  });

  group('formulir tanya harga', () {
    Future<void> buka(WidgetTester tester, {AwalTanyaHarga? awal}) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: _dasar(nota: [_nota('1')]),
          child: MaterialApp(home: PartDialog(awal: awal)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('dari nota: SN dan unit terisi, nota bisa dibuka', (
      tester,
    ) async {
      await buka(tester, awal: AwalTanyaHarga.dariNota(_nota('1')));

      expect(find.widgetWithText(TextFormField, 'SN123'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'LAPTOP ASUS X441BA'),
        findsNothing,
      );
      expect(find.text('Nota SVR-01112621'), findsOneWidget);
      expect(find.text('BUKA NOTA'), findsOneWidget);
      // Nota sudah pasti; tidak ada lagi pilihan nota yang bisa salah.
      expect(find.text('NOTA SERVIS UNTUK JASA PASANG'), findsNothing);
    });

    testWidgets('tanpa nota: boleh, nota dipilih belakangan', (tester) async {
      await buka(tester);

      expect(find.text('BUKA NOTA'), findsNothing);
      expect(find.text('NOTA SERVIS UNTUK JASA PASANG'), findsOneWidget);
      expect(find.textContaining('dibuat dari nota servis'), findsNothing);
    });
  });
}
