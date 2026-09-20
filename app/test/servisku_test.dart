// Servisku: nota yang dipegang pengguna, dan pencarian di halaman Servis.
//
// Yang dijaga di sini adalah batas-batasnya -- siapa yang dihitung
// "sedang dikerjakan", siapa yang "sudah selesai", dan di mana tepat garis
// tiga bulannya -- karena kesalahan di batas itu tidak terlihat dari layar:
// daftarnya tetap terisi, hanya kurang satu unit.

import 'package:flutter_test/flutter_test.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/nota/cocok_cari.dart';
import 'package:sc_management/features/service/servisku.dart';

ServiceOrderEntry _nota(
  String id, {
  String status = 'dikerjakan',
  String? teknisi = 'saya',
  DateTime? masuk,
  DateTime? selesai,
  String nama = 'Budi',
  String? telp,
  String? sn,
  String barang = 'ASUS',
  String? tipe,
}) => ServiceOrderEntry(
  id: id,
  noNota: id,
  tanggalMasuk: masuk ?? DateTime(2026, 9, 1, 9),
  customerNama: nama,
  customerTelp: telp,
  barangNama: barang,
  barangType: tipe,
  barangSn: sn,
  teknisiId: teknisi,
  status: status,
  tanggalSelesai: selesai,
  updatedAt: DateTime(2026, 9, 1),
);

List<String> _id(List<ServiceOrderEntry> l) => [for (final n in l) n.id];

