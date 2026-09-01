import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'local/database.dart';
import 'sync/sync_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final supabaseProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final syncServiceProvider = Provider<SyncService>((ref) {
  final svc = SyncService(ref.watch(databaseProvider), ref.watch(supabaseProvider));
  ref.onDispose(svc.dispose);
  return svc;
});

final syncStatusProvider = StreamProvider<SyncStatus>(
  (ref) => ref.watch(syncServiceProvider).status,
);

/// Berapa perubahan lokal yang belum terkirim. Ditampilkan di app bar supaya
/// teknisi tahu pekerjaannya sudah sampai server atau belum.
final pendingCountProvider = StreamProvider<int>(
  (ref) => ref.watch(databaseProvider).watchPendingCount(),
);

// ---------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------

final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(supabaseProvider).auth.onAuthStateChange,
);

final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(supabaseProvider).auth.currentUser;
});

/// Profil (nama + role) dari user yang sedang login.
///
/// Sengaja stream: saat login pertama, profilnya baru sampai di perangkat
/// setelah sinkronisasi berjalan. Kalau dibaca sekali saja, hak akses admin
/// tidak pernah muncul sampai aplikasi dijalankan ulang.
final currentProfileProvider = StreamProvider<Profile?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);
  return ref.watch(databaseProvider).watchProfileById(user.id);
});

final isAdminProvider = Provider<bool>((ref) {
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  return profile?.role == 'admin';
});

// ---------------------------------------------------------------------
// Master data
// ---------------------------------------------------------------------

/// Hanya yang aktif -- dipakai untuk pilihan saat input klaim.
final brandsProvider = StreamProvider<List<Brand>>(
  (ref) => ref.watch(databaseProvider).watchBrands(),
);

final partTypesProvider = StreamProvider<List<PartType>>(
  (ref) => ref.watch(databaseProvider).watchPartTypes(),
);

/// Termasuk yang nonaktif. Dipakai saat menerjemahkan brand_id dan
/// part_type_id pada klaim lama menjadi nama -- tanpa ini, menonaktifkan
/// sebuah brand membuat riwayat klaimnya tampil tanpa nama.
final allBrandsProvider = StreamProvider<List<Brand>>(
  (ref) => ref.watch(databaseProvider).watchAllBrands(),
);

final allPartTypesProvider = StreamProvider<List<PartType>>(
  (ref) => ref.watch(databaseProvider).watchAllPartTypes(),
);

final techniciansProvider = StreamProvider<List<Profile>>(
  (ref) => ref.watch(databaseProvider).watchTechnicians(),
);

/// Semua pengguna termasuk yang nonaktif. Khusus halaman kelola pengguna.
final allProfilesProvider = StreamProvider<List<Profile>>(
  (ref) => ref.watch(databaseProvider).watchAllProfiles(),
);

// ---------------------------------------------------------------------
// Klaim
// ---------------------------------------------------------------------

/// Filter aktif di halaman daftar klaim.
class ClaimFilter {
  const ClaimFilter({this.brandId, this.status, this.query = ''});

  final int? brandId;
  final String? status;
  final String query;

  ClaimFilter copyWith({
    int? brandId,
    String? status,
    String? query,
    bool clearBrand = false,
    bool clearStatus = false,
  }) =>
      ClaimFilter(
        brandId: clearBrand ? null : (brandId ?? this.brandId),
        status: clearStatus ? null : (status ?? this.status),
        query: query ?? this.query,
      );
}

final claimFilterProvider =
    StateProvider<ClaimFilter>((ref) => const ClaimFilter());

final claimsProvider = StreamProvider<List<Claim>>((ref) {
  final filter = ref.watch(claimFilterProvider);
  final stream = ref
      .watch(databaseProvider)
      .watchClaims(brandId: filter.brandId, status: filter.status);

  if (filter.query.trim().isEmpty) return stream;

  // Pencarian dilakukan di memori, bukan di server, supaya tetap jalan
  // waktu offline.
  final q = filter.query.toLowerCase().trim();
  return stream.map(
    (list) => list
        .where((c) =>
            c.namaPelanggan.toLowerCase().contains(q) ||
            c.sn.toLowerCase().contains(q) ||
            (c.noPerbaikan ?? '').toLowerCase().contains(q) ||
            (c.telp ?? '').contains(q))
        .toList(),
  );
});

/// Jumlah klaim per status. Dipakai stat tile di halaman utama, yang
/// sekaligus berfungsi sebagai filter status.
final statusCountsProvider = StreamProvider<Map<String, int>>(
  (ref) => ref.watch(databaseProvider).watchStatusCounts(),
);

final partsOfClaimProvider =
    StreamProvider.family<List<ClaimPart>, String>((ref, claimId) {
  return ref.watch(databaseProvider).watchPartsOf(claimId);
});

final claimByIdProvider = StreamProvider.family<Claim?, String>((ref, id) {
  return ref.watch(databaseProvider).watchClaim(id);
});
