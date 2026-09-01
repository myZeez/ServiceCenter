/// Perhitungan bagi hasil.
///
/// Sengaja fungsi murni tanpa ketergantungan ke database maupun Flutter:
/// rumus yang menentukan bayaran orang harus bisa diuji, dan hasilnya harus
/// sama persis di perangkat mana pun.
///
/// Seluruh perhitungan dilakukan PER BRAND lalu dijumlahkan. Tiap brand
/// membayar fee berbeda dan bisa punya susunan tim berbeda, jadi bagian
/// toko, admin, dan teknisi dihitung dari nilai brand masing-masing --
/// bukan dari satu angka gabungan.
library;

enum MetodeTeknisi {
  /// Porsi mengikuti nilai rupiah yang dihasilkan tiap teknisi di brand itu.
  perUnit('per_unit'),

  /// Jatah teknisi dibagi sama besar antar yang bekerja di brand itu.
  rata('rata'),

  /// Persentase tetap per teknisi, ditentukan per brand.
  manual('manual');

  const MetodeTeknisi(this.kode);
  final String kode;

  static MetodeTeknisi dari(String kode) => MetodeTeknisi.values.firstWhere(
        (e) => e.kode == kode,
        orElse: () => MetodeTeknisi.perUnit,
      );
}

/// Pembagian antara toko, admin, dan teknisi.
class AturanBagi {
  const AturanBagi({
    this.persenToko = 30,
    this.persenAdmin = 10,
    this.persenTeknisi = 60,
  });

  final double persenToko;
  final double persenAdmin;
  final double persenTeknisi;
}

class RevenueSettings {
  const RevenueSettings({
    this.umum = const AturanBagi(),
    this.metode = MetodeTeknisi.perUnit,
    this.aturanBrand = const {},
  });

  /// Dipakai untuk brand yang tidak punya aturan sendiri.
  final AturanBagi umum;

  final MetodeTeknisi metode;

  /// Aturan khusus per brand. Brand yang tidak ada di sini memakai [umum].
  final Map<int, AturanBagi> aturanBrand;

  AturanBagi untukBrand(int brandId) => aturanBrand[brandId] ?? umum;
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

  /// Unit yang tercatat atas namanya. Pada mode manual bisa nol sementara
  /// pendapatannya tidak -- misalnya untuk pekerjaan pendukung seperti
  /// input klaim dan permintaan part.
  final int unit;
  final double nilai;

  /// Porsi dalam persen dari jatah teknisi. Ditampilkan apa adanya di
  /// laporan supaya dasar hitungannya bisa dilihat, bukan hanya rupiahnya.
  final double porsi;
  final int pendapatan;
}

/// Perhitungan lengkap untuk satu brand.
class BrandBreakdown {
  const BrandBreakdown({
    required this.brandId,
    required this.unit,
    required this.nilai,
    required this.bagianToko,
    required this.bagianAdmin,
    required this.bagianTeknisi,
    required this.teknisi,
  });

  final int brandId;
  final int unit;
  final double nilai;
  final int bagianToko;
  final int bagianAdmin;
  final int bagianTeknisi;
  final List<TechnicianEarning> teknisi;

  double get feeRataRata => unit == 0 ? 0 : nilai / unit;

  int get belumDialokasikan =>
      bagianTeknisi - teknisi.fold(0, (a, e) => a + e.pendapatan);
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

  /// Klaim selesai yang kolom teknisinya kosong.
  final int unitTanpaTeknisi;

  final int bagianToko;
  final int bagianAdmin;
  final int bagianTeknisi;

  /// Gabungan seluruh brand, per teknisi.
  final List<TechnicianEarning> teknisi;

  final List<BrandBreakdown> brands;

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

  final sisa = total - hasil.fold<int>(0, (a, b) => a + b);
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

