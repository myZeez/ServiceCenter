// Status "Dikirim ke Cabang": unit yang dikerjakan di cabang lain.
//
// Yang dijaga: kalimatnya tepat seperti yang diminta toko, cabang dan
// tanggal hanya bermakna selama unitnya memang sedang dikirim, tanggalnya
// terisi hari ini tetapi bisa diubah, dan nota garansi brand -- yang
// statusnya milik klaim -- tidak ikut menawarkannya.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/export/excel_export.dart';
import 'package:sc_management/core/nota/kirim_cabang.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/features/service/service_dialog.dart';
import 'package:sc_management/features/service/service_page.dart';
import 'package:sc_management/features/service/service_status.dart';
import 'package:sc_management/features/settings/cabang_card.dart';

final _hariIni = DateFormat('dd-MM-yyyy').format(DateTime.now());

ServiceOrderEntry _nota({
  String status = 'masuk',
  String? cabang,
  DateTime? kirim,
  bool garansi = false,
  String? claimId,
}) => ServiceOrderEntry(
  id: 'nota-1',
  noNota: 'SVR-08092628300',
  tanggalMasuk: DateTime(2026, 9, 8),
  customerNama: 'Irwan',
  barangNama: 'Laptop Lenovo',
  teknisiId: 't1',
  garansi: garansi || claimId != null,
  claimId: claimId,
  status: status,
  cabangTujuan: cabang,
  tanggalKirim: kirim,
  updatedAt: DateTime(2026, 9, 8),
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

void main() {
  group('Kalimat pengiriman', () {
    test('persis seperti yang diminta toko', () {
      expect(
        keteranganKirimCabang('Pangkalan Bun', DateTime(2026, 9, 8)),
        'Unit dikirim ke Cabang Pangkalan Bun Tanggal 08-09-2026',
      );
    });

    test('nama cabang dirapikan dari spasi di ujung', () {
      expect(
        keteranganKirimCabang('  Sampit ', DateTime(2026, 12, 25)),
        'Unit dikirim ke Cabang Sampit Tanggal 25-12-2026',
      );
    });

    test('hanya berlaku selama unitnya memang sedang dikirim', () {
      final kirim = DateTime(2026, 9, 8);

      expect(
        _nota(
          status: 'dikirim_cabang',
          cabang: 'Kasongan',
          kirim: kirim,
        ).keteranganKirim,
        'Unit dikirim ke Cabang Kasongan Tanggal 08-09-2026',
      );

      // Cabang dan tanggal yang tersisa sesudah unitnya kembali hanya jejak.
      expect(
        _nota(
          status: 'dikerjakan',
          cabang: 'Kasongan',
          kirim: kirim,
        ).keteranganKirim,
        isNull,
      );
      // Keterangan yang belum lengkap tidak menghasilkan kalimat setengah.
      expect(
        _nota(status: 'dikirim_cabang', kirim: kirim).keteranganKirim,
        isNull,
      );
      expect(
        _nota(status: 'dikirim_cabang', cabang: 'Sampit').keteranganKirim,
        isNull,
      );
    });
  });

  group('Status', () {
    test('ada di daftar, urut menurut jalannya pekerjaan', () {
      expect(ServiceStatus.all, [
        'masuk',
        'dikerjakan',
        'tunggu_part',
        'dikirim_cabang',
        'selesai',
        'diambil',
        'batal',
      ]);
      expect(ServiceStatus.label('dikirim_cabang'), 'Dikirim ke Cabang');
    });

    test('unit yang dikirim masih dihitung sedang dikerjakan', () {
      expect(ServiceStatus.sedangDikerjakan('dikirim_cabang'), isTrue);
      expect(ServiceStatus.sedangDikerjakan('selesai'), isFalse);
    });

    test('sama persis dengan enum service_status di migrasi', () {
      // Nilai yang tidak ada di enum ditolak server dengan pesan yang tidak
      // menyebut status sama sekali -- dan yang terlihat hanya "gagal
      // menyimpan".
      final awal = File('../supabase/migrations/0005_administrasi_servis.sql')
          .readAsStringSync();
      final tambahan = File(
        '../supabase/migrations/0032_status_dikirim_cabang.sql',
      ).readAsStringSync();

      final enumAwal = RegExp(
        r"create type service_status as enum \((.*?)\);",
        dotAll: true,
      ).firstMatch(awal)!.group(1)!;
      final diSql = [
        ...RegExp(r"'([a-z_]+)'").allMatches(enumAwal).map((m) => m.group(1)!),
        ...RegExp(r"add value if not exists '([a-z_]+)'")
            .allMatches(tambahan)
            .map((m) => m.group(1)!),
      ];

      expect(diSql.toSet(), ServiceStatus.all.toSet());
    });

    test('nilai di kode sama dengan yang dipakai model dan ekspor', () {
      expect(ServiceStatus.dikirimCabang, statusDikirimCabang);
    });
  });

  group('Model', () {
    test('nota membaca cabang dan tanggal kirim', () {
      final n = ServiceOrderEntry.fromMap({
        'id': 'n1',
        'no_nota': 'SVR-08092628300',
        'tanggal_masuk': '2026-09-08T01:00:00+00:00',
        'customer_nama': 'Irwan',
        'barang_nama': 'Laptop',
        'status': 'dikirim_cabang',
        'cabang_tujuan': 'Lamandau',
        'tanggal_kirim': '2026-09-08',
        'updated_at': '2026-09-08T01:00:00+00:00',
      });
      expect(n.cabangTujuan, 'Lamandau');
      expect(n.tanggalKirim, DateTime(2026, 9, 8));
    });

    test('nota lama tanpa kolomnya tetap terbaca', () {
      final n = ServiceOrderEntry.fromMap({
        'id': 'n1',
        'no_nota': 'SVR-08092628300',
        'tanggal_masuk': '2026-09-08T01:00:00+00:00',
        'customer_nama': 'Irwan',
        'barang_nama': 'Laptop',
        'status': 'masuk',
        'updated_at': '2026-09-08T01:00:00+00:00',
      });
      expect(n.cabangTujuan, isNull);
      expect(n.tanggalKirim, isNull);
    });

    Map<String, dynamic> toko(Object? cabang, {bool ada = true}) => {
      'id': 1,
      'nama': 'Cellcom',
      if (ada) 'cabang': cabang,
    };

    test('daftar cabang dari larik JSON', () {
      final s = StoreSetting.fromMap(toko(['Pangkalan Bun', 'Sampit']));
      expect(s.cabang, ['Pangkalan Bun', 'Sampit']);
    });

    test(
      'daftar cabang dari literal array Postgres, nama berspasi dikutip',
      () {
        // Bentuk yang datang lewat Realtime. Dipecah begitu saja di koma,
        // "Pangkalan Bun" menjadi dua cabang yang tidak ada.
        final s = StoreSetting.fromMap(
          toko('{"Pangkalan Bun",Sampit,Kasongan,Lamandau}'),
        );
        expect(s.cabang, ['Pangkalan Bun', 'Sampit', 'Kasongan', 'Lamandau']);
      },
    );

    test('literal Postgres dengan koma, kutip, dan NULL di dalamnya', () {
      final s = StoreSetting.fromMap(
        toko(r'{"Bun, Pusat","Pak \"Haji\"",NULL,"NULL",Sampit}'),
      );
      expect(s.cabang, ['Bun, Pusat', 'Pak "Haji"', 'NULL', 'Sampit']);
    });

    test('daftar kosong tetap kosong, bukan bawaan', () {
      // Pemilik toko yang mengosongkan daftarnya sedang memutuskan sesuatu;
      // mengembalikan empat cabang diam-diam membatalkannya.
      expect(StoreSetting.fromMap(toko('{}')).cabang, isEmpty);
      expect(StoreSetting.fromMap(toko(<String>[])).cabang, isEmpty);
    });

    test('database yang belum dimigrasi memakai empat cabang bawaan', () {
      expect(StoreSetting.fromMap(toko(null, ada: false)).cabang, [
        'Pangkalan Bun',
        'Sampit',
        'Kasongan',
        'Lamandau',
      ]);
    });
  });

  group('Menambah cabang', () {
    const daftar = ['Pangkalan Bun', 'Sampit'];

    test('menambahkan di ujung, nama dirapikan', () {
      expect(cabangDitambah(daftar, '  Kasongan '), [...daftar, 'Kasongan']);
      expect(cabangDitambah(daftar, 'Kotawaringin   Lama'), [
        ...daftar,
        'Kotawaringin Lama',
      ]);
    });

    test('nama kosong, kembar, atau kepanjangan ditolak dengan alasan', () {
      expect(
        () => cabangDitambah(daftar, '   '),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => cabangDitambah(daftar, 'sampit'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'pesan',
            contains('sudah ada'),
          ),
        ),
      );
      expect(
        () => cabangDitambah(daftar, 'x' * 41),
        throwsA(isA<FormatException>()),
      );
    });

    test('daftar penuh ditolak', () {
      final penuh = [for (var i = 0; i < 30; i++) 'C$i'];
      expect(
        () => cabangDitambah(penuh, 'Baru'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Laporan', () {
    final kirim = DateTime(2026, 9, 8);

    test('kolom keterangan harian menyebut ke mana unitnya dikirim', () {
      expect(
        ExcelExport.keteranganHarian(
          _nota(
            status: 'dikirim_cabang',
            cabang: 'Pangkalan Bun',
            kirim: kirim,
          ),
        ),
        'Unit dikirim ke Cabang Pangkalan Bun Tanggal 08-09-2026',
      );
    });

    test('unit garansi menyebut garansi dan pengirimannya sekaligus', () {
      expect(
        ExcelExport.keteranganHarian(
          _nota(
            status: 'dikirim_cabang',
            cabang: 'Sampit',
            kirim: kirim,
            garansi: true,
          ),
        ),
        'Garansi. Unit dikirim ke Cabang Sampit Tanggal 08-09-2026',
      );
    });

    test('nota yang sudah kembali tidak lagi menyebut pengiriman', () {
      expect(
        ExcelExport.keteranganHarian(
          _nota(status: 'dikerjakan', cabang: 'Sampit', kirim: kirim),
        ),
        '',
      );
    });

    test('kolom status penerimaan menggantikan "Belum Diambil"', () {
      expect(
        ExcelExport.statusServis(
          _nota(status: 'dikirim_cabang', cabang: 'Kasongan', kirim: kirim),
        ),
        'Non Garansi (Unit dikirim ke Cabang Kasongan Tanggal 08-09-2026)',
      );
      expect(
        ExcelExport.statusServis(_nota(status: 'dikerjakan')),
        'Non Garansi (Barang Belum Diambil)',
      );
    });
  });

  group('Chip status', () {
    Future<void> lukis(
      WidgetTester tester,
      ServiceOrderEntry nota, {
      bool compact = false,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allClaimsProvider.overrideWith((ref) => Stream.value(const [])),
            allBrandsProvider.overrideWith((ref) => Stream.value(const [])),
          ],
          child: MaterialApp(
            home: Scaffold(body: StatusNotaChip(nota, compact: compact)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('menyebut cabang tujuannya', (tester) async {
      await lukis(
        tester,
        _nota(
          status: 'dikirim_cabang',
          cabang: 'Pangkalan Bun',
          kirim: DateTime(2026, 9, 8),
        ),
      );
      expect(find.text('DIKIRIM KE PANGKALAN BUN'), findsOneWidget);
    });

    testWidgets('bentuk ringkas untuk kolom sempit', (tester) async {
      await lukis(
        tester,
        _nota(
          status: 'dikirim_cabang',
          cabang: 'Sampit',
          kirim: DateTime(2026, 9, 8),
        ),
        compact: true,
      );
      expect(find.text('KE SAMPIT'), findsOneWidget);
    });

    testWidgets('tanpa cabang tetap terbaca sebagai status', (tester) async {
      await lukis(tester, _nota(status: 'dikirim_cabang'));
      expect(find.text('DIKIRIM KE CABANG'), findsOneWidget);
    });

    testWidgets('keterangan lengkapnya keluar saat ditahan', (tester) async {
      await lukis(
        tester,
        _nota(
          status: 'dikirim_cabang',
          cabang: 'Pangkalan Bun',
          kirim: DateTime(2026, 9, 8),
        ),
      );
      final tip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(
        tip.message,
        'Unit dikirim ke Cabang Pangkalan Bun Tanggal 08-09-2026',
      );
    });
  });

  group('Formulir nota', () {
    Future<void> lukis(
      WidgetTester tester, {
      ServiceOrderEntry? nota,
      List<Claim> klaim = const [],
    }) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storeSettingsProvider.overrideWith(
              (ref) => Stream.value(const StoreSetting(id: 1, nama: 'Cellcom')),
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

    Future<void> pilihStatus(
      WidgetTester tester,
      String dari,
      String ke,
    ) async {
      final dropdown = find.widgetWithText(
        DropdownButtonFormField<String>,
        dari,
      );
      await tester.ensureVisible(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text(ke).last);
      await tester.pumpAndSettle();
    }

    Future<void> pilihCabang(WidgetTester tester, String nama) async {
      final dropdown = find.widgetWithText(
        DropdownButtonFormField<String>,
        'Pilih cabang',
      );
      await tester.ensureVisible(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text(nama).last);
      await tester.pumpAndSettle();
    }

    testWidgets('kolom cabang tidak ada di status lain', (tester) async {
      await lukis(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('CABANG TUJUAN'), findsNothing);
      expect(find.text('TANGGAL DIKIRIM'), findsNothing);
    });

    testWidgets('memilih Dikirim ke Cabang memunculkan cabang dan tanggal '
        'yang terisi hari ini', (tester) async {
      await lukis(tester);
      await pilihStatus(tester, 'Masuk', 'Dikirim ke Cabang');

      expect(find.text('CABANG TUJUAN'), findsOneWidget);
      expect(find.text('TANGGAL DIKIRIM'), findsOneWidget);
      // Tanggal sudah terisi sebelum ada yang mengetik apa pun.
      expect(find.text(_hariIni), findsOneWidget);
      // Belum ada cabang, jadi belum ada kalimat.
      expect(find.textContaining('Unit dikirim ke Cabang'), findsNothing);
    });

    testWidgets('kalimatnya tampil begitu cabang dipilih', (tester) async {
      await lukis(tester);
      await pilihStatus(tester, 'Masuk', 'Dikirim ke Cabang');
      await pilihCabang(tester, 'Sampit');

      expect(
        find.text('Unit dikirim ke Cabang Sampit Tanggal $_hariIni'),
        findsOneWidget,
      );
    });

    testWidgets('keempat cabang bawaan ditawarkan', (tester) async {
      await lukis(tester);
      await pilihStatus(tester, 'Masuk', 'Dikirim ke Cabang');

      final dropdown = find.widgetWithText(
        DropdownButtonFormField<String>,
        'Pilih cabang',
      );
      await tester.ensureVisible(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      for (final c in ['Pangkalan Bun', 'Sampit', 'Kasongan', 'Lamandau']) {
        expect(find.text(c), findsWidgets, reason: c);
      }
    });

    testWidgets('menyimpan tanpa cabang ditolak dengan pesan yang jelas', (
      tester,
    ) async {
      await lukis(tester);
      await pilihStatus(tester, 'Masuk', 'Dikirim ke Cabang');

      final simpan = find.widgetWithText(FilledButton, 'SIMPAN NOTA');
      await tester.ensureVisible(simpan);
      await tester.pumpAndSettle();
      await tester.tap(simpan);
      await tester.pumpAndSettle();

      expect(find.text('Pilih cabang tujuan'), findsOneWidget);
    });

    testWidgets('nota yang sedang dikirim menampilkan keterangan tersimpan', (
      tester,
    ) async {
      await lukis(
        tester,
        nota: _nota(
          status: 'dikirim_cabang',
          cabang: 'Pangkalan Bun',
          kirim: DateTime(2026, 9, 8),
        ),
      );

      expect(
        find.text('Unit dikirim ke Cabang Pangkalan Bun Tanggal 08-09-2026'),
        findsOneWidget,
      );
      // Tanggal yang tersimpan dipakai, bukan hari ini.
      expect(find.text('08-09-2026'), findsOneWidget);
    });

    testWidgets('dikirim lagi sesudah kembali memakai tanggal hari ini, '
        'bukan jejak yang lama', (tester) async {
      await lukis(
        tester,
        nota: _nota(
          status: 'dikerjakan',
          cabang: 'Sampit',
          kirim: DateTime(2026, 9, 1),
        ),
      );
      await pilihStatus(tester, 'Dikerjakan', 'Dikirim ke Cabang');

      expect(find.text('01-09-2026'), findsNothing);
      expect(find.text(_hariIni), findsOneWidget);
      // Cabang terakhir ikut terisi, tinggal dikonfirmasi.
      expect(
        find.text('Unit dikirim ke Cabang Sampit Tanggal $_hariIni'),
        findsOneWidget,
      );
    });

    testWidgets('cabang yang sudah dihapus dari daftar tetap terbaca', (
      tester,
    ) async {
      await lukis(
        tester,
        nota: _nota(
          status: 'dikirim_cabang',
          cabang: 'Cabang Lama',
          kirim: DateTime(2026, 9, 8),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.text('Unit dikirim ke Cabang Cabang Lama Tanggal 08-09-2026'),
        findsOneWidget,
      );
    });

    testWidgets('nota garansi brand memakai status klaimnya, tanpa pilihan '
        'kirim ke cabang', (tester) async {
      await lukis(
        tester,
        nota: _nota(claimId: 'k1'),
        klaim: [_klaim('k1')],
      );

      expect(find.text('STATUS GARANSI'), findsOneWidget);
      expect(find.text('Dikirim ke Cabang'), findsNothing);
    });
  });

  group('Lembar ubah di HP', () {
    testWidgets('memilih Dikirim ke Cabang meminta cabang dan tanggal', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storeSettingsProvider.overrideWith(
              (ref) => Stream.value(const StoreSetting(id: 1, nama: 'Cellcom')),
            ),
            serviceOrdersProvider.overrideWith(
              (ref) => Stream.value([_nota(status: 'dikerjakan')]),
            ),
            allProfilesProvider.overrideWith(
              (ref) => Stream.value([
                const Profile(id: 't1', nama: 'Reza', role: 'teknisi'),
              ]),
            ),
            allClaimsProvider.overrideWith((ref) => Stream.value(const [])),
            allBrandsProvider.overrideWith((ref) => Stream.value(const [])),
            koneksiProvider.overrideWith((ref) => Stream.value(true)),
          ],
          child: const MaterialApp(home: ServicePage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Irwan'));
      await tester.pumpAndSettle();
      expect(find.text('CABANG TUJUAN'), findsNothing);

      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Dikerjakan'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dikirim ke Cabang').last);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('CABANG TUJUAN'), findsOneWidget);
      expect(find.text(_hariIni), findsOneWidget);
    });
  });
}
