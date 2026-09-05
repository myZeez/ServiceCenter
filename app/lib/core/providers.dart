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

/// Untuk MEMBACA nama pengerja, bukan untuk memilihnya.
///
/// Sengaja tidak disaring menurut role. Nota dan klaim lama tercatat atas
/// nama siapa pun yang mengerjakannya saat itu, admin termasuk, dan daftar
/// yang membuang mereka membuat nama itu berubah jadi tanda hubung di
/// laporan yang sudah terlanjur dibaca orang.
///
/// Untuk dropdown pemilihan, pakai [pengerjaUntukProvider].
final techniciansProvider = Provider<AsyncValue<List<Profile>>>(
  (ref) => ref
      .watch(allProfilesProvider)
      .whenData((l) => l.where((p) => p.aktif).toList()),
);

/// Siapa saja yang boleh ditunjuk mengerjakan sebuah unit.
///
/// Admin tidak termasuk: yang memegang obeng adalah teknisi, dan bagi hasil
/// dihitung atas nama merekalah. Daftar ini bisa kosong kalau belum ada
/// teknisi terdaftar -- layar yang memakainya menjelaskan keadaan itu alih-
/// alih menampilkan dropdown yang tampak terkunci.
final pengerjaProvider = Provider<List<Profile>>(
  (ref) => [
    for (final p
        in ref.watch(allProfilesProvider).valueOrNull ?? const <Profile>[])
      if (p.aktif && p.role != 'admin') p,
  ],
);

/// Pilihan pengerja untuk satu unit, beserta orang yang sudah tercatat
/// mengerjakannya.
///
/// Yang sudah tercatat selalu ikut walau ia admin atau sudah dinonaktifkan.
/// Dua sebabnya sama-sama keras: dropdown yang nilainya tidak ada di antara
/// pilihannya melempar galat, dan nama yang menghilang dari kolomnya
/// terbaca seperti pekerjaannya ikut terhapus.
final pengerjaUntukProvider = Provider.family<List<Profile>, String?>((
  ref,
  terpilih,
) {
  final daftar = ref.watch(pengerjaProvider);
  if (terpilih == null || daftar.any((p) => p.id == terpilih)) return daftar;

  for (final p
      in ref.watch(allProfilesProvider).valueOrNull ?? const <Profile>[]) {
    if (p.id == terpilih) return [...daftar, p];
  }
  return daftar;
});

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

/// Nota servis yang menaungi sebuah klaim, kalau memang ada.
///
/// Status keduanya disinkronkan di server ke dua arah, jadi layar klaim
/// perlu bisa menyebutkan nota mana yang ikut berubah. Perubahan yang
/// diam-diam merembet ke tempat lain adalah perubahan yang tidak bisa
/// dijelaskan kepada yang menemukannya.
final notaOfClaimProvider = Provider.family<ServiceOrderEntry?, String>((
  ref,
  claimId,
) {
  for (final n
      in ref.watch(serviceOrdersProvider).valueOrNull ??
          const <ServiceOrderEntry>[]) {
    if (n.claimId == claimId) return n;
  }
  return null;
});

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

final serviceOrdersProvider = StreamProvider<List<ServiceOrderEntry>>(
  (ref) => ref.watch(databaseProvider).watchServiceOrders(),
);

final customersProvider = StreamProvider<List<CustomerEntry>>(
  (ref) => ref.watch(databaseProvider).watchCustomers(),
);

/// Memasang ulang seluruh langganan data.
///
/// Dipanggil saat aplikasi kembali dibuka. Di Android, sistem memutus
/// websocket begitu aplikasinya ditidurkan, dan langganan yang terputus
/// begitu tidak melempar galat apa pun -- alirannya hanya berhenti
/// mengirim. Tanpa pemasangan ulang, yang terlihat saat aplikasi dibuka
/// lagi adalah keadaan terakhir sebelum HP dikunci, tanpa satu pun tanda
/// bahwa itu sudah basi.
void segarkanData(WidgetRef ref) {
  ref.invalidate(allClaimsProvider);
  ref.invalidate(allPartsProvider);
  ref.invalidate(allProfilesProvider);
  ref.invalidate(allBrandsProvider);
  ref.invalidate(allPartTypesProvider);
  ref.invalidate(serviceOrdersProvider);
  ref.invalidate(customersProvider);
  ref.invalidate(storeSettingsProvider);
}

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
