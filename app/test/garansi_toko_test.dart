// Dua jenis garansi, dan yang membedakan keduanya bukan namanya.
//
// Garansi brand ditagihkan ke brand: nomor seri wajib, karena brand
// mengenali unit dari situ, dan unitnya masuk Rekap Brand serta bagi
// hasil. Garansi toko ditanggung toko sendiri -- unit yang rusak lagi
// dalam masa garansi servis -- jadi tidak ada SN yang perlu diyakinkan
// kepada siapa pun, dan tidak ada yang bisa ditagihkan.
//
// Yang paling mahal kalau salah ada di bagian uang: garansi toko yang
// ikut terhitung berarti menagih brand atas pekerjaan yang tidak pernah
// mereka setujui, dan membagi hasil dari uang yang tidak pernah diterima.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/fitur.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/features/service/service_dialog.dart';

import 'package:sc_management/core/status.dart';

void main() {
  group('Aturan jenis garansi', () {
    test('nomor seri hanya wajib untuk klaim ke brand', () {
      expect(ClaimJenis.perluSn(ClaimJenis.brand), isTrue);
      expect(ClaimJenis.perluSn(ClaimJenis.toko), isFalse);
    });

    test('hanya klaim ke brand yang ditagihkan', () {
      expect(ClaimJenis.ditagihkan(ClaimJenis.brand), isTrue);
      expect(ClaimJenis.ditagihkan(ClaimJenis.toko), isFalse);
    });

    test('keduanya punya nama dan keterangannya sendiri', () {
      for (final j in ClaimJenis.all) {
        expect(ClaimJenis.label(j), isNotEmpty);
        expect(ClaimJenis.hint(j), isNotEmpty);
      }
      expect(ClaimJenis.label(ClaimJenis.toko), contains('Toko'));
    });

    test('nilai yang tidak dikenal tidak dianggap ditagihkan', () {
      // Sisi yang lebih aman untuk salah: jenis yang tidak terbaca lebih
      // baik luput dari tagihan daripada menagihkan sesuatu yang tidak
      // pernah disetujui brand.
      expect(ClaimJenis.ditagihkan('entah'), isFalse);
      expect(ClaimJenis.perluSn('entah'), isFalse);
    });
  });

  // -------------------------------------------------------------------
  // Jalan yang paling sering dipakai untuk garansi toko: pelanggan
  // kembali beberapa hari sesudah servis, dan admin membuka nota barunya
  // lalu mencentang "Unit bergaransi". Dari situ klaimnya lahir.
  // -------------------------------------------------------------------
  group('Garansi dari formulir nota servis', () {
    testWidgets('memilih jenisnya, dan bawaannya ke brand', (tester) async {
      await _lukis(tester);
      await _ketuk(tester, find.text('Unit bergaransi'));

      expect(find.text('JENIS GARANSI'), findsOneWidget);
      expect(find.text('Garansi Brand'), findsWidgets);
    });

    testWidgets('garansi brand menuntut nomor seri', (tester) async {
      await _lukis(tester);
      await _ketuk(tester, find.text('Unit bergaransi'));
      await _ketuk(tester, find.widgetWithText(FilledButton, 'SIMPAN NOTA'));

      expect(
        find.text('Nomor seri wajib untuk klaim ke brand'),
        findsOneWidget,
      );
    });

    testWidgets('garansi toko tidak menuntut nomor seri', (tester) async {
      await _lukis(tester);
      await _ketuk(tester, find.text('Unit bergaransi'));
      await _pilihJenis(tester, 'Garansi Toko');
      await _ketuk(tester, find.widgetWithText(FilledButton, 'SIMPAN NOTA'));

      // Unitnya baru saja ditangani toko sendiri; tidak ada pihak luar
      // yang perlu diyakinkan lewat nomor seri.
      expect(find.text('Nomor seri wajib untuk klaim ke brand'), findsNothing);
      // Yang wajib sejak dulu tetap wajib.
      expect(find.text('Nama wajib diisi'), findsOneWidget);
    });

    testWidgets('email tidak pernah wajib, jenis mana pun', (tester) async {
      await _lukis(tester);
      await _ketuk(tester, find.text('Unit bergaransi'));
      await _ketuk(tester, find.widgetWithText(FilledButton, 'SIMPAN NOTA'));

      // Sempat dipaksa dengan alasan portal RMA brand menuntutnya.
      // Alasannya benar, tempatnya salah: yang menuntut email adalah
      // portal brand saat unitnya didaftarkan, bukan meja depan saat
      // notanya diketik.
      expect(find.textContaining('Email wajib'), findsNothing);
    });

    testWidgets('garansi toko menyebut bahwa ia tidak ditagihkan', (
      tester,
    ) async {
      await _lukis(tester);
      await _ketuk(tester, find.text('Unit bergaransi'));
      await _pilihJenis(tester, 'Garansi Toko');

      // Akibatnya harus terbaca di tempat orang memilihnya, bukan
      // ditemukan sebulan kemudian sebagai unit yang hilang dari rekap.
      expect(find.textContaining('Tidak ditagihkan ke brand'), findsOneWidget);
    });
  });
}

Future<void> _lukis(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        fiturTanyaHargaProvider.overrideWithValue(false),
        customersProvider.overrideWith((ref) => Stream.value(const [])),
        serviceOrdersProvider.overrideWith((ref) => Stream.value(const [])),
        partOrdersProvider.overrideWith((ref) => Stream.value(const [])),
        allBrandsProvider.overrideWith(
          (ref) => Stream.value([const Brand(id: 1, nama: 'ASUS')]),
        ),
        allProfilesProvider.overrideWith(
          (ref) => Stream.value(const <Profile>[]),
        ),
      ],
      child: const MaterialApp(home: ServiceDialog()),
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

/// Dikenali dari nilai yang sedang tampil, bukan dari urutan widgetnya.
/// Formulir nota punya beberapa dropdown bertipe sama -- teknisi, status,
/// cara bayar -- dan yang pertama di antaranya bukan yang ini.
Future<void> _pilihJenis(WidgetTester tester, String label) async {
  await _ketuk(tester, find.text('Garansi Brand').first);
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}
