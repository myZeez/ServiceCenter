import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/parts/part_status.dart';
import 'data/db.dart';
import 'data/models.dart';
import 'data/prefs.dart';
import 'hari_laporan.dart';
import 'status.dart';
import 'widgets/grid_canvas.dart';

final supabaseProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final databaseProvider = Provider<Db>((ref) => Db(ref.watch(supabaseProvider)));

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

// ---------------------------------------------------------------------
// Cara bayar
// ---------------------------------------------------------------------

final allMetodeBayarProvider = StreamProvider<List<MetodeBayar>>(
  (ref) => ref.watch(databaseProvider).watchMetodeBayar(),
);

/// Pilihan yang ditawarkan saat mencatat pembayaran.
///
/// Yang dinonaktifkan tidak ikut. Untuk MEMBACA cara bayar nota lama,
/// pakai [namaMetodeBayar] -- rekening yang sudah ditutup tetap harus
/// bisa disebut namanya di nota yang terlanjur memakainya.
final metodeBayarProvider = Provider<List<MetodeBayar>>(
  (ref) => [
    for (final m
        in ref.watch(allMetodeBayarProvider).valueOrNull ??
            const <MetodeBayar>[])
      if (m.aktif) m,
  ],
);

/// Nama yang enak dibaca untuk sebuah kode cara bayar.
///
/// Kode yang tidak ada di daftar dikembalikan apa adanya, bukan diganti
/// tanda hubung: nota lama menyimpan kodenya sendiri, dan menyembunyikan
/// yang tidak dikenali membuat nota itu tampak tidak punya cara bayar.
final namaMetodeBayar = Provider.family<String, String?>((ref, kode) {
  if (kode == null) return '';
  for (final m
      in ref.watch(allMetodeBayarProvider).valueOrNull ??
          const <MetodeBayar>[]) {
    if (m.kode == kode) return m.nama;
  }
  return kode.replaceAll('_', ' ').toUpperCase();
});

