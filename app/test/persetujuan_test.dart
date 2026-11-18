// Nota yang sudah keluar hanya berubah lewat persetujuan super admin.
//
// Kuncinya ada di server, dan aturannya diuji di sana. Yang dijaga di sini
// adalah bagian yang dilihat orang: yang akan berubah harus terbaca sebelum
// diajukan, dan tombol keputusan hanya ada di tangan yang berhak.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:sc_management/core/data/db.dart';
import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/features/persetujuan/persetujuan_view.dart';
import 'package:sc_management/features/persetujuan/perubahan_nota.dart';
import 'package:sc_management/features/persetujuan/simpan_nota_terkunci.dart';
import 'package:sc_management/features/service/service_status.dart';

class _DbPalsu implements Db {
  _DbPalsu([this.jawaban = const []]);

  /// Hasil ajukanPerubahanNota, berurutan.
  final List<Map<String, dynamic>> jawaban;

  final alasanDiterima = <String?>[];
  final putusan = <String>[];
  final dibatalkan = <String>[];

  @override
  Future<Map<String, dynamic>> ajukanPerubahanNota(
    String notaId,
    Map<String, dynamic> data, {
    String? alasan,
  }) async {
    alasanDiterima.add(alasan);
    return jawaban[alasanDiterima.length - 1];
  }

  @override
  Future<void> putuskanPermintaanNota(
    String id, {
    required bool setuju,
    String? catatan,
  }) async => putusan.add('$id:$setuju:$catatan');