  /// brandId -> (teknisiId -> persen). Hanya dipakai pada mode manual.
  Map<int, Map<String, double>> porsiManual = const {},
}) {
  // ---- kelompokkan per brand -------------------------------------------
  final unitPerBrand = <int, int>{};
  final nilaiPerBrand = <int, double>{};
  final unitTeknisiPerBrand = <int, Map<String, int>>{};
  final nilaiTeknisiPerBrand = <int, Map<String, double>>{};

  var totalNilai = 0.0;
  var tanpaFee = 0;
  var tanpaTeknisi = 0;

  for (final c in claims) {
    final nilai = feeUntuk(fees, c.brandId, c.tanggal);
    if (nilai == 0) tanpaFee++;
    totalNilai += nilai;

    unitPerBrand[c.brandId] = (unitPerBrand[c.brandId] ?? 0) + 1;
    nilaiPerBrand[c.brandId] = (nilaiPerBrand[c.brandId] ?? 0) + nilai;

    final t = c.teknisiId;
    if (t == null) {
      tanpaTeknisi++;
      continue;
    }
    (unitTeknisiPerBrand[c.brandId] ??= {}).update(
      t,
      (v) => v + 1,
      ifAbsent: () => 1,
    );
    (nilaiTeknisiPerBrand[c.brandId] ??= {}).update(
      t,
      (v) => v + nilai,
      ifAbsent: () => nilai,
    );
  }

  // Brand yang punya aturan manual tetap dihitung walau tanpa klaim, agar
  // pengaturannya terlihat berpengaruh atau tidak.
  final brandIds = {...unitPerBrand.keys}.toList()
    ..sort((a, b) => (nilaiPerBrand[b] ?? 0).compareTo(nilaiPerBrand[a] ?? 0));

  // ---- hitung tiap brand -----------------------------------------------
  final breakdowns = <BrandBreakdown>[];

  for (final brandId in brandIds) {
    final nilaiBrand = nilaiPerBrand[brandId] ?? 0;
    final aturan = settings.untukBrand(brandId);

    final bagian = bagiRata(nilaiBrand.round(), [
      aturan.persenToko,
      aturan.persenAdmin,
      aturan.persenTeknisi,
    ]);
    final jatah = bagian[2];

    final unitTek = unitTeknisiPerBrand[brandId] ?? const <String, int>{};
    final nilaiTek = nilaiTeknisiPerBrand[brandId] ?? const <String, double>{};

    final earnings = <TechnicianEarning>[];

    switch (settings.metode) {
      case MetodeTeknisi.perUnit:
        // Pembaginya seluruh nilai brand, bukan hanya yang sudah punya
        // teknisi. Kalau memakai jumlah nilai teknisi saja, klaim yang lupa
        // diisi teknisinya akan menaikkan bayaran orang lain -- satu
        // kelalaian pencatatan berubah jadi salah bayar.
        final ids = nilaiTek.keys.toList()
          ..sort((a, b) => nilaiTek[b]!.compareTo(nilaiTek[a]!));

        if (ids.isNotEmpty) {
          final belumBertuan = (nilaiBrand -
                  nilaiTek.values.fold<double>(0, (a, b) => a + b))
              .clamp(0.0, double.infinity);

          final nilaiOrang = bagiRata(jatah, [
            for (final id in ids) nilaiTek[id]!,
            belumBertuan,
          ]);

          for (var i = 0; i < ids.length; i++) {
            earnings.add(
              TechnicianEarning(
                teknisiId: ids[i],
                unit: unitTek[ids[i]] ?? 0,
                nilai: nilaiTek[ids[i]]!,
                porsi: nilaiBrand == 0 ? 0 : nilaiTek[ids[i]]! * 100 / nilaiBrand,
                pendapatan: nilaiOrang[i],
              ),
            );
          }
        }

      case MetodeTeknisi.rata:
        final ids = nilaiTek.keys.toList()..sort();
        if (ids.isNotEmpty) {
          final nilaiOrang = bagiRata(jatah, [for (final _ in ids) 1.0]);
          for (var i = 0; i < ids.length; i++) {
            earnings.add(
              TechnicianEarning(
                teknisiId: ids[i],
                unit: unitTek[ids[i]] ?? 0,
                nilai: nilaiTek[ids[i]]!,
                porsi: 100 / ids.length,
                pendapatan: nilaiOrang[i],
              ),
            );
          }
        }

      case MetodeTeknisi.manual:
        // Yang dibayar adalah siapa pun yang punya persentase di brand ini,
        // termasuk yang tidak mengerjakan satu unit pun -- itulah cara
        // pekerjaan pendukung seperti input klaim dan permintaan part
        // mendapat bagian.
        //
        // Persentase sengaja tidak dinormalkan ke 100%: kalau baru terisi
        // sebagian, sisanya harus terlihat sebagai belum dialokasikan.
        final porsi = porsiManual[brandId] ?? const <String, double>{};
        final ids = porsi.keys.toList()
          ..sort((a, b) => porsi[b]!.compareTo(porsi[a]!));

        for (final id in ids) {
          if (porsi[id] == 0) continue;
          earnings.add(
            TechnicianEarning(
              teknisiId: id,
              unit: unitTek[id] ?? 0,
              nilai: nilaiTek[id] ?? 0,
              porsi: porsi[id]!,
              pendapatan: (jatah * porsi[id]! / 100).round(),
            ),
          );
        }
    }

    breakdowns.add(
      BrandBreakdown(
        brandId: brandId,
        unit: unitPerBrand[brandId] ?? 0,
        nilai: nilaiBrand,
        bagianToko: bagian[0],
        bagianAdmin: bagian[1],
        bagianTeknisi: jatah,
        teknisi: earnings,
      ),
    );
  }

  // ---- gabungkan lintas brand ------------------------------------------
  var toko = 0;
  var admin = 0;
  var teknisiPool = 0;

  final unitGabungan = <String, int>{};
  final nilaiGabungan = <String, double>{};
  final rupiahGabungan = <String, int>{};

  for (final b in breakdowns) {
    toko += b.bagianToko;
    admin += b.bagianAdmin;
    teknisiPool += b.bagianTeknisi;

    for (final e in b.teknisi) {
      unitGabungan.update(e.teknisiId, (v) => v + e.unit, ifAbsent: () => e.unit);
      nilaiGabungan.update(
        e.teknisiId,
        (v) => v + e.nilai,
        ifAbsent: () => e.nilai,
      );
      rupiahGabungan.update(
        e.teknisiId,
        (v) => v + e.pendapatan,
        ifAbsent: () => e.pendapatan,
      );
    }
  }

  final gabungan = [
    for (final id in rupiahGabungan.keys)
      TechnicianEarning(
        teknisiId: id,
        unit: unitGabungan[id] ?? 0,
        nilai: nilaiGabungan[id] ?? 0,
        // Porsi gabungan adalah bagian dari seluruh jatah teknisi, karena
        // porsi tiap brand tidak bisa dijumlahkan begitu saja.
        porsi: teknisiPool == 0 ? 0 : rupiahGabungan[id]! * 100 / teknisiPool,
        pendapatan: rupiahGabungan[id]!,
      ),
  ]..sort((a, b) => b.pendapatan.compareTo(a.pendapatan));

  return RevenueResult(
    totalUnit: claims.length,
    totalNilai: totalNilai,
    unitTanpaFee: tanpaFee,
    unitTanpaTeknisi: tanpaTeknisi,
    bagianToko: toko,
    bagianAdmin: admin,
    bagianTeknisi: teknisiPool,
    teknisi: gabungan,
    brands: breakdowns,
  );
}
