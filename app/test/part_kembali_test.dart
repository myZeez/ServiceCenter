import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/core/theme.dart';
import 'package:sc_management/features/claims/part_kembali_view.dart';

Claim _claim(
  String id, {
  int brandId = 1,
  String status = 'close',
  String jenis = 'brand',
  DateTime? kembali,
  String nama = 'Budi',
  String telp = '08123456789',
  String email = 'budi@example.com',
  String? sn,
  String keluhan = 'Mati total',
  String? teknisiId = 'teknisi-1',
}) => Claim(
  id: id,
  tanggal: DateTime(2026, 9, 1),
  brandId: brandId,
  namaPelanggan: nama,
  telp: telp,
  email: email,
  sn: sn ?? 'SN-$id',
  jenis: jenis,
  teknisiId: teknisiId,
  keluhan: keluhan,
  noPerbaikan: 'RMA-$id',
  status: status,
  tanggalClose: DateTime(2026, 9, 10),
  tanggalPartKembali: kembali,
  createdBy: 'admin',
  createdAt: DateTime(2026, 9, 1),
  updatedAt: DateTime(2026, 9, 10),
);

void main() {
  group('saringPartKembali', () {
    final pending = _claim('pending', nama: 'Budi Pending');
    final returned = _claim(
      'returned',
      nama: 'Sari Returned',
      kembali: DateTime(2026, 9, 12, 10),
    );
    final open = _claim('open', status: 'open');
    final toko = _claim('toko', jenis: 'toko');
    final brandLain = _claim('lenovo', brandId: 2, nama: 'Dewi');
    final semua = [pending, returned, open, toko, brandLain];

    test('hanya mengambil klaim brand yang close dan belum kembali', () {
      expect(saringPartKembali(semua, sudahKembali: false).map((c) => c.id), [
        'pending',
        'lenovo',
      ]);
    });

    test('memisahkan riwayat yang sudah kembali', () {
      expect(
        saringPartKembali(semua, sudahKembali: true).single.id,
        'returned',
      );
    });

    test('filter brand dan pencarian mencakup RMA serta telepon', () {
      expect(
        saringPartKembali(
          semua,
          sudahKembali: false,
          brandId: 2,
          query: 'dewi',
        ).single.id,
        'lenovo',
      );
      expect(
        saringPartKembali(semua, sudahKembali: false, query: '081234').length,
        2,
      );
      expect(
        saringPartKembali(
          semua,
          sudahKembali: false,
          query: 'rma-pending',
        ).single.id,
        'pending',
      );
    });
  });

  test(
    'Claim membaca tanggal pengembalian dari database sebagai waktu lokal',
    () {
      final claim = Claim.fromMap({
        'id': '1',
        'tanggal': '2026-09-01T00:00:00Z',
        'brand_id': 1,
        'nama_pelanggan': 'Budi',
        'sn': 'SN1',
        'status': 'close',
        'tanggal_part_kembali': '2026-09-12T03:00:00Z',
        'created_by': 'admin',
        'created_at': '2026-09-01T00:00:00Z',
        'updated_at': '2026-09-12T03:00:00Z',
      });

      expect(claim.tanggalPartKembali, isNotNull);
      expect(claim.tanggalPartKembali!.toUtc().hour, 3);
    },
  );

  testWidgets(
    'halaman memisahkan daftar dan menampilkan data yang bisa disalin',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1300));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final claims = [
        _claim('pending', nama: 'Budi Pending'),
        _claim(
          'pending-long',
          nama: 'Nama Pelanggan Sangat Panjang Tidak Boleh Menambah Tinggi',
          sn: 'NXD3LSN00252900DEE6L01SANGATPANJANG',
          email: '',
          keluhan: 'Keluhan yang panjang juga harus tetap satu baris',
        ),
        _claim(
          'returned',
          nama: 'Sari Returned',
          kembali: DateTime(2026, 9, 12, 10),
        ),
        _claim('open', status: 'open', nama: 'Tidak Boleh Muncul'),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allClaimsProvider.overrideWith((ref) => Stream.value(claims)),
            allBrandsProvider.overrideWith(
              (ref) => Stream.value([const Brand(id: 1, nama: 'ASUS')]),
            ),
            allPartsProvider.overrideWith(
              (ref) => Stream.value([
                const ClaimPart(
                  id: 'part-1',
                  claimId: 'pending',
                  partTypeId: 1,
                  snBadPart: 'BAD-001',
                ),
              ]),
            ),
            allPartTypesProvider.overrideWith(
              (ref) => Stream.value([
                const PartType(id: 1, kode: 'MB', nama: 'Mainboard'),
              ]),
            ),
            allProfilesProvider.overrideWith(
              (ref) => Stream.value([
                const Profile(
                  id: 'teknisi-1',
                  nama: 'Budi Teknisi',
                  role: 'teknisi',
                ),
              ]),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.terang(),
            home: const Scaffold(body: PartKembaliView()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Budi Pending'), findsNWidgets(2));
      expect(find.text('Sari Returned'), findsNothing);
      expect(find.text('Tidak Boleh Muncul'), findsNothing);
      expect(find.text('Mainboard'), findsOneWidget);
      expect(find.text('BAD-001'), findsOneWidget);
      expect(find.text('Budi Teknisi'), findsNWidgets(2));
      expect(find.text('EMAIL'), findsNothing);
      expect(find.text('SALIN SEMUA'), findsNothing);
      expect(find.text('KEMBALIKAN'), findsNWidgets(2));

      final pendek = tester.getSize(
        find.byKey(const ValueKey('part-kembali-pending')),
      );
      final panjang = tester.getSize(
        find.byKey(const ValueKey('part-kembali-pending-long')),
      );
      expect(pendek.height, panjang.height);

      final snPanjang = tester.widget<Text>(
        find.text('NXD3LSN00252900DEE6L01SANGATPANJANG'),
      );
      expect(snPanjang.maxLines, 1);
      expect(snPanjang.softWrap, isFalse);
      expect(snPanjang.overflow, TextOverflow.ellipsis);

      await tester.tap(find.text('SUDAH KEMBALI'));
      await tester.pumpAndSettle();

      expect(find.text('Budi Pending'), findsNothing);
      expect(find.text('Sari Returned'), findsNWidgets(2));
      expect(find.text('KEMBALIKAN'), findsNothing);
    },
  );
}
