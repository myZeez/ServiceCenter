// Kedua kartu dilukis betulan pada ukuran layar sungguhan. Dua kali
// sebelumnya cacat tata letak lolos dari flutter analyze dan dari test
// perhitungan, lalu baru terlihat sebagai layar kosong di tangan pemakai.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/omset/omset_providers.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/core/theme.dart';
import 'package:sc_management/features/mywork/my_work_view.dart';
import 'package:sc_management/features/service/service_view.dart';
import 'package:sc_management/features/service/teknisi_ringkas.dart';

final _bulanIni = DateTime(DateTime.now().year, DateTime.now().month, 15);

ServiceOrderEntry _nota({
  required String id,
  String? teknisi,
  String status = 'dikerjakan',
  double biaya = 0,
  DateTime? selesai,
}) => ServiceOrderEntry(
  id: id,
  noNota: id,
  tanggalMasuk: _bulanIni,
  customerNama: 'Pelanggan',
  barangNama: 'ASUS',
  teknisiId: teknisi,
  status: status,
  biaya: biaya,
  tanggalSelesai: selesai,
  updatedAt: _bulanIni,
);

void main() {
  setUpAll(() => initializeDateFormatting('id', null));

  testWidgets('kartu teknisi tampil di halaman servis', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serviceOrdersProvider.overrideWith(
            (ref) => Stream.value([
              _nota(id: '1', teknisi: 't1'),
              _nota(id: '2', teknisi: 't1'),
              _nota(
                id: '3',
                teknisi: 't1',
                status: 'diambil',
                biaya: 450000,
                selesai: _bulanIni,
              ),
            ]),
          ),
          allProfilesProvider.overrideWith(
            (ref) => Stream.value([
              const Profile(id: 't1', nama: 'Reza', role: 'teknisi'),
              const Profile(id: 't2', nama: 'Andi', role: 'teknisi'),
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
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const Scaffold(body: ServiceView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Diperiksa lewat teks yang hanya ada di panel: nama teknisi juga
    // muncul di kolom TEKNISI pada tabel nota di sebelahnya.
    expect(find.text('BULAN INI'), findsOneWidget);
    expect(find.text('Rp450.000  ·  1 selesai'), findsOneWidget);
    // Teknisi yang sedang kosong tetap punya barisnya sendiri.
    expect(find.text('Rp0  ·  0 selesai'), findsOneWidget);
    expect(find.text('UNIT'), findsNWidgets(2));
  });

  testWidgets('panel disembunyikan di jendela sempit', (tester) async {
    // Kolom nota yang tergencet sampai nama pelanggan terpotong lebih
    // merugikan daripada tidak melihat beban teknisi sama sekali.
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serviceOrdersProvider.overrideWith(
            (ref) => Stream.value([_nota(id: '1', teknisi: 't1')]),
          ),
          allProfilesProvider.overrideWith(
            (ref) => Stream.value([
              const Profile(id: 't1', nama: 'Reza', role: 'teknisi'),
            ]),
          ),
          omsetSettingsProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const Scaffold(body: ServiceView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('BULAN INI'), findsNothing);
  });

  testWidgets('kartu omset tampil di halaman pekerjaanku', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(null),
          allClaimsProvider.overrideWith((ref) => Stream.value([])),
          ringkasSayaProvider.overrideWithValue(
            const RingkasTeknisi(
              teknisi: Profile(id: 't1', nama: 'Reza', role: 'teknisi'),
              unitBerjalan: 2,
              notaSelesai: 3,
              omset: 1000000,
              target: 4000000,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const Scaffold(body: MyWorkView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Rp1.000.000'), findsOneWidget);
    expect(find.text('3 NOTA SELESAI  ·  2 UNIT DIKERJAKAN'), findsOneWidget);
    expect(find.textContaining('Kurang Rp3.000.000'), findsOneWidget);
  });

  testWidgets('yang bukan teknisi tidak melihat kartu omset', (tester) async {
    // Nol yang tidak berarti apa-apa lebih membingungkan daripada tidak ada
    // kartunya sama sekali.
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(null),
          allClaimsProvider.overrideWith((ref) => Stream.value([])),
          ringkasSayaProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const Scaffold(body: MyWorkView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('OMSET SERVIS BULAN INI'), findsNothing);
    expect(find.text('UNIT SELESAI'), findsOneWidget);
  });
}