  @override
  Future<void> batalkanPermintaanNota(String id) async => dibatalkan.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PermintaanUbahNota _permintaan({
  String id = 'p1',
  String status = 'menunggu',
  String oleh = 'admin',
}) => PermintaanUbahNota.fromMap({
  'id': id,
  'service_order_id': 'nota-1',
  'no_nota': 'SVR-0111262900$id',
  'perubahan': {'biaya': 175000},
  'sebelum': {'biaya': 150000},
  'alasan': 'Salah ketik',
  'status': status,
  'diajukan_oleh': oleh,
  'diajukan_pada': '2026-11-01T03:00:00Z',
  'diputus_oleh': status == 'menunggu' ? null : 'super',
  'diputus_pada': status == 'menunggu' ? null : '2026-11-01T04:00:00Z',
  'catatan_putusan': status == 'ditolak' ? 'Tidak jelas' : null,
});

void main() {
  setUpAll(() => initializeDateFormatting('id', null));

  test('hanya Diambil dan Batal yang terkunci', () {
    for (final s in ServiceStatus.all) {
      expect(
        ServiceStatus.terkunci(s),
        s == ServiceStatus.diambil || s == ServiceStatus.batal,
        reason: s,
      );
    }
  });

  group('baruKeluar', () {
    test('nota baru atau nota berjalan yang keluar dicap', () {
      expect(
        ServiceStatus.baruKeluar(sebelum: null, sesudah: 'diambil'),
        isTrue,
      );
      expect(
        ServiceStatus.baruKeluar(sebelum: 'selesai', sesudah: 'diambil'),
        isTrue,
      );
      expect(
        ServiceStatus.baruKeluar(sebelum: 'masuk', sesudah: 'batal'),
        isTrue,
      );
    });

    test('arsip yang disunting tidak pindah ke hari ini', () {
      expect(
        ServiceStatus.baruKeluar(sebelum: 'diambil', sesudah: 'diambil'),
        isFalse,
      );
      expect(
        ServiceStatus.baruKeluar(sebelum: 'batal', sesudah: 'diambil'),
        isFalse,
      );
    });

    test('yang belum keluar tidak dicap', () {
      expect(
        ServiceStatus.baruKeluar(sebelum: 'masuk', sesudah: 'selesai'),
        isFalse,
      );
    });
  });

  group('barisPerubahan', () {
    List<BarisPerubahan> baris(
      Map<String, dynamic> perubahan,
      Map<String, dynamic> sebelum,
    ) => barisPerubahan(
      perubahan: perubahan,
      sebelum: sebelum,
      namaOrang: const {'t1': 'Aris', 't2': 'Reza'},
      namaMetode: const {'cash': 'Cash', 'qris': 'QRIS'},
    );

    test('biaya, status, dan orang ditulis seperti di layar', () {
      final b = baris(
        {'biaya': 175000, 'status': 'selesai', 'teknisi_id': 't2'},
        {'biaya': 150000, 'status': 'diambil', 'teknisi_id': 't1'},
      );

      expect(b.map((x) => x.label), ['Biaya', 'Status', 'Teknisi']);
      expect(b[0].sebelum, 'Rp150.000');
      expect(b[0].sesudah, 'Rp175.000');
      expect(b[1].sebelum, 'Sudah Diambil');
      expect(b[1].sesudah, 'Selesai');
      expect(b[2].sebelum, 'Aris');
      expect(b[2].sesudah, 'Reza');
    });

    test('kosong dan tanggal terbaca', () {
      final b = baris(
        {
          'customer_telp': null,
          'tanggal_diambil': '2026-11-02',
          'cara_bayar': 'qris',
        },
        {
          'customer_telp': '0812',
          'tanggal_diambil': null,
          'cara_bayar': 'cash',
        },
      );

      expect(b[0].sebelum, '0812');
      expect(b[0].sesudah, '—');
      expect(b[1].sebelum, '—');
      expect(b[1].sesudah, '02/11/2026');
      expect(b[2].sesudah, 'QRIS');
    });
  });

  group('simpanNotaTerkunci', () {
    Future<HasilSimpanTerkunci?> jalankan(
      WidgetTester tester,
      _DbPalsu db,
      Future<void> Function() langkah,
    ) async {
      HasilSimpanTerkunci? hasil;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            allProfilesProvider.overrideWith((ref) => Stream.value(const [])),
            allMetodeBayarProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    hasil = await simpanNotaTerkunci(context, ref, 'nota-1', {
                      'biaya': 175000,
                    });
                  },
                  child: const Text('SIMPAN'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('SIMPAN'));
      await tester.pumpAndSettle();
      await langkah();
      await tester.pumpAndSettle();
      return hasil;
    }

    const perluAlasan = {
      'status': 'perlu_alasan',
      'perubahan': {'biaya': 175000},
      'sebelum': {'biaya': 150000},
    };

    testWidgets('catatan saja tidak menanyakan alasan', (tester) async {
      final db = _DbPalsu([
        {'status': 'tersimpan'},
      ]);
      final hasil = await jalankan(tester, db, () async {});

      expect(hasil, HasilSimpanTerkunci.tersimpan);
      expect(db.alasanDiterima, [null]);
      expect(find.text('Ajukan ke super admin'), findsNothing);
    });

    testWidgets('perubahan ditunjukkan dan alasan wajib diisi', (tester) async {
      final db = _DbPalsu([
        perluAlasan,
        {'status': 'diajukan', 'id': 'p1'},
      ]);
      final hasil = await jalankan(tester, db, () async {
        expect(find.textContaining('Rp150.000 → Rp175.000'), findsOneWidget);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );

        await tester.enterText(find.byType(TextField), '  Salah ketik  ');
        await tester.pump();
        await tester.tap(find.text('AJUKAN'));
      });

      expect(hasil, HasilSimpanTerkunci.diajukan);
      expect(db.alasanDiterima, [null, 'Salah ketik']);
    });

    testWidgets('dibatalkan tidak mengirim apa pun', (tester) async {
      final db = _DbPalsu([perluAlasan]);
      final hasil = await jalankan(tester, db, () async {
        await tester.tap(find.text('BATAL'));
      });

      expect(hasil, HasilSimpanTerkunci.dibatalkan);
      expect(db.alasanDiterima, [null]);
    });
  });

  group('halaman', () {
    Future<void> lukis(
      WidgetTester tester, {
      required bool superAdmin,
      required List<PermintaanUbahNota> daftar,
      _DbPalsu? db,
    }) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            if (db != null) databaseProvider.overrideWithValue(db),
            isSuperAdminProvider.overrideWithValue(superAdmin),
            currentUserProvider.overrideWithValue(null),
            permintaanNotaProvider.overrideWith((ref) => Stream.value(daftar)),
            serviceOrdersProvider.overrideWith((ref) => Stream.value(const [])),
            allProfilesProvider.overrideWith(
              (ref) => Stream.value(const [
                Profile(id: 'admin', nama: 'Admin Toko', role: 'admin'),
              ]),
            ),
            allMetodeBayarProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: PersetujuanView())),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('kosong diberi tahu', (tester) async {
      await lukis(tester, superAdmin: true, daftar: const []);

      expect(find.text('Tidak ada permintaan yang menunggu.'), findsOneWidget);
    });

    testWidgets('super admin membaca perubahan lalu memutuskan', (
      tester,
    ) async {
      final db = _DbPalsu();
      await lukis(tester, superAdmin: true, daftar: [_permintaan()], db: db);

      expect(find.text('MENUNGGU (1)'), findsOneWidget);
      expect(find.textContaining('Rp150.000 → Rp175.000'), findsOneWidget);
      expect(find.text('Alasan: Salah ketik'), findsOneWidget);

      await tester.tap(find.text('SETUJUI'));
      await tester.pump();

      expect(db.putusan, ['p1:true:null']);
    });

    testWidgets('menolak bisa disertai catatan', (tester) async {
      final db = _DbPalsu();
      await lukis(tester, superAdmin: true, daftar: [_permintaan()], db: db);

      await tester.tap(find.text('TOLAK'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Tidak jelas');
      await tester.tap(find.text('TOLAK').last);
      await tester.pumpAndSettle();

      expect(db.putusan, ['p1:false:Tidak jelas']);
    });

    testWidgets('admin tidak punya tombol keputusan', (tester) async {
      await lukis(tester, superAdmin: false, daftar: [_permintaan()]);

      expect(find.text('SETUJUI'), findsNothing);
      expect(find.text('TOLAK'), findsNothing);
    });

    testWidgets('riwayat menyimpan hasil dan catatannya', (tester) async {
      await lukis(
        tester,
        superAdmin: false,
        daftar: [_permintaan(status: 'ditolak')],
      );

      await tester.tap(find.text('RIWAYAT'));
      await tester.pumpAndSettle();

      expect(find.text('DITOLAK'), findsOneWidget);
      expect(find.textContaining('Tidak jelas'), findsOneWidget);
      expect(find.text('BATALKAN'), findsNothing);
    });
  });
}
