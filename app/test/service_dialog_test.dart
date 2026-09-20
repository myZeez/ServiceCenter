// Jalan pintas dari nota servis ke tanya harga part.
//
// Yang paling penting diuji di sini bukan jalan pintasnya, melainkan
// bahwa ia tidak mengganggu apa pun selama tidak dipakai: menambah nota
// servis biasa harus tetap persis seperti sebelum fitur ini ada.
//
// Tanya harga sedang disimpan, jadi hampir seluruh berkas ini menyalakan
// fiturTanyaHargaProvider lewat override. Itu disengaja: fitur yang
// disembunyikan dengan cara membiarkan tesnya mati akan kembali dalam
// keadaan rusak, dan yang menemukannya adalah orang yang memakainya.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/fitur.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/core/widgets/swiss_widgets.dart';
import 'package:sc_management/features/service/service_dialog.dart';

ServiceOrderEntry _nota({String? claimId, bool garansi = false}) =>
    ServiceOrderEntry(
      id: 'nota-1',
      garansi: garansi || claimId != null,
      claimId: claimId,
      noNota: 'SVR-05092628222',
      tanggalMasuk: DateTime(2026, 9, 5),
      customerNama: 'Irwan',
      customerTelp: '192837182370',
      customerId: 'plg4',
      barangNama: 'Laptop Lenovo',
      barangType: 'Ideapad',
      barangSn: 'OSIA0J09U309JOI3',
      keluhan: 'LCD PECAH',
      teknisiId: 't1',
      status: 'masuk',
      updatedAt: DateTime(2026, 9, 5),
    );

PartOrder _pesanan({String part = 'LCD 14 SLIM'}) => PartOrder(
  id: 'po-1',
  tanggal: DateTime(2026, 9, 5),
  customerNama: 'Irwan',
  partReq: part,
  tahap: 'tanya',
  serviceOrderId: 'nota-1',
  updatedAt: DateTime(2026, 9, 5),
);

Future<void> _lukis(
  WidgetTester tester, {
  ServiceOrderEntry? nota,
  List<PartOrder> pesanan = const [],
  List<Claim> klaim = const [],
  bool adaTanyaHarga = true,
}) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        fiturTanyaHargaProvider.overrideWithValue(adaTanyaHarga),
        customersProvider.overrideWith((ref) => Stream.value(const [])),
        serviceOrdersProvider.overrideWith((ref) => Stream.value(const [])),
        partOrdersProvider.overrideWith((ref) => Stream.value(pesanan)),
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

Future<void> _ketuk(WidgetTester tester, Finder sasaran) async {
  await tester.ensureVisible(sasaran);
  await tester.pumpAndSettle();
  await tester.tap(sasaran);
  await tester.pumpAndSettle();
}

