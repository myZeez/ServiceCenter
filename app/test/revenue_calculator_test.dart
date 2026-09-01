import 'package:flutter_test/flutter_test.dart';
import 'package:sc_management/core/revenue/revenue_calculator.dart';

/// Angka pada berkas ini diambil dari contoh nyata yang dipakai saat
/// merancang fitur, supaya hasilnya bisa dicocokkan dengan hitungan tangan.
void main() {
  final asus = BrandFee(
    brandId: 1,
    fee: 100000,
    berlakuDari: DateTime(2026, 1, 1),
  );
  final lenovo = BrandFee(
    brandId: 2,
    fee: 150000,
    berlakuDari: DateTime(2026, 1, 1),
  );

  const budi = 'budi';
  const irwan = 'irwan';

  List<RevenueClaim> klaim(int jumlah, int brandId, String? teknisi) => [
        for (var i = 0; i < jumlah; i++)
          RevenueClaim(
            brandId: brandId,
            tanggal: DateTime(2026, 2, 10),
            teknisiId: teknisi,
          ),
      ];

  group('Pembagian menurut peran', () {
    test('100 unit ASUS menghasilkan 10 juta, terbagi 30/10/60', () {
      final hasil = hitungPendapatan(
        claims: klaim(100, 1, budi),
        fees: [asus],
        settings: const RevenueSettings(),
      );

      expect(hasil.totalNilai, 10000000);
      expect(hasil.bagianToko, 3000000);
      expect(hasil.bagianAdmin, 1000000);
      expect(hasil.bagianTeknisi, 6000000);
    });

    test('seluruh bagian selalu berjumlah persis sama dengan total', () {
      // Angka ganjil sengaja dipilih agar pembulatan benar-benar diuji.
      final hasil = hitungPendapatan(
        claims: klaim(7, 1, budi),
        fees: [
          BrandFee(brandId: 1, fee: 33333, berlakuDari: DateTime(2026, 1, 1)),
        ],
        settings: const RevenueSettings(),
      );

      expect(
        hasil.bagianToko + hasil.bagianAdmin + hasil.bagianTeknisi,
        hasil.totalNilai.round(),
      );
    });
  });

  group('Metode per unit dikerjakan', () {
    test('Budi 40 unit dan Irwan 60 unit dibagi 2,4 juta dan 3,6 juta', () {
      final hasil = hitungPendapatan(
        claims: [...klaim(40, 1, budi), ...klaim(60, 1, irwan)],
        fees: [asus],
        settings: const RevenueSettings(),
      );

      final b = hasil.teknisi.firstWhere((e) => e.teknisiId == budi);
      final i = hasil.teknisi.firstWhere((e) => e.teknisiId == irwan);

      expect(b.unit, 40);
      expect(i.unit, 60);
      expect(b.pendapatan, 2400000);
      expect(i.pendapatan, 3600000);
      expect(b.pendapatan + i.pendapatan, hasil.bagianTeknisi);
    });

    test('unit bernilai lebih tinggi memberi porsi lebih besar', () {
      // Budi 40 ASUS = 4 juta. Irwan 40 ASUS + 20 Lenovo = 7 juta.
      // Jumlah unit Irwan hanya 1,5 kali Budi, tapi nilainya 1,75 kali.
      final hasil = hitungPendapatan(
        claims: [
          ...klaim(40, 1, budi),
          ...klaim(40, 1, irwan),
          ...klaim(20, 2, irwan),
        ],
        fees: [asus, lenovo],
        settings: const RevenueSettings(),
      );

      expect(hasil.totalNilai, 11000000);

      final b = hasil.teknisi.firstWhere((e) => e.teknisiId == budi);
      final i = hasil.teknisi.firstWhere((e) => e.teknisiId == irwan);

      expect(b.pendapatan, 2400000);
      expect(i.pendapatan, 4200000);
    });

    test('tiga teknisi terbagi tanpa aturan tambahan', () {
      final hasil = hitungPendapatan(
        claims: [
          ...klaim(20, 1, budi),
          ...klaim(30, 1, irwan),
          ...klaim(50, 1, 'reza'),
        ],
        fees: [asus],
        settings: const RevenueSettings(),
      );

      expect(hasil.teknisi.length, 3);
      expect(
        hasil.teknisi.fold<int>(0, (a, e) => a + e.pendapatan),
        hasil.bagianTeknisi,
      );
      expect(
        hasil.teknisi.firstWhere((e) => e.teknisiId == 'reza').pendapatan,
        3000000,
      );
    });
  });

  group('Metode rata', () {
    test('dibagi sama besar walau jumlah unitnya berbeda', () {
      final hasil = hitungPendapatan(
        claims: [...klaim(40, 1, budi), ...klaim(60, 1, irwan)],
        fees: [asus],
        settings: const RevenueSettings(metode: MetodeTeknisi.rata),
      );

      expect(hasil.teknisi.every((e) => e.pendapatan == 3000000), isTrue);
    });
  });

  group('Metode manual', () {
    test('persentase yang belum genap menyisakan bagian tak teralokasi', () {
      final hasil = hitungPendapatan(
        claims: [...klaim(40, 1, budi), ...klaim(60, 1, irwan)],
        fees: [asus],
        settings: const RevenueSettings(metode: MetodeTeknisi.manual),
        porsiManual: const {budi: 20},
      );

      final b = hasil.teknisi.firstWhere((e) => e.teknisiId == budi);
      expect(b.pendapatan, 1200000);

      // Sisanya tidak diam-diam dibagi ke Irwan.
      expect(hasil.teknisiBelumDialokasikan, 4800000);
    });
  });

  group('Fee dengan tanggal berlaku', () {
    test('klaim sebelum kenaikan tetap memakai fee lama', () {
      final fees = [
        asus,
        BrandFee(brandId: 1, fee: 120000, berlakuDari: DateTime(2026, 4, 1)),
      ];

      expect(feeUntuk(fees, 1, DateTime(2026, 3, 31)), 100000);
      expect(feeUntuk(fees, 1, DateTime(2026, 4, 1)), 120000);
      expect(feeUntuk(fees, 1, DateTime(2026, 5, 20)), 120000);
    });

    test('klaim sebelum fee pertama dianggap belum punya fee', () {
      expect(feeUntuk([asus], 1, DateTime(2025, 12, 31)), 0);
    });
  });

  group('Data yang belum lengkap', () {
    test('brand tanpa fee dilaporkan tersendiri, bukan dihitung diam-diam', () {
      final hasil = hitungPendapatan(
        claims: [...klaim(10, 1, budi), ...klaim(5, 99, budi)],
        fees: [asus],
        settings: const RevenueSettings(),
      );

      expect(hasil.totalUnit, 15);
      expect(hasil.unitTanpaFee, 5);
      expect(hasil.totalNilai, 1000000);
    });

    test('klaim tanpa teknisi tidak menaikkan porsi orang lain', () {
      final hasil = hitungPendapatan(
        claims: [...klaim(50, 1, budi), ...klaim(50, 1, null)],
        fees: [asus],
        settings: const RevenueSettings(),
      );

      expect(hasil.unitTanpaTeknisi, 50);
      expect(hasil.bagianTeknisi, 6000000);

      // Budi hanya mengerjakan separuh nilainya, jadi hanya separuh jatah.
      final b = hasil.teknisi.firstWhere((e) => e.teknisiId == budi);
      expect(b.pendapatan, 3000000);
      expect(hasil.teknisiBelumDialokasikan, 3000000);
    });

    test('periode tanpa klaim tidak membuat perhitungan gagal', () {
      final hasil = hitungPendapatan(
        claims: const [],
        fees: [asus],
        settings: const RevenueSettings(),
      );

      expect(hasil.totalNilai, 0);
      expect(hasil.bagianTeknisi, 0);
      expect(hasil.teknisi, isEmpty);
    });
  });

  group('bagiRata', () {
    test('sisa pembulatan dibagikan sehingga jumlahnya tetap utuh', () {
      final hasil = bagiRata(100, [1, 1, 1]);
      expect(hasil.fold<int>(0, (a, b) => a + b), 100);
      expect(hasil, [34, 33, 33]);
    });

    test('bobot nol menghasilkan bagian nol tanpa membagi dengan nol', () {
      expect(bagiRata(500, [0, 0]), [0, 0]);
    });
  });
}
