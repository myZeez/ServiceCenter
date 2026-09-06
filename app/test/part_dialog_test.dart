// Formulir tanya harga.
//
// Di sinilah harga ditetapkan, jadi yang diuji bukan tampilannya melainkan
// tiga penolakan yang mencegah uang tercatat setengah: DP tanpa harga,
// pesanan berjalan tanpa harga, dan pesanan ditutup padahal sisanya masih
// ada. Ketiganya juga dijaga Postgres; yang diuji di sini adalah bahwa
// penolakannya sampai sebagai kalimat, bukan sebagai galat constraint.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/core/widgets/swiss_widgets.dart';
import 'package:sc_management/features/parts/part_dialog.dart';

Future<void> _lukis(WidgetTester tester, {PartOrder? pesanan}) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        customersProvider.overrideWith((ref) => Stream.value(const [])),
        serviceOrdersProvider.overrideWith((ref) => Stream.value(const [])),
        partCostsProvider.overrideWith((ref) => Stream.value(const [])),
        partSettingsProvider.overrideWith(
          (ref) => Stream.value(
            const PartSettingsRow(
              upTokoPilihan: [10, 20],
              upTokoBawaan: 20,
            ),
          ),
        ),
        allProfilesProvider.overrideWith(
          (ref) => Stream.value([
            const Profile(id: 't1', nama: 'Reza', role: 'teknisi'),
          ]),
        ),
      ],
      child: MaterialApp(home: PartDialog(pesanan: pesanan)),
    ),
  );
  await tester.pumpAndSettle();
}

/// Kolom isian di bawah sebuah label. LabeledField menaikkan labelnya jadi
/// huruf besar, jadi teksnya dicari dalam bentuk itu.
Finder _isian(String label) => find.descendant(
  of: find.ancestor(
    of: find.text(label),
    matching: find.byType(LabeledField),
  ),
  matching: find.byType(TextFormField),
);

Future<void> _isi(WidgetTester tester, String label, String nilai) async {
  await tester.enterText(_isian(label), nilai);
  await tester.pumpAndSettle();
}

Future<void> _isiWajib(WidgetTester tester) async {
  await _isi(tester, 'NAMA PELANGGAN', 'JAMAL');
  await _isi(tester, 'PART REQ', 'KEYBOARD');
}

/// Formulirnya lebih panjang daripada layar mana pun, jadi tiap ketukan
/// harus menggulirkan sasarannya ke dalam pandangan lebih dulu.
Future<void> _ketuk(WidgetTester tester, Finder sasaran) async {
  await tester.ensureVisible(sasaran);
  await tester.pumpAndSettle();
  await tester.tap(sasaran);
  await tester.pumpAndSettle();
}

