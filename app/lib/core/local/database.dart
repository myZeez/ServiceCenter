import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

// Cerminan lokal dari tabel Postgres di Supabase.
//
// Aplikasi SELALU membaca dan menulis ke sini, tidak pernah langsung ke
// Supabase. Itulah yang bikin app tetap jalan waktu sinyal hilang. Baris yang
// belum terkirim ditandai syncPending, lalu SyncService yang mengantarnya.

class Brands extends Table {
  IntColumn get id => integer()();
  TextColumn get nama => text()();
  BoolColumn get aktif => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class PartTypes extends Table {
  IntColumn get id => integer()();
  TextColumn get kode => text()();
  TextColumn get nama => text()();
  BoolColumn get aktif => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get nama => text()();
  TextColumn get role => text()();
  BoolColumn get aktif => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class Claims extends Table {
  // UUID dibuat di sisi aplikasi, bukan oleh server. Ini syarat supaya klaim
  // bisa dibuat saat offline tanpa menunggu server memberi nomor.
  TextColumn get id => text()();

  DateTimeColumn get tanggal => dateTime()();
  IntColumn get brandId => integer()();
  TextColumn get namaPelanggan => text()();
  TextColumn get telp => text().nullable()();
  TextColumn get sn => text()();
  TextColumn get teknisiId => text().nullable()();
  TextColumn get keluhan => text().nullable()();
  TextColumn get noPerbaikan => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('open'))();
  TextColumn get catatan => text().nullable()();
  TextColumn get createdBy => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// true = ada perubahan lokal yang belum sampai ke Supabase.
  BoolColumn get syncPending => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class ClaimParts extends Table {
  TextColumn get id => text()();
  TextColumn get claimId => text()();
  IntColumn get partTypeId => integer()();
  TextColumn get snBadPart => text().nullable()();
  BoolColumn get syncPending => boolean().withDefault(const Constant(false))();

  /// Ditandai hapus, tapi belum sempat dihapus di server.
  ///
  /// Baris tidak langsung dibuang supaya penghapusan yang dilakukan saat
  /// offline tetap sampai ke server. Baris ini disembunyikan dari tampilan
  /// dan dibuang setelah server mengonfirmasi.
  BoolColumn get pendingDelete =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// Tiga tabel berikut ikut disinkronkan supaya perhitungan bagi hasil bisa
// berjalan tanpa koneksi, sama seperti bagian aplikasi lainnya. Isinya
// kecil: beberapa baris fee dan satu baris aturan.
//
// Aturan akses di server yang menentukan siapa menerima apa -- teknisi
// menarik nol baris, jadi angka fee tidak pernah sampai ke perangkat mereka.

class BrandFeeEntries extends Table {
  IntColumn get id => integer()();
  IntColumn get brandId => integer()();
  RealColumn get fee => real()();
  DateTimeColumn get berlakuDari => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class RevenueConfigs extends Table {
  IntColumn get id => integer()();
  RealColumn get persenToko => real()();
  RealColumn get persenAdmin => real()();
  RealColumn get persenTeknisi => real()();
  TextColumn get metodeTeknisi => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class TechnicianShareEntries extends Table {
  TextColumn get profileId => text()();
  RealColumn get persen => real()();

  @override
  Set<Column> get primaryKey => {profileId};
}

/// Penyimpanan kunci-nilai untuk keperluan sinkron, mis. kapan terakhir
/// menarik data dari server.
class SyncMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Brands,
    PartTypes,
    Profiles,
    Claims,
    ClaimParts,
    SyncMeta,
    BrandFeeEntries,
    RevenueConfigs,
    TechnicianShareEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'sc_management'));

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // Perangkat yang sudah terpasang tidak boleh kehilangan antrean
          // klaim yang belum terkirim, jadi perubahan dilakukan bertahap,
          // bukan dengan membuat ulang seluruh tabel.
          if (from < 2) {
            await m.addColumn(claimParts, claimParts.pendingDelete);
          }
          if (from < 3) {
            await m.createTable(brandFeeEntries);
            await m.createTable(revenueConfigs);
            await m.createTable(technicianShareEntries);
          }
        },
      );

  // ------------------------------------------------------------------
  // Baca
  // ------------------------------------------------------------------

  /// Daftar klaim terbaru di atas. Dipakai halaman utama.
  Stream<List<Claim>> watchClaims({int? brandId, String? status}) {
    final q = select(claims)
      ..orderBy([(t) => OrderingTerm.desc(t.tanggal)]);

    if (brandId != null) q.where((t) => t.brandId.equals(brandId));
    if (status != null) q.where((t) => t.status.equals(status));

    return q.watch();
  }

