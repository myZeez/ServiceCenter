// Tampilan prioritas omset: sorotan di panel teknisi, antrian di Servis
// Baru, peringatan saat aplikasi dibuka, dan pengaturannya.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/omset/omset_providers.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/core/theme.dart';
import 'package:sc_management/features/service/service_dialog.dart';
import 'package:sc_management/features/service/service_view.dart';
import 'package:sc_management/features/settings/omset_card.dart';
import 'package:sc_management/features/shell/peringatan_omset.dart';

final _kini = DateTime.now();
final _awalBulan = DateTime(_kini.year, _kini.month, 1);

ServiceOrderEntry _selesai(String id, String teknisi, double biaya) =>
    ServiceOrderEntry(
      id: id,
      noNota: id,
      tanggalMasuk: _awalBulan,
      customerNama: 'Pelanggan',
      barangNama: 'ASUS',
      teknisiId: teknisi,
      status: 'diambil',
      biaya: biaya,
      tanggalSelesai: _awalBulan,
      updatedAt: _awalBulan,
    );

ServiceOrderEntry _masukHariIni(String id, String teknisi) => ServiceOrderEntry(
  id: id,
  noNota: id,
  tanggalMasuk: DateTime.now(),
  customerNama: 'Pelanggan',
  barangNama: 'ASUS',
  teknisiId: teknisi,
  status: 'dikerjakan',
  updatedAt: DateTime.now(),
);

ServiceSettingsRow _aturan({int hari = 10, double target = 4000000}) =>
    ServiceSettingsRow(
      id: 1,
      targetOmset: target,
      feeAdminPerNota: 0,
      hariPeringatanOmset: hari,
    );

const _profil = [
  Profile(id: 'aris', nama: 'Aris', role: 'teknisi'),
  Profile(id: 'daniel', nama: 'Daniel', role: 'teknisi'),
  Profile(id: 'reza', nama: 'Reza', role: 'teknisi'),
  Profile(id: 'irwan', nama: 'Irwan', role: 'teknisi'),
  Profile(id: 'admin', nama: 'admin', role: 'admin'),
];

// Angka dari panel yang dilihat pemilik toko.
List<ServiceOrderEntry> _dataToko() => [
  _selesai('1', 'aris', 4270000), // di atas target
  _selesai('2', 'reza', 3025000),
  _selesai('3', 'daniel', 860000),
  _selesai('4', 'irwan', 2655000),
  _selesai('5', 'admin', 9340000), // di atas target
];

Widget _bungkus(Widget anak, List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(theme: AppTheme.terang(), home: anak),
);

List<Override> _data({
  List<ServiceOrderEntry>? nota,
  ServiceSettingsRow? aturan,
  List<Profile> profil = _profil,
}) => [
  serviceOrdersProvider.overrideWith(
    (ref) => Stream.value(nota ?? _dataToko()),
  ),
  allProfilesProvider.overrideWith((ref) => Stream.value(profil)),
  omsetSettingsProvider.overrideWith(
    (ref) => Stream.value(aturan ?? _aturan()),
  ),
];

