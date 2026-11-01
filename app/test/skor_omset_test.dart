// Skor teknisi dari omset bulanan.
//
// Rumusnya menentukan siapa yang terlihat "teknisi terbaik", jadi setiap
// batasnya diuji: titik 50% di target, 100% di dua kali target, ambang
// bintang, dan bulan mana yang ikut dinilai.

import 'package:flutter_test/flutter_test.dart';
import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/omset/skor_omset.dart';

ServiceOrderEntry _nota(
  String id, {
  String teknisi = 't1',
  DateTime? selesai,
  DateTime? diambil,
  double biaya = 100000,
  String status = 'diambil',
}) => ServiceOrderEntry(
  id: id,
  noNota: id,
  tanggalMasuk: DateTime(2026, 1, 1),
  customerNama: 'X',
  barangNama: 'Laptop',
  teknisiId: teknisi,
  status: status,
  biaya: biaya,
  tanggalSelesai: selesai,
  tanggalDiambil: diambil,
  updatedAt: DateTime(2026, 1, 1),
);

const _aturan = ServiceSettingsRow(
  id: 1,
  targetOmset: 4000000,
  feeAdminPerNota: 0,
);

OmsetBulan _b(int bulan, double omset, {int tahun = 2026}) =>
    OmsetBulan(bulan: DateTime(tahun, bulan), omset: omset, jumlahNota: 1);

