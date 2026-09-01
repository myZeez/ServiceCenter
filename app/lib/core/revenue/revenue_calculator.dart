/// Perhitungan bagi hasil.
///
/// Sengaja fungsi murni tanpa ketergantungan ke database maupun Flutter:
/// rumus yang menentukan bayaran orang harus bisa diuji, dan hasilnya harus
/// sama persis di perangkat mana pun.
library;

class RevenueSettings {
  const RevenueSettings({
    this.persenToko = 30,
    this.persenAdmin = 10,
    this.persenTeknisi = 60,
    this.metode = MetodeTeknisi.perUnit,
  });

  final double persenToko;
  final double persenAdmin;
  final double persenTeknisi;
  final MetodeTeknisi metode;
}

enum MetodeTeknisi {
  /// Porsi mengikuti nilai rupiah yang dihasilkan tiap teknisi.
  perUnit('per_unit'),

  /// Jatah teknisi dibagi sama besar antar yang bekerja di periode itu.
  rata('rata'),

  /// Persentase tetap per orang.
  manual('manual');

  const MetodeTeknisi(this.kode);
  final String kode;

  static MetodeTeknisi dari(String kode) =>
      MetodeTeknisi.values.firstWhere(
        (e) => e.kode == kode,
        orElse: () => MetodeTeknisi.perUnit,
      );
}

/// Satu fee yang berlaku sejak tanggal tertentu.
class BrandFee {
  const BrandFee({
    required this.brandId,
    required this.fee,
    required this.berlakuDari,
  });

  final int brandId;
  final double fee;
  final DateTime berlakuDari;
}

/// Klaim yang ikut dihitung. Pemanggil bertanggung jawab menyaring status
/// dan periodenya.
class RevenueClaim {
  const RevenueClaim({
    required this.brandId,
    required this.tanggal,
    required this.teknisiId,
  });

  final int brandId;
  final DateTime tanggal;
  final String? teknisiId;
}

class TechnicianEarning {
  const TechnicianEarning({
    required this.teknisiId,
    required this.unit,
    required this.nilai,
    required this.porsi,
    required this.pendapatan,
  });

  final String teknisiId;
  final int unit;
  final double nilai;

  /// Porsi dalam persen dari jatah teknisi. Ditampilkan apa adanya di
  /// laporan supaya dasar hitungannya bisa dilihat, bukan hanya rupiahnya.
  final double porsi;
  final int pendapatan;
}

class BrandRevenue {
  const BrandRevenue({
    required this.brandId,
    required this.unit,
    required this.nilai,
  });

  final int brandId;
  final int unit;
  final double nilai;

  double get feeRataRata => unit == 0 ? 0 : nilai / unit;
}

class RevenueResult {
  const RevenueResult({
    required this.totalUnit,
    required this.totalNilai,
    required this.unitTanpaFee,
    required this.unitTanpaTeknisi,
    required this.bagianToko,
    required this.bagianAdmin,
    required this.bagianTeknisi,
    required this.teknisi,
    required this.brands,
  });

  final int totalUnit;
  final double totalNilai;

  /// Klaim yang brand-nya belum punya fee. Dilaporkan tersendiri supaya
  /// tidak diam-diam ikut terhitung sebagai nol.
  final int unitTanpaFee;

  /// Klaim selesai yang kolom teknisinya kosong. Nilainya tetap masuk total
  /// tetapi tidak jatuh ke siapa pun.
  final int unitTanpaTeknisi;

  final int bagianToko;
  final int bagianAdmin;
  final int bagianTeknisi;

  final List<TechnicianEarning> teknisi;
  final List<BrandRevenue> brands;

  /// Bagian teknisi yang belum jatuh ke siapa pun. Terjadi pada metode
  /// manual yang persentasenya belum genap 100%, atau saat ada klaim tanpa
  /// teknisi.
  int get teknisiBelumDialokasikan =>
      bagianTeknisi - teknisi.fold(0, (a, e) => a + e.pendapatan);
}

/// Fee yang berlaku untuk sebuah klaim: baris dengan tanggal berlaku
/// terbesar yang tidak melewati tanggal klaim.
double feeUntuk(List<BrandFee> fees, int brandId, DateTime tanggal) {
  BrandFee? terpilih;
  for (final f in fees) {
    if (f.brandId != brandId) continue;
    if (f.berlakuDari.isAfter(tanggal)) continue;
    if (terpilih == null || f.berlakuDari.isAfter(terpilih.berlakuDari)) {
      terpilih = f;
    }
  }
  return terpilih?.fee ?? 0;
}

/// Membagi [total] menurut [bobot] sehingga jumlah seluruh bagian persis
/// sama dengan total.
///
/// Pembulatan biasa membuat jumlah potongan meleset beberapa rupiah dari
/// keseluruhan, dan selisih semacam itu selalu jadi pertanyaan. Metode sisa
/// terbesar menaruh sisa pembulatan pada bagian yang paling dirugikan.
List<int> bagiRata(int total, List<double> bobot) {
  if (bobot.isEmpty) return const [];

  final jumlahBobot = bobot.fold<double>(0, (a, b) => a + b);
  if (jumlahBobot <= 0) return List.filled(bobot.length, 0);

  final tepat = [for (final b in bobot) total * b / jumlahBobot];
  final hasil = [for (final t in tepat) t.floor()];

  var sisa = total - hasil.fold<int>(0, (a, b) => a + b);
  if (sisa <= 0) return hasil;

  final urutan = List.generate(bobot.length, (i) => i)
    ..sort((a, b) => (tepat[b] - hasil[b]).compareTo(tepat[a] - hasil[a]));

  for (var i = 0; i < sisa && i < urutan.length; i++) {
    hasil[urutan[i]]++;
  }
  return hasil;
}

