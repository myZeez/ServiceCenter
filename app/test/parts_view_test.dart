// Dua layar tanya harga dan pemesanan part di Windows.
//
// Keduanya membaca tabel yang sama; yang membedakan hanya saringannya --
// Tanya Harga berhenti di batas DP, Pemesanan mulai dari sana. Kalau
// saringan itu meleset, sebuah unit menghilang dari kedua layar tanpa satu
// pun tanda bahwa ia pernah ada.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/features/parts/part_orders_view.dart';
import 'package:sc_management/features/parts/part_status.dart';
import 'package:sc_management/features/parts/parts_view.dart';

PartOrder _pesanan({
  required String id,
  String nama = 'Jamal',
  String part = 'KEYBOARD',
  String tahap = PartTahap.foto,
  double? harga,
  double dp = 0,
  double sisa = 0,
  String? teknisi = 't1',
  String? catatan,
}) => PartOrder(
  id: id,
  tanggal: DateTime(2026, 9, 4),
  customerNama: nama,
  barangType: 'ASUS X441',
  barangSn: 'SN$id',
  partReq: part,
  keterangan: 'OEM',
  teknisiId: teknisi,
  tahap: tahap,
  harga: harga,
  dp: dp,
  sisa: sisa,
  catatan: catatan,
  updatedAt: DateTime(2026, 9, 4),
);

