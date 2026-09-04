import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/db.dart';
import 'data/models.dart';
import 'data/prefs.dart';
import 'widgets/grid_canvas.dart';

final supabaseProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final databaseProvider = Provider<Db>(
  (ref) => Db(ref.watch(supabaseProvider)),
);

/// Diisi di main() sebelum aplikasi berjalan, supaya layar tidak perlu
/// menunggui pembacaan berkas pengaturan yang isinya sekadar nama printer.
final prefsProvider = Provider<Prefs>(
  (ref) => throw StateError('prefsProvider harus di-override di main()'),
);

/// Apakah saluran Realtime sedang tersambung.
///
/// Menggantikan indikator sinkronisasi yang dulu. Dulu yang perlu diketahui
/// pengguna adalah berapa banyak perubahan masih mengantre di perangkat;
/// sekarang tidak ada antrean sama sekali -- yang perlu diketahui hanyalah
/// apakah yang terlihat di layar masih mengikuti server.
///
/// Keadaannya ditengok berkala, bukan ditunggu dari pemberitahuan pustaka:
/// yang dicari justru saat sambungan putus tanpa sempat memberi kabar.
final koneksiProvider = StreamProvider<bool>((ref) {
  final c = ref.watch(supabaseProvider);
  Stream<bool> pantau() async* {
    yield c.realtime.isConnected;
    yield* Stream.periodic(
      const Duration(seconds: 3),
      (_) => c.realtime.isConnected,
    );
  }

  return pantau().distinct();
});

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
final currentProfileProvider = Provider<Profile?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final semua = ref.watch(allProfilesProvider).valueOrNull;
  if (semua == null) return null;
  for (final p in semua) {
    if (p.id == user.id) return p;
  }
  return null;
});

final isAdminProvider = Provider<bool>(
  (ref) => ref.watch(currentProfileProvider)?.role == 'admin',
);

// ---------------------------------------------------------------------
// Master data
//
// Satu langganan per tabel, lalu diturunkan. Kalau tiap tampilan membuka
// langganannya sendiri, satu tabel bisa terpasang lima kali untuk isi yang
// sama persis.
// ---------------------------------------------------------------------

final allBrandsProvider = StreamProvider<List<Brand>>(
  (ref) => ref.watch(databaseProvider).watchAllBrands(),
);

final allPartTypesProvider = StreamProvider<List<PartType>>(
  (ref) => ref.watch(databaseProvider).watchAllPartTypes(),
);

final allProfilesProvider = StreamProvider<List<Profile>>(
  (ref) => ref.watch(databaseProvider).watchAllProfiles(),
);

/// Hanya yang aktif -- dipakai untuk pilihan saat input klaim.
final brandsProvider = Provider<AsyncValue<List<Brand>>>(
  (ref) => ref
      .watch(allBrandsProvider)
      .whenData((l) => l.where((b) => b.aktif).toList()),
);

final partTypesProvider = Provider<AsyncValue<List<PartType>>>(
  (ref) => ref
      .watch(allPartTypesProvider)
      .whenData((l) => l.where((p) => p.aktif).toList()),
);

/// Siapa saja yang bisa ditunjuk sebagai pengerjanya.
///
/// Disaring menurut aktif, BUKAN menurut role. Admin di toko ini juga
/// memegang obeng, dan nota lama pun sudah tercatat atas namanya. Menyaring
/// role di sini membuat daftarnya kosong, dan dropdown tanpa isi otomatis
/// mati -- di layar terlihat seperti kolom teknisi yang terkunci.
final techniciansProvider = Provider<AsyncValue<List<Profile>>>(
  (ref) => ref
      .watch(allProfilesProvider)
      .whenData((l) => l.where((p) => p.aktif).toList()),
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
  }) => ClaimFilter(
    brandId: clearBrand ? null : (brandId ?? this.brandId),
    status: clearStatus ? null : (status ?? this.status),
    query: query ?? this.query,
  );
}

