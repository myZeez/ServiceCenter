// Penyaring daftar. Semuanya keluaran murni dari satu daftar profil atau
// klaim, jadi bisa diuji tanpa server sama sekali.
//
// Yang dijaga di sini pernah rusak sungguhan: kolom Teknisi di formulir
// servis sempat mati total karena daftarnya kosong -- dropdown tanpa isi
// otomatis dinonaktifkan Flutter, dan di layar terlihat seperti kolom yang
// sengaja dikunci, bukan seperti daftar yang kosong.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/providers.dart';

Profile _orang(String id, String nama, String role, {bool aktif = true}) =>
    Profile(id: id, nama: nama, role: role, aktif: aktif);

ProviderContainer _wadah(List<Profile> profil) {
  final c = ProviderContainer(
    overrides: [
      allProfilesProvider.overrideWith((ref) => Stream.value(profil)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('Daftar untuk membaca nama', () {
    test('memuat admin juga, karena nota lama tercatat atas namanya', () async {
      final c = _wadah([
        _orang('1', 'Budi', 'admin'),
        _orang('2', 'Andi', 'teknisi'),
      ]);
      await c.read(allProfilesProvider.future);

      final daftar = c.read(techniciansProvider).valueOrNull!;
      expect(daftar.map((p) => p.nama), ['Budi', 'Andi']);
    });

    test('toko yang semua akunnya admin tetap terbaca namanya', () async {
      // Daftar ini tidak boleh ikut menyaring role: yang dibacanya adalah
      // nama pada nota yang sudah terlanjur tercatat, bukan siapa yang
      // boleh ditunjuk berikutnya.
      final c = _wadah([
        _orang('1', 'Budi', 'admin'),
        _orang('2', 'Sari', 'admin'),
      ]);
      await c.read(allProfilesProvider.future);

      expect(c.read(techniciansProvider).valueOrNull, isNotEmpty);
    });

    test('yang sudah dinonaktifkan tidak ikut', () async {
      final c = _wadah([
        _orang('1', 'Budi', 'admin'),
        _orang('2', 'Mantan', 'teknisi', aktif: false),
      ]);
      await c.read(allProfilesProvider.future);

      final daftar = c.read(techniciansProvider).valueOrNull!;
      expect(daftar.map((p) => p.id), ['1']);
    });

    test('halaman kelola pengguna tetap melihat yang nonaktif', () async {
      final c = _wadah([
        _orang('1', 'Budi', 'admin'),
        _orang('2', 'Mantan', 'teknisi', aktif: false),
      ]);

      final semua = await c.read(allProfilesProvider.future);
      expect(semua.length, 2);
    });
  });

  group('Pilihan pengerja', () {
    test('admin tidak bisa ditunjuk mengerjakan', () async {
      final c = _wadah([
        _orang('1', 'Budi', 'admin'),
        _orang('2', 'Andi', 'teknisi'),
      ]);
      await c.read(allProfilesProvider.future);

      expect(c.read(pengerjaProvider).map((p) => p.nama), ['Andi']);
    });

    test('toko yang belum punya teknisi menghasilkan daftar kosong', () async {
      // Sengaja tidak dijatuhkan kembali ke daftar admin. Yang benar adalah
      // menambahkan teknisinya dulu, dan formulirnya mengatakan itu -- bukan
      // menawarkan nama yang tidak boleh dipilih.
      final c = _wadah([
        _orang('1', 'Budi', 'admin'),
        _orang('2', 'Sari', 'admin'),
      ]);
      await c.read(allProfilesProvider.future);

      expect(c.read(pengerjaProvider), isEmpty);
    });

    test('yang sudah tercatat tetap ikut walau ia admin', () async {
      // Dua sebabnya sama-sama keras: dropdown yang nilainya tidak ada di
      // antara pilihannya melempar galat, dan nama yang menghilang dari
      // kolomnya terbaca seperti pekerjaannya ikut terhapus.
      final c = _wadah([
        _orang('1', 'Budi', 'admin'),
        _orang('2', 'Andi', 'teknisi'),
      ]);
      await c.read(allProfilesProvider.future);

      final daftar = c.read(pengerjaUntukProvider('1'));
      expect(daftar.map((p) => p.nama), ['Andi', 'Budi']);
    });

    test('yang sudah tercatat tetap ikut walau sudah dinonaktifkan', () async {
      final c = _wadah([
        _orang('1', 'Budi', 'admin'),
        _orang('2', 'Andi', 'teknisi'),
        _orang('3', 'Mantan', 'teknisi', aktif: false),
      ]);
      await c.read(allProfilesProvider.future);

      expect(
        c.read(pengerjaUntukProvider('3')).map((p) => p.nama),
        ['Andi', 'Mantan'],
      );
    });

    test('tidak menggandakan orang yang memang sudah ada di daftar', () async {
      final c = _wadah([
        _orang('1', 'Budi', 'admin'),
        _orang('2', 'Andi', 'teknisi'),
      ]);
      await c.read(allProfilesProvider.future);

      expect(c.read(pengerjaUntukProvider('2')).map((p) => p.nama), ['Andi']);
    });

    test('tanpa siapa pun terpilih, daftarnya apa adanya', () async {
      final c = _wadah([
        _orang('1', 'Budi', 'admin'),
        _orang('2', 'Andi', 'teknisi'),
      ]);
      await c.read(allProfilesProvider.future);

      expect(c.read(pengerjaUntukProvider(null)).map((p) => p.nama), ['Andi']);
    });
  });

  // isAdminProvider tidak diuji di sini: rantainya sampai ke sesi login
  // Supabase, dan memalsukannya butuh lebih banyak perancah daripada nilai
  // yang didapat. Yang diperiksa cukup penyaringnya.

  group('Filter klaim', () {
    Claim k(String id, int brand, String status, String nama, String sn) =>
        Claim(
          id: id,
          tanggal: DateTime(2026, 9, 4),
          brandId: brand,
          namaPelanggan: nama,
          sn: sn,
          status: status,
          createdBy: 'adm',
          createdAt: DateTime(2026, 9, 4),
          updatedAt: DateTime(2026, 9, 4),
        );

    ProviderContainer wadahKlaim(List<Claim> klaim) {
      final c = ProviderContainer(
        overrides: [
          allClaimsProvider.overrideWith((ref) => Stream.value(klaim)),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('pencarian menjangkau nama dan nomor seri', () async {
      final c = wadahKlaim([
        k('1', 1, 'open', 'Budi', 'SN111'),
        k('2', 2, 'open', 'Sari', 'SN222'),
      ]);
      await c.read(allClaimsProvider.future);

      c.read(claimFilterProvider.notifier).state = const ClaimFilter(
        query: 'sn22',
      );
      expect(c.read(claimsProvider).valueOrNull!.single.id, '2');

      c.read(claimFilterProvider.notifier).state = const ClaimFilter(
        query: 'budi',
      );
      expect(c.read(claimsProvider).valueOrNull!.single.id, '1');
    });

    test('saringan brand dan status berlaku bersamaan', () async {
      final c = wadahKlaim([
        k('1', 1, 'open', 'Budi', 'A'),
        k('2', 1, 'close', 'Budi', 'B'),
        k('3', 2, 'open', 'Budi', 'C'),
      ]);
      await c.read(allClaimsProvider.future);

      c.read(claimFilterProvider.notifier).state = const ClaimFilter(
        brandId: 1,
        status: 'open',
      );
      expect(c.read(claimsProvider).valueOrNull!.single.id, '1');
    });

    test('hitungan status dipakai kartu di halaman utama', () async {
      final c = wadahKlaim([
        k('1', 1, 'open', 'A', 'A'),
        k('2', 1, 'open', 'B', 'B'),
        k('3', 1, 'close', 'C', 'C'),
      ]);
      await c.read(allClaimsProvider.future);

      expect(c.read(statusCountsProvider).valueOrNull, {'open': 2, 'close': 1});
    });
  });
}