void main() {
  group('persenSkor: rata-rata dibanding dua kali target', () {
    test('target bernilai 50%, dua kali target 100%', () {
      expect(persenSkor(4000000, 4000000), 50);
      expect(persenSkor(8000000, 4000000), 100);
      expect(persenSkor(6000000, 4000000), 75);
    });
    test('di atas dua kali target tetap 100%, nol tetap 0%', () {
      expect(persenSkor(16000000, 4000000), 100);
      expect(persenSkor(0, 4000000), 0);
    });
    test('target dinaikkan di Pengaturan, standarnya ikut naik', () {
      expect(persenSkor(5000000, 5000000), 50);
      expect(persenSkor(6000000, 5000000), 60);
    });
    test('target nol tidak membagi dengan nol', () {
      expect(persenSkor(5000000, 0), 0);
    });
  });

  group('bintangDariPersen', () {
    test('ambang 90, 75, 60, 40', () {
      expect(bintangDariPersen(100), 5);
      expect(bintangDariPersen(90), 5);
      expect(bintangDariPersen(89.9), 4);
      expect(bintangDariPersen(75), 4);
      expect(bintangDariPersen(74.9), 3);
      expect(bintangDariPersen(60), 3);
      expect(bintangDariPersen(59.9), 2);
      expect(bintangDariPersen(40), 2);
      expect(bintangDariPersen(39.9), 1);
      expect(bintangDariPersen(0), 1);
    });
    test('dibandingkan seperti yang tampil di layar (satu desimal)', () {
      expect(bintangDariPersen(89.96), 5, reason: 'tampil 90,0%');
      expect(bintangDariPersen(89.94), 4, reason: 'tampil 89,9%');
    });
    test('predikat bintang 5 adalah teknisi terbaik', () {
      expect(predikatBintang(5), 'Teknisi terbaik');
      expect(predikatBintang(1), 'Perlu ditingkatkan');
    });
  });

  group('omsetBulananTeknisi', () {
    final kini = DateTime(2026, 10, 19, 15);

    test('bulan berjalan tidak ikut dinilai', () {
      final b = omsetBulananTeknisi(
        nota: [
          _nota('a', selesai: DateTime(2026, 9, 3), biaya: 300000),
          _nota('b', selesai: DateTime(2026, 9, 30), biaya: 200000),
          _nota('c', selesai: DateTime(2026, 10, 5), biaya: 999000),
        ],
        teknisiId: 't1',
        kini: kini,
        aturan: _aturan,
      );
      expect(b.map((x) => x.bulan), [DateTime(2026, 9)]);
      expect(b.single.omset, 500000);
      expect(b.single.jumlahNota, 2);
    });

    test('aturan omset sama dengan laporan: batal tidak, tanggal diambil jadi cadangan', () {
      final b = omsetBulananTeknisi(
        nota: [
          _nota('a', selesai: DateTime(2026, 9, 3), biaya: 300000),
          _nota(
            'batal',
            selesai: DateTime(2026, 9, 4),
            biaya: 50000,
            status: 'batal',
          ),
          _nota('arsip', diambil: DateTime(2026, 9, 10), biaya: 100000),
          _nota('jalan', biaya: 70000, status: 'dikerjakan'),
          _nota('orang lain', teknisi: 't2', selesai: DateTime(2026, 9, 3)),
        ],
        teknisiId: 't1',
        kini: kini,
        aturan: _aturan,
      );
      expect(b.single.omset, 400000);
      expect(b.single.jumlahNota, 2);
    });

    test('paling banyak dua belas bulan ke belakang', () {
      final b = omsetBulananTeknisi(
        nota: [
          for (var m = 1; m <= 21; m++)
            _nota('n$m', selesai: DateTime(2025, m, 10)),
        ],
        teknisiId: 't1',
        kini: kini,
        aturan: _aturan,
      );
      expect(b.length, 12);
      expect(b.first.bulan, DateTime(2025, 10));
      expect(b.last.bulan, DateTime(2026, 9));
    });

    test('bulan sebelum nota pertama tidak dihitung nol', () {
      final b = omsetBulananTeknisi(
        nota: [_nota('a', selesai: DateTime(2026, 8, 20))],
        teknisiId: 't1',
        kini: kini,
        aturan: _aturan,
      );
      expect(b.map((x) => x.bulan), [DateTime(2026, 8), DateTime(2026, 9)]);
    });

    test('bulan aktif tanpa omset tetap dihitung nol', () {
      final b = omsetBulananTeknisi(
        nota: [
          _nota('a', selesai: DateTime(2026, 7, 20), biaya: 500000),
          _nota('b', selesai: DateTime(2026, 9, 20), biaya: 500000),
        ],
        teknisiId: 't1',
        kini: kini,
        aturan: _aturan,
      );
      expect(b.map((x) => x.omset), [500000, 0, 500000]);
    });

    test('belum punya nota: kosong', () {
      expect(
        omsetBulananTeknisi(
          nota: const [],
          teknisiId: 't1',
          kini: kini,
          aturan: _aturan,
        ),
        isEmpty,
      );
    });

    test('pergantian tahun', () {
      final b = omsetBulananTeknisi(
        nota: [_nota('a', selesai: DateTime(2026, 11, 20))],
        teknisiId: 't1',
        kini: DateTime(2027, 1, 5),
        aturan: _aturan,
      );
      expect(b.map((x) => x.bulan), [DateTime(2026, 11), DateTime(2026, 12)]);
    });
  });

  group('hitungSkorOmset', () {
    test('belum ada bulan penuh: tidak ada skor', () {
      expect(hitungSkorOmset(const [], 4000000), isNull);
    });

    test('omset Budi Januari-September 2026: 76,8%, bintang 4', () {
      final omset = [6290, 6485, 5685, 6430, 6225, 5070, 5150, 5820, 8135];
      final s = hitungSkorOmset([
        for (var i = 0; i < omset.length; i++) _b(i + 1, omset[i] * 1000.0),
      ], 4000000)!;
      expect(s.rataRata.round(), 6143333);
      expect(s.persen.toStringAsFixed(1), '76.8');
      expect(s.bintang, 4);
      expect(s.predikat, 'Sangat baik');
      expect(s.terendah.bulan, DateTime(2026, 6));
      expect(s.tertinggi.bulan, DateTime(2026, 9));
    });

    test('rata-rata dua kali target ke atas: bintang 5, teknisi terbaik', () {
      final s = hitungSkorOmset([_b(8, 9000000), _b(9, 7500000)], 4000000)!;
      expect(s.persen, 100);
      expect(s.bintang, 5);
      expect(s.predikat, 'Teknisi terbaik');
    });

    test('nilai yang sama: bulan yang lebih baru yang disebut', () {
      final s = hitungSkorOmset([_b(7, 5000000), _b(8, 5000000)], 4000000)!;
      expect(s.terendah.bulan, DateTime(2026, 8));
      expect(s.tertinggi.bulan, DateTime(2026, 8));
    });
  });
}
