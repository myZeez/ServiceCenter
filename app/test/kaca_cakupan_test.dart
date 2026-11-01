// Menjaga supaya tidak ada bagian yang terlewat dari mode kaca.
//
// Dua cara, karena keduanya menangkap kelalaian yang berbeda:
//
//  1. Membaca kodenya. Dialog dan lembar harus lewat satu pintu
//     (core/kaca/overlay_kaca.dart), supaya isinya ikut memburam saat ada
//     menu terbuka di atasnya. Kalau besok ada yang memanggil showDialog
//     langsung, pengujian ini yang menyebutkannya -- bukan mata seseorang
//     yang kebetulan membuka layar itu di HP.
//
//  2. Melukis halamannya. Di mode kaca tidak boleh ada satu pun bidang
//     yang masih memakai warna permukaan padat: satu Container yang
//     terlewat akan berdiri sebagai kotak putih di atas latar berwarna,
//     dan itu justru yang paling kentara.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/kaca/kerangka_app.dart';
import 'package:sc_management/core/kaca/latar_kaca.dart';
import 'package:sc_management/core/kaca/panel_kaca.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/core/revenue/revenue_providers.dart';
import 'package:sc_management/core/theme.dart';
import 'package:sc_management/features/auth/login_page.dart';
import 'package:sc_management/features/claims/claims_page.dart';
import 'package:sc_management/features/claims/dock_utama.dart';
import 'package:sc_management/core/data/prefs.dart';
import 'package:sc_management/features/claims/claim_detail_page.dart';
import 'package:sc_management/features/claims/claim_form_page.dart';
import 'package:sc_management/features/mywork/my_work_page.dart';
import 'package:sc_management/features/reports/reports_page.dart';
import 'package:sc_management/features/parts/parts_page.dart';
import 'package:sc_management/features/settings/settings_page.dart';
import 'package:sc_management/features/shell/admin_shell.dart';
import 'package:sc_management/features/settlement/settlement_page.dart';
import 'package:sc_management/features/service/service_page.dart';
import 'package:sc_management/features/service/service_reports_view.dart';
import 'package:sc_management/features/settings/tampilan_card.dart';

const _saya = User(
  id: 't1',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  createdAt: '2026-01-01T00:00:00Z',
);

ServiceOrderEntry _nota(String nama, {String status = 'dikerjakan'}) =>
    ServiceOrderEntry(
      id: nama,
      noNota: 'SVR-$nama',
      tanggalMasuk: DateTime.now(),
      customerNama: nama,
      barangNama: 'ASUS',
      barangType: 'X441',
      keluhan: 'Mati total',
      teknisiId: 't1',
      status: status,
      biaya: 150000,
      updatedAt: DateTime.now(),
    );

Claim _klaim(String id) => Claim(
  id: id,
  tanggal: DateTime.now(),
  brandId: 1,
  namaPelanggan: 'Pelanggan $id',
  sn: 'SN$id',
  status: 'open',
  keluhan: 'Layar bergaris',
  teknisiId: 't1',
  createdBy: 't1',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

late Prefs prefs;

Future<void> _lukis(
  WidgetTester tester,
  Widget halaman, {
  Size ukuran = const Size(400, 900),
  bool kaca = true,

  /// Tinggi status bar dalam dp. HP sungguhan punya sekitar 47; tes tanpa
  /// ini tidak akan pernah melihat AppBar yang lebih tinggi dari 56.
  double statusBar = 0,
}) async {
  await tester.binding.setSurfaceSize(ukuran);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(top: statusBar);
  tester.view.viewPadding = FakeViewPadding(top: statusBar);
  addTearDown(tester.view.reset);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_saya),
        allClaimsProvider.overrideWith(
          (ref) => Stream.value([_klaim('1'), _klaim('2')]),
        ),
        allPartsProvider.overrideWith((ref) => Stream.value([])),
        allPartTypesProvider.overrideWith((ref) => Stream.value([])),
        allBrandsProvider.overrideWith(
          (ref) => Stream.value([const Brand(id: 1, nama: 'ASUS')]),
        ),
        allProfilesProvider.overrideWith(
          (ref) => Stream.value([
            const Profile(id: 't1', nama: 'Reza', role: 'teknisi'),
          ]),
        ),
        allMetodeBayarProvider.overrideWith((ref) => Stream.value([])),
        serviceOrdersProvider.overrideWith(
          (ref) =>
              Stream.value([_nota('Jamal'), _nota('Soni', status: 'masuk')]),
        ),
        customersProvider.overrideWith((ref) => Stream.value([])),
        partOrdersProvider.overrideWith((ref) => Stream.value([])),
        partCostsProvider.overrideWith((ref) => Stream.value([])),
        storeSettingsProvider.overrideWith((ref) => Stream.value(null)),
        shipmentsProvider.overrideWith((ref) => Stream.value([])),
        brandFeesProvider.overrideWith((ref) => Stream.value([])),
        settlementsProvider.overrideWith((ref) => Stream.value([])),
        koneksiProvider.overrideWith((ref) => Stream.value(true)),
        prefsProvider.overrideWithValue(prefs),
      ],
      child: KerangkaApp(kaca: kaca, home: halaman),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Warna bidang padat yang tidak boleh muncul lagi di mode kaca. Semuanya
