// Mode kaca: palet, tema, latar, dan buram di balik yang melayang.
//
// Kaca hanya menyala di Android. Karena itu hampir semua pengujian di sini
// berpasangan: satu memastikan kacanya bekerja, satu lagi memastikan tema
// tanpa kaca -- yang dipakai Windows -- tidak ikut berubah sedikit pun.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sc_management/core/kaca/kepala_mengambang.dart';
import 'package:sc_management/core/kaca/kerangka_app.dart';
import 'package:sc_management/core/kaca/lapisan_kaca.dart';
import 'package:sc_management/core/kaca/latar_kaca.dart';
import 'package:sc_management/core/kaca/overlay_kaca.dart';
import 'package:sc_management/core/kaca/panel_kaca.dart';
import 'package:sc_management/core/theme.dart';

/// Halaman sederhana dengan tombol-tombol pembuka lapisan.
class _Halaman extends StatelessWidget {
  const _Halaman();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('isi halaman'),
            TextButton(
              onPressed: () => tampilkanDialog<void>(
                context: context,
                builder: (_) => const AlertDialog(content: Text('dialog')),
              ),
              child: const Text('buka dialog'),
            ),
            TextButton(
              onPressed: () => tampilkanLembar<void>(
                context: context,
                builder: (_) =>
                    const SizedBox(height: 200, child: Text('lembar')),
              ),
              child: const Text('buka lembar'),
            ),
            DropdownButton<int>(
              value: 1,
              items: const [
                DropdownMenuItem(value: 1, child: Text('satu')),
                DropdownMenuItem(value: 2, child: Text('dua')),
              ],
              onChanged: (_) {},
            ),
            Builder(
              builder: (c) => TextButton(
                onPressed: () =>
                    ScaffoldMessenger.of(c)
                        .showSnackBar(const SnackBar(content: Text('pesan'))),
                child: const Text('pesan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _lukis(WidgetTester tester, {required bool kaca}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: KerangkaApp(kaca: kaca, home: const _Halaman()),
    ),
  );
  await tester.pumpAndSettle();
}

/// Seberapa buram isi lapisan ke-[ke] (0 = halaman paling bawah).
double _buram(WidgetTester tester, {int ke = 0}) {
  final f = find.byType(KabutKaca);
  if (f.evaluate().length <= ke) return 0;
  return tester.widget<KabutKaca>(f.at(ke)).sigma;
}

void main() {
  tearDown(PengamatKaca.instance.lupakan);

  group('Palet', () {
    test('bidang kaca tembus pandang, tulisannya tidak', () {
      for (final w in [WarnaApp.terangKaca, WarnaApp.gelapKaca]) {
        expect(w.latar.a, 0, reason: 'latar halaman bening');
        expect(w.permukaan.a, lessThan(1), reason: 'kartu tembus pandang');
        expect(w.teredam.a, lessThan(1));
        // Yang dipakai sebagai warna tulisan di atas bidang berwarna harus
        // tetap padat -- kalau tidak, tulisan putih di atas chip biru ikut
        // berubah kebiruan.
        expect(w.kertas.a, 1);
        expect(w.diTeks.a, 1);
        expect(w.teks.a, 1);
        expect(w.aksen.a, 1);
        expect(w.bahaya.a, 1);
        expect(w.garansi.a, 1);
      }
    });

    test('palet biasa tidak berubah: kertas dan diTeks ikut yang lama', () {
      // Windows memakai palet ini. Dua peran baru hanya memberi nama pada
      // warna yang memang sudah dipakai di sana, jadi rupanya sama persis.
      expect(WarnaApp.terang.kertas, WarnaApp.terang.permukaan);
      expect(WarnaApp.terang.diTeks, WarnaApp.terang.latar);
      expect(WarnaApp.gelap.kertas, WarnaApp.gelap.permukaan);
      expect(WarnaApp.gelap.diTeks, WarnaApp.gelap.latar);
    });

    test('warna kaca terang dan gelap tetap sepasang dengan paletnya', () {
      expect(WarnaApp.terangKaca.teks, WarnaApp.terang.teks);
      expect(WarnaApp.gelapKaca.teks, WarnaApp.gelap.teks);
      expect(WarnaApp.terangKaca.aksen, WarnaApp.terang.aksen);
      expect(WarnaApp.gelapKaca.aksen, WarnaApp.gelap.aksen);
    });
  });

  group('Tema', () {
    test('tanpa kaca: tidak ada gaya kaca, latar halaman padat', () {
      for (final t in [AppTheme.terang(), AppTheme.gelap()]) {
        expect(t.extension<GayaKaca>(), isNull);
        expect(t.scaffoldBackgroundColor.a, 1);
      }
    });

    test('dengan kaca: gaya kaca terpasang, latar halaman bening', () {
      for (final t in [
        AppTheme.terang(kaca: true),
        AppTheme.gelap(kaca: true),
      ]) {
        expect(t.extension<GayaKaca>(), isNotNull);
        expect(t.scaffoldBackgroundColor.a, 0);
        expect(t.appBarTheme.backgroundColor?.a, 0);
        expect(t.cardTheme.color?.a, lessThan(1));
        expect(t.dialogTheme.backgroundColor?.a, lessThan(1));
        expect(t.canvasColor.a, lessThan(1));
        expect(t.snackBarTheme.backgroundColor?.a, lessThan(1));
      }
    });

    test('makin melayang makin tebal buramnya', () {
      expect(
        GayaKaca.sigma(TingkatKaca.tipis),
        lessThan(GayaKaca.sigma(TingkatKaca.ringan)),
      );
      expect(
        GayaKaca.sigma(TingkatKaca.ringan),
        lessThan(GayaKaca.sigma(TingkatKaca.sedang)),
      );
      expect(
        GayaKaca.sigma(TingkatKaca.sedang),
        lessThan(GayaKaca.sigma(TingkatKaca.tebal)),
      );
    });

    test('peralihan halaman membawa latar kaca, tanpa kaca tidak', () {
      final kaca = AppTheme.terang(kaca: true)
          .pageTransitionsTheme
          .builders[TargetPlatform.android];
      final biasa = AppTheme.terang()
          .pageTransitionsTheme
          .builders[TargetPlatform.android];
      expect(kaca, isA<TransisiKaca>());
      expect(biasa, isNot(isA<TransisiKaca>()));

      // Windows memakai peralihan yang sama seperti sebelumnya.
      expect(
        AppTheme.terang(kaca: true)
            .pageTransitionsTheme
            .builders[TargetPlatform.windows],
        isNot(isA<TransisiKaca>()),
      );
    });
  });

  group('Latar', () {
    testWidgets('setiap halaman membawa latar kacanya sendiri', (tester) async {
      await _lukis(tester, kaca: true);
      expect(find.byType(LatarKaca), findsOneWidget);
    });

    testWidgets('tanpa kaca tidak ada latar sama sekali', (tester) async {
      await _lukis(tester, kaca: false);
      expect(find.byType(LatarKaca), findsNothing);
    });
  });

  group('Yang tertutup ikut memburam', () {
    testWidgets('dialog memburamkan halaman di bawahnya', (tester) async {
      await _lukis(tester, kaca: true);
      expect(_buram(tester), 0);

      await tester.tap(find.text('buka dialog'));
      await tester.pumpAndSettle();
      final sigmaDialog = _buram(tester);
      expect(sigmaDialog, GayaKaca.sigma(TingkatKaca.tebal));

      // Dan kembali jernih setelah ditutup.
      Navigator.of(tester.element(find.text('dialog'))).pop();
      await tester.pumpAndSettle();
      expect(_buram(tester), 0);
    });

    testWidgets('buramnya naik pelan, tidak muncul sekaligus', (tester) async {
      await _lukis(tester, kaca: true);

      await tester.tap(find.text('buka dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final tengah = _buram(tester);

      await tester.pumpAndSettle();
      final penuh = _buram(tester);

      expect(tengah, greaterThan(0));
      expect(tengah, lessThan(penuh));
    });

    testWidgets('lembar bawah lebih tipis daripada dialog', (tester) async {
      await _lukis(tester, kaca: true);

      await tester.tap(find.text('buka lembar'));
      await tester.pumpAndSettle();

      expect(_buram(tester), GayaKaca.sigma(TingkatKaca.sedang));
      expect(_buram(tester), lessThan(GayaKaca.sigma(TingkatKaca.tebal)));
    });

    testWidgets('menu pilihan paling tipis', (tester) async {
      await _lukis(tester, kaca: true);

      await tester.tap(find.text('satu'));
      await tester.pumpAndSettle();

      expect(_buram(tester), GayaKaca.sigma(TingkatKaca.ringan));
      expect(_buram(tester), lessThan(GayaKaca.sigma(TingkatKaca.sedang)));
    });

    testWidgets('dialog di atas lembar: lembarnya ikut memburam', (
      tester,
    ) async {
      // Lembar ubah pekerjaan memanggil pemilih tanggal, dan menu status.
      // Tanpa ini, menu berdiri di atas isi lembar yang masih tajam.
      await _lukis(tester, kaca: true);

      await tester.tap(find.text('buka lembar'));
      await tester.pumpAndSettle();
      // Lapisan kedua adalah isi lembarnya sendiri.
      expect(_buram(tester, ke: 1), 0);

      // Tanpa await: dialognya baru selesai saat ditutup, dan yang diuji
      // justru keadaan selagi ia terbuka.
      unawaited(
        tampilkanDialog<void>(
          context: tester.element(find.text('lembar')),
          builder: (_) => const AlertDialog(content: Text('di atas lembar')),
        ),
      );
      await tester.pumpAndSettle();

      expect(_buram(tester, ke: 1), GayaKaca.sigma(TingkatKaca.tebal));
    });

    testWidgets('tanpa kaca tidak ada yang diburamkan', (tester) async {
      await _lukis(tester, kaca: false);

      await tester.tap(find.text('buka dialog'));
      await tester.pumpAndSettle();

      // Lapisannya tetap ada -- susunan widget-nya sama di kedua mode --
      // tetapi tidak pernah memburamkan apa pun.
      for (final k in tester.widgetList<KabutKaca>(find.byType(KabutKaca))) {
        expect(k.sigma, 0);
      }
      expect(find.byType(BackdropFilter), findsNothing);
    });
  });

  group('Snackbar', () {
    testWidgets('berkaca tanpa satu pun pemanggilan diubah', (tester) async {
      await _lukis(tester, kaca: true);

      await tester.tap(find.text('pesan'));
      await tester.pumpAndSettle();

      expect(find.text('pesan').hitTestable(), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tanpa kaca snackbar tetap padat', (tester) async {
      await _lukis(tester, kaca: false);

      await tester.tap(find.text('pesan'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.byType(BackdropFilter),
        ),
        findsNothing,
      );
    });
  });

  group('Kepala mengambang', () {
    Widget susun({required bool kaca}) => KerangkaApp(
      kaca: kaca,
      home: Scaffold(
        body: KepalaMengambang(
          kepala: const SizedBox(height: 90, child: Text('kepala')),
          isi: (context, atas) => ListView(
            padding: EdgeInsets.only(top: atas),
            children: const [SizedBox(height: 2000, child: Text('isi'))],
          ),
        ),
      ),
    );

    testWidgets('di kaca: isi lewat di belakang kepala', (tester) async {
      await tester.pumpWidget(susun(kaca: true));
      await tester.pumpAndSettle();

      final kepala = tester.getRect(find.text('kepala'));
      final daftar = tester.getRect(find.byType(ListView));

      // Daftarnya memenuhi layar dari puncak -- kartu yang digulir lewat
      // di belakang kepala, dan di situlah buramnya terlihat.
      expect(daftar.top, lessThanOrEqualTo(kepala.top));
      expect(
        find.descendant(
          of: find.byType(PanelKaca),
          matching: find.text('kepala'),
        ),
        findsOneWidget,
      );

      // Tetapi isi pertamanya tetap mulai di bawah kepala.
      expect(
        tester.getRect(find.text('isi')).top,
        greaterThanOrEqualTo(kepala.bottom),
      );
    });

    testWidgets('tanpa kaca: susunannya bertumpuk seperti semula', (
      tester,
    ) async {
      await tester.pumpWidget(susun(kaca: false));
      await tester.pumpAndSettle();

      final kepala = tester.getRect(find.text('kepala'));
      final daftar = tester.getRect(find.byType(ListView));

      expect(daftar.top, greaterThanOrEqualTo(kepala.bottom));
      expect(find.byType(PanelKaca), findsNothing);
    });
  });

  group('Panel', () {
    testWidgets('berkaca hanya saat kacanya menyala', (tester) async {
      for (final kaca in [true, false]) {
        await tester.pumpWidget(
          KerangkaApp(
            kaca: kaca,
            home: const Scaffold(
              body: PanelKaca(tingkat: TingkatKaca.sedang, child: Text('pa')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byType(BackdropFilter),
          kaca ? findsOneWidget : findsNothing,
          reason: 'kaca=$kaca',
        );
        expect(tester.takeException(), isNull);
      }
    });
  });
}
