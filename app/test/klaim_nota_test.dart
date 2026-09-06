// Dua hal yang sama-sama tidak terlihat dari flutter analyze, dan
// dua-duanya baru terasa saat orang memakainya:
//
//   1. Daftar pilihan part yang cuma menyebut kodenya. ADPT, FRM_LCD,
//      CVR_LCD -- yang memilih harus hafal, padahal namanya sudah ada di
//      data master. Dan daftar teknisi yang ikut memuat admin, padahal
//      yang memegang obeng bukan dia.
//   2. Status klaim yang ternyata terikat ke nota servis. Perubahannya
//      merembet ke layar lain, dan itu harus disebutkan di tempat orang
//      mengubahnya.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/core/theme.dart';
import 'package:sc_management/features/claims/claim_detail_page.dart';
import 'package:sc_management/features/claims/claim_form_page.dart';

final _tgl = DateTime(2026, 9, 4);

const _partTypes = [
  PartType(id: 1, kode: 'ADPT', nama: 'Adaptor'),
  PartType(id: 2, kode: 'FRM_LCD', nama: 'Frame LCD'),
];

const _orang = [
  Profile(id: 'a1', nama: 'Budi Admin', role: 'admin'),
  Profile(id: 't1', nama: 'Reza Teknisi', role: 'teknisi'),
];

final _klaim = Claim(
  id: 'k1',
  tanggal: _tgl,
  brandId: 1,
  namaPelanggan: 'Budi',
  sn: 'SN1',
  noPerbaikan: 'IDD7R20001',
  status: 'open',
  createdBy: 'adm',
  createdAt: _tgl,
  updatedAt: _tgl,
);

ServiceOrderEntry _nota({String? claimId}) => ServiceOrderEntry(
  id: 'n1',
  noNota: 'SRV-0409260001',
  tanggalMasuk: _tgl,
  customerNama: 'Budi',
  barangNama: 'ASUS',
  garansi: claimId != null,
  claimId: claimId,
  status: 'dikerjakan',
  updatedAt: _tgl,
);

List<Override> _dasar() => [
  allBrandsProvider.overrideWith(
    (ref) => Stream.value([const Brand(id: 1, nama: 'ASUS')]),
  ),
  allProfilesProvider.overrideWith((ref) => Stream.value(_orang)),
  allPartTypesProvider.overrideWith((ref) => Stream.value(_partTypes)),
  currentUserProvider.overrideWithValue(null),
];

/// Dropdown di formulir ini sering berada di bawah lipatan layar HP, dan
/// mengetuk yang tidak terlihat tidak membuka apa pun.
Future<void> _buka(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('daftar pilihan part menyebut namanya, bukan kodenya saja', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: _dasar(),
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const ClaimFormPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _buka(tester, find.byType(DropdownButtonFormField<int>).last);

    expect(tester.takeException(), isNull);

    // Namanya yang dibaca, kodenya cukup jadi keterangan kecil di bawahnya.
    expect(find.text('Adaptor'), findsWidgets);
    expect(find.text('ADPT'), findsWidgets);
    expect(find.text('Frame LCD'), findsWidgets);
    expect(find.text('FRM_LCD'), findsWidgets);
  });

  testWidgets('admin ikut muncul di pilihan teknisi', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: _dasar(),
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const ClaimFormPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _buka(tester, find.byType(DropdownButtonFormField<String>).first);

    expect(find.text('Reza Teknisi'), findsWidgets);
    // Admin ikut: pada hari yang sepi memang orang di meja depan yang
    // mengerjakan sendiri, dan arsip 2026 mencatatnya pada 462 nota.
    // Mengeluarkannya berarti pekerjaan itu tidak bisa dicatat atas nama
    // siapa pun.
    expect(find.text('Budi Admin'), findsWidgets);
  });

  testWidgets('klaim yang punya nota menyebutkan status keduanya seiring', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._dasar(),
          isAdminProvider.overrideWithValue(true),
          allClaimsProvider.overrideWith((ref) => Stream.value([_klaim])),
          allPartsProvider.overrideWith(
            (ref) => Stream.value(const <ClaimPart>[]),
          ),
          serviceOrdersProvider.overrideWith(
            (ref) => Stream.value([_nota(claimId: 'k1')]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const ClaimDetailPage('k1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.textContaining('Sejalan dengan nota SRV-0409260001'),
      findsOneWidget,
    );
  });

  testWidgets('klaim tanpa nota tidak menjanjikan apa pun soal nota', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._dasar(),
          isAdminProvider.overrideWithValue(true),
          allClaimsProvider.overrideWith((ref) => Stream.value([_klaim])),
          allPartsProvider.overrideWith(
            (ref) => Stream.value(const <ClaimPart>[]),
          ),
          // Nota yang ada, tetapi bukan milik klaim ini.
          serviceOrdersProvider.overrideWith((ref) => Stream.value([_nota()])),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const ClaimDetailPage('k1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Sejalan dengan nota'), findsNothing);
  });
}