RevenueResult hitungPendapatan({
  required List<RevenueClaim> claims,
  required List<BrandFee> fees,
  required RevenueSettings settings,
  Map<String, double> porsiManual = const {},
}) {
  // ---- nilai tiap klaim -------------------------------------------------
  var totalNilai = 0.0;
  var tanpaFee = 0;
  var tanpaTeknisi = 0;

  final perBrandUnit = <int, int>{};
  final perBrandNilai = <int, double>{};
  final perTeknisiUnit = <String, int>{};
  final perTeknisiNilai = <String, double>{};

  for (final c in claims) {
    final nilai = feeUntuk(fees, c.brandId, c.tanggal);
    if (nilai == 0) tanpaFee++;

    totalNilai += nilai;
    perBrandUnit[c.brandId] = (perBrandUnit[c.brandId] ?? 0) + 1;
    perBrandNilai[c.brandId] = (perBrandNilai[c.brandId] ?? 0) + nilai;

    final t = c.teknisiId;
    if (t == null) {
      tanpaTeknisi++;
    } else {
      perTeknisiUnit[t] = (perTeknisiUnit[t] ?? 0) + 1;
      perTeknisiNilai[t] = (perTeknisiNilai[t] ?? 0) + nilai;
    }
  }

  // ---- pembagian menurut peran -----------------------------------------
  final total = totalNilai.round();
  final bagian = bagiRata(total, [
    settings.persenToko,
    settings.persenAdmin,
    settings.persenTeknisi,
  ]);

  final jatahTeknisi = bagian[2];

  // ---- pembagian antar teknisi -----------------------------------------
  final ids = perTeknisiNilai.keys.toList()
    ..sort((a, b) => (perTeknisiNilai[b] ?? 0).compareTo(perTeknisiNilai[a] ?? 0));

  final earnings = <TechnicianEarning>[];

  if (ids.isNotEmpty) {
    switch (settings.metode) {
      case MetodeTeknisi.perUnit:
        // Pembaginya adalah SELURUH nilai periode, bukan hanya nilai yang
        // sudah punya teknisi. Kalau memakai jumlah nilai teknisi saja,
        // klaim yang lupa diisi teknisinya akan menaikkan bayaran orang
        // lain -- satu kelalaian pencatatan berubah jadi salah bayar.
        //
        // Nilai yang belum bertuan ikut sebagai keranjang terakhir supaya
        // pembulatannya tetap utuh, lalu dilaporkan sebagai belum
        // dialokasikan.
        final nilaiTanpaTeknisi = (totalNilai -
                perTeknisiNilai.values.fold<double>(0, (a, b) => a + b))
            .clamp(0.0, double.infinity);

        final bobot = <double>[
          for (final id in ids) perTeknisiNilai[id] ?? 0,
          nilaiTanpaTeknisi,
        ];
        final nilaiPerOrang = bagiRata(jatahTeknisi, bobot);

        for (var i = 0; i < ids.length; i++) {
          earnings.add(
            TechnicianEarning(
              teknisiId: ids[i],
              unit: perTeknisiUnit[ids[i]] ?? 0,
              nilai: perTeknisiNilai[ids[i]] ?? 0,
              porsi: totalNilai == 0
                  ? 0
                  : (perTeknisiNilai[ids[i]] ?? 0) * 100 / totalNilai,
              pendapatan: nilaiPerOrang[i],
            ),
          );
        }

      case MetodeTeknisi.rata:
        // Di sini jumlah unit memang tidak diperhitungkan sama sekali, jadi
        // klaim tanpa teknisi tidak mengubah apa pun.
        final nilaiPerOrang =
            bagiRata(jatahTeknisi, [for (final _ in ids) 1.0]);

        for (var i = 0; i < ids.length; i++) {
          earnings.add(
            TechnicianEarning(
              teknisiId: ids[i],
              unit: perTeknisiUnit[ids[i]] ?? 0,
              nilai: perTeknisiNilai[ids[i]] ?? 0,
              porsi: 100 / ids.length,
              pendapatan: nilaiPerOrang[i],
            ),
          );
        }

      case MetodeTeknisi.manual:
        // Sengaja tidak dinormalkan ke 100%: kalau persentasenya baru terisi
        // sebagian, sisanya harus terlihat sebagai belum dialokasikan --
        // bukan diam-diam dibagi rata ke yang sudah terisi.
        for (final id in ids) {
          final persen = porsiManual[id] ?? 0;
          earnings.add(
            TechnicianEarning(
              teknisiId: id,
              unit: perTeknisiUnit[id] ?? 0,
              nilai: perTeknisiNilai[id] ?? 0,
              porsi: persen,
              pendapatan: (jatahTeknisi * persen / 100).round(),
            ),
          );
        }
    }
  }

  earnings.sort((a, b) => b.pendapatan.compareTo(a.pendapatan));

  final brands = [
    for (final e in perBrandUnit.entries)
      BrandRevenue(
        brandId: e.key,
        unit: e.value,
        nilai: perBrandNilai[e.key] ?? 0,
      ),
  ]..sort((a, b) => b.nilai.compareTo(a.nilai));

  return RevenueResult(
    totalUnit: claims.length,
    totalNilai: totalNilai,
    unitTanpaFee: tanpaFee,
    unitTanpaTeknisi: tanpaTeknisi,
    bagianToko: bagian[0],
    bagianAdmin: bagian[1],
    bagianTeknisi: jatahTeknisi,
    teknisi: earnings,
    brands: brands,
  );
}
