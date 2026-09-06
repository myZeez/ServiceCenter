// Cara bayar sebagai daftar yang bisa diatur sendiri.
//
// Yang dijaga di sini satu hal: 'cash' dulu punya arti khusus -- ia yang
// menandai sebuah nota langsung lunas. Kalau transfer dan QRIS ditambahkan
// tanpa membawa arti itu, uangnya sudah masuk rekening tetapi notanya
// tercatat piutang, dan pelanggan yang sudah membayar akan ditagih lagi.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/features/settings/metode_bayar_card.dart';

const _daftar = [
  MetodeBayar(id: 1, kode: 'cash', nama: 'Cash', urutan: 1),
  MetodeBayar(id: 2, kode: 'qris', nama: 'QRIS', urutan: 2),
  MetodeBayar(
    id: 3,
    kode: 'transfer_bri',
    nama: 'Transfer BRI',
    urutan: 3,
  ),
  MetodeBayar(
    id: 4,
    kode: 'transfer_btn',
    nama: 'Transfer BTN',
    urutan: 4,
    aktif: false,
  ),
  MetodeBayar(
    id: 5,
    kode: 'piutang',
    nama: 'Piutang',
    piutang: true,
    urutan: 9,
  ),
];

ProviderContainer _wadah([List<MetodeBayar> daftar = _daftar]) {
  final c = ProviderContainer(
    overrides: [
      allMetodeBayarProvider.overrideWith((ref) => Stream.value(daftar)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('pilihan', () {
    test('hanya yang aktif ditawarkan', () async {
      final c = _wadah();
      await c.read(allMetodeBayarProvider.future);

      expect(
        c.read(metodeBayarProvider).map((m) => m.kode),
        ['cash', 'qris', 'transfer_bri', 'piutang'],
      );
    });

    test('daftar kosong tidak menjatuhkan apa pun', () async {
      final c = _wadah(const []);
      await c.read(allMetodeBayarProvider.future);
      expect(c.read(metodeBayarProvider), isEmpty);
    });
  });

  group('membaca nama', () {
    test('kode dikembalikan sebagai nama yang enak dibaca', () async {
      final c = _wadah();
      await c.read(allMetodeBayarProvider.future);

      expect(c.read(namaMetodeBayar('transfer_bri')), 'Transfer BRI');
      // Yang sudah dinonaktifkan tetap punya nama: nota lama memakainya.
      expect(c.read(namaMetodeBayar('transfer_btn')), 'Transfer BTN');
    });

    test('kode asing tidak disembunyikan, hanya dirapikan', () async {
      final c = _wadah();
      await c.read(allMetodeBayarProvider.future);

      // Nota lama menyimpan kodenya sendiri. Mengembalikan tanda hubung
      // akan membuat nota itu tampak tidak punya cara bayar sama sekali.
      expect(c.read(namaMetodeBayar('dompet_lama')), 'DOMPET LAMA');
      expect(c.read(namaMetodeBayar(null)), '');
    });
  });

  group('lunas atau piutang', () {
    test('hanya yang ditandai piutang yang berarti belum dibayar', () async {
      final c = _wadah();
      await c.read(allMetodeBayarProvider.future);

      expect(c.read(metodePiutang('piutang')), isTrue);

      // Inilah yang dijaga: uang yang sudah masuk rekening bukan piutang.
      expect(c.read(metodePiutang('cash')), isFalse);
      expect(c.read(metodePiutang('qris')), isFalse);
      expect(c.read(metodePiutang('transfer_bri')), isFalse);
    });

    test('kode yang tidak dikenal dianggap lunas, bukan piutang', () async {
      final c = _wadah();
      await c.read(allMetodeBayarProvider.future);

      // Sisi yang lebih aman untuk salah: piutang palsu akan menagih
      // pelanggan yang sudah membayar, dan itu sampai ke orang di depan
      // meja. Trigger di server memutuskan dengan cara yang sama.
      expect(c.read(metodePiutang('dompet_lama')), isFalse);
      expect(c.read(metodePiutang(null)), isFalse);
    });
  });

  group('kartu pengaturan', () {
    testWidgets('menampilkan daftarnya dan menandai yang piutang', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(600, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allMetodeBayarProvider.overrideWith(
              (ref) => Stream.value(_daftar),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(height: 700, child: MetodeBayarCard()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('CARA BAYAR'), findsOneWidget);
      expect(find.text('Transfer BRI'), findsOneWidget);
      expect(find.text('QRIS'), findsOneWidget);
      expect(find.text('PIUTANG'), findsOneWidget);
    });
  });
}