Future<void> _pilihTahap(WidgetTester tester, String label) async {
  await _ketuk(
    tester,
    find.descendant(
      of: find.ancestor(
        of: find.text('TAHAP'),
        matching: find.byType(LabeledField),
      ),
      matching: find.byType(DropdownButtonFormField<String>),
    ),
  );
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('terbuka tanpa galat dan memuat bagian-bagiannya', (
    tester,
  ) async {
    await _lukis(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('TANYA HARGA'), findsWidgets);
    expect(find.text('HPP (MODAL)'), findsOneWidget);
    expect(find.text('HARGA JUAL'), findsOneWidget);
    expect(find.text('SISA TAGIHAN'), findsOneWidget);
  });

  testWidgets('harga jual terhitung sendiri dari modal dan up bawaan', (
    tester,
  ) async {
    await _lukis(tester);
    await _isi(tester, 'HPP (MODAL)', '100000');

    // Bawaan toko 20%: modal 100rb dijual 120rb, untungnya 20rb.
    expect(find.textContaining('Untung Rp20.000'), findsOneWidget);
    expect(find.textContaining('20% dari modal'), findsOneWidget);
  });

  testWidgets('sisa tagihan ikut berubah saat DP diketik', (tester) async {
    await _lukis(tester);
    await _isi(tester, 'HPP (MODAL)', '100000');
    await _isi(tester, 'DP USER', '50000');

    expect(find.text('Rp70.000'), findsOneWidget);
  });

  testWidgets('USER DP terkunci selama harganya belum ada', (tester) async {
    await _lukis(tester);

    final tombol = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'USER DP'),
    );
    expect(tombol.onPressed, isNull);
    expect(find.textContaining('Isi harga jualnya dulu'), findsOneWidget);
  });

  testWidgets('USER DP terbuka begitu harganya ada, lalu memindahkan tahap', (
    tester,
  ) async {
    await _lukis(tester);
    await _isi(tester, 'HPP (MODAL)', '100000');

    await _ketuk(tester, find.widgetWithText(FilledButton, 'USER DP'));

    // Tombolnya hilang karena tahapnya sudah pindah -- itu penandanya.
    expect(find.widgetWithText(FilledButton, 'USER DP'), findsNothing);
    expect(find.text('Part Dipesan'), findsWidgets);
  });

  testWidgets('dimulai di tahap yang menunggu kode part', (tester) async {
    await _lukis(tester);

    // Yang pertama ditunggu dari sebuah permintaan baru adalah kode part
    // persisnya, dan itu ada di tangan teknisi -- bukan harga, yang belum
    // bisa ditanyakan sebelum kodenya jelas.
    expect(find.text('Tunggu Kode Part'), findsOneWidget);
  });

  testWidgets('menolak pesanan berjalan tanpa harga', (tester) async {
    await _lukis(tester);
    await _isiWajib(tester);
    await _pilihTahap(tester, 'Part Dipesan');

    await _ketuk(tester, find.widgetWithText(FilledButton, 'SIMPAN'));

    expect(
      find.textContaining('Tahap ini menunggu jawaban pelanggan'),
      findsOneWidget,
    );
  });

  testWidgets('menunggu konfirmasi DP boleh tanpa kolom harga terisi', (
    tester,
  ) async {
    await _lukis(tester);
    await _isiWajib(tester);
    await _pilihTahap(tester, 'Tunggu Konfirmasi DP');

    await _ketuk(tester, find.widgetWithText(FilledButton, 'SIMPAN'));

    // Penawaran sering memuat beberapa part dengan harga masing-masing dan
    // ditulis di catatan. Memaksa satu angka di sini akan mengunci tahap
    // yang isinya ratusan baris.
    expect(
      find.textContaining('Tahap ini menunggu jawaban pelanggan'),
      findsNothing,
    );
  });

  testWidgets('tahap awal tidak menuntut harga sama sekali', (tester) async {
    await _lukis(tester);
    await _isiWajib(tester);
    await _pilihTahap(tester, 'Tunggu Harga');

    await _ketuk(tester, find.widgetWithText(FilledButton, 'SIMPAN'));

    // Menunggu jawaban supplier memang keadaan tanpa harga; menolaknya
    // akan mengunci tahap yang paling ramai isinya.
    expect(
      find.textContaining('Tahap ini menunggu jawaban pelanggan'),
      findsNothing,
    );
  });

  testWidgets('kolom pemesanan muncul hanya setelah uangnya berpindah', (
    tester,
  ) async {
    await _lukis(tester);
    expect(find.text('NO PO'), findsNothing);
    expect(find.text('TANGGAL ORDER'), findsNothing);

    await _isi(tester, 'HPP (MODAL)', '100000');
    await _ketuk(tester, find.widgetWithText(FilledButton, 'USER DP'));

    expect(find.text('NO PO'), findsOneWidget);
    expect(find.text('TANGGAL ORDER'), findsOneWidget);
    expect(find.text('TANGGAL DP'), findsOneWidget);
  });

  testWidgets('menolak pesanan ditutup padahal sisanya masih ada', (
    tester,
  ) async {
    await _lukis(tester);
    await _isiWajib(tester);
    await _isi(tester, 'HPP (MODAL)', '100000');
    await _isi(tester, 'DP USER', '50000');
    await _pilihTahap(tester, 'Close');

    await _ketuk(tester, find.widgetWithText(FilledButton, 'SIMPAN'));

    expect(find.textContaining('Sisa tagihan masih Rp70.000'), findsOneWidget);
  });

  testWidgets('nama dan part wajib diisi', (tester) async {
    await _lukis(tester);

    await _ketuk(tester, find.widgetWithText(FilledButton, 'SIMPAN'));

    expect(find.text('Nama wajib diisi'), findsOneWidget);
    expect(find.text('Part yang dicari wajib diisi'), findsOneWidget);
  });
}
