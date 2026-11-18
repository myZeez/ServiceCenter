import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show AdaptiveGlass, GlassContainer, GlassPullDownButton, GlassSwitch;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/data/prefs.dart';
import 'package:sc_management/core/fitur.dart';
import 'package:sc_management/core/kaca/kerangka_app.dart';
import 'package:sc_management/core/kaca/kursor_liquid.dart';
import 'package:sc_management/core/kaca/liquid.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/core/revenue/revenue_providers.dart';
import 'package:sc_management/core/theme.dart';
import 'package:sc_management/core/widgets/bento.dart';
import 'package:sc_management/core/widgets/filter_dropdown.dart';
import 'package:sc_management/features/claims/claims_page.dart';
import 'package:sc_management/features/service/service_reports_view.dart';
import 'package:sc_management/features/settings/tampilan_card.dart';
import 'package:sc_management/features/shell/admin_shell.dart';

const _pengguna = User(
  id: 't1',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  createdAt: '2026-01-01T00:00:00Z',
);

late Prefs _prefs;

List<Override> _dasarOverrides({bool superAdmin = false}) => [
  currentUserProvider.overrideWithValue(_pengguna),
  fiturTanyaHargaProvider.overrideWithValue(true),
  allClaimsProvider.overrideWith((ref) => Stream.value([])),
  allPartsProvider.overrideWith((ref) => Stream.value([])),
  allPartTypesProvider.overrideWith((ref) => Stream.value([])),
  allBrandsProvider.overrideWith(
    (ref) => Stream.value([const Brand(id: 1, nama: 'ASUS')]),
  ),
  allProfilesProvider.overrideWith(
    (ref) => Stream.value([
      Profile(
        id: 't1',
        nama: 'Budi',
        role: superAdmin ? 'super_admin' : 'admin',
      ),
    ]),
  ),
  allMetodeBayarProvider.overrideWith((ref) => Stream.value([])),
  serviceOrdersProvider.overrideWith((ref) => Stream.value([])),
  permintaanNotaProvider.overrideWith((ref) => Stream.value([])),
  partnerServicesProvider.overrideWith((ref) => Stream.value([])),
  customersProvider.overrideWith((ref) => Stream.value([])),
  partOrdersProvider.overrideWith((ref) => Stream.value([])),
  partCostsProvider.overrideWith((ref) => Stream.value([])),
  partSettingsProvider.overrideWith((ref) => Stream.value(null)),
  storeSettingsProvider.overrideWith((ref) => Stream.value(null)),
  shipmentsProvider.overrideWith((ref) => Stream.value([])),
  brandFeesProvider.overrideWith((ref) => Stream.value([])),
  settlementsProvider.overrideWith((ref) => Stream.value([])),
  koneksiProvider.overrideWith((ref) => Stream.value(true)),
  prefsProvider.overrideWithValue(_prefs),
];

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id', null);
    SharedPreferences.setMockInitialValues({});
    _prefs = await Prefs.buka();
  });

  group('Android: hanya navigasi atas/bawah yang berkaca cair', () {
    testWidgets(
      'AppBar kembali memakai TombolIkonLiquid sementara tombol formulir dan dropdown bebas kaca cair',
      (tester) async {
        String pilihan = 'a';
        var chipAktif = false;
        var filledKetuk = 0;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return KerangkaApp(
                kaca: false,
                liquid: true,
                home: Builder(
                  builder: (navCtx) => Scaffold(
                    body: Center(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(navCtx).push(
                            MaterialPageRoute<void>(
                              builder: (_) => Scaffold(
                                appBar: AppBar(title: const Text('Formulir')),
                                body: Column(
                                  children: [
                                    FilledButton(
                                      onPressed: () => filledKetuk++,
                                      child: const Text('Simpan'),
                                    ),
                                    OutlinedButton(
                                      onPressed: () {},
                                      child: const Text('Batal'),
                                    ),
                                    TextButton(
                                      onPressed: () {},
                                      child: const Text('Teks'),
                                    ),
                                    IconButton(
                                      onPressed: () {},
                                      icon: const Icon(Icons.edit),
                                    ),
                                    DropdownButtonFormField<String>(
                                      initialValue: pilihan,
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'a',
                                          child: Text('Satu'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'b',
                                          child: Text('Dua'),
                                        ),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) {
                                          setState(() => pilihan = v);
                                        }
                                      },
                                    ),
                                    FilterDropdown<String?>(
                                      value: pilihan,
                                      placeholder: 'Semua',
                                      items: const [('a', 'A'), ('b', 'B')],
                                      onChanged: (_) {},
                                    ),
                                    ChoiceChip(
                                      label: const Text('Cip'),
                                      selected: chipAktif,
                                      onSelected: (v) =>
                                          setState(() => chipAktif = v),
                                    ),
                                    StatTile(
                                      value: '5',
                                      label: 'Unit',
                                      onTap: () {},
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        child: const Text('Buka'),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );

        await tester.tap(find.text('Buka'));
        await tester.pumpAndSettle();

        // Tepat satu AdaptiveGlass: tombol kembali di AppBar. Tombol form,
        // dropdown, chip, dan ubin statistik tidak membungkus shader.
        expect(find.byType(TombolIkonLiquid), findsOneWidget);
        expect(find.byType(AdaptiveGlass), findsOneWidget);

        await tester.tap(find.text('Simpan'));
        await tester.pump();
        expect(filledKetuk, 1);

        // Tombol kembali tetap menutup halaman dengan normal.
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Formulir'), findsNothing);
      },
    );

    testWidgets(
      'ClaimsPage mempertahankan GlassPullDownButton untuk menu titik tiga atas',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            overrides: _dasarOverrides(superAdmin: false),
            child: const KerangkaApp(
              kaca: false,
              liquid: true,
              home: ClaimsPage(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(GlassPullDownButton), findsOneWidget);
        expect(find.byType(PopupMenuButton<String>), findsNothing);

        await tester.tap(find.byType(GlassPullDownButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Part'), findsOneWidget);
        expect(find.text('Pengaturan'), findsOneWidget);
        expect(find.text('Keluar'), findsOneWidget);
      },
    );
  });

  group('Windows: tanpa Liquid Glass UI, hanya kursor tetesan kaca cair', () {
    testWidgets(
      'Tema Windows (kaca: false, liquid: false, kursor: true) padat tanpa GayaLiquid namun tetap menyembunyikan panah pada tombol',
      (tester) async {
        final terang = AppTheme.terang(liquid: false, kursor: true);
        final gelap = AppTheme.gelap(liquid: false, kursor: true);

        expect(terang.extension<GayaLiquid>(), isNull);
        expect(terang.extension<GayaKaca>(), isNull);
        expect(terang.scaffoldBackgroundColor.a, 1);
        expect(terang.actionIconTheme, isNull);
        expect(gelap.extension<GayaLiquid>(), isNull);
        expect(gelap.scaffoldBackgroundColor.a, 1);

        expect(
          terang.filledButtonTheme.style?.mouseCursor?.resolve(const {}),
          SystemMouseCursors.none,
        );
        expect(
          terang.iconButtonTheme.style?.mouseCursor?.resolve(const {}),
          SystemMouseCursors.none,
        );
      },
    );

    testWidgets(
      'KursorLiquid mengikuti mouse, mengecil saat ditekan tanpa menghalangi tombol, dan tidak membungkus shader di kontrol Windows',
      (tester) async {
        var ketuk = 0;
        late BuildContext ctxDalam;

        await tester.pumpWidget(
          KerangkaApp(
            kaca: false,
            liquid: false,
            kursor: true,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  ctxDalam = context;
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton(
                          onPressed: () => ketuk++,
                          child: const Text('Aksi'),
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: 'a',
                          items: const [
                            DropdownMenuItem(value: 'a', child: Text('Alpha')),
                          ],
                          onChanged: (_) {},
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pump();

        expect(ctxDalam.liquid, isFalse);
        expect(KursorLiquid.aktifDi(ctxDalam), isTrue);
        // Sebelum pointer mouse masuk, nol AdaptiveGlass di layar Windows.
        expect(find.byType(AdaptiveGlass), findsNothing);

        final gerak = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await gerak.addPointer(location: const Offset(20, 20));
        await tester.pump();
        await gerak.moveTo(const Offset(120, 120));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 32));

        // Hanya satu AdaptiveGlass: tetesan KursorLiquid.
        expect(find.byType(AdaptiveGlass), findsOneWidget);

        await tester.tap(find.text('Aksi'));
        await tester.pump();
        expect(ketuk, 1);

        await gerak.removePointer();
        await tester.pump();
      },
    );

    testWidgets(
      'AdminShell & TampilanCard di Windows memakai tampilan padat tanpa GlassContainer atau GlassSwitch, cukup sakelar Kursor Liquid Glass',
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        SharedPreferences.setMockInitialValues({});
        await _prefs.tulis('tema.kaca', 'nyala');

        await tester.pumpWidget(
          ProviderScope(
            overrides: _dasarOverrides(),
            child: const KerangkaApp(
              kaca: false,
              liquid: false,
              kursor: true,
              home: AdminShell(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(GlassContainer), findsNothing);
        expect(find.byType(AdaptiveGlass), findsNothing);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('PENGATURAN'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(TampilanCard), findsOneWidget);
        expect(find.text('KURSOR LIQUID GLASS'), findsOneWidget);
        expect(find.byType(GlassSwitch), findsNothing);
        expect(find.byType(Switch), findsOneWidget);
        expect(find.text('Menyala'), findsOneWidget);

        await tester.tap(find.text('Menyala'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Mati'), findsOneWidget);
        expect(_prefs.baca('tema.kaca'), 'mati');
      },
    );
  });
}