void main() {
  group('nota baru', () {
    testWidgets('centang tanya harga ada, dan mati sejak awal', (tester) async {
      await _lukis(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Perlu tanya harga part'), findsOneWidget);
      // Selama belum dicentang, tidak ada kolom tambahan sama sekali.
      expect(find.text('PART YANG DICARI'), findsNothing);
    });

    testWidgets('mencentangnya memunculkan kolom yang perlu dilengkapi', (
      tester,
    ) async {
      await _lukis(tester);
      await _ketuk(tester, find.text('Perlu tanya harga part'));

      expect(find.text('PART YANG DICARI'), findsOneWidget);
      expect(find.text('KETERANGAN'), findsWidgets);
    });

    testWidgets('part wajib diisi begitu centangnya menyala', (tester) async {
      await _lukis(tester);
      await _ketuk(tester, find.text('Perlu tanya harga part'));
      await _ketuk(tester, find.widgetWithText(FilledButton, 'SIMPAN NOTA'));

      expect(find.text('Sebutkan part yang dicari'), findsOneWidget);
    });

    testWidgets('tanpa centang, nota biasa tidak menuntut apa pun soal part', (
      tester,
    ) async {
      await _lukis(tester);
      await _ketuk(tester, find.widgetWithText(FilledButton, 'SIMPAN NOTA'));

      // Yang wajib tetap hanya yang wajib sejak dulu. Kalau validator part
      // ikut galak di sini, seluruh alur tambah servis akan terkunci.
      expect(find.text('Nama wajib diisi'), findsOneWidget);
      expect(find.text('Sebutkan part yang dicari'), findsNothing);
    });

    testWidgets('melepas centangnya membuang kolomnya lagi', (tester) async {
      await _lukis(tester);
      await _ketuk(tester, find.text('Perlu tanya harga part'));
      expect(find.text('PART YANG DICARI'), findsOneWidget);

      await _ketuk(tester, find.text('Perlu tanya harga part'));
      expect(find.text('PART YANG DICARI'), findsNothing);

      await _ketuk(tester, find.widgetWithText(FilledButton, 'SIMPAN NOTA'));
      expect(find.text('Sebutkan part yang dicari'), findsNothing);
    });
  });

  group('nota yang sudah tersimpan', () {
    testWidgets('menawarkan membuat tanya harga', (tester) async {
      await _lukis(tester, nota: _nota());

      expect(tester.takeException(), isNull);
      expect(find.text('TANYA HARGA PART'), findsOneWidget);
      // Centangnya khusus nota baru; di sini yang masuk akal adalah
      // membuka formulirnya, bukan menandai niat.
      expect(find.text('Perlu tanya harga part'), findsNothing);
    });

    testWidgets('membuka formulir tanya harga yang sudah terisi', (
      tester,
    ) async {
      await _lukis(tester, nota: _nota());
      await _ketuk(tester, find.text('TANYA HARGA PART'));

      expect(tester.takeException(), isNull);
      // Data nota terbawa: pelanggan, merek dan tipe digabung, dan SN.
      expect(find.text('Irwan'), findsWidgets);
      expect(find.text('Laptop Lenovo Ideapad'), findsOneWidget);
      expect(find.text('OSIA0J09U309JOI3'), findsWidgets);
      // Yang memang belum diketahui tetap kosong, tidak ditebak dari
      // keluhannya.
      expect(find.text('LCD PECAH'), findsWidgets);
      expect(find.text('PART REQ'), findsOneWidget);
    });

    testWidgets('yang sudah punya tanya harga menawarkan membukanya', (
      tester,
    ) async {
      await _lukis(tester, nota: _nota(), pesanan: [_pesanan()]);

      // Bukan membuat yang kedua dengan isi yang sama persis.
      expect(find.text('LIHAT TANYA HARGA'), findsOneWidget);
      expect(find.text('TANYA HARGA PART'), findsNothing);
      expect(find.textContaining('LCD 14 SLIM'), findsOneWidget);
    });

    testWidgets('tanya harga milik nota lain tidak dianggap miliknya', (
      tester,
    ) async {
      await _lukis(
        tester,
        nota: _nota(),
        pesanan: [
          PartOrder(
            id: 'po-9',
            tanggal: DateTime(2026, 9, 5),
            customerNama: 'Orang Lain',
            partReq: 'KEYBOARD',
            tahap: 'tanya',
            serviceOrderId: 'nota-lain',
            updatedAt: DateTime(2026, 9, 5),
          ),
        ],
      );

      expect(find.text('TANYA HARGA PART'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------
  // Tanya harga sedang disimpan. Yang ditutup hanya pintu masuknya, dan
  // yang diuji di sini adalah bahwa penutupannya rapi -- tidak ada
  // potongan kalimat yang tertinggal, dan alur nota biasa tidak ikut
  // terganggu.
  // -------------------------------------------------------------------
  group('tanya harga yang sedang disimpan', () {
    testWidgets('tidak menyisakan jejak di formulir nota baru', (tester) async {
      await _lukis(tester, adaTanyaHarga: false);

      expect(find.text('Perlu tanya harga part'), findsNothing);
      expect(find.text('PART YANG DICARI'), findsNothing);
    });

    testWidgets('tidak menyisakan jejak di nota yang sudah ada', (
      tester,
    ) async {
      await _lukis(tester, nota: _nota(), adaTanyaHarga: false);

      expect(find.text('TANYA HARGA PART'), findsNothing);
      expect(find.text('LIHAT TANYA HARGA'), findsNothing);
      // Sisa formulirnya utuh: yang disembunyikan cuma satu bagian.
      expect(find.text('Irwan'), findsWidgets);
    });

    testWidgets('nota biasa tidak ikut terkunci', (tester) async {
      await _lukis(tester, adaTanyaHarga: false);
      await _ketuk(tester, find.widgetWithText(FilledButton, 'SIMPAN NOTA'));

      expect(find.text('Nama wajib diisi'), findsOneWidget);
      expect(find.text('Sebutkan part yang dicari'), findsNothing);
    });
  });

  // -------------------------------------------------------------------
  // Urutan kerja yang sebenarnya: unit masuk sebagai servis biasa, lalu
  // dibongkar, dan baru di situ ketahuan masih bergaransi.
  // -------------------------------------------------------------------
  group('unit yang ternyata bergaransi', () {
    CheckboxListTile centang(WidgetTester tester) =>
        tester.widget(find.widgetWithText(CheckboxListTile, 'Unit bergaransi'));

    testWidgets('centangnya tetap hidup pada nota yang sudah tersimpan', (
      tester,
    ) async {
      await _lukis(tester, nota: _nota());

      // Dulu mati begitu notanya tersimpan, dengan asumsi status garansi
      // sudah diketahui saat unit diterima. Asumsi itu keliru.
      expect(centang(tester).onChanged, isNotNull);
      expect(
        find.textContaining('Ternyata garansi setelah dicek'),
        findsOneWidget,
      );
    });

    testWidgets('mencentangnya menuntut brand klaimnya', (tester) async {
      await _lukis(tester, nota: _nota());
      await _ketuk(tester, find.text('Unit bergaransi'));

      expect(find.text('BRAND UNTUK KLAIM'), findsOneWidget);
    });

    testWidgets('nota yang klaimnya sudah ada dikunci', (tester) async {
      await _lukis(tester, nota: _nota(claimId: 'klaim-1'));

      // Melepasnya akan meninggalkan klaim yatim di halaman Klaim.
      expect(centang(tester).onChanged, isNull);
      expect(centang(tester).value, isTrue);
      expect(find.textContaining('Klaimnya sudah dibuat'), findsOneWidget);
      expect(find.text('BRAND UNTUK KLAIM'), findsNothing);
    });

    testWidgets('nota arsip yang sudah bertanda garansi dibiarkan apa adanya', (
      tester,
    ) async {
      // Bentuk nota bergaransi di arsip 2026: bertanda garansi, tanpa
      // claim_id, karena klaim ke brand punya arsipnya sendiri. Kalau
      // centangnya dibiarkan terbuka di sini, sekadar membuka lalu
      // menyimpan nota lama akan menerbitkan klaim baru yang tidak
      // diminta siapa pun.
      await _lukis(tester, nota: _nota(garansi: true));

      expect(centang(tester).value, isTrue);
      expect(centang(tester).onChanged, isNull);
      expect(find.textContaining('Sudah bertanda garansi'), findsOneWidget);
      expect(find.text('BRAND UNTUK KLAIM'), findsNothing);
    });
  });

  // -------------------------------------------------------------------
  // Nota garansi brand memakai status garansi -- daftar yang sama dengan
  // klaimnya. Servis reguler dan garansi toko tetap memakai status nota.
  // -------------------------------------------------------------------
  group('status nota garansi', () {
    Claim klaim({
      String jenis = 'brand',
      String status = 'wait_approval',
      String? keluhan,
    }) => Claim(
      id: 'klaim-1',
      keluhan: keluhan,
      tanggal: DateTime(2026, 9, 5),
      brandId: 1,
      namaPelanggan: 'Irwan',
      sn: 'OSIA0J09U309JOI3',
      jenis: jenis,
      status: status,
      createdBy: 'a',
      createdAt: DateTime(2026, 9, 5),
      updatedAt: DateTime(2026, 9, 5),
    );

    testWidgets('garansi brand memilih dari status klaimnya', (tester) async {
      await _lukis(
        tester,
        nota: _nota(claimId: 'klaim-1'),
        klaim: [klaim()],
      );

      expect(tester.takeException(), isNull);
      expect(find.text('STATUS GARANSI'), findsOneWidget);
      expect(find.text('Wait Approval Warranty'), findsOneWidget);
    });

    testWidgets('daftarnya memuat Ship dengan nama brand klaimnya', (
      tester,
    ) async {
      await _lukis(
        tester,
        nota: _nota(claimId: 'klaim-1'),
        klaim: [klaim(status: 'ship_pusat')],
      );

      expect(find.text('Ship ASUS Pusat'), findsOneWidget);
    });

    testWidgets('garansi toko tetap memakai status nota', (tester) async {
      await _lukis(
        tester,
        nota: _nota(claimId: 'klaim-1'),
        klaim: [klaim(jenis: 'toko')],
      );

      expect(find.text('STATUS GARANSI'), findsNothing);
      expect(find.text('Masuk'), findsOneWidget);
    });

    testWidgets('servis reguler tetap memakai status nota', (tester) async {
      await _lukis(tester, nota: _nota());

      expect(find.text('STATUS GARANSI'), findsNothing);
      expect(find.text('Masuk'), findsOneWidget);
    });

    // Keluhan nota adalah kata-kata pelanggan saat unit datang; keluhan
    // garansi adalah hasil pengecekan teknisi, dan itu yang dibaca brand.
    // Keduanya tampil berdampingan, masing-masing dari tempatnya sendiri.
    TextField kolom(WidgetTester tester, String label) => tester.widget(
      find.descendant(
        of: find.ancestor(
          of: find.text(label),
          matching: find.byType(LabeledField),
        ),
        matching: find.byType(TextField),
      ),
    );

    testWidgets('garansi brand punya keluhan garansi milik klaimnya', (
      tester,
    ) async {
      await _lukis(
        tester,
        nota: _nota(claimId: 'klaim-1'),
        klaim: [klaim(keluhan: 'NO POWER')],
      );

      expect(kolom(tester, 'KELUHAN PELANGGAN').controller!.text, 'LCD PECAH');
      expect(kolom(tester, 'KELUHAN GARANSI').controller!.text, 'NO POWER');
    });

    testWidgets('servis reguler hanya punya keluhan pelanggan', (tester) async {
      await _lukis(tester, nota: _nota());

      expect(find.text('KELUHAN PELANGGAN'), findsOneWidget);
      expect(find.text('KELUHAN GARANSI'), findsNothing);
    });
  });

  // -------------------------------------------------------------------
  // Unit bergaransi ditanggung brand: notanya tidak dikenakan biaya sama
  // sekali, kecuali memang ada layanan tambahan di luar garansi. Jadi
  // angka yang muncul di sana hampir selalu salah ketik.
  // -------------------------------------------------------------------
  group('Biaya pada nota bergaransi', () {
    test('ditanyakan saat angkanya baru muncul', () {
      expect(
        perluKonfirmasiBiayaGaransi(garansi: true, biaya: 150000, biayaLama: 0),
        isTrue,
      );
    });

    test('nota tanpa garansi tidak pernah ditanyakan', () {
      expect(
        perluKonfirmasiBiayaGaransi(
          garansi: false,
          biaya: 150000,
          biayaLama: 0,
        ),
        isFalse,
      );
    });

    test('garansi tanpa biaya adalah keadaan yang normal', () {
      expect(
        perluKonfirmasiBiayaGaransi(garansi: true, biaya: 0, biayaLama: 0),
        isFalse,
      );
      // Termasuk saat biayanya justru dihapus jadi nol.
      expect(
        perluKonfirmasiBiayaGaransi(garansi: true, biaya: 0, biayaLama: 150000),
        isFalse,
      );
    });

    test('angka yang tidak berubah tidak ditanyakan lagi', () {
      // Layanan tambahannya sudah dikonfirmasi sekali. Menanyakannya tiap
      // kali nota itu dibuka dan disimpan lagi hanya melatih orang
      // menekan tombolnya tanpa membaca.
      expect(
        perluKonfirmasiBiayaGaransi(
          garansi: true,
          biaya: 150000,
          biayaLama: 150000,
        ),
        isFalse,
      );
    });

    test('angka yang diubah ditanyakan ulang', () {
      expect(
        perluKonfirmasiBiayaGaransi(
          garansi: true,
          biaya: 200000,
          biayaLama: 150000,
        ),
        isTrue,
      );
    });

    testWidgets('kolom biayanya menyebutkan aturannya lebih dulu', (
      tester,
    ) async {
      await _lukis(tester, nota: _nota(claimId: 'klaim-1'));

      // Yang paling murah adalah salah ketik yang tidak jadi diketik.
      expect(
        find.textContaining('Unit bergaransi ditanggung brand'),
        findsOneWidget,
      );
    });

    testWidgets('menyimpan dengan biaya memunculkan pertanyaannya', (
      tester,
    ) async {
      await _lukis(tester, nota: _nota(claimId: 'klaim-1'));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Rp ').first,
        '150000',
      );
      await tester.pumpAndSettle();
      await _ketuk(
        tester,
        find.widgetWithText(FilledButton, 'SIMPAN PERUBAHAN'),
      );

      expect(find.text('Unit bergaransi, tetapi ada biaya'), findsOneWidget);
      expect(find.textContaining('Rp150.000'), findsOneWidget);

      // "Periksa lagi" mengembalikan ke formulirnya tanpa menyimpan apa
      // pun -- termasuk tanpa menyentuh server.
      await tester.tap(find.text('PERIKSA LAGI'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Unit bergaransi, tetapi ada biaya'), findsNothing);
      expect(find.text('150000'), findsWidgets);
    });
  });
}