  /// Hanya yang aktif -- untuk pilihan saat input klaim baru.
  Stream<List<Brand>> watchBrands() =>
      (select(brands)..where((t) => t.aktif)).watch();

  Stream<List<PartType>> watchPartTypes() =>
      (select(partTypes)..where((t) => t.aktif)).watch();

  /// Termasuk yang nonaktif -- untuk menampilkan klaim lama yang terlanjur
  /// memakainya, dan untuk halaman data master.
  Stream<List<Brand>> watchAllBrands() =>
      (select(brands)..orderBy([(t) => OrderingTerm.asc(t.nama)])).watch();

  Stream<List<PartType>> watchAllPartTypes() =>
      (select(partTypes)..orderBy([(t) => OrderingTerm.asc(t.kode)])).watch();

  Stream<List<Profile>> watchTechnicians() =>
      (select(profiles)..where((t) => t.aktif)).watch();

  /// Termasuk yang sudah dinonaktifkan. Dipakai halaman kelola pengguna,
  /// karena admin tetap perlu melihat dan bisa mengaktifkan mereka lagi.
  Stream<List<Profile>> watchAllProfiles() =>
      (select(profiles)..orderBy([(t) => OrderingTerm.asc(t.nama)])).watch();

  Future<void> setProfileActive(String id, bool aktif) =>
      (update(profiles)..where((t) => t.id.equals(id)))
          .write(ProfilesCompanion(aktif: Value(aktif)));

  Future<void> setProfileRole(String id, String role) =>
      (update(profiles)..where((t) => t.id.equals(id)))
          .write(ProfilesCompanion(role: Value(role)));

  Future<List<Profile>> allProfiles() => select(profiles).get();