/// warna "kertas" dari palet biasa: begitu salah satunya terlihat, berarti
/// ada bidang yang belum ikut berkaca.
const _padat = {
  0xFFFFFFFF, // putih -- permukaan & latar mode terang
  0xFFF2F2F2, // teredam mode terang
  0xFF0B1623, // latar mode gelap
  0xFF12202F, // permukaan mode gelap
  0xFF1C2B3A, // teredam mode gelap
};

/// Semua warna bidang yang dilukis di layar sekarang.
List<String> _bidangPadat(WidgetTester tester) {
  final pelanggar = <String>[];

  // Pratinjau tema di Pengaturan memang melukis palet yang SEDANG TIDAK
  // dipakai, lengkap dengan warna padatnya -- gunanya justru memperlihatkan
  // yang belum dipilih. Isi kotak itu dilewati.
  final abaikan = <Widget>{};
  void kumpul(Element e) {
    abaikan.add(e.widget);
    e.visitChildren(kumpul);
  }

  for (final e in find.byKey(kunciPratinjauTema).evaluate()) {
    kumpul(e);
  }

  void periksa(Object pemilik, Color? c) {
    if (c == null) return;
    final nilai = c.toARGB32();
    if (_padat.contains(nilai)) {
      pelanggar.add(
        '$pemilik: #${nilai.toRadixString(16).toUpperCase().padLeft(8, '0')}',
      );
    }
  }

  for (final w in tester.allWidgets) {
    if (abaikan.contains(w)) continue;
    switch (w) {
      case ColoredBox(:final color):
        periksa(w.runtimeType, color);
      case DecoratedBox(:final decoration):
        if (decoration is BoxDecoration) {
          periksa(w.runtimeType, decoration.color);
        }
      case Material(:final color):
        periksa(w.runtimeType, color);
      case Card(:final color):
        periksa(w.runtimeType, color);
      case AppBar(:final backgroundColor):
        periksa(w.runtimeType, backgroundColor);
      case Scaffold(:final backgroundColor):
        periksa(w.runtimeType, backgroundColor);
      case Container(:final color):
        periksa(w.runtimeType, color);
    }
  }
  return pelanggar;
}

