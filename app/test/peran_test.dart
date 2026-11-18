// Admin dipecah menjadi admin (meja depan) dan super admin (pengelola).
//
// Pembatasannya ada dua lapis: di aplikasi yang ditampilkan, di server yang
// diizinkan. Test ini menjaga lapis aplikasi: kalau daftar di sini bergeser,
// admin bisa membuka halaman yang isinya ditolak server, atau super admin
// kehilangan halaman yang hanya dia yang boleh membukanya.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/peran.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/features/shell/admin_shell.dart';

List<String> _label(String? peran, {bool adaPart = false}) => [
  for (final b in menuUntuk(peran, adaPart: adaPart)) b.label,
];

ProviderContainer _sebagai(String peran) {
  final c = ProviderContainer(
    overrides: [
      currentProfileProvider.overrideWithValue(
        Profile(id: 'saya', nama: 'Saya', role: peran),
      ),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('Peran.label', () {
    test('nama tiap peran untuk pengguna', () {
      expect(Peran.label('super_admin'), 'Super Admin');
      expect(Peran.label('admin'), 'Admin');
      expect(Peran.label('admin_sc'), 'Admin SC');
      expect(Peran.label('teknisi'), 'Teknisi');
    });

    test('peran yang belum terbaca tidak menampilkan apa pun', () {
      expect(Peran.label(null), '');
    });
  });

  group('menuUntuk', () {
    test('super admin memegang laporan dan keuangan, bukan meja depan', () {
      final menu = _label(Peran.superAdmin);

      expect(
        menu,
        containsAll([
          'Semua Nota',
          'Persetujuan',
          'Laporan Servis',
          'Kerja Teknisi',
          'Piutang',
          'Kirim Partner',
          'Klaim',
          'Part Kembali',
          'Rekap',
          'Rekap Brand',
          'Pendapatan',
          'Pengaturan',
        ]),
      );
      // Meja depan tetap milik admin: menerima nota baru bukan urusannya.
      expect(menu, isNot(contains('Servis')));
      expect(menu, isNot(contains('Pekerjaanku')));
    });

    test('super admin ikut memegang tanya harga dan pemesanan part', () {
      expect(
        _label(Peran.superAdmin, adaPart: true),
        containsAll(['Tanya Harga', 'Pemesanan Part']),
      );
      expect(_label(Peran.superAdmin), isNot(contains('Tanya Harga')));
    });

    test('admin tidak melihat halaman milik super admin', () {
      final menu = _label(Peran.admin);

      expect(
        menu,
        containsAll([
          'Servis',
          'Semua Nota',
          'Laporan Servis',
          'Piutang',
          'Klaim',
          'Part Kembali',
          'Pekerjaanku',
          'Persetujuan',
          'Pengaturan',
        ]),
      );
      for (final milikSuperAdmin in const [
        'Kerja Teknisi',
        'Kirim Partner',
        'Rekap',
        'Rekap Brand',
        'Pendapatan',
      ]) {
        expect(menu, isNot(contains(milikSuperAdmin)));
      }
    });

    test('Tanya Harga mengikuti sakelar fiturnya', () {
      expect(_label(Peran.admin), isNot(contains('Tanya Harga')));
      expect(
        _label(Peran.admin, adaPart: true),
        containsAll(['Tanya Harga', 'Pemesanan Part']),
      );
    });

    test('admin SC tetap pada daftarnya', () {
      expect(_label(Peran.adminSc), [
        'Klaim',
        'Part Kembali',
        'Rekap',
        'Rekap Brand',
        'Laporan Servis',
        'Piutang',
      ]);
    });

    test('teknisi, atau profil yang belum terbaca', () {
      expect(_label(Peran.teknisi), ['Klaim', 'Pekerjaanku']);
      expect(_label(null), ['Klaim', 'Pekerjaanku']);
    });
  });

  group('provider peran', () {
    test('super admin dihitung admin, tapi bukan admin meja depan', () {
      final c = _sebagai(Peran.superAdmin);

      expect(c.read(isAdminProvider), isTrue);
      expect(c.read(isSuperAdminProvider), isTrue);
      expect(c.read(isAdminDepanProvider), isFalse);
    });

    test('admin bukan super admin', () {
      final c = _sebagai(Peran.admin);

      expect(c.read(isAdminProvider), isTrue);
      expect(c.read(isSuperAdminProvider), isFalse);
      expect(c.read(isAdminDepanProvider), isTrue);
    });

    test('admin SC dan teknisi tidak termasuk keduanya', () {
      for (final peran in const [Peran.adminSc, Peran.teknisi]) {
        final c = _sebagai(peran);

        expect(c.read(isAdminProvider), isFalse);
        expect(c.read(isSuperAdminProvider), isFalse);
        expect(c.read(isAdminDepanProvider), isFalse);
      }
    });
  });
}
