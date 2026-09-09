// Halaman pencocokan rekap bulanan brand, dilukis betulan.
//
// Yang diuji di sini bukan rumusnya -- itu ada di revenue_calculator_test --
// melainkan hal yang justru paling mudah salah dan tidak ketahuan sampai
// dipakai: unit bulan mana yang muncul, angka mana yang dipakai saat surat
// brand sudah dan belum datang, dan berapa total yang dibandingkan admin
// dengan kertas di tangannya.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/core/revenue/revenue_providers.dart';
import 'package:sc_management/core/theme.dart';
import 'package:sc_management/features/settlement/settlement_view.dart';

final _now = DateTime.now();
final _bulanIni = DateTime(_now.year, _now.month, 10);
final _bulanLalu = DateTime(_now.year, _now.month - 1, 10);

Claim _klaim({
  required String id,
  required String rma,
  int brandId = 1,
  String status = 'close',
  DateTime? tutup,
}) => Claim(
  id: id,
  // Sengaja jauh sebelum tanggal tutup: fee yang berlaku diambil menurut
  // tanggal klaim, dan keduanya memang tidak harus di bulan yang sama.
  tanggal: DateTime(_now.year, 1, 5),
  brandId: brandId,
  namaPelanggan: 'Pelanggan $id',
  sn: 'SN$id',
  noPerbaikan: rma,
  status: status,
  tanggalClose: tutup,
  createdBy: 'adm',
  createdAt: DateTime(_now.year, 1, 5),
  updatedAt: DateTime(_now.year, 1, 5),
);

Widget _layar({
  required List<Claim> claims,
  List<ClaimSettlement> hasil = const [],
}) => ProviderScope(
  overrides: [
    allClaimsProvider.overrideWith((ref) => Stream.value(claims)),
    allBrandsProvider.overrideWith(
      (ref) => Stream.value([const Brand(id: 1, nama: 'ASUS')]),
    ),
    allProfilesProvider.overrideWith((ref) => Stream.value(const <Profile>[])),
    brandFeesProvider.overrideWith(
      (ref) => Stream.value([
        BrandFeeEntry(
          id: 1,
          brandId: 1,
          fee: 100000,
          berlakuDari: DateTime(2020, 1, 1),
        ),
      ]),
    ),
    settlementsProvider.overrideWith((ref) => Stream.value(hasil)),
  ],
  child: MaterialApp(
    theme: AppTheme.build(),
    home: const Scaffold(body: SettlementView()),
  ),
);

void main() {
  setUpAll(() => initializeDateFormatting('id', null));

  testWidgets('unit selesai bulan ini memakai fee brand sebagai nilai awal', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _layar(
        claims: [
          _klaim(id: '1', rma: 'IDD7R20001', tutup: _bulanIni),
          _klaim(id: '2', rma: 'IDD7R20002', tutup: _bulanIni),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('IDD7R20001'), findsOneWidget);
    expect(find.text('Rp200.000'), findsOneWidget);

    // Selama surat brand belum datang, angkanya harus mengaku sebagai
    // perkiraan -- bukan tampil seperti angka yang sudah dipastikan.
    expect(find.text('NILAI AWAL'), findsNWidgets(2));
  });

  testWidgets('angka dari surat brand menimpa nilai awal', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _layar(
        claims: [
          _klaim(id: '1', rma: 'IDD7R20001', tutup: _bulanIni),
          _klaim(id: '2', rma: 'IDD7R20002', tutup: _bulanIni),
        ],
        hasil: [
          ClaimSettlement(
            claimId: '1',
            fee: 175000,
            cocok: true,
            updatedAt: _bulanIni,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rp175.000'), findsOneWidget);
    expect(find.text('Rp275.000'), findsOneWidget);
    expect(find.text('NILAI AWAL'), findsOneWidget);
  });

  testWidgets('unit yang tutup di bulan lain tidak ikut', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _layar(
        claims: [
          _klaim(id: '1', rma: 'IDD7R20001', tutup: _bulanIni),
          _klaim(id: '2', rma: 'IDD7R20002', tutup: _bulanLalu),
          // Belum selesai: brand belum membayar apa pun untuk unit ini.
          _klaim(id: '3', rma: 'IDD7R20003', status: 'proses'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('IDD7R20001'), findsOneWidget);
    expect(find.text('IDD7R20002'), findsNothing);
    expect(find.text('IDD7R20003'), findsNothing);

    // Dua kali: sekali di barisnya, sekali sebagai total bulan ini -- yang
    // berarti hanya satu unit yang ikut terhitung.
    expect(find.text('Rp100.000'), findsNWidgets(2));
  });

  testWidgets('unit tanpa nomor perbaikan ditandai, bukan didiamkan', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _layar(
        claims: [_klaim(id: '1', rma: '', tutup: _bulanIni)],
      ),
    );
    await tester.pumpAndSettle();

    // Tanpa nomor ini unit tersebut tidak bisa dicari di surat brand sama
    // sekali, jadi keadaannya harus terlihat dari daftar.
    expect(find.text('BELUM ADA RMA'), findsOneWidget);
  });

  testWidgets('nilai bisa dikoreksi dan unitnya dipindah ke bulan lain', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _layar(
        claims: [_klaim(id: '1', rma: 'IDD7R20001', tutup: _bulanIni)],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('NILAI AWAL'));
    await tester.pumpAndSettle();

    expect(find.text('IDD7R20001'), findsWidgets);
    expect(find.text('BIAYA DARI BRAND'), findsOneWidget);

    // Tanggal tutup klaim lama hanya perkiraan, dan brand kadang memasukkan
    // sebuah unit ke surat bulan berikutnya. Tanpa jalan memindahkannya dari
    // sini, unit itu tersangkut di bulan yang salah selamanya.
    expect(find.text('MASUK REKAP BULAN'), findsOneWidget);
  });

  testWidgets('layar sempit memakai kartu, bukan tabel', (tester) async {
    // Ukuran HP yang dipakai teknisi di lapangan. Tabel delapan kolom tidak
    // muat di sini, dan cacat tata letak semacam itu tidak pernah ketahuan
    // dari flutter analyze.
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _layar(
        claims: [
          _klaim(id: '1', rma: 'IDD7R20001', tutup: _bulanIni),
          _klaim(id: '2', rma: 'IDD7R20002', tutup: _bulanIni),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('IDD7R20001'), findsOneWidget);
    expect(find.text('Rp200.000'), findsOneWidget);
  });
}
