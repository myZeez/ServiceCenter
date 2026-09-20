// Pembatalan nota: berbiaya atau tanpa biaya, dan wajib dijawab.
//
// Pembatalan bisa berbiaya (biaya cek, misalnya) dan bisa tidak. Yang dijaga
// di sini adalah bahwa jawabannya tidak pernah ditebak dari kolom biaya:
// harga taksiran yang sudah terlanjur diisi sebelum unitnya batal tidak
// boleh terbaca sebagai tagihan.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/features/service/service_dialog.dart';

ServiceOrderEntry _nota({
  String status = 'dikerjakan',
  double biaya = 0,
  String? caraBayar,
  String? claimId,
}) => ServiceOrderEntry(
  id: 'nota-1',
  noNota: 'SVR-20092628400',
  tanggalMasuk: DateTime(2026, 9, 20),
  customerNama: 'Irwan',
  barangNama: 'Laptop Lenovo',
  teknisiId: 't1',
  status: status,
  biaya: biaya,
  caraBayar: caraBayar,
  garansi: claimId != null,
  claimId: claimId,
  updatedAt: DateTime(2026, 9, 20),
);

Claim _klaim(String id) => Claim(
  id: id,
  tanggal: DateTime(2026, 9, 4),
  brandId: 1,
  namaPelanggan: 'Irwan',
  sn: 'SN1',
  jenis: 'brand',
  status: 'proses',
  createdBy: 'a',
  createdAt: DateTime(2026, 9, 4),
  updatedAt: DateTime(2026, 9, 4),
);

Future<void> _lukis(
  WidgetTester tester, {
  required ServiceOrderEntry nota,
  List<Claim> klaim = const [],
}) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storeSettingsProvider.overrideWith(
          (ref) => Stream.value(const StoreSetting(id: 1, nama: 'Cellcom')),
        ),
        allMetodeBayarProvider.overrideWith(
          (ref) => Stream.value(const [
            MetodeBayar(id: 1, kode: 'cash', nama: 'Cash'),
            MetodeBayar(id: 2, kode: 'piutang', nama: 'Piutang', piutang: true),
          ]),
        ),
        customersProvider.overrideWith((ref) => Stream.value(const [])),
        serviceOrdersProvider.overrideWith((ref) => Stream.value(const [])),
        allClaimsProvider.overrideWith((ref) => Stream.value(klaim)),
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

Future<void> _pilihStatus(WidgetTester tester, String dari, String ke) async {
  final dropdown = find.widgetWithText(DropdownButtonFormField<String>, dari);
  await tester.ensureVisible(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(ke).last);
  await tester.pumpAndSettle();
}

Future<void> _ketuk(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Finder get _kolomBiaya => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.prefixText == 'Rp ',
);

bool _biayaAktif(WidgetTester tester) =>
    tester.widget<TextField>(_kolomBiaya).enabled ?? true;

String _isiBiaya(WidgetTester tester) =>
    tester.widget<TextField>(_kolomBiaya).controller!.text;

Future<void> _simpan(WidgetTester tester) =>
    _ketuk(tester, find.widgetWithText(FilledButton, 'SIMPAN PERUBAHAN'));

