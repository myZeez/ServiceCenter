import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/core/status.dart';

void main() {
  group('ClaimStatus', () {
    test('urut menurut jalannya pekerjaan, dari buku garansi toko', () {
      expect(ClaimStatus.all, [
        'open',
        'wait_approval',
        'wait_eskalasi',
        'wait_stok_toko',
        'proses',
        'tunggu_part',
        'ship',
        'part_ready',
        'ship_pusat',
        'ok',
        'selesai',
        'close',
        'batal',
      ]);
    });

    // Daftar di Dart dan check di Postgres ditulis di dua tempat. Kalau
    // keduanya berbeda, status yang dipilih dari dropdown ditolak server
    // -- dan yang terlihat hanya "gagal menyimpan".
    test('sama persis dengan check status_klaim_dikenal di migrasi 0027', () {
      final sql = File(
        '../supabase/migrations/0027_status_garansi_lengkap.sql',
      ).readAsStringSync();
      final isi = RegExp(
        r'check \(status in \((.*?)\)\);',
        dotAll: true,
      ).firstMatch(sql)!.group(1)!;
      final diSql = RegExp(r"'([a-z_]+)'")
          .allMatches(isi)
          .map((m) => m.group(1))
          .toList();

      expect(diSql, ClaimStatus.all);
    });

    test('setiap status punya label, bukan kodenya', () {
      for (final s in ClaimStatus.all) {
        expect(ClaimStatus.label(s), isNot(equals(s)));
      }
    });

    test('label buku garansi', () {
      expect(ClaimStatus.label('wait_approval'), 'Wait Approval Warranty');
      expect(ClaimStatus.label('wait_eskalasi'), 'Wait Eskalasi Teknikal');
      expect(ClaimStatus.label('wait_stok_toko'), 'Wait Approval Stok Toko');
      expect(ClaimStatus.label('part_ready'), 'Part Ready');
      expect(ClaimStatus.label('selesai'), 'Selesai');
      expect(ClaimStatus.label('close'), 'Close');
    });

    test('Ship Pusat menyebut brand klaimnya', () {
      expect(
        ClaimStatus.label('ship_pusat', brand: 'ASUS'),
        'Ship ASUS Pusat',
      );
      expect(ClaimStatus.label('ship_pusat', brand: 'msi'), 'Ship MSI Pusat');
    });

    test('Ship Pusat tanpa brand tidak menulis tanda pengganti', () {
      expect(ClaimStatus.label('ship_pusat'), 'Ship Pusat');
      expect(ClaimStatus.label('ship_pusat', brand: '—'), 'Ship Pusat');
      expect(ClaimStatus.label('ship_pusat', brand: '  '), 'Ship Pusat');
    });

    test('label pendek hanya menyingkat yang panjang', () {
      expect(ClaimStatus.pendek('wait_approval'), 'Wait Approval');
      expect(ClaimStatus.pendek('wait_stok_toko'), 'Wait Stok Toko');
      expect(
        ClaimStatus.pendek('ship_pusat', brand: 'ACER'),
        'Ship ACER Pusat',
      );
      expect(ClaimStatus.pendek('selesai'), 'Selesai');
    });

    // Rekap Brand dan bagi hasil membaca daftar ini. Brand membayar
    // perbaikannya, bukan kedatangan pelanggan mengambil unitnya.
    test('Selesai dan Close sama-sama tuntas; yang lain belum', () {
      expect(ClaimStatus.tuntas, ['selesai', 'close']);
      for (final s in ClaimStatus.all) {
        expect(
          ClaimStatus.isTuntas(s),
          s == 'selesai' || s == 'close',
          reason: s,
        );
      }
    });

    test('status tak dikenal tidak bikin crash', () {
      expect(ClaimStatus.label('entah'), 'entah');
      expect(ClaimStatus.pendek('entah'), 'entah');
    });
  });

  group('ClaimFilter', () {
    test('copyWith mempertahankan nilai yang tidak diubah', () {
      const f = ClaimFilter(brandId: 1, status: 'open', query: 'asus');
      final next = f.copyWith(query: 'acer');

      expect(next.brandId, 1);
      expect(next.status, 'open');
      expect(next.query, 'acer');
    });

    test('clearBrand mengosongkan filter brand', () {
      const f = ClaimFilter(brandId: 1, status: 'open');
      final next = f.copyWith(clearBrand: true);

      expect(next.brandId, isNull);
      expect(next.status, 'open');
    });

    test('clearStatus mengosongkan filter status', () {
      const f = ClaimFilter(brandId: 1, status: 'open');
      final next = f.copyWith(clearStatus: true);

      expect(next.status, isNull);
      expect(next.brandId, 1);
    });
  });
}