Future<void> _lukis(
  WidgetTester tester,
  Widget layar,
  List<PartOrder> pesanan,
) async {
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        partOrdersProvider.overrideWith((ref) => Stream.value(pesanan)),
        partCostsProvider.overrideWith((ref) => Stream.value(const [])),
        partSettingsProvider.overrideWith((ref) => Stream.value(null)),
        allProfilesProvider.overrideWith(
          (ref) => Stream.value([
            const Profile(id: 't1', nama: 'Reza', role: 'teknisi'),
          ]),
        ),
        customersProvider.overrideWith((ref) => Stream.value(const [])),
        serviceOrdersProvider.overrideWith((ref) => Stream.value(const [])),
        koneksiProvider.overrideWith((ref) => Stream.value(true)),
      ],
      child: MaterialApp(home: Scaffold(body: layar)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('tahap', () {
    test('tiap tahap masuk tepat satu sisi batas DP', () {
      for (final t in PartTahap.all) {
        expect(
          PartTahap.sebelumDp.contains(t) != PartTahap.sesudahDp.contains(t),
          isTrue,
          reason: '$t harus ada di salah satu sisi, tidak keduanya dan '
              'tidak bukan keduanya',
        );
      }
    });

    test('tahap yang menunggu jawaban pelanggan menuntut harga', () {
      // Menunggu pelanggan menyetujui angka yang belum ada tidak berarti
      // apa-apa; ini juga dijaga constraint di Postgres.
      expect(PartTahap.perluHarga(PartTahap.konfirmasi), isTrue);
      expect(PartTahap.perluHarga(PartTahap.dipesan), isTrue);
      expect(PartTahap.perluHarga(PartTahap.selesai), isTrue);

      expect(PartTahap.perluHarga(PartTahap.foto), isFalse);
      expect(PartTahap.perluHarga(PartTahap.harga), isFalse);
      expect(PartTahap.perluHarga(PartTahap.kosong), isFalse);
      expect(PartTahap.perluHarga(PartTahap.batal), isFalse);
    });
  });

  group('saringPesanan', () {
    final semua = [
      _pesanan(id: '1', nama: 'Jamal', tahap: PartTahap.foto),
      _pesanan(
        id: '2',
        nama: 'Soni',
        tahap: PartTahap.dipesan,
        harga: 120000,
      ),
      _pesanan(id: '3', nama: 'Rudi', tahap: PartTahap.selesai, harga: 90000),
      _pesanan(id: '4', nama: 'Tika', tahap: PartTahap.kosong),
    ];

    test('tanpa saringan mengembalikan semuanya', () {
      expect(saringPesanan(semua).length, 4);
    });

    test('hanyaTahap membatasi ke pesanan yang sudah berjalan', () {
      final hasil = saringPesanan(semua, hanyaTahap: PartTahap.sesudahDp);
      expect(hasil.map((p) => p.customerNama), ['Soni', 'Rudi']);
    });

    test('tahap dan hanyaTahap berlaku bersamaan, bukan saling menimpa', () {
      final hasil = saringPesanan(
        semua,
        hanyaTahap: PartTahap.sesudahDp,
        tahap: PartTahap.kosong,
      );
      // 'kosong' ada di tabel tetapi di luar cakupan halaman ini. Yang
      // benar adalah kosong -- bukan menampilkannya karena tahapnya cocok.
      expect(hasil, isEmpty);
    });

    test('pencarian menjangkau nama, part, tipe, dan SN', () {
      expect(saringPesanan(semua, query: 'soni').length, 1);
      expect(saringPesanan(semua, query: 'keyboard').length, 4);
      expect(saringPesanan(semua, query: 'x441').length, 4);
      expect(saringPesanan(semua, query: 'sn3').single.customerNama, 'Rudi');
    });

    test('pencarian tidak peduli besar kecil huruf', () {
      expect(saringPesanan(semua, query: 'JAMAL').length, 1);
    });
  });

  group('halaman Tanya Harga', () {
    testWidgets('menampilkan permintaan yang belum lewat DP', (tester) async {
      await _lukis(tester, const PartsView(), [
        _pesanan(id: '1', nama: 'Jamal'),
        _pesanan(id: '2', nama: 'Soni', tahap: PartTahap.harga),
      ]);

      expect(tester.takeException(), isNull);
      expect(find.text('Jamal'), findsOneWidget);
      expect(find.text('Soni'), findsOneWidget);
      expect(find.text('Reza'), findsNWidgets(2));
    });

    testWidgets('yang sudah dibayar DP keluar dari halaman ini', (
      tester,
    ) async {
      await _lukis(tester, const PartsView(), [
        _pesanan(id: '1', nama: 'Jamal'),
        _pesanan(
          id: '2',
          nama: 'Soni',
          tahap: PartTahap.dipesan,
          harga: 120000,
        ),
      ]);

      // Bukan disalin ke Pemesanan Part, melainkan pindah ke sana.
      expect(find.text('Jamal'), findsOneWidget);
      expect(find.text('Soni'), findsNothing);
    });

    testWidgets('tiga tahap awal dibedakan, bukan ditumpuk jadi satu', (
      tester,
    ) async {
      await _lukis(tester, const PartsView(), [
        _pesanan(id: '1', nama: 'Jamal', tahap: PartTahap.foto),
        _pesanan(id: '2', nama: 'Soni', tahap: PartTahap.harga),
        _pesanan(
          id: '3',
          nama: 'Rudi',
          tahap: PartTahap.konfirmasi,
          harga: 500000,
        ),
        _pesanan(id: '4', nama: 'Tika', tahap: PartTahap.kosong),
      ]);

      expect(find.text('KODE PART'), findsWidgets);
      expect(find.text('TUNGGU HARGA'), findsWidgets);
      expect(find.text('TUNGGU DP'), findsWidgets);
      expect(find.text('NO STOCK'), findsWidgets);
    });

    testWidgets('catatan harga ikut terlihat di layar lebar', (tester) async {
      await _lukis(tester, const PartsView(), [
        _pesanan(id: '1', catatan: 'ORI KB MODULE 1500K, BATT 1300K'),
      ]);

      expect(find.text('ORI KB MODULE 1500K, BATT 1300K'), findsOneWidget);
    });

    testWidgets('daftar kosong tetap menawarkan cara menambah', (
      tester,
    ) async {
      await _lukis(tester, const PartsView(), const []);

      expect(tester.takeException(), isNull);
      expect(find.text('Belum ada permintaan part'), findsOneWidget);
    });
  });

  group('halaman Pemesanan Part', () {
    testWidgets('hanya memuat pesanan yang sudah lewat DP', (tester) async {
      await _lukis(tester, const PartOrdersView(), [
        _pesanan(id: '1', nama: 'Jamal', tahap: PartTahap.konfirmasi,
            harga: 90000),
        _pesanan(
          id: '2',
          nama: 'Soni',
          tahap: PartTahap.dipesan,
          harga: 120000,
          dp: 50000,
          sisa: 70000,
        ),
      ]);

      expect(tester.takeException(), isNull);
      expect(find.text('Soni'), findsOneWidget);
      expect(find.text('Jamal'), findsNothing);
    });

    testWidgets('menjumlahkan uang dari baris yang sedang tampil', (
      tester,
    ) async {
      await _lukis(tester, const PartOrdersView(), [
        _pesanan(
          id: '1',
          tahap: PartTahap.dipesan,
          harga: 120000,
          dp: 50000,
          sisa: 70000,
        ),
        _pesanan(
          id: '2',
          tahap: PartTahap.dipasang,
          harga: 80000,
          dp: 30000,
          sisa: 50000,
        ),
      ]);

      expect(find.text('NILAI PESANAN'), findsOneWidget);
      expect(find.text('Rp200.000'), findsOneWidget);
      expect(find.text('Rp80.000'), findsWidgets);
      expect(find.text('Rp120.000'), findsWidgets);
    });

    testWidgets('yang sudah lunas ditandai lunas, bukan Rp0', (tester) async {
      await _lukis(tester, const PartOrdersView(), [
        _pesanan(
          id: '1',
          tahap: PartTahap.selesai,
          harga: 90000,
          dp: 90000,
        ),
      ]);

      expect(find.text('LUNAS'), findsOneWidget);
    });

    testWidgets('kosong menjelaskan dari mana pesanan dimulai', (tester) async {
      await _lukis(tester, const PartOrdersView(), [
        _pesanan(id: '1', tahap: PartTahap.foto),
      ]);

      expect(find.text('Belum ada pesanan berjalan'), findsOneWidget);
      expect(find.textContaining('USER DP'), findsOneWidget);
    });
  });
}