final claimFilterProvider = StateProvider<ClaimFilter>(
  (ref) => const ClaimFilter(),
);

/// Seluruh klaim, terbaru di atas. Sumber bagi semua tampilan klaim.
final allClaimsProvider = StreamProvider<List<Claim>>(
  (ref) => ref.watch(databaseProvider).watchClaims(),
);

final allPartsProvider = StreamProvider<List<ClaimPart>>(
  (ref) => ref.watch(databaseProvider).watchParts(),
);

final claimsProvider = Provider<AsyncValue<List<Claim>>>((ref) {
  final filter = ref.watch(claimFilterProvider);
  final q = filter.query.toLowerCase().trim();

  return ref.watch(allClaimsProvider).whenData(
        (list) => list.where((c) {
          if (filter.brandId != null && c.brandId != filter.brandId) {
            return false;
          }
          if (filter.status != null && c.status != filter.status) return false;
          if (q.isEmpty) return true;
          return c.namaPelanggan.toLowerCase().contains(q) ||
              c.sn.toLowerCase().contains(q) ||
              (c.noPerbaikan ?? '').toLowerCase().contains(q) ||
              (c.telp ?? '').contains(q);
        }).toList(),
      );
});

/// Jumlah klaim per status. Dipakai stat tile di halaman utama, yang
/// sekaligus berfungsi sebagai filter status.
final statusCountsProvider = Provider<AsyncValue<Map<String, int>>>(
  (ref) => ref.watch(allClaimsProvider).whenData((list) {
    final hasil = <String, int>{};
    for (final c in list) {
      hasil[c.status] = (hasil[c.status] ?? 0) + 1;
    }
    return hasil;
  }),
);

final partsOfClaimProvider =
    Provider.family<AsyncValue<List<ClaimPart>>, String>(
  (ref, claimId) => ref
      .watch(allPartsProvider)
      .whenData((l) => l.where((p) => p.claimId == claimId).toList()),
);

final claimByIdProvider = Provider.family<AsyncValue<Claim?>, String>(
  (ref, id) => ref.watch(allClaimsProvider).whenData((l) {
    for (final c in l) {
      if (c.id == id) return c;
    }
    return null;
  }),
);

// ---------------------------------------------------------------------
// Administrasi servis
// ---------------------------------------------------------------------

final customersProvider = StreamProvider<List<CustomerEntry>>(
  (ref) => ref.watch(databaseProvider).watchCustomers(),
);

/// Identitas toko untuk kepala dan kaki nota.
final storeSettingsProvider = StreamProvider<StoreSetting?>(
  (ref) => ref.watch(databaseProvider).watchStoreSettings(),
);

// ---------------------------------------------------------------------
// Pengaturan yang melekat pada perangkat
// ---------------------------------------------------------------------

/// Susunan grid yang dipilih pengguna, per halaman.
final gridLayoutProvider = StreamProvider.family<GridLayout, String>(
  (ref, key) =>
      ref.watch(prefsProvider).watch('grid.$key').map(decodeLayout),
);

Future<void> simpanGridLayout(WidgetRef ref, String key, GridLayout layout) =>
    ref.read(prefsProvider).tulis('grid.$key', encodeLayout(layout));

final printerNamaProvider = StreamProvider<String>(
  (ref) => ref.watch(prefsProvider).watch('printer.nama').map((v) => v ?? ''),
);

final printerLebarProvider = StreamProvider<int>(
  (ref) => ref
      .watch(prefsProvider)
      .watch('printer.lebar')
      .map((v) => int.tryParse(v ?? '') ?? 32),
);

Future<void> simpanPrinter(WidgetRef ref, String nama, int lebar) async {
  final p = ref.read(prefsProvider);
  await p.tulis('printer.nama', nama);
  await p.tulis('printer.lebar', '$lebar');
}