void main() {
  group('Pilihan biaya pembatalan', () {
    testWidgets('tidak ada selama statusnya bukan Batal', (tester) async {
      await _lukis(tester, nota: _nota());

      expect(tester.takeException(), isNull);
      expect(find.text('BIAYA PEMBATALAN'), findsNothing);
      expect(find.text('TANPA BIAYA'), findsNothing);
    });

    testWidgets('muncul begitu Batal dipilih, dan belum terjawab', (
      tester,
    ) async {
      await _lukis(tester, nota: _nota());
      await _pilihStatus(tester, 'Dikerjakan', 'Batal');

      expect(tester.takeException(), isNull);
      expect(find.text('BIAYA PEMBATALAN'), findsOneWidget);
      expect(find.text('TANPA BIAYA'), findsOneWidget);
      expect(find.text('ADA BIAYA'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'TANPA BIAYA'))
            .selected,
        isFalse,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'ADA BIAYA'))
            .selected,
        isFalse,
      );
    });

    testWidgets('harga taksiran yang sudah terisi tidak dianggap jawaban', (
      tester,
    ) async {
      // Nota dikerjakan dengan taksiran Rp250.000, lalu dibatalkan. Angka itu
      // bukan biaya pembatalan -- belum ada yang memutuskannya.
      await _lukis(tester, nota: _nota(biaya: 250000));
      await _pilihStatus(tester, 'Dikerjakan', 'Batal');

      await _simpan(tester);

      expect(find.textContaining('Tentukan biaya pembatalan'), findsOneWidget);
    });

    testWidgets('Tanpa Biaya mengosongkan dan mengunci biaya dan cara bayar', (
      tester,
    ) async {
      await _lukis(tester, nota: _nota(biaya: 250000, caraBayar: 'cash'));
      await _pilihStatus(tester, 'Dikerjakan', 'Batal');
      expect(_isiBiaya(tester), '250000');

      await _ketuk(tester, find.widgetWithText(ChoiceChip, 'TANPA BIAYA'));

      expect(_isiBiaya(tester), isEmpty);
      expect(_biayaAktif(tester), isFalse);
      expect(find.text('Pembatalan tanpa biaya.'), findsOneWidget);
    });

    testWidgets('Ada Biaya membuka kembali kolom biayanya', (tester) async {
      await _lukis(tester, nota: _nota());
      await _pilihStatus(tester, 'Dikerjakan', 'Batal');
      await _ketuk(tester, find.widgetWithText(ChoiceChip, 'TANPA BIAYA'));
      expect(_biayaAktif(tester), isFalse);

      await _ketuk(tester, find.widgetWithText(ChoiceChip, 'ADA BIAYA'));

      expect(_biayaAktif(tester), isTrue);
    });
  });

  group('Menyimpan pembatalan', () {
    testWidgets('Ada Biaya tanpa jumlah ditolak', (tester) async {
      await _lukis(tester, nota: _nota());
      await _pilihStatus(tester, 'Dikerjakan', 'Batal');
      await _ketuk(tester, find.widgetWithText(ChoiceChip, 'ADA BIAYA'));

      await _simpan(tester);

      expect(
        find.textContaining('harus mengisi jumlah biayanya'),
        findsOneWidget,
      );
    });

    testWidgets('Ada Biaya berjumlah tetapi tanpa cara bayar ditolak', (
      tester,
    ) async {
      await _lukis(tester, nota: _nota(biaya: 75000));
      await _pilihStatus(tester, 'Dikerjakan', 'Batal');
      await _ketuk(tester, find.widgetWithText(ChoiceChip, 'ADA BIAYA'));

      await _simpan(tester);

      // Cara bayar yang belum dipilih membuat "sudah dibayar atau belum"
      // tidak terjawab -- di laporan ia jatuh ke Piutang tanpa ada yang
      // memutuskannya.
      expect(find.textContaining('Pilih cara bayar'), findsOneWidget);
    });
  });

  group('Nota yang sudah batal', () {
    testWidgets('tanpa biaya dibuka dengan Tanpa Biaya terpilih', (
      tester,
    ) async {
      await _lukis(tester, nota: _nota(status: 'batal'));

      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'TANPA BIAYA'))
            .selected,
        isTrue,
      );
      expect(_biayaAktif(tester), isFalse);
    });

    testWidgets('berbiaya dibuka dengan Ada Biaya terpilih dan biaya terbuka', (
      tester,
    ) async {
      await _lukis(
        tester,
        nota: _nota(status: 'batal', biaya: 50000, caraBayar: 'cash'),
      );

      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'ADA BIAYA'))
            .selected,
        isTrue,
      );
      expect(_biayaAktif(tester), isTrue);
      expect(_isiBiaya(tester), '50000');
    });
  });

  group('Yang tidak ikut aturan ini', () {
    testWidgets('nota garansi brand memakai status klaimnya', (tester) async {
      await _lukis(
        tester,
        nota: _nota(claimId: 'k1'),
        klaim: [_klaim('k1')],
      );

      expect(find.text('STATUS GARANSI'), findsOneWidget);
      expect(find.text('BIAYA PEMBATALAN'), findsNothing);
    });
  });
}
