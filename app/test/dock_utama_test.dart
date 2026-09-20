// Dock kapsul di halaman utama layar sempit, dan Servisku di dalamnya.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/core/theme.dart';
import 'package:sc_management/features/claims/claims_page.dart';
import 'package:sc_management/features/claims/dock_utama.dart';

const _saya = User(
  id: 't1',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  createdAt: '2026-01-01T00:00:00Z',
);

DateTime _hariLalu(int n) {
  final k = DateTime.now().subtract(Duration(days: n));
  return DateTime(k.year, k.month, k.day);
}

ServiceOrderEntry _nota(
  String nama, {
  String status = 'dikerjakan',
  String? teknisi = 't1',
  DateTime? selesai,
}) => ServiceOrderEntry(
  id: nama,
  noNota: 'SVR-$nama',
  tanggalMasuk: DateTime(2026, 9, 4),
  customerNama: nama,
  barangNama: 'ASUS',
  barangType: 'X441',
  keluhan: 'Mati total',
  teknisiId: teknisi,
  status: status,
  tanggalSelesai: selesai,
  updatedAt: DateTime(2026, 9, 4),
);

Claim _klaim(String id, String nama) => Claim(
  id: id,
  tanggal: DateTime(2026, 9, 4),
  brandId: 1,
  namaPelanggan: nama,
  sn: 'SN$id',
  status: 'open',
  createdBy: 'adm',
  createdAt: DateTime(2026, 9, 4),
  updatedAt: DateTime(2026, 9, 4),
);