/// Apakah cara bayar ini berarti uangnya belum diterima.
///
/// Yang tidak dikenal dianggap LUNAS, sama seperti trigger di server.
/// Itu sisi yang lebih aman untuk salah: piutang palsu akan menagih
/// pelanggan yang sudah membayar.
final metodePiutang = Provider.family<bool, String?>((ref, kode) {
  if (kode == null) return false;
  for (final m
      in ref.watch(allMetodeBayarProvider).valueOrNull ??
          const <MetodeBayar>[]) {
    if (m.kode == kode) return m.piutang;
  }
  return false;
});

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
/// Admin ikut. Sempat dikeluarkan dengan alasan yang terdengar rapi --
/// yang memegang obeng adalah teknisi -- tetapi arsipnya membantah:
/// "Admin" tercatat sebagai pengerja pada 462 nota sepanjang 2026, dan
/// pada hari yang sepi memang orang di meja depan yang mengerjakannya
/// sendiri. Mengeluarkannya berarti pekerjaan itu tidak bisa dicatat atas
/// nama siapa pun.
///
/// Daftar ini bisa kosong kalau belum ada pengguna aktif -- layar yang
/// memakainya menjelaskan keadaan itu alih-alih menampilkan dropdown yang
/// tampak terkunci.
final pengerjaProvider = Provider<List<Profile>>(
  (ref) => [
    for (final p
        in ref.watch(allProfilesProvider).valueOrNull ?? const <Profile>[])
      if (p.aktif) p,
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

  return ref
      .watch(allClaimsProvider)
      .whenData(
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

/// claimId -> klaim. Satu peta untuk seluruh daftar nota, bukan satu
/// pencarian per baris: daftar Semua Nota memuat ribuan baris.
final klaimPerIdProvider = Provider<Map<String, Claim>>(
  (ref) => {
    for (final c in ref.watch(allClaimsProvider).valueOrNull ?? const <Claim>[])
      c.id: c,
  },
);

/// Klaim garansi BRAND yang menaungi sebuah nota, kalau ada.
///
/// Nota seperti ini tidak lagi memakai status nota biasa: statusnya adalah
/// status klaimnya -- Wait Approval Warranty, Ship ASUS Pusat, dan
/// seterusnya. Garansi toko tidak termasuk; ia tidak berurusan dengan
/// brand mana pun, dan status nota biasa sudah cukup menceritakannya.
final klaimBrandNotaProvider = Provider.family<Claim?, String?>((
  ref,
  claimId,
) {
  if (claimId == null) return null;
  final c = ref.watch(klaimPerIdProvider)[claimId];
  return c != null && ClaimJenis.ditagihkan(c.jenis) ? c : null;
});

/// brandId -> nama brand.
final namaBrandProvider = Provider<Map<int, String>>(
  (ref) => {
    for (final b in ref.watch(allBrandsProvider).valueOrNull ?? const <Brand>[])
      b.id: b.nama,
  },
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

// ---------------------------------------------------------------------
// Tanya harga dan pemesanan part
// ---------------------------------------------------------------------

final partOrdersProvider = StreamProvider<List<PartOrder>>(
  (ref) => ref.watch(databaseProvider).watchPartOrders(),
);

/// Modal tiap pesanan, dipetakan menurut id pesanannya.
///
/// Kosong bagi teknisi -- aturan akses di server yang menyaringnya, dan
/// layar memperlakukan ketiadaan itu sebagai "tidak berhak melihat".
final partCostsProvider = StreamProvider<List<PartCost>>(
  (ref) => ref.watch(databaseProvider).watchPartCosts(),
);

final partCostProvider = Provider.family<PartCost?, String>((ref, id) {
  for (final c
      in ref.watch(partCostsProvider).valueOrNull ?? const <PartCost>[]) {
    if (c.partOrderId == id) return c;
  }
  return null;
});

final partSettingsProvider = StreamProvider<PartSettingsRow?>(
  (ref) => ref.watch(databaseProvider).watchPartSettings(),
);

/// Asal part yang pernah dipakai, untuk pelengkapan otomatis.
///
/// Dibaca dari isi tabelnya sendiri, bukan dari daftar tetap. Di arsip
/// lama nilainya tumbuh sepanjang tahun -- AXIOO ID, MSI ID, Canon ID,
/// sampai nama toko tempat membeli lepasan -- dan daftar yang harus
/// diurus manual pasti tertinggal dari kenyataan. Yang sering dipakai
/// jadi bibit awalnya supaya kolomnya tidak kosong di hari pertama.
final asalPartProvider = Provider<List<String>>((ref) {
  final pakai = <String>{...asalPartUmum};
  for (final p in ref.watch(partOrdersProvider).valueOrNull ?? const []) {
    final k = p.keterangan?.trim().toUpperCase();
    if (k != null && k.isNotEmpty) pakai.add(k);
  }
  return pakai.toList()..sort();
});

/// Tanya harga yang lahir dari sebuah nota servis, kalau memang ada.
///
/// Dipakai formulir nota untuk memutuskan menawarkan "buat tanya harga"
/// atau "lihat tanya harga". Tanpa ini, tombolnya akan membuat baris baru
/// tiap kali ditekan, dan satu unit berakhir punya tiga tanya harga yang
/// isinya sama.
final tanyaHargaNotaProvider = Provider.family<PartOrder?, String>((
  ref,
  notaId,
) {
  for (final p
      in ref.watch(partOrdersProvider).valueOrNull ?? const <PartOrder>[]) {
    if (p.serviceOrderId == notaId) return p;
  }
  return null;
});

/// Pilihan persentase yang ditawarkan saat menetapkan harga.
///
/// Jatuh ke 10/15/20 bila pengaturannya belum terbaca. Dropdown tanpa satu
/// pun pilihan tampak seperti kolom yang rusak, dan itu keadaan yang
/// paling mungkin terjadi justru di detik-detik pertama aplikasi dibuka.
final upTokoPilihanProvider = Provider<List<double>>((ref) {
  final s = ref.watch(partSettingsProvider).valueOrNull;
  final pilihan = s?.upTokoPilihan ?? const <double>[];
  return pilihan.isEmpty ? const [10, 15, 20] : pilihan;
});

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
  ref.invalidate(partOrdersProvider);
  ref.invalidate(partCostsProvider);
  ref.invalidate(partSettingsProvider);
  ref.invalidate(allMetodeBayarProvider);
}

/// Identitas toko untuk kepala dan kaki nota.
final storeSettingsProvider = StreamProvider<StoreSetting?>(
  (ref) => ref.watch(databaseProvider).watchStoreSettings(),
);

/// Jam laporan harian ditutup, dari pengaturan toko.
///
/// Ditaruh di Pengaturan dan bukan di kode karena yang mengubahnya adalah
/// orang yang sedang berdiri di toko. Jam tutup bisa bergeser -- bulan
/// puasa, hari libur, atau sekadar keputusan baru -- dan menunggu aplikasi
/// dibangun ulang untuk itu berarti angka laporannya salah setiap hari
/// selama menunggu.
final jamTutupProvider = Provider<int>(
  (ref) =>
      ref.watch(storeSettingsProvider).valueOrNull?.tutupJam ?? jamTutupBawaan,
);

/// Hari toko tutup, dari pengaturan toko. Nomor hari ISO: 1 Senin sampai
/// 7 Minggu.
///
/// Laporan harian menandai hari ini libur alih-alih menampilkan dua tabel
/// kosong yang terbaca seperti laporan yang belum diisi, dan ekspor
/// bulanan tidak menerbitkan tabnya sama sekali -- persis seperti berkas
/// SVS yang dipakai toko, yang memang tidak punya lembar Sabtu.
final hariLiburProvider = Provider<Set<int>>(
  (ref) =>
      ref.watch(storeSettingsProvider).valueOrNull?.hariLibur ??
      hariLiburBawaan,
);

/// Cabang tujuan pengiriman unit, dari pengaturan toko.
///
/// Di Pengaturan dan bukan di kode: cabang bisa bertambah, dan yang
/// menambahkannya orang yang berdiri di toko.
final cabangProvider = Provider<List<String>>(
  (ref) => ref.watch(storeSettingsProvider).valueOrNull?.cabang ?? cabangBawaan,
);

// ---------------------------------------------------------------------
// Pengaturan yang melekat pada perangkat
// ---------------------------------------------------------------------

/// Susunan grid yang dipilih pengguna, per halaman.
final gridLayoutProvider = StreamProvider.family<GridLayout, String>(
  (ref, key) => ref.watch(prefsProvider).watch('grid.$key').map(decodeLayout),
);

Future<void> simpanGridLayout(WidgetRef ref, String key, GridLayout layout) =>
    ref.read(prefsProvider).tulis('grid.$key', encodeLayout(layout));

/// Terang, gelap, atau ikut sistem.
///
/// Melekat pada perangkat, bukan pada akun. Komputer meja depan berdiri di
/// ruangan berlampu sepanjang hari sementara HP teknisi ikut dibawa ke
/// ruang belakang yang remang; memaksa keduanya sama tidak menolong
/// siapa pun. Bawaannya ikut sistem, jadi Windows dan Android yang sudah
/// disetel gelap langsung gelap tanpa disuruh.
final modeTemaProvider = StreamProvider<ThemeMode>(
  (ref) => ref.watch(prefsProvider).watch('tema.mode').map(bacaModeTema),
);

ThemeMode bacaModeTema(String? nilai) => switch (nilai) {
  'terang' => ThemeMode.light,
  'gelap' => ThemeMode.dark,
  _ => ThemeMode.system,
};

String tulisModeTema(ThemeMode mode) => switch (mode) {
  ThemeMode.light => 'terang',
  ThemeMode.dark => 'gelap',
  ThemeMode.system => 'sistem',
};

Future<void> simpanModeTema(WidgetRef ref, ThemeMode mode) =>
    ref.read(prefsProvider).tulis('tema.mode', tulisModeTema(mode));

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
