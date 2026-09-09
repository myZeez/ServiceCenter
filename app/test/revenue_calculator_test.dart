import 'package:flutter_test/flutter_test.dart';
import 'package:sc_management/core/revenue/revenue_calculator.dart';

/// Angka pada berkas ini diambil dari contoh nyata yang dipakai saat
/// merancang fitur, supaya hasilnya bisa dicocokkan dengan hitungan tangan.
void main() {
  const asusId = 1;
  const lenovoId = 2;

  final asus = BrandFee(
    brandId: asusId,
    fee: 100000,
    berlakuDari: DateTime(2026, 1, 1),
  );
  final lenovo = BrandFee(
    brandId: lenovoId,
    fee: 150000,
    berlakuDari: DateTime(2026, 1, 1),
  );

  const budi = 'budi';
  const irwan = 'irwan';
  const reza = 'reza';
  const agus = 'agus';

  List<RevenueClaim> klaim(int jumlah, int brandId, String? teknisi) => [
    for (var i = 0; i < jumlah; i++)
      RevenueClaim(
        brandId: brandId,
        tanggal: DateTime(2026, 2, 10),
        teknisiId: teknisi,
      ),
  ];

  TechnicianEarning cari(List<TechnicianEarning> list, String id) =>
      list.firstWhere((e) => e.teknisiId == id);

  group('Pembagian menurut peran', () {
    test('100 unit ASUS menghasilkan 10 juta, terbagi 30/10/60', () {
      final hasil = hitungPendapatan(
        claims: klaim(100, asusId, budi),
        fees: [asus],
        settings: const RevenueSettings(),
      );

      expect(hasil.totalNilai, 10000000);
      expect(hasil.bagianToko, 3000000);
      expect(hasil.bagianAdmin, 1000000);
      expect(hasil.bagianTeknisi, 6000000);
    });

    test('tiap brand dihitung sendiri lalu dijumlahkan', () {
      final hasil = hitungPendapatan(
        claims: [...klaim(100, asusId, budi), ...klaim(20, lenovoId, irwan)],
        fees: [asus, lenovo],
        settings: const RevenueSettings(),
      );

      expect(hasil.brands.length, 2);
      expect(hasil.totalNilai, 13000000);

      final a = hasil.brands.firstWhere((b) => b.brandId == asusId);
      final l = hasil.brands.firstWhere((b) => b.brandId == lenovoId);
      expect(a.nilai, 10000000);
      expect(l.nilai, 3000000);
      expect(a.bagianTeknisi + l.bagianTeknisi, hasil.bagianTeknisi);
    });

    test('brand boleh punya aturan pembagian sendiri', () {
      final hasil = hitungPendapatan(
        claims: [...klaim(100, asusId, budi), ...klaim(20, lenovoId, irwan)],
        fees: [asus, lenovo],
        settings: const RevenueSettings(
          aturanBrand: {
            // Lenovo memberi porsi lebih besar untuk teknisi.
            lenovoId: AturanBagi(
              persenToko: 20,
              persenAdmin: 10,
              persenTeknisi: 70,
            ),
          },
        ),
      );

      final l = hasil.brands.firstWhere((b) => b.brandId == lenovoId);
      expect(l.bagianToko, 600000);
      expect(l.bagianTeknisi, 2100000);

      // ASUS tetap memakai aturan umum.
      final a = hasil.brands.firstWhere((b) => b.brandId == asusId);
      expect(a.bagianToko, 3000000);

      expect(hasil.bagianToko, 3600000);
    });

    test('seluruh bagian tiap brand berjumlah persis nilai brand itu', () {
      final hasil = hitungPendapatan(
        claims: klaim(7, asusId, budi),
        fees: [
          BrandFee(
            brandId: asusId,
            fee: 33333,
            berlakuDari: DateTime(2026, 1, 1),
          ),
        ],
        settings: const RevenueSettings(),
      );

      final b = hasil.brands.single;
      expect(b.bagianToko + b.bagianAdmin + b.bagianTeknisi, b.nilai.round());
    });
  });

  group('Metode per unit dikerjakan', () {
    test('Budi 40 unit dan Irwan 60 unit dibagi 2,4 juta dan 3,6 juta', () {
      final hasil = hitungPendapatan(
        claims: [...klaim(40, asusId, budi), ...klaim(60, asusId, irwan)],
        fees: [asus],
        settings: const RevenueSettings(),
      );

      expect(cari(hasil.teknisi, budi).pendapatan, 2400000);
      expect(cari(hasil.teknisi, irwan).pendapatan, 3600000);
    });

    test('unit bernilai lebih tinggi memberi porsi lebih besar', () {
      // Budi 40 ASUS = 4 juta. Irwan 40 ASUS + 20 Lenovo = 7 juta.
      final hasil = hitungPendapatan(
        claims: [
          ...klaim(40, asusId, budi),
          ...klaim(40, asusId, irwan),
          ...klaim(20, lenovoId, irwan),
        ],
        fees: [asus, lenovo],
        settings: const RevenueSettings(),
      );

      expect(hasil.totalNilai, 11000000);

      // ASUS: pool 4,8 juta dibagi rata karena unitnya sama banyak.
      // Lenovo: pool 1,8 juta seluruhnya milik Irwan.
      expect(cari(hasil.teknisi, budi).pendapatan, 2400000);
      expect(cari(hasil.teknisi, irwan).pendapatan, 2400000 + 1800000);
    });

    test('tiga teknisi terbagi tanpa aturan tambahan', () {
      final hasil = hitungPendapatan(
        claims: [
          ...klaim(20, asusId, budi),
          ...klaim(30, asusId, irwan),
          ...klaim(50, asusId, reza),
        ],
        fees: [asus],
        settings: const RevenueSettings(),
      );

      expect(hasil.teknisi.length, 3);
      expect(cari(hasil.teknisi, reza).pendapatan, 3000000);
      expect(
        hasil.teknisi.fold<int>(0, (a, e) => a + e.pendapatan),
        hasil.bagianTeknisi,
      );
    });
  });

  group('Metode rata', () {
    test('dibagi sama besar walau jumlah unitnya berbeda', () {
      final hasil = hitungPendapatan(
        claims: [...klaim(40, asusId, budi), ...klaim(60, asusId, irwan)],
        fees: [asus],
        settings: const RevenueSettings(metode: MetodeTeknisi.rata),
      );

      expect(hasil.teknisi.every((e) => e.pendapatan == 3000000), isTrue);
    });
  });

  group('Metode manual per brand', () {
    test('tiap brand memakai persentase timnya sendiri', () {
      final hasil = hitungPendapatan(
        claims: [...klaim(100, asusId, irwan), ...klaim(20, lenovoId, reza)],
        fees: [asus, lenovo],
        settings: const RevenueSettings(metode: MetodeTeknisi.manual),
        porsiManual: const {
          asusId: {budi: 25, irwan: 35, reza: 40},
          lenovoId: {budi: 40, agus: 30, reza: 30},
        },
      );

      // ASUS: jatah teknisi 6 juta.
      final a = hasil.brands.firstWhere((b) => b.brandId == asusId);
      expect(a.bagianTeknisi, 6000000);
      expect(cari(a.teknisi, budi).pendapatan, 1500000);
      expect(cari(a.teknisi, irwan).pendapatan, 2100000);
      expect(cari(a.teknisi, reza).pendapatan, 2400000);

      // Lenovo: jatah teknisi 1,8 juta.
      final l = hasil.brands.firstWhere((b) => b.brandId == lenovoId);
      expect(l.bagianTeknisi, 1800000);
      expect(cari(l.teknisi, budi).pendapatan, 720000);
      expect(cari(l.teknisi, agus).pendapatan, 540000);
    });

    test('pendapatan gabungan adalah jumlah porsi dari semua brand', () {
      final hasil = hitungPendapatan(
        claims: [...klaim(100, asusId, irwan), ...klaim(20, lenovoId, reza)],
        fees: [asus, lenovo],
        settings: const RevenueSettings(metode: MetodeTeknisi.manual),
        porsiManual: const {
          asusId: {budi: 25, irwan: 35, reza: 40},
          lenovoId: {budi: 40, agus: 30, reza: 30},
        },
      );

      // Budi: 1.500.000 dari ASUS + 720.000 dari Lenovo.
      expect(cari(hasil.teknisi, budi).pendapatan, 2220000);
      // Reza: 2.400.000 dari ASUS + 540.000 dari Lenovo.
      expect(cari(hasil.teknisi, reza).pendapatan, 2940000);
    });

    test('yang punya persentase tetap dibayar walau tanpa unit', () {
      // Inti mode manual: Budi tidak memperbaiki satu unit ASUS pun, tetapi
      // membantu input klaim dan permintaan part.
      final hasil = hitungPendapatan(
        claims: klaim(100, asusId, irwan),
        fees: [asus],
        settings: const RevenueSettings(metode: MetodeTeknisi.manual),
        porsiManual: const {
          asusId: {budi: 25, irwan: 75},
        },
      );

      final b = cari(hasil.teknisi, budi);
      expect(b.unit, 0);
      expect(b.pendapatan, 1500000);
      expect(cari(hasil.teknisi, irwan).pendapatan, 4500000);
    });

    test('persentase yang belum genap menyisakan bagian tak teralokasi', () {
      final hasil = hitungPendapatan(
        claims: klaim(100, asusId, irwan),
        fees: [asus],
        settings: const RevenueSettings(metode: MetodeTeknisi.manual),
        porsiManual: const {
          asusId: {budi: 20},
        },
      );

      expect(cari(hasil.teknisi, budi).pendapatan, 1200000);
      expect(hasil.teknisiBelumDialokasikan, 4800000);
    });

    test('brand tanpa pengaturan tidak membagikan apa pun', () {
      final hasil = hitungPendapatan(
        claims: klaim(100, asusId, irwan),
        fees: [asus],
        settings: const RevenueSettings(metode: MetodeTeknisi.manual),
      );

      expect(hasil.teknisi, isEmpty);
      expect(hasil.teknisiBelumDialokasikan, 6000000);
    });
  });

  group('Fee dengan tanggal berlaku', () {
    test('klaim sebelum kenaikan tetap memakai fee lama', () {
      final fees = [
        asus,
        BrandFee(
          brandId: asusId,
          fee: 120000,
          berlakuDari: DateTime(2026, 4, 1),
        ),
      ];

      expect(feeUntuk(fees, asusId, DateTime(2026, 3, 31)), 100000);
      expect(feeUntuk(fees, asusId, DateTime(2026, 4, 1)), 120000);
    });

    test('klaim sebelum fee pertama dianggap belum punya fee', () {
      expect(feeUntuk([asus], asusId, DateTime(2025, 12, 31)), 0);
    });
  });

  group('Nilai dari rekap bulanan brand', () {
    test('angka dari surat brand mengalahkan fee brand', () {
      final hasil = hitungPendapatan(
        claims: [
          RevenueClaim(
            brandId: asusId,
            tanggal: DateTime(2026, 2, 10),
            teknisiId: budi,
            fee: 175000,
          ),
        ],
        fees: [asus],
        settings: const RevenueSettings(),
      );

      expect(hasil.totalNilai, 175000);
      expect(hasil.bagianTeknisi, 105000);
    });

    test('unit yang belum dicocokkan memakai fee brand', () {
      final hasil = hitungPendapatan(
        claims: [
          RevenueClaim(
            brandId: asusId,
            tanggal: DateTime(2026, 2, 10),
            teknisiId: budi,
            fee: 175000,
          ),
          ...klaim(1, asusId, budi),
        ],
        fees: [asus],
        settings: const RevenueSettings(),
      );

      // 175.000 dari surat brand, 100.000 dari nilai awal.
      expect(hasil.totalNilai, 275000);
      expect(hasil.unitTanpaFee, 0);
    });

    test(
      'brand yang menolak sebuah unit dicatat sebagai nol, bukan diabaikan',
      () {
        final hasil = hitungPendapatan(
          claims: [
            RevenueClaim(
              brandId: asusId,
              tanggal: DateTime(2026, 2, 10),
              teknisiId: budi,
              fee: 0,
            ),
            ...klaim(1, asusId, budi),
          ],
          fees: [asus],
          settings: const RevenueSettings(),
        );

        // Unitnya tetap terhitung sebagai pekerjaan yang dilakukan; yang nol
        // hanya nilainya.
        expect(hasil.totalUnit, 2);
        expect(hasil.totalNilai, 100000);
        expect(hasil.unitTanpaFee, 1);
      },
    );
  });

  group('Data yang belum lengkap', () {
    test('brand tanpa fee dilaporkan tersendiri, bukan dihitung diam-diam', () {
      final hasil = hitungPendapatan(
        claims: [...klaim(10, asusId, budi), ...klaim(5, 99, budi)],
        fees: [asus],
        settings: const RevenueSettings(),
      );

      expect(hasil.totalUnit, 15);
      expect(hasil.unitTanpaFee, 5);
      expect(hasil.totalNilai, 1000000);
    });

    test('klaim tanpa teknisi tidak menaikkan porsi orang lain', () {
      final hasil = hitungPendapatan(
        claims: [...klaim(50, asusId, budi), ...klaim(50, asusId, null)],
        fees: [asus],
        settings: const RevenueSettings(),
      );

      expect(hasil.unitTanpaTeknisi, 50);
      expect(hasil.bagianTeknisi, 6000000);
      expect(cari(hasil.teknisi, budi).pendapatan, 3000000);
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
      expect(hasil.brands, isEmpty);
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