  Future<Profile?> profileById(String id) =>
      (select(profiles)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Harus stream, bukan future. Saat login pertama, baris profil belum ada
  /// di perangkat sampai sinkronisasi menariknya. Kalau ini dibaca sekali
  /// saja, hasilnya null dan aplikasi menganggap penggunanya bukan admin
  /// untuk seterusnya.
  Stream<Profile?> watchProfileById(String id) =>
      (select(profiles)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Stream<List<ClaimPart>> watchPartsOf(String claimId) =>
      (select(claimParts)
            ..where((t) => t.claimId.equals(claimId) & t.pendingDelete.not()))
          .watch();

  Future<List<ClaimPart>> partsOf(String claimId) =>
      (select(claimParts)
            ..where((t) => t.claimId.equals(claimId) & t.pendingDelete.not()))
          .get();

  Stream<Claim?> watchClaim(String id) =>
      (select(claims)..where((t) => t.id.equals(id))).watchSingleOrNull();

  /// Jumlah klaim per status, dihitung di database bukan di memori supaya
  /// tetap ringan saat datanya sudah ribuan baris.
  Stream<Map<String, int>> watchStatusCounts() {
    final jumlah = claims.id.count();
    final q = selectOnly(claims)
      ..addColumns([claims.status, jumlah])
      ..groupBy([claims.status]);

    return q.map((row) => MapEntry(row.read(claims.status)!, row.read(jumlah)!))
        .watch()
        .map(Map.fromEntries);
  }

  /// Berapa banyak perubahan lokal yang masih mengantre.
  Stream<int> watchPendingCount() {
    final c = claims.id.count();
    final q = selectOnly(claims)
      ..addColumns([c])
      ..where(claims.syncPending.equals(true));
    return q.map((row) => row.read(c) ?? 0).watchSingle();
  }

  // ------------------------------------------------------------------
  // Tulis (selalu lokal dulu, ditandai untuk disinkron)
  // ------------------------------------------------------------------

  Future<void> upsertClaimLocal(ClaimsCompanion entry) =>
      into(claims).insertOnConflictUpdate(entry);

  Future<void> upsertPartLocal(ClaimPartsCompanion entry) =>
      into(claimParts).insertOnConflictUpdate(entry);

  /// Mengganti teknisi yang mengerjakan. Ini satu-satunya perubahan yang
  /// boleh dilakukan teknisi terhadap klaim yang sudah ada.
  Future<void> reassignTechnician(String claimId, String technicianId) {
    return (update(claims)..where((t) => t.id.equals(claimId))).write(
      ClaimsCompanion(
        teknisiId: Value(technicianId),
        updatedAt: Value(DateTime.now()),
        syncPending: const Value(true),
      ),
    );
  }

  /// Menyimpan hasil penyuntingan penuh oleh admin. Pemanggil bertanggung
  /// jawab mengisi updatedAt dan syncPending.
  Future<void> updateClaimFull(String claimId, ClaimsCompanion values) =>
      (update(claims)..where((t) => t.id.equals(claimId))).write(values);

  /// Menandai part untuk dihapus. Baris baru benar-benar dibuang setelah
  /// server mengonfirmasi, supaya penghapusan saat offline tidak hilang.
  Future<void> markPartDeleted(String id) =>
      (update(claimParts)..where((t) => t.id.equals(id))).write(
        const ClaimPartsCompanion(
          pendingDelete: Value(true),
          syncPending: Value(true),
        ),
      );

  Future<void> deletePartLocal(String id) =>
      (delete(claimParts)..where((t) => t.id.equals(id))).go();

  Future<void> updateStatus(String claimId, String status) {
    return (update(claims)..where((t) => t.id.equals(claimId))).write(
      ClaimsCompanion(
        status: Value(status),
        updatedAt: Value(DateTime.now()),
        syncPending: const Value(true),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Dipakai SyncService
  // ------------------------------------------------------------------

  Future<List<Claim>> pendingClaims() =>
      (select(claims)..where((t) => t.syncPending.equals(true))).get();

  Future<List<ClaimPart>> pendingParts() =>
      (select(claimParts)..where((t) => t.syncPending.equals(true))).get();

  Future<void> markClaimSynced(String id) =>
      (update(claims)..where((t) => t.id.equals(id)))
          .write(const ClaimsCompanion(syncPending: Value(false)));

  Future<void> markPartSynced(String id) =>
      (update(claimParts)..where((t) => t.id.equals(id)))
          .write(const ClaimPartsCompanion(syncPending: Value(false)));

  /// Baris yang masih punya perubahan lokal tidak boleh ditimpa data server.
  Future<bool> hasPendingChange(String claimId) async {
    final row = await (select(claims)
          ..where((t) => t.id.equals(claimId) & t.syncPending.equals(true)))
        .getSingleOrNull();
    return row != null;
  }

  // ------------------------------------------------------------------
  // Bagi hasil
  // ------------------------------------------------------------------

  /// Klaim yang ikut dihitung: hanya yang berstatus selesai, karena fee
  /// dibayarkan brand setelah perbaikan tuntas.
  Stream<List<Claim>> watchClosedClaims(DateTime dari, DateTime sampai) {
    return (select(claims)
          ..where(
            (t) =>
                t.status.equals('close') &
                t.tanggal.isBiggerOrEqualValue(dari) &
                t.tanggal.isSmallerOrEqualValue(sampai),
          ))
        .watch();
  }

  Stream<List<BrandFeeEntry>> watchBrandFees() => select(brandFeeEntries).watch();

  Stream<RevenueConfig?> watchRevenueConfig() =>
      (select(revenueConfigs)..where((t) => t.id.equals(1)))
          .watchSingleOrNull();

  Stream<List<TechnicianShareEntry>> watchTechnicianShares() =>
      select(technicianShareEntries).watch();

  /// Diganti seluruhnya tiap sinkron. Tabelnya kecil, dan cara ini membuat
  /// baris yang dihapus di server ikut hilang di perangkat -- fee yang
  /// sudah dicabut tidak boleh tertinggal dan dipakai menghitung.
  Future<void> replaceBrandFees(List<BrandFeeEntriesCompanion> rows) async {
    await batch((b) {
      b.deleteAll(brandFeeEntries);
      b.insertAll(brandFeeEntries, rows);
    });
  }

  Future<void> replaceTechnicianShares(
    List<TechnicianShareEntriesCompanion> rows,
  ) async {
    await batch((b) {
      b.deleteAll(technicianShareEntries);
      b.insertAll(technicianShareEntries, rows);
    });
  }

  Future<void> upsertRevenueConfig(RevenueConfigsCompanion row) =>
      into(revenueConfigs).insertOnConflictUpdate(row);

  Future<bool> hasPendingPart(String id) async {
    final row = await (select(claimParts)
          ..where((t) => t.id.equals(id) & t.syncPending.equals(true)))
        .getSingleOrNull();
    return row != null;
  }

  Future<String?> getMeta(String key) async {
    final row = await (select(syncMeta)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setMeta(String key, String value) => into(syncMeta)
      .insertOnConflictUpdate(SyncMetaCompanion.insert(key: key, value: value));
}
