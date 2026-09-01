import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/database.dart';
import '../providers.dart';
import 'revenue_calculator.dart';

/// Rentang waktu perhitungan. Kuartal dipakai sebagai bawaan karena begitulah
/// bagi hasil selama ini dihitung.
class Periode {
  const Periode(this.label, this.dari, this.sampai);

  final String label;
  final DateTime dari;
  final DateTime sampai;

  static List<Periode> daftar({int tahunKeBelakang = 2}) {
    final now = DateTime.now();
    final out = <Periode>[];

    for (var y = now.year; y >= now.year - tahunKeBelakang; y--) {
      for (var q = 4; q >= 1; q--) {
        final mulai = DateTime(y, (q - 1) * 3 + 1, 1);
        if (mulai.isAfter(now)) continue;
        // Akhir kuartal = detik terakhir sebelum kuartal berikutnya, supaya
        // klaim yang dicatat sore hari di hari terakhir tetap ikut terhitung.
        final akhir = DateTime(y, q * 3 + 1, 1)
            .subtract(const Duration(milliseconds: 1));
        out.add(Periode('Q$q $y', mulai, akhir));
      }
    }
    return out;
  }
}

final periodeProvider = StateProvider<Periode>((ref) => Periode.daftar().first);

final _closedClaimsProvider = StreamProvider.autoDispose<List<Claim>>((ref) {
  final p = ref.watch(periodeProvider);
  return ref.watch(databaseProvider).watchClosedClaims(p.dari, p.sampai);
});

final _feesProvider = StreamProvider.autoDispose<List<BrandFeeEntry>>(
  (ref) => ref.watch(databaseProvider).watchBrandFees(),
);

final revenueConfigProvider = StreamProvider.autoDispose<RevenueConfig?>(
  (ref) => ref.watch(databaseProvider).watchRevenueConfig(),
);

final _sharesProvider = StreamProvider.autoDispose<List<TechnicianShareEntry>>(
  (ref) => ref.watch(databaseProvider).watchTechnicianShares(),
);

/// Hasil perhitungan bagi hasil untuk periode terpilih.
///
/// Seluruhnya dari data di perangkat, jadi angka ini tetap muncul saat
/// offline -- sama seperti bagian aplikasi lainnya. Server hanya menjadi
/// tempat data itu berasal, bukan syarat untuk melihatnya.
final revenueResultProvider = Provider.autoDispose<RevenueResult?>((ref) {
  final claims = ref.watch(_closedClaimsProvider).valueOrNull;
  final fees = ref.watch(_feesProvider).valueOrNull;
  final config = ref.watch(revenueConfigProvider).valueOrNull;
  final shares = ref.watch(_sharesProvider).valueOrNull ?? const [];

  if (claims == null || fees == null) return null;

  // Aturan bawaan dipakai bila belum pernah tersinkron, supaya layarnya
  // tetap bisa dibaca alih-alih kosong tanpa penjelasan.
  final settings = config == null
      ? const RevenueSettings()
      : RevenueSettings(
          persenToko: config.persenToko,
          persenAdmin: config.persenAdmin,
          persenTeknisi: config.persenTeknisi,
          metode: MetodeTeknisi.dari(config.metodeTeknisi),
        );

  return hitungPendapatan(
    claims: [
      for (final c in claims)
        RevenueClaim(
          brandId: c.brandId,
          tanggal: c.tanggal,
          teknisiId: c.teknisiId,
        ),
    ],
    fees: [
      for (final f in fees)
        BrandFee(brandId: f.brandId, fee: f.fee, berlakuDari: f.berlakuDari),
    ],
    settings: settings,
    porsiManual: {for (final s in shares) s.profileId: s.persen},
  );
});

final technicianSharesMapProvider = Provider.autoDispose<Map<String, double>>(
  (ref) => {
    for (final s in ref.watch(_sharesProvider).valueOrNull ?? const [])
      s.profileId: s.persen,
  },
);

/// Fee yang berlaku saat ini untuk tiap brand, untuk halaman pengaturan.
final currentFeesProvider = Provider.autoDispose<Map<int, BrandFeeEntry>>((ref) {
  final fees = ref.watch(_feesProvider).valueOrNull ?? const [];
  final out = <int, BrandFeeEntry>{};
  for (final f in fees) {
    final ada = out[f.brandId];
    if (ada == null || f.berlakuDari.isAfter(ada.berlakuDari)) {
      out[f.brandId] = f;
    }
  }
  return out;
});
