import 'package:flutter_test/flutter_test.dart';
import 'package:sc_management/core/omset/omset_calculator.dart';

void main() {
  const budi = 'budi';
  const irwan = 'irwan';

  List<OmsetNota> nota(
    int jumlah,
    double biaya,
    String? teknisi, {
    bool lunas = true,
  }) => [
    for (var i = 0; i < jumlah; i++)
      OmsetNota(teknisiId: teknisi, biaya: biaya, lunas: lunas),
  ];

  OmsetTeknisi cari(OmsetResult r, String id) =>
      r.teknisi.firstWhere((e) => e.teknisiId == id);

  group('Omset toko', () {
    test('menjumlahkan seluruh jasa pada periode', () {
      final hasil = hitungOmset(
        nota: [...nota(30, 100000, budi), ...nota(10, 250000, irwan)],
        settings: const OmsetSettings(),
      );

      expect(hasil.omsetToko, 5500000);
      expect(hasil.jumlahNota, 40);
    });

    test('memisahkan yang sudah dibayar dari piutang', () {
      final hasil = hitungOmset(
        nota: [
          ...nota(10, 100000, budi),
          ...nota(5, 100000, budi, lunas: false),
        ],
        settings: const OmsetSettings(),
      );

      expect(hasil.omsetToko, 1500000);
      expect(hasil.sudahMasuk, 1000000);
      expect(hasil.piutang, 500000);
    });
  });

  group('Omset teknisi', () {
    test('memakai jasa kotor, bukan bagian setelah dipotong', () {
      // Instal ulang Rp100rb masuk penuh Rp100rb ke omset teknisinya.
      final hasil = hitungOmset(
        nota: nota(1, 100000, budi),
        settings: const OmsetSettings(),
      );

      expect(cari(hasil, budi).omset, 100000);
    });

    test('piutang tetap dihitung sebagai omset teknisi', () {
      // Pelanggan yang menunda membayar bukan salah teknisi yang
      // mengerjakannya.
      final hasil = hitungOmset(
        nota: nota(10, 200000, budi, lunas: false),
        settings: const OmsetSettings(),
      );

      expect(cari(hasil, budi).omset, 2000000);
      expect(hasil.piutang, 2000000);
    });

    test('kemajuan terhadap target dihitung dari targetnya', () {
      final hasil = hitungOmset(
        nota: nota(20, 150000, budi),
        settings: const OmsetSettings(targetTeknisi: 4000000),
      );

      final b = cari(hasil, budi);
      expect(b.omset, 3000000);
      expect(b.persenTarget(4000000), 75);
      expect(b.kurangDariTarget(4000000), 1000000);
    });

    test('yang melampaui target tidak menghasilkan kekurangan negatif', () {
      final hasil = hitungOmset(
        nota: nota(50, 100000, budi),
        settings: const OmsetSettings(targetTeknisi: 4000000),
      );

      final b = cari(hasil, budi);
      expect(b.omset, 5000000);
      expect(b.kurangDariTarget(4000000), 0);
      expect(b.persenTarget(4000000), 125);
    });

    test('target nol tidak membuat pembagian dengan nol', () {
      final hasil = hitungOmset(
        nota: nota(5, 100000, budi),
        settings: const OmsetSettings(targetTeknisi: 0),
      );

      expect(cari(hasil, budi).persenTarget(0), 0);
    });
  });

  group('Omset admin', () {
    test('dihitung dari jumlah nota, bukan dari nilainya', () {
      // Nota kecil sama repotnya dengan nota besar, jadi imbalannya sama.
      final kecil = hitungOmset(
        nota: nota(40, 50000, budi),
        settings: const OmsetSettings(feeAdminPerNota: 5000),
      );
      final besar = hitungOmset(
        nota: nota(40, 900000, budi),
        settings: const OmsetSettings(feeAdminPerNota: 5000),
      );

      expect(kecil.omsetAdmin, 200000);
      expect(besar.omsetAdmin, 200000);
    });

    test('fee nol menghasilkan omset admin nol', () {
      final hasil = hitungOmset(
        nota: nota(40, 100000, budi),
        settings: const OmsetSettings(),
      );

      expect(hasil.omsetAdmin, 0);
    });
  });

  group('Data yang belum lengkap', () {
    test('nota tanpa teknisi masuk omset toko tapi tidak ke siapa pun', () {
      final hasil = hitungOmset(
        nota: [...nota(10, 100000, budi), ...nota(5, 100000, null)],
        settings: const OmsetSettings(),
      );

      expect(hasil.omsetToko, 1500000);
      expect(hasil.notaTanpaTeknisi, 5);
      expect(cari(hasil, budi).omset, 1000000);
      expect(hasil.teknisi.length, 1);
    });

    test('periode tanpa nota tidak membuat perhitungan gagal', () {
      final hasil = hitungOmset(
        nota: const [],
        settings: const OmsetSettings(feeAdminPerNota: 5000),
      );

      expect(hasil.omsetToko, 0);
      expect(hasil.omsetAdmin, 0);
      expect(hasil.teknisi, isEmpty);
    });
  });
}