void main() {
  setUpAll(() => initializeDateFormatting('id', null));

  group('Panel teknisi', () {
    Future<void> lukis(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1366, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _bungkus(const Scaffold(body: ServiceView()), _data()),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('yang di bawah target disorot dengan kurangnya', (
      tester,
    ) async {
      await lukis(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('KURANG Rp3.140.000'), findsOneWidget); // Daniel
      expect(find.text('KURANG Rp1.345.000'), findsOneWidget); // Irwan
      expect(find.text('KURANG Rp975.000'), findsOneWidget); // Reza
    });

    testWidgets('yang sudah di atas target tidak disorot', (tester) async {
      await lukis(tester);

      // Tiga orang di bawah target (Daniel, Irwan, Reza): tiga sorotan,
      // bukan lima. Aris dan admin sudah di atas target.
      expect(find.textContaining('KURANG Rp'), findsNWidgets(3));
    });

    testWidgets('urutannya dari omset terendah ke tertinggi', (tester) async {
      await lukis(tester);

      double y(String teks) => tester.getTopLeft(find.text(teks)).dy;
      // Rp860.000 Daniel, Rp2.655.000 Irwan, Rp3.025.000 Reza,
      // Rp4.270.000 Aris, Rp9.340.000 admin.
      expect(
        y('Rp860.000  ·  1 selesai'),
        lessThan(y('Rp2.655.000  ·  1 selesai')),
      );
      expect(
        y('Rp2.655.000  ·  1 selesai'),
        lessThan(y('Rp3.025.000  ·  1 selesai')),
      );
      expect(
        y('Rp3.025.000  ·  1 selesai'),
        lessThan(y('Rp4.270.000  ·  1 selesai')),
      );
      expect(
        y('Rp4.270.000  ·  1 selesai'),
        lessThan(y('Rp9.340.000  ·  1 selesai')),
      );
    });
  });

  group('Antrian di Servis Baru', () {
    Future<void> lukis(
      WidgetTester tester, {
      List<ServiceOrderEntry>? nota,
      List<Profile> profil = _profil,
      ServiceOrderEntry? notaDibuka,
    }) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _bungkus(ServiceDialog(nota: notaDibuka), [
          ..._data(nota: nota, profil: profil),
          customersProvider.overrideWith((ref) => Stream.value(const [])),
          allClaimsProvider.overrideWith((ref) => Stream.value(const [])),
          allBrandsProvider.overrideWith((ref) => Stream.value(const [])),
        ]),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('muncul di nota baru, dengan yang paling perlu di atas', (
      tester,
    ) async {
      // Reza sudah dapat kerja hari ini; yang lain belum. Empat orang, jadi
      // seluruh antriannya terlihat.
      await lukis(
        tester,
        nota: [..._dataToko(), _masukHariIni('h1', 'reza')],
        profil: _profil.take(4).toList(),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('ANTRIAN HARI INI'), findsOneWidget);
      expect(find.text('BERIKUTNYA'), findsOneWidget);

      double y(String nama) => tester.getTopLeft(find.text(nama).first).dy;
      // Daniel (omset terendah, belum dapat kerja) mendahului Irwan; Aris
      // belum dapat kerja tetapi omsetnya cukup; Reza sudah dapat kerja
      // dan paling belakang.
      expect(y('Daniel'), lessThan(y('Irwan')));
      expect(y('Irwan'), lessThan(y('Aris')));
      expect(y('Aris'), lessThan(y('Reza')));
      expect(find.text('BELUM DAPAT KERJA HARI INI'), findsNWidgets(3));
      expect(find.text('1 nota hari ini'), findsOneWidget);
      expect(find.text('PUSH OMSET · kurang Rp3.140.000'), findsOneWidget);
    });

    testWidgets('mengetuk sebuah nama memilihnya sebagai teknisi', (
      tester,
    ) async {
      await lukis(tester);
      expect(
        find.widgetWithText(DropdownButtonFormField<String>, 'Reza'),
        findsNothing,
      );

      await tester.ensureVisible(find.text('Reza').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reza').first);
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(DropdownButtonFormField<String>, 'Reza'),
        findsOneWidget,
      );
    });

    testWidgets('antrian panjang dipotong, dan bisa dibuka semua', (
      tester,
    ) async {
      await lukis(tester);

      // Lima orang: empat baris dulu.
      expect(find.text('LIHAT SEMUA (5)'), findsOneWidget);
      expect(find.text('admin'), findsNothing);

      await tester.ensureVisible(find.text('LIHAT SEMUA (5)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('LIHAT SEMUA (5)'));
      await tester.pumpAndSettle();

      expect(find.text('admin'), findsWidgets);
      expect(find.text('TAMPILKAN SEDIKIT'), findsOneWidget);
    });

    testWidgets('tidak muncul saat membuka nota yang sudah ada', (
      tester,
    ) async {
      await lukis(
        tester,
        notaDibuka: ServiceOrderEntry(
          id: 'n1',
          noNota: 'SVR-21092628500',
          tanggalMasuk: DateTime.now(),
          customerNama: 'Irwan',
          barangNama: 'Laptop',
          teknisiId: 'reza',
          status: 'masuk',
          updatedAt: DateTime.now(),
        ),
      );

      expect(find.text('ANTRIAN HARI INI'), findsNothing);
    });
  });

  group('Peringatan saat aplikasi dibuka', () {
    Future<void> buka(
      WidgetTester tester, {
      required DateTime hari,
      bool admin = true,
      List<ServiceOrderEntry>? nota,
      ServiceSettingsRow? aturan,
      bool dataBelumSampai = false,
    }) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _bungkus(
          const PeringatanOmsetPembuka(
            child: Scaffold(body: Center(child: Text('beranda'))),
          ),
          [
            isAdminProvider.overrideWithValue(admin),
            hariPeringatanProvider.overrideWithValue(hari),
            ...(dataBelumSampai
                // Nota tidak pernah datang; yang lain sudah.
                ? [
                    serviceOrdersProvider.overrideWith(
                      (ref) => const Stream<List<ServiceOrderEntry>>.empty(),
                    ),
                    ..._data().skip(1),
                  ]
                : _data(nota: nota, aturan: aturan)),
          ],
        ),
      );
      await tester.pumpAndSettle();
    }

    bool sudah(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.text('beranda')))
            .read(peringatanOmsetSudahProvider);

    testWidgets('dalam sepuluh hari terakhir: menyebut yang kurang, terendah '
        'di atas', (tester) async {
      await buka(tester, hari: DateTime(2026, 9, 21));

      expect(tester.takeException(), isNull);
      expect(find.text('OMSET BULAN INI'), findsOneWidget);
      expect(find.text('Sisa 10 hari sebelum ganti bulan.'), findsOneWidget);
      expect(
        find.textContaining('3 teknisi masih di bawah target Rp4.000.000'),
        findsOneWidget,
      );

      double y(String nama) => tester.getTopLeft(find.text(nama)).dy;
      expect(y('Daniel'), lessThan(y('Irwan')));
      expect(y('Irwan'), lessThan(y('Reza')));
      // Yang sudah di atas target tidak disebut.
      expect(find.text('Aris'), findsNothing);
      expect(find.text('admin'), findsNothing);

      expect(find.text('KURANG'), findsNWidgets(3));
      expect(find.text('Rp3.140.000'), findsOneWidget);
    });

    testWidgets('sehari sebelum masa peringatan: tidak muncul', (tester) async {
      await buka(tester, hari: DateTime(2026, 9, 20));

      expect(find.text('OMSET BULAN INI'), findsNothing);
      // Sudah diputuskan untuk aplikasi ini; tidak diperiksa ulang.
      expect(sudah(tester), isTrue);
    });

    testWidgets('hari terakhir bulan menyebutnya', (tester) async {
      await buka(tester, hari: DateTime(2026, 9, 30));

      expect(find.text('Hari terakhir bulan ini.'), findsOneWidget);
    });

    testWidgets('bukan admin: tidak muncul', (tester) async {
      await buka(tester, hari: DateTime(2026, 9, 28), admin: false);

      expect(find.text('OMSET BULAN INI'), findsNothing);
    });

    testWidgets('semua sudah di atas target: tidak ada yang diingatkan', (
      tester,
    ) async {
      await buka(
        tester,
        hari: DateTime(2026, 9, 28),
        nota: [
          _selesai('1', 'aris', 5000000),
          _selesai('2', 'daniel', 4100000),
          _selesai('3', 'reza', 4000000),
          _selesai('4', 'irwan', 6000000),
          _selesai('5', 'admin', 9000000),
        ],
      );

      expect(find.text('OMSET BULAN INI'), findsNothing);
    });

    testWidgets('jumlah harinya mengikuti pengaturan', (tester) async {
      // Lima hari terakhir: 26 September menyala, 25 belum.
      await buka(tester, hari: DateTime(2026, 9, 25), aturan: _aturan(hari: 5));
      expect(find.text('OMSET BULAN INI'), findsNothing);
    });

    testWidgets('dan menyala saat masuk masa peringatannya', (tester) async {
      await buka(tester, hari: DateTime(2026, 9, 26), aturan: _aturan(hari: 5));
      expect(find.text('Sisa 5 hari sebelum ganti bulan.'), findsOneWidget);
    });

    testWidgets('nol mematikan peringatannya', (tester) async {
      await buka(tester, hari: DateTime(2026, 9, 30), aturan: _aturan(hari: 0));
      expect(find.text('OMSET BULAN INI'), findsNothing);
    });

    testWidgets('ditutup, lalu tidak muncul lagi selama aplikasi berjalan', (
      tester,
    ) async {
      await buka(tester, hari: DateTime(2026, 9, 22));
      expect(find.text('OMSET BULAN INI'), findsOneWidget);

      await tester.tap(find.text('MENGERTI'));
      await tester.pumpAndSettle();
      expect(find.text('OMSET BULAN INI'), findsNothing);

      // Halaman digambar ulang beberapa kali.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('OMSET BULAN INI'), findsNothing);
      expect(sudah(tester), isTrue);
    });

    testWidgets('menunggu datanya sampai, bukan menebak', (tester) async {
      await buka(tester, hari: DateTime(2026, 9, 28), dataBelumSampai: true);

      // Datanya belum lengkap: menyebut semua orang kurang lalu hilang
      // begitu datanya datang adalah peringatan palsu.
      expect(find.text('OMSET BULAN INI'), findsNothing);
      expect(sudah(tester), isFalse);
    });
  });

  group('Pengaturan peringatan', () {
    Future<void> lukis(WidgetTester tester, ServiceSettingsRow aturan) async {
      await tester.binding.setSurfaceSize(const Size(600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _bungkus(
          Scaffold(
            body: SizedBox(width: 520, height: 900, child: const OmsetCard()),
          ),
          [omsetSettingsProvider.overrideWith((ref) => Stream.value(aturan))],
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('kolomnya terisi dari pengaturan, dengan penjelasannya', (
      tester,
    ) async {
      await lukis(tester, _aturan(hari: 10));

      expect(tester.takeException(), isNull);
      expect(find.text('PERINGATAN AKHIR BULAN'), findsOneWidget);
      expect(find.text('Mulai 10 hari sebelum ganti bulan'), findsOneWidget);
    });

    testWidgets('nol tertulis sebagai mati', (tester) async {
      await lukis(tester, _aturan(hari: 0));

      expect(find.text('Peringatan mati'), findsOneWidget);
    });
  });
}