Future<void> _lukisHalaman(
  WidgetTester tester, {
  List<ServiceOrderEntry> nota = const [],
  List<Claim> klaim = const [],
  ThemeData? tema,
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_saya),
        allClaimsProvider.overrideWith((ref) => Stream.value(klaim)),
        allPartsProvider.overrideWith((ref) => Stream.value([])),
        allBrandsProvider.overrideWith(
          (ref) => Stream.value([const Brand(id: 1, nama: 'ASUS')]),
        ),
        allProfilesProvider.overrideWith(
          (ref) => Stream.value([
            const Profile(id: 't1', nama: 'Reza', role: 'teknisi'),
          ]),
        ),
        serviceOrdersProvider.overrideWith((ref) => Stream.value(nota)),
        koneksiProvider.overrideWith((ref) => Stream.value(true)),
      ],
      child: MaterialApp(
        theme: tema ?? AppTheme.terang(),
        home: const ClaimsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Teks di dalam dock saja: "Klaim Garansi" juga judul halaman, dan
/// "Servisku" juga judul setelah tab-nya dibuka.
Finder _didock(String teks) =>
    find.descendant(of: find.byType(DockUtama), matching: find.text(teks));

void main() {
  group('DockUtama', () {
    Future<void> lukis(
      WidgetTester tester, {
      TabUtama tab = TabUtama.klaim,
      int jumlah = 0,
      ValueChanged<TabUtama>? onTab,
      VoidCallback? onBaru,
      ThemeData? tema,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: tema ?? AppTheme.terang(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: DockUtama(
                tab: tab,
                jumlahServisku: jumlah,
                onTab: onTab ?? (_) {},
                onKlaimBaru: onBaru ?? () {},
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'memuat tiga menu; tengahnya hanya ikon tambah, tanpa tulisan',
      (tester) async {
        await lukis(tester);

        expect(find.text('Klaim Garansi'), findsOneWidget);
        expect(find.text('Servisku'), findsOneWidget);
        expect(find.byIcon(Icons.add), findsOneWidget);
        // Tengahnya sengaja polos supaya kedua sisinya lega.
        expect(find.text('KLAIM BARU'), findsNothing);
        expect(find.text('Klaim Baru'), findsNothing);
      },
    );

    testWidgets('tombol tambah tetap punya nama untuk pembaca layar', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      await lukis(tester);

      expect(find.bySemanticsLabel('Klaim Baru'), findsOneWidget);
      semantik.dispose();
    });

    testWidgets('setiap menu memanggil yang semestinya', (tester) async {
      final tab = <TabUtama>[];
      var baru = 0;
      await lukis(tester, onTab: tab.add, onBaru: () => baru++);

      await tester.tap(find.text('Servisku'));
      await tester.tap(find.text('Klaim Garansi'));
      await tester.tap(find.byIcon(Icons.add));

      expect(tab, [TabUtama.servisku, TabUtama.klaim]);
      // Klaim Baru bukan tab: ia membuka formulir, bukan berpindah isi.
      expect(baru, 1);
    });

    testWidgets('ketukan di luar teksnya pun kena: seluruh ruang menu hidup', (
      tester,
    ) async {
      final tab = <TabUtama>[];
      await lukis(tester, onTab: tab.add);

      // Ujung kiri dan kanan dock, jauh dari label dan ikonnya.
      final dock = tester.getRect(find.byType(DockUtama));
      await tester.tapAt(Offset(dock.left + 24, dock.center.dy));
      await tester.tapAt(Offset(dock.right - 24, dock.center.dy));

      expect(tab, [TabUtama.klaim, TabUtama.servisku]);
    });

    testWidgets('kedua sisi lega: tiap menu selebar seratus lebih', (
      tester,
    ) async {
      await lukis(tester);

      for (final label in ['Klaim Garansi', 'Servisku']) {
        final menu = find.ancestor(
          of: find.text(label),
          matching: find.byType(InkWell),
        );
        expect(
          tester.getSize(menu).width,
          greaterThan(100),
          reason: 'menu $label terlalu sempit',
        );
      }
    });

    testWidgets('tinggi dock lebih dari 64, lebarnya tidak melebihi 320', (
      tester,
    ) async {
      await lukis(tester);

      final ukuran = tester.getSize(find.byType(DockUtama));
      expect(ukuran.height, greaterThan(64));
      expect(ukuran.width, lessThanOrEqualTo(320));
    });

    testWidgets('penanda tab meluncur ke menu yang diketuk, bukan melompat', (
      tester,
    ) async {
      await lukis(tester, tab: TabUtama.klaim);
      final penanda = find.byKey(DockUtama.kunciPenanda);
      final kiri = tester.getCenter(penanda).dx;

      await lukis(tester, tab: TabUtama.servisku);
      // Baru satu frame: belum sempat bergerak jauh.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final tengah = tester.getCenter(penanda).dx;

      await tester.pumpAndSettle();
      final kanan = tester.getCenter(penanda).dx;

      expect(kanan, greaterThan(kiri));
      expect(tengah, greaterThan(kiri), reason: 'sudah mulai bergerak');
      expect(tengah, lessThan(kanan), reason: 'belum sampai');
    });

    testWidgets('penanda kembali ke kiri saat Klaim Garansi diketuk lagi', (
      tester,
    ) async {
      await lukis(tester, tab: TabUtama.servisku);
      final penanda = find.byKey(DockUtama.kunciPenanda);
      final kanan = tester.getCenter(penanda).dx;

      await lukis(tester, tab: TabUtama.klaim);
      await tester.pumpAndSettle();

      expect(tester.getCenter(penanda).dx, lessThan(kanan));
    });

    testWidgets('penanda tidak menutupi tombol tambah', (tester) async {
      await lukis(tester, tab: TabUtama.klaim);
      final penanda = tester.getRect(find.byKey(DockUtama.kunciPenanda));
      final tambah = tester.getRect(find.byIcon(Icons.add));
      expect(penanda.overlaps(tambah), isFalse);

      await lukis(tester, tab: TabUtama.servisku);
      await tester.pumpAndSettle();
      final penandaKanan = tester.getRect(find.byKey(DockUtama.kunciPenanda));
      expect(penandaKanan.overlaps(tambah), isFalse);
    });

    testWidgets('animasi dimatikan di sistem: penanda langsung di tempatnya', (
      tester,
    ) async {
      Future<void> lukisTanpaGerak(TabUtama tab) => tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.terang(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: DockUtama(tab: tab, onTab: (_) {}, onKlaimBaru: () {}),
            ),
          ),
        ),
      );

      await lukisTanpaGerak(TabUtama.klaim);
      final penanda = find.byKey(DockUtama.kunciPenanda);
      final kiri = tester.getCenter(penanda).dx;

      await lukisTanpaGerak(TabUtama.servisku);
      await tester.pump(); // satu frame saja

      expect(tester.getCenter(penanda).dx, greaterThan(kiri + 100));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('hanya tab aktif yang ditandai terpilih', (tester) async {
      final semantik = tester.ensureSemantics();
      await lukis(tester, tab: TabUtama.servisku);

      SemanticsNode simpul(String label) =>
          tester.getSemantics(find.bySemanticsLabel(label));

      expect(simpul('Servisku'), isSemantics(isSelected: true));
      expect(simpul('Klaim Garansi'), isNot(isSemantics(isSelected: true)));
      semantik.dispose();
    });

    testWidgets('lencana Servisku: tersembunyi di nol, dibatasi 99+', (
      tester,
    ) async {
      await lukis(tester, jumlah: 0);
      expect(find.text('0'), findsNothing);

      await lukis(tester, jumlah: 7);
      expect(find.text('7'), findsOneWidget);

      await lukis(tester, jumlah: 250);
      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('tergambar di tema terang dan gelap tanpa galat', (
      tester,
    ) async {
      await lukis(tester, jumlah: 3);
      expect(tester.takeException(), isNull);

      await lukis(tester, jumlah: 3, tema: AppTheme.gelap());
      expect(tester.takeException(), isNull);
    });

    testWidgets('kacanya mengaburkan yang ada di belakangnya', (tester) async {
      await lukis(tester);

      expect(
        find.descendant(
          of: find.byType(DockUtama),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
      );
    });

    testWidgets('muat di layar tersempit tanpa meluap', (tester) async {
      await tester.binding.setSurfaceSize(const Size(300, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await lukis(tester, jumlah: 12);

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(DockUtama)).width,
        lessThanOrEqualTo(300),
      );
    });
  });

  group('halaman utama', () {
    testWidgets('dock menggantikan tombol melayang Klaim Baru', (tester) async {
      await _lukisHalaman(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(DockUtama), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(
        find.descendant(
          of: find.byType(DockUtama),
          matching: find.byIcon(Icons.add),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'Servisku hanya memuat unit yang sedang dikerjakan atas namaku',
      (tester) async {
        await _lukisHalaman(
          tester,
          nota: [
            _nota('Jamal'),
            _nota('Soni', status: 'masuk'),
            _nota('Orang', teknisi: 'lain'),
            _nota('Rara', status: 'selesai', selesai: _hariLalu(5)),
            _nota('Batal', status: 'batal'),
          ],
        );

        await tester.tap(_didock('Servisku'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Jamal'), findsOneWidget);
        expect(find.text('Soni'), findsOneWidget);
        expect(find.text('Orang'), findsNothing);
        expect(find.text('Rara'), findsNothing);
        expect(find.text('Batal'), findsNothing);

        expect(find.text('SEDANG DIKERJAKAN  2'), findsOneWidget);
        expect(find.text('SUDAH SELESAI  1'), findsOneWidget);
      },
    );

    testWidgets('isi bergeser searah penanda saat berpindah menu', (
      tester,
    ) async {
      await _lukisHalaman(tester, nota: [_nota('Jamal')]);
      final klaim = find.byKey(const ValueKey<TabUtama>(TabUtama.klaim));
      final servisku = find.byKey(const ValueKey<TabUtama>(TabUtama.servisku));

      // Ke Servisku (kanan): ia datang dari kanan, klaim keluar ke kiri.
      await tester.tap(_didock('Servisku'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getTopLeft(servisku).dx, greaterThan(0));
      expect(tester.getTopLeft(klaim).dx, lessThan(0));

      await tester.pumpAndSettle();
      expect(tester.getTopLeft(servisku).dx, 0);
      expect(klaim, findsNothing);

      // Kembali (kiri): klaim datang dari kiri, Servisku keluar ke kanan.
      await tester.tap(_didock('Klaim Garansi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getTopLeft(klaim).dx, lessThan(0));
      expect(tester.getTopLeft(servisku).dx, greaterThan(0));

      await tester.pumpAndSettle();
      expect(tester.getTopLeft(klaim).dx, 0);
      expect(servisku, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mengetuk menu yang sedang aktif tidak menggerakkan apa-apa', (
      tester,
    ) async {
      await _lukisHalaman(tester);
      final klaim = find.byKey(const ValueKey<TabUtama>(TabUtama.klaim));

      await tester.tap(_didock('Klaim Garansi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tidak bergeser, dan tidak ada isi kedua yang ikut masuk.
      expect(tester.getTopLeft(klaim).dx, 0);
      expect(
        find.byKey(const ValueKey<TabUtama>(TabUtama.servisku)),
        findsNothing,
      );
    });

    testWidgets('judul halaman mengikuti tab', (tester) async {
      await _lukisHalaman(tester);

      expect(find.text('Klaim Garansi'), findsNWidgets(2)); // judul + dock
      await tester.tap(_didock('Servisku'));
      await tester.pumpAndSettle();

      expect(find.text('Servisku'), findsNWidgets(2)); // judul + dock
      expect(find.text('Klaim Garansi'), findsOneWidget); // tinggal dock
    });

    testWidgets('tombol Sudah Selesai menampilkan tiga bulan terakhir', (
      tester,
    ) async {
      await _lukisHalaman(
        tester,
        nota: [
          _nota('Jamal'),
          _nota('Baru', status: 'selesai', selesai: _hariLalu(5)),
          _nota('Diambil', status: 'diambil', selesai: _hariLalu(40)),
          _nota('Lawas', status: 'diambil', selesai: _hariLalu(120)),
        ],
      );
      await tester.tap(_didock('Servisku'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SUDAH SELESAI  2'));
      await tester.pumpAndSettle();

      expect(find.text('Baru'), findsOneWidget);
      expect(find.text('Diambil'), findsOneWidget);
      expect(find.text('Lawas'), findsNothing);
      expect(find.text('Jamal'), findsNothing);
      // Yang terbaru selesai di atas.
      expect(
        tester.getTopLeft(find.text('Baru')).dy,
        lessThan(tester.getTopLeft(find.text('Diambil')).dy),
      );
      // Kapan selesainya disebut di kartu.
      expect(find.textContaining('Selesai '), findsWidgets);
    });

    testWidgets('lencana di dock menghitung unit yang sedang dipegang', (
      tester,
    ) async {
      await _lukisHalaman(
        tester,
        nota: [
          _nota('A'),
          _nota('B', status: 'tunggu_part'),
          _nota('C', status: 'selesai', selesai: _hariLalu(1)),
          _nota('D', teknisi: 'lain'),
        ],
      );

      expect(
        find.descendant(of: find.byType(DockUtama), matching: find.text('2')),
        findsOneWidget,
      );
    });

    testWidgets('kembali ke Klaim menampilkan daftar klaimnya lagi', (
      tester,
    ) async {
      await _lukisHalaman(tester, klaim: [_klaim('1', 'Pelanggan Klaim')]);
      expect(find.text('Pelanggan Klaim'), findsOneWidget);

      await tester.tap(_didock('Servisku'));
      await tester.pumpAndSettle();
      expect(find.text('Pelanggan Klaim'), findsNothing);

      await tester.tap(_didock('Klaim Garansi'));
      await tester.pumpAndSettle();
      expect(find.text('Pelanggan Klaim'), findsOneWidget);
    });

    testWidgets('Servisku kosong menjelaskan diri, dan tetap bisa ditarik', (
      tester,
    ) async {
      await _lukisHalaman(tester);
      await tester.tap(_didock('Servisku'));
      await tester.pumpAndSettle();

      expect(
        find.text('Tidak ada unit yang sedang kamu kerjakan'),
        findsOneWidget,
      );
      expect(find.byType(RefreshIndicator), findsOneWidget);

      await tester.tap(find.text('SUDAH SELESAI  0'));
      await tester.pumpAndSettle();
      expect(find.text('Belum ada unit selesai'), findsOneWidget);
    });

    testWidgets('dock menyingkir selama papan ketik terbuka', (tester) async {
      await _lukisHalaman(tester);

      AnimatedOpacity kabut() => tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byType(DockUtama),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(kabut().opacity, 1);

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      expect(kabut().opacity, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('daftar klaim tidak tertutup dock di ujung bawahnya', (
      tester,
    ) async {
      await _lukisHalaman(
        tester,
        klaim: [for (var i = 0; i < 12; i++) _klaim('$i', 'Klaim $i')],
      );

      await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
      await tester.pumpAndSettle();

      final dock = tester.getTopLeft(find.byType(DockUtama)).dy;
      final terakhir = tester.getBottomLeft(find.text('Klaim 11')).dy;
      expect(terakhir, lessThan(dock));
    });

    testWidgets('tema gelap tergambar tanpa galat', (tester) async {
      await _lukisHalaman(tester, tema: AppTheme.gelap());

      expect(tester.takeException(), isNull);
      expect(find.byType(DockUtama), findsOneWidget);
    });
  });
}
