// Jalan pintas dari nota servis ke tanya harga part.
//
// Yang paling penting diuji di sini bukan jalan pintasnya, melainkan
// bahwa ia tidak mengganggu apa pun selama tidak dipakai: menambah nota
// servis biasa harus tetap persis seperti sebelum fitur ini ada.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/features/service/service_dialog.dart';

ServiceOrderEntry _nota() => ServiceOrderEntry(
  id: 'nota-1',
  noNota: 'SRV-05092628222',
  tanggalMasuk: DateTime(2026, 9, 5),
  customerNama: 'Irwan',
  customerTelp: '192837182370',
  customerId: 'plg4',
  barangNama: 'Laptop Lenovo',
  barangType: 'Ideapad',
  barangSn: 'OSIA0J09U309JOI3',
  keluhan: 'LCD PECAH',
  teknisiId: 't1',
  status: 'masuk',
  updatedAt: DateTime(2026, 9, 5),
);

PartOrder _pesanan({String part = 'LCD 14 SLIM'}) => PartOrder(
  id: 'po-1',
  tanggal: DateTime(2026, 9, 5),
  customerNama: 'Irwan',
  partReq: part,
  tahap: 'tanya',
  serviceOrderId: 'nota-1',
  updatedAt: DateTime(2026, 9, 5),
);

Future<void> _lukis(
  WidgetTester tester, {
  ServiceOrderEntry? nota,
  List<PartOrder> pesanan = const [],
}) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        customersProvider.overrideWith((ref) => Stream.value(const [])),
        serviceOrdersProvider.overrideWith((ref) => Stream.value(const [])),
        partOrdersProvider.overrideWith((ref) => Stream.value(pesanan)),
        allBrandsProvider.overrideWith(
          (ref) => Stream.value([const Brand(id: 1, nama: 'ASUS')]),
        ),
        allProfilesProvider.overrideWith(
          (ref) => Stream.value([
            const Profile(id: 't1', nama: 'Agus', role: 'teknisi'),
          ]),
        ),
      ],
      child: MaterialApp(home: ServiceDialog(nota: nota)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _ketuk(WidgetTester tester, Finder sasaran) async {
  await tester.ensureVisible(sasaran);
  await tester.pumpAndSettle();
  await tester.tap(sasaran);
  await tester.pumpAndSettle();
}

void main() {
  group('nota baru', () {
    testWidgets('centang tanya harga ada, dan mati sejak awal', (
      tester,
    ) async {
      await _lukis(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Perlu tanya harga part'), findsOneWidget);
      // Selama belum dicentang, tidak ada kolom tambahan sama sekali.
      expect(find.text('PART YANG DICARI'), findsNothing);
    });

    testWidgets('mencentangnya memunculkan kolom yang perlu dilengkapi', (
      tester,
    ) async {
      await _lukis(tester);
      await _ketuk(tester, find.text('Perlu tanya harga part'));

      expect(find.text('PART YANG DICARI'), findsOneWidget);
      expect(find.text('KETERANGAN'), findsWidgets);
    });

    testWidgets('part wajib diisi begitu centangnya menyala', (tester) async {
      await _lukis(tester);
      await _ketuk(tester, find.text('Perlu tanya harga part'));
      await _ketuk(tester, find.widgetWithText(FilledButton, 'SIMPAN NOTA'));

      expect(find.text('Sebutkan part yang dicari'), findsOneWidget);
    });

    testWidgets('tanpa centang, nota biasa tidak menuntut apa pun soal part', (
      tester,
    ) async {
      await _lukis(tester);
      await _ketuk(tester, find.widgetWithText(FilledButton, 'SIMPAN NOTA'));

      // Yang wajib tetap hanya yang wajib sejak dulu. Kalau validator part
      // ikut galak di sini, seluruh alur tambah servis akan terkunci.
      expect(find.text('Nama wajib diisi'), findsOneWidget);
      expect(find.text('Sebutkan part yang dicari'), findsNothing);
    });

    testWidgets('melepas centangnya membuang kolomnya lagi', (tester) async {
      await _lukis(tester);
      await _ketuk(tester, find.text('Perlu tanya harga part'));
      expect(find.text('PART YANG DICARI'), findsOneWidget);

      await _ketuk(tester, find.text('Perlu tanya harga part'));
      expect(find.text('PART YANG DICARI'), findsNothing);

      await _ketuk(tester, find.widgetWithText(FilledButton, 'SIMPAN NOTA'));
      expect(find.text('Sebutkan part yang dicari'), findsNothing);
    });
  });

  group('nota yang sudah tersimpan', () {
    testWidgets('menawarkan membuat tanya harga', (tester) async {
      await _lukis(tester, nota: _nota());

      expect(tester.takeException(), isNull);
      expect(find.text('TANYA HARGA PART'), findsOneWidget);
      // Centangnya khusus nota baru; di sini yang masuk akal adalah
      // membuka formulirnya, bukan menandai niat.
      expect(find.text('Perlu tanya harga part'), findsNothing);
    });

    testWidgets('membuka formulir tanya harga yang sudah terisi', (
      tester,
    ) async {
      await _lukis(tester, nota: _nota());
      await _ketuk(tester, find.text('TANYA HARGA PART'));

      expect(tester.takeException(), isNull);
      // Data nota terbawa: pelanggan, merek dan tipe digabung, dan SN.
      expect(find.text('Irwan'), findsWidgets);
      expect(find.text('Laptop Lenovo Ideapad'), findsOneWidget);
      expect(find.text('OSIA0J09U309JOI3'), findsWidgets);
      // Yang memang belum diketahui tetap kosong, tidak ditebak dari
      // keluhannya.
      expect(find.text('LCD PECAH'), findsWidgets);
      expect(find.text('PART REQ'), findsOneWidget);
    });

    testWidgets('yang sudah punya tanya harga menawarkan membukanya', (
      tester,
    ) async {
      await _lukis(tester, nota: _nota(), pesanan: [_pesanan()]);

      // Bukan membuat yang kedua dengan isi yang sama persis.
      expect(find.text('LIHAT TANYA HARGA'), findsOneWidget);
      expect(find.text('TANYA HARGA PART'), findsNothing);
      expect(find.textContaining('LCD 14 SLIM'), findsOneWidget);
    });

    testWidgets('tanya harga milik nota lain tidak dianggap miliknya', (
      tester,
    ) async {
      await _lukis(
        tester,
        nota: _nota(),
        pesanan: [
          PartOrder(
            id: 'po-9',
            tanggal: DateTime(2026, 9, 5),
            customerNama: 'Orang Lain',
            partReq: 'KEYBOARD',
            tahap: 'tanya',
            serviceOrderId: 'nota-lain',
            updatedAt: DateTime(2026, 9, 5),
          ),
        ],
      );

      expect(find.text('TANYA HARGA PART'), findsOneWidget);
    });
  });
}
