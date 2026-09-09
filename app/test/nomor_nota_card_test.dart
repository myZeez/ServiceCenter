// Kartu ini dilukis betulan, bukan sekadar dianalisis. Kartu setting
// tinggal di dalam grid yang bisa diubah ukurannya, jadi isinya harus
// tetap muat saat tingginya dipepetkan -- kesalahan tata letak semacam itu
// tidak pernah muncul di flutter analyze.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sc_management/core/theme.dart';
import 'package:sc_management/features/settings/nomor_nota_card.dart';

Future<void> _lukis(
  WidgetTester tester,
  Future<int> Function() ambilNomor, {
  double tinggi = 470,
}) async {
  await tester.binding.setSurfaceSize(const Size(700, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        nomorNotaBerikutnyaProvider.overrideWith((ref) => ambilNomor()),
      ],
      child: MaterialApp(
        theme: AppTheme.terang(),
        home: Scaffold(
          body: SizedBox(height: tinggi, child: const NomorNotaCard()),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('menampilkan nomor yang berlaku beserta bentuk lengkapnya', (
    tester,
  ) async {
    await _lukis(tester, () async => 28177);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('28177'), findsWidgets);
    expect(
      find.text('28176 nota sudah terpakai menurut hitungan ini'),
      findsOneWidget,
    );
    expect(find.text('SIMPAN NOMOR NOTA'), findsOneWidget);
  });

  testWidgets('database yang masih kosong tidak dibaca sebagai satu nota', (
    tester,
  ) async {
    await _lukis(tester, () async => 1);
    await tester.pumpAndSettle();

    expect(find.text('Belum ada nota yang terbit'), findsOneWidget);
  });

  testWidgets('tanpa koneksi memberi alasan, bukan layar kosong', (
    tester,
  ) async {
    await _lukis(tester, () => Future<int>.error('putus'));
    await tester.pumpAndSettle();

    expect(find.textContaining('tersambung ke server'), findsOneWidget);
    // Tombol simpan tetap ada; yang tidak diketahui hanya nomor sekarang.
    expect(find.text('SIMPAN NOMOR NOTA'), findsOneWidget);
  });

  testWidgets('tetap utuh saat kartunya dipendekkan di grid', (tester) async {
    await _lukis(tester, () async => 28177, tinggi: 260);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
