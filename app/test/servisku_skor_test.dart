// Tab Skor dan riwayat omset di Servisku, dilukis dengan data yang bulannya
// dihitung dari hari ini -- provider-nya memakai jam sungguhan.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/omset/omset_providers.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/features/service/servisku_view.dart';
import 'package:sc_management/features/service/widgets/skor_saya_card.dart';

const _saya = User(
  id: 't1',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  createdAt: '2026-01-01T00:00:00Z',
);

const _namaBulan = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

Future<void> _lukis(WidgetTester tester, List<ServiceOrderEntry> nota) async {
  await tester.binding.setSurfaceSize(const Size(400, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_saya),
        serviceOrdersProvider.overrideWith((ref) => Stream.value(nota)),
        allProfilesProvider.overrideWith(
          (ref) => Stream.value([
            const Profile(id: 't1', nama: 'Budi', role: 'teknisi'),
          ]),
        ),
        omsetSettingsProvider.overrideWith(
          (ref) => Stream.value(
            const ServiceSettingsRow(
              id: 1,
              targetOmset: 4000000,
              feeAdminPerNota: 0,
            ),
          ),
        ),
        koneksiProvider.overrideWith((ref) => Stream.value(true)),
      ],
      child: const MaterialApp(home: Scaffold(body: ServiskuView())),
    ),
  );
  await tester.pumpAndSettle();
}

/// Chip di luar layar uji (huruf tes Flutter lebar) digulir masuk dulu.
Future<void> _ketuk(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  final kini = DateTime.now();
  // Omset Budi Januari-September 2026, ditaruh di sembilan bulan terakhir.
  const omset = [6290, 6485, 5685, 6430, 6225, 5070, 5150, 5820, 8135];
  DateTime bulanKe(int mundur) => DateTime(kini.year, kini.month - mundur, 10);
  final nota = [
    for (var i = 0; i < omset.length; i++)
      ServiceOrderEntry(
        id: 'n$i',
        noNota: 'SVR-$i',
        tanggalMasuk: bulanKe(9 - i),
        customerNama: 'Pelanggan $i',
        barangNama: 'Laptop',
        teknisiId: 't1',
        status: 'diambil',
        biaya: omset[i] * 1000.0,
        tanggalSelesai: bulanKe(9 - i),
        tanggalDiambil: bulanKe(9 - i),
        updatedAt: kini,
      ),
  ];

  testWidgets('tab Skor: tiga bulan dan dua belas bulan dengan bintangnya', (
    tester,
  ) async {
    await _lukis(tester, nota);

    final chip = find.text('SKOR  ★4', skipOffstage: false);
    expect(chip, findsOneWidget);
    await _ketuk(tester, chip);

    expect(tester.takeException(), isNull);
    expect(find.text('3 BULAN TERAKHIR'), findsOneWidget);
    expect(find.text('12 BULAN TERAKHIR'), findsOneWidget);
    // 12 bulan: rata-rata 6.143.333 dari sembilan bulan -> 76,8%.
    expect(find.text('76,8%'), findsOneWidget);
    // 3 bulan: (5.150.000 + 5.820.000 + 8.135.000) / 3 -> 79,6%.
    expect(find.text('79,6%'), findsOneWidget);
    expect(find.text('SANGAT BAIK'), findsNWidgets(2));
    // Dua kartu, masing-masing empat bintang terisi dan satu kosong.
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(8));
    expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(2));
    expect(find.textContaining('(9 bulan)'), findsOneWidget);
    // Tidak ada kotak pencarian di tab Skor.
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
    'tab Sudah Selesai: omset bulan-bulan sebelumnya, terbaru di atas',
    (tester) async {
      await _lukis(tester, nota);

      await _ketuk(tester, find.textContaining('SUDAH SELESAI'));

      expect(tester.takeException(), isNull);
      expect(find.text('OMSET BULAN SEBELUMNYA'), findsOneWidget);
      expect(find.text('9 BULAN'), findsOneWidget);
      final terbaru = bulanKe(1);
      final teks =
          '${_namaBulan[terbaru.month - 1].substring(0, 3)} ${terbaru.year}'
              .toUpperCase();
      expect(find.text('Rp8.135.000'), findsWidgets);
      expect(find.text('$teks  203,4%'), findsOneWidget);
      // Strip mendatar, terbaru di kiri.
      final kartu = find.byType(RiwayatOmsetCard);
      expect(
        tester
                .getTopLeft(
                  find.descendant(
                    of: kartu,
                    matching: find.text('Rp8.135.000'),
                  ),
                )
                .dx <
            tester
                .getTopLeft(
                  find.descendant(
                    of: kartu,
                    matching: find.text('Rp5.820.000'),
                  ),
                )
                .dx,
        isTrue,
        reason: 'bulan terbaru di kiri',
      );
      // Strip itu pendek: nota yang sudah selesai tetap terlihat di bawahnya.
      expect(
        tester.getSize(kartu).height,
        lessThan(150),
        reason: 'kartu riwayat tidak boleh mendorong daftar nota',
      );
    },
  );

  testWidgets('belum ada bulan penuh: skor tidak ditebak', (tester) async {
    await _lukis(tester, [
      ServiceOrderEntry(
        id: 'baru',
        noNota: 'SVR-baru',
        tanggalMasuk: kini,
        customerNama: 'Baru',
        barangNama: 'Laptop',
        teknisiId: 't1',
        status: 'diambil',
        biaya: 500000,
        tanggalSelesai: kini,
        updatedAt: kini,
      ),
    ]);

    await _ketuk(tester, find.text('SKOR', skipOffstage: false));
    expect(find.text('Belum ada bulan penuh untuk dinilai.'), findsNWidgets(2));
  });
}