void main() {
  // Halaman Pekerjaanku menulis nama bulan dalam bahasa Indonesia.
  setUpAll(() async {
    await initializeDateFormatting('id', null);
    SharedPreferences.setMockInitialValues({});
    prefs = await Prefs.buka();
  });

  group('Semua dialog dan lembar lewat satu pintu', () {
    // Nama berkas yang memang berisi pembungkusnya.
    const pintu = 'overlay_kaca.dart';
    const terlarang = [
      'showDialog(',
      'showDialog<',
      'showGeneralDialog(',
      'showGeneralDialog<',
      'showModalBottomSheet(',
      'showModalBottomSheet<',
    ];

    test('tidak ada pemanggilan langsung di lib/', () {
      final pelanggar = <String>[];

      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        if (f.path.endsWith(pintu)) continue;

        final baris = f.readAsLinesSync();
        for (var i = 0; i < baris.length; i++) {
          final b = baris[i];
          // Komentar tidak dihitung: yang dicari pemanggilan sungguhan.
          if (b.trimLeft().startsWith('//')) continue;
          for (final t in terlarang) {
            if (b.contains(t)) pelanggar.add('${f.path}:${i + 1}: $t');
          }
        }
      }

      expect(
        pelanggar,
        isEmpty,
        reason:
            'Pakai tampilkanDialog / tampilkanDialogUmum / tampilkanLembar '
            'dari core/kaca/overlay_kaca.dart supaya isinya ikut memburam '
            'saat ada menu terbuka di atasnya.\n${pelanggar.join('\n')}',
      );
    });
  });

  group('Tidak ada bidang padat yang tersisa', () {
    // Layar HP.
    final halaman = <String, Widget>{
      'Klaim': const ClaimsPage(),
      'Servis': const ServicePage(),
      'Pekerjaanku': const MyWorkPage(),
      'Login': const LoginPage(),
      'Klaim Baru': const ClaimFormPage(),
      'Rincian Klaim': const ClaimDetailPage('1'),
      'Part': const PartsPage(),
    };

    // Tiga halaman yang isinya memang disusun untuk layar lebar; di HP
    // isinya meluap -- itu sudah begitu sebelum ada mode kaca, dan bukan
    // yang sedang diuji di sini. Yang diperiksa tetap warna bidangnya.
    final halamanLuas = <String, Widget>{
      'Rekap': const ReportsPage(),
      'Rekap Brand': const SettlementPage(),
      'Pengaturan': const SettingsPage(),
      // Tablet Android memakai kerangka bersidebar seperti Windows.
      'Kerangka lebar': const AdminShell(),
    };

    for (final e in halamanLuas.entries) {
      testWidgets('${e.key} berkaca seluruhnya', (tester) async {
        await _lukis(tester, e.value, ukuran: const Size(1100, 1400));

        expect(find.byType(LatarKaca), findsWidgets, reason: 'latar kaca');
        expect(_bidangPadat(tester), isEmpty);
      });
    }

    for (final e in halaman.entries) {
      testWidgets('${e.key} berkaca seluruhnya', (tester) async {
        await _lukis(tester, e.value);

        expect(tester.takeException(), isNull);
        expect(find.byType(LatarKaca), findsWidgets, reason: 'latar kaca');
        expect(_bidangPadat(tester), isEmpty);
      });
    }

    testWidgets('Servisku berkaca seluruhnya', (tester) async {
      await _lukis(tester, const ClaimsPage());
      await tester.tap(
        find.descendant(
          of: find.byType(DockUtama),
          matching: find.text('Servisku'),
        ),
      );
      await tester.pumpAndSettle();

      expect(_bidangPadat(tester), isEmpty);

      // Tab Sudah Selesai (riwayat omset) dan tab Skor punya kartu sendiri.
      // Chipnya bisa di luar layar uji; digulir masuk dulu.
      for (final tab in ['SUDAH SELESAI', 'SKOR']) {
        final chip = find.textContaining(tab, skipOffstage: false).first;
        await tester.ensureVisible(chip);
        await tester.pumpAndSettle();
        await tester.tap(chip);
        await tester.pumpAndSettle();
        expect(_bidangPadat(tester), isEmpty, reason: tab);
      }
    });

    testWidgets('lembar ubah pekerjaan ikut berkaca', (tester) async {
      await _lukis(tester, const ServicePage());
      await tester.tap(find.text('Jamal'));
      await tester.pumpAndSettle();

      expect(find.text('SIMPAN'), findsOneWidget);
      expect(_bidangPadat(tester), isEmpty);
    });

    testWidgets('tema gelap juga, karena paletnya dua', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(null),
            allClaimsProvider.overrideWith((ref) => Stream.value([])),
            allPartsProvider.overrideWith((ref) => Stream.value([])),
            allBrandsProvider.overrideWith((ref) => Stream.value([])),
            allProfilesProvider.overrideWith((ref) => Stream.value([])),
            serviceOrdersProvider.overrideWith((ref) => Stream.value([])),
            koneksiProvider.overrideWith((ref) => Stream.value(true)),
          ],
          child: const KerangkaApp(
            kaca: true,
            mode: ThemeMode.dark,
            home: LoginPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_bidangPadat(tester), isEmpty);
    });
  });

  group('Kepala daftar menyambung dengan AppBar', () {
    // Pernah ada tepi keras tepat di bawah judul: AppBar yang bening
    // memperlihatkan latar berwarna, sedangkan panel kaca di bawahnya
    // sudah bertinta gelap -- dua bidang yang terlihat ditempel. Panelnya
    // harus dimulai dari puncak layar dan menutupi AppBar juga.
    //
    // Status bar disimulasikan 47dp seperti HP sungguhan: tanpa itu AppBar
    // hanya 56dp dan jarak antar bidang yang salah tidak kelihatan.
    const statusBar = 47.0;

    Finder panelDari(Finder isi) =>
        find.ancestor(of: isi.first, matching: find.byType(PanelKaca)).first;

    void periksa(WidgetTester tester, Finder isiKepala) {
      final panel = tester.getRect(panelDari(isiKepala));
      final appBar = tester.getRect(find.byType(AppBar));

      expect(appBar.top, 0);
      expect(appBar.bottom, greaterThan(statusBar), reason: 'AppBar utuh');
      expect(panel.top, 0, reason: 'panel kaca mulai dari puncak layar');
      expect(
        panel.bottom,
        greaterThan(appBar.bottom),
        reason: 'panel menutupi AppBar, bukan berawal di bawahnya',
      );
      // Isi kepalanya sendiri tetap di bawah AppBar, tidak tertimpa.
      expect(
        tester.getRect(isiKepala.first).top,
        greaterThanOrEqualTo(appBar.bottom),
      );
    }

    testWidgets('Klaim: panel menutupi AppBar', (tester) async {
      await _lukis(tester, const ClaimsPage(), statusBar: statusBar);

      periksa(tester, find.byType(TextField));

      // Dan kartu pertama mulai di bawah panelnya, tidak di bawah AppBar.
      final panel = tester.getRect(panelDari(find.byType(TextField)));
      expect(
        tester.getRect(find.text('Pelanggan 1')).top,
        greaterThanOrEqualTo(panel.bottom),
      );
    });

    testWidgets('Servis: panel menutupi AppBar', (tester) async {
      await _lukis(tester, const ServicePage(), statusBar: statusBar);

      periksa(tester, find.byType(TextField));

      final panel = tester.getRect(panelDari(find.byType(TextField)));
      expect(
        tester.getRect(find.text('Jamal')).top,
        greaterThanOrEqualTo(panel.bottom),
      );
    });

    testWidgets('Servisku: panel menutupi AppBar', (tester) async {
      await _lukis(tester, const ClaimsPage(), statusBar: statusBar);
      await tester.tap(
        find.descendant(
          of: find.byType(DockUtama),
          matching: find.text('Servisku'),
        ),
      );
      await tester.pumpAndSettle();

      periksa(tester, find.textContaining('SEDANG DIKERJAKAN'));
    });

    testWidgets('Scaffold-nya memperpanjang isi ke belakang AppBar', (
      tester,
    ) async {
      // Syarat KepalaMengambang: tanpa ini isinya mulai di bawah AppBar dan
      // panelnya tidak akan pernah bisa menutupinya.
      for (final halaman in [const ClaimsPage(), const ServicePage()]) {
        await _lukis(tester, halaman, statusBar: statusBar);
        expect(
          tester
              .widget<Scaffold>(find.byType(Scaffold).first)
              .extendBodyBehindAppBar,
          isTrue,
          reason: halaman.runtimeType.toString(),
        );
      }
    });

    testWidgets('tanpa kaca (Windows) susunannya tidak berubah', (
      tester,
    ) async {
      await _lukis(tester, const ServicePage(), kaca: false);

      expect(
        tester
            .widget<Scaffold>(find.byType(Scaffold).first)
            .extendBodyBehindAppBar,
        isFalse,
      );
      expect(find.byType(PanelKaca), findsNothing);

      // Kotak pencarian tetap di bawah AppBar, seperti semula.
      expect(
        tester.getRect(find.byType(TextField)).top,
        greaterThanOrEqualTo(tester.getRect(find.byType(AppBar)).bottom),
      );
    });
  });

  group('Windows tidak ikut berubah', () {
    testWidgets('tanpa kaca, bidangnya justru harus padat', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(null),
            allClaimsProvider.overrideWith((ref) => Stream.value([])),
            allPartsProvider.overrideWith((ref) => Stream.value([])),
            allBrandsProvider.overrideWith((ref) => Stream.value([])),
            allProfilesProvider.overrideWith((ref) => Stream.value([])),
            serviceOrdersProvider.overrideWith((ref) => Stream.value([])),
            koneksiProvider.overrideWith((ref) => Stream.value(true)),
          ],
          child: const KerangkaApp(home: LoginPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LatarKaca), findsNothing);
      expect(AppTheme.terang().scaffoldBackgroundColor.a, 1);
    });
  });
}