void main() {
  group('notaBerjalanSaya', () {
    test('mengambil yang baru masuk sampai yang tertahan', () {
      final hasil = notaBerjalanSaya([
        _nota('masuk', status: 'masuk'),
        _nota('kerja', status: 'dikerjakan'),
        _nota('part', status: 'tunggu_part'),
        _nota('kirim', status: 'dikirim_cabang'),
      ], 'saya');

      expect(_id(hasil), ['masuk', 'kerja', 'part', 'kirim']);
    });

    test('yang sudah rampung atau batal bukan lagi beban', () {
      final hasil = notaBerjalanSaya([
        _nota('a', status: 'selesai'),
        _nota('b', status: 'diambil'),
        _nota('c', status: 'batal'),
        _nota('d', status: 'dikerjakan'),
      ], 'saya');

      expect(_id(hasil), ['d']);
    });

    test('hanya milik pengguna itu', () {
      final hasil = notaBerjalanSaya([
        _nota('saya1'),
        _nota('orang', teknisi: 'lain'),
        _nota('tanpa', teknisi: null),
      ], 'saya');

      expect(_id(hasil), ['saya1']);
    });

    test('belum ada yang login: kosong, bukan semua nota tanpa teknisi', () {
      // teknisiId == null dan userId == null sama-sama null; perbandingan
      // yang ceroboh akan menganggap keduanya cocok.
      final hasil = notaBerjalanSaya([_nota('tanpa', teknisi: null)], null);

      expect(hasil, isEmpty);
    });

    test('urutan kedatangan dipertahankan', () {
      final hasil = notaBerjalanSaya([
        _nota('baru', masuk: DateTime(2026, 9, 20)),
        _nota('lama', masuk: DateTime(2026, 9, 2)),
      ], 'saya');

      expect(_id(hasil), ['baru', 'lama']);
    });
  });

  group('notaSelesaiSaya', () {
    final kini = DateTime(2026, 9, 21, 10, 30);

    test('selesai dan sudah diambil sama-sama ikut, batal tidak', () {
      final hasil = notaSelesaiSaya(
        [
          _nota('sel', status: 'selesai', selesai: DateTime(2026, 9, 10)),
          _nota('amb', status: 'diambil', selesai: DateTime(2026, 9, 12)),
          _nota('bat', status: 'batal', selesai: DateTime(2026, 9, 14)),
          _nota('jalan', status: 'dikerjakan'),
        ],
        'saya',
        kini,
      );

      expect(_id(hasil), ['amb', 'sel']);
    });

    test('garisnya tanggal yang sama tiga bulan lalu, dan itu masih ikut', () {
      final hasil = notaSelesaiSaya(
        [
          _nota('pas', status: 'selesai', selesai: DateTime(2026, 6, 21)),
          _nota(
            'kurang sehari',
            status: 'selesai',
            selesai: DateTime(2026, 6, 20),
          ),
        ],
        'saya',
        kini,
      );

      expect(_id(hasil), ['pas']);
    });

    test('memakai tanggal selesai, bukan tanggal masuk', () {
      // Masuk lima bulan lalu, baru rampung kemarin: pekerjaan minggu ini.
      final hasil = notaSelesaiSaya(
        [
          _nota(
            'lama',
            status: 'selesai',
            masuk: DateTime(2026, 4, 2),
            selesai: DateTime(2026, 9, 20),
          ),
        ],
        'saya',
        kini,
      );

      expect(_id(hasil), ['lama']);
    });

    test('tanpa tanggal selesai jatuh ke tanggal masuknya', () {
      final hasil = notaSelesaiSaya(
        [
          _nota('impor baru', status: 'diambil', masuk: DateTime(2026, 8, 1)),
          _nota('impor lama', status: 'diambil', masuk: DateTime(2026, 3, 1)),
        ],
        'saya',
        kini,
      );

      expect(_id(hasil), ['impor baru']);
    });

    test('yang terbaru selesai di atas; seri diputus tanggal masuk', () {
      final hasil = notaSelesaiSaya(
        [
          _nota('a', status: 'selesai', selesai: DateTime(2026, 9, 1)),
          _nota(
            'b',
            status: 'selesai',
            selesai: DateTime(2026, 9, 15),
            masuk: DateTime(2026, 9, 3),
          ),
          _nota(
            'c',
            status: 'selesai',
            selesai: DateTime(2026, 9, 15),
            masuk: DateTime(2026, 9, 10),
          ),
        ],
        'saya',
        kini,
      );

      expect(_id(hasil), ['c', 'b', 'a']);
    });

    test('hanya milik pengguna itu, dan tanpa login kosong', () {
      final semua = [
        _nota('saya1', status: 'selesai', selesai: DateTime(2026, 9, 1)),
        _nota(
          'orang',
          status: 'selesai',
          teknisi: 'lain',
          selesai: DateTime(2026, 9, 1),
        ),
        _nota(
          'tanpa',
          status: 'selesai',
          teknisi: null,
          selesai: DateTime(2026, 9, 1),
        ),
      ];

      expect(_id(notaSelesaiSaya(semua, 'saya', kini)), ['saya1']);
      expect(notaSelesaiSaya(semua, null, kini), isEmpty);
    });
  });

  group('tigaBulanSebelum', () {
    test('mundur tiga bulan pada tanggal yang sama, di awal harinya', () {
      expect(
        tigaBulanSebelum(DateTime(2026, 9, 21, 23, 59)),
        DateTime(2026, 6, 21),
      );
    });

    test('melewati pergantian tahun', () {
      expect(tigaBulanSebelum(DateTime(2026, 1, 15)), DateTime(2025, 10, 15));
      expect(tigaBulanSebelum(DateTime(2026, 3, 1)), DateTime(2025, 12, 1));
    });

    test('tanggal 31 jatuh di hari terakhir bulan yang lebih pendek', () {
      // 31 Mei -> "31 Februari" tidak ada; bukan 3 Maret.
      expect(tigaBulanSebelum(DateTime(2026, 5, 31)), DateTime(2026, 2, 28));
      // Tahun kabisat.
      expect(tigaBulanSebelum(DateTime(2028, 5, 31)), DateTime(2028, 2, 29));
      // 31 Desember -> 31 September tidak ada; jatuh di 30 September.
      expect(tigaBulanSebelum(DateTime(2026, 12, 31)), DateTime(2026, 9, 30));
    });
  });

  group('cocokCariNota', () {
    final n = _nota(
      'SVR-08092628272',
      nama: 'Irwan Saputra',
      telp: '081234567890',
      sn: 'R9ABC123',
      barang: 'Laptop ASUS',
      tipe: 'X441BA',
    );

    test('kata kosong cocok dengan semuanya', () {
      expect(cocokCariNota(n, ''), isTrue);
      expect(cocokCariNota(n, '   '), isTrue);
    });

    test('mencocokkan nomor nota, nama, telepon, seri, barang, dan tipe', () {
      for (final kata in [
        'svr-0809',
        '28272',
        'irwan',
        'SAPUTRA',
        '567890',
        'r9abc',
        'asus',
        'x441',
      ]) {
        expect(cocokCariNota(n, kata), isTrue, reason: kata);
      }
    });

    test('spasi di ujung diabaikan', () {
      expect(cocokCariNota(n, '  irwan  '), isTrue);
    });

    test('yang tidak ada di nota tidak cocok', () {
      expect(cocokCariNota(n, 'lenovo'), isFalse);
      expect(cocokCariNota(n, 'budi'), isFalse);
    });

    test('kolom yang kosong tidak membuat galat', () {
      expect(cocokCariNota(_nota('X1'), 'sesuatu'), isFalse);
    });
  });
}
