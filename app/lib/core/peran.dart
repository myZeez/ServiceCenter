/// Peran pengguna, sama dengan enum user_role di server.
///
/// Admin dipecah dua sejak November 2026. Admin bekerja di meja depan:
/// menerima servis, klaim, pelunasan, dan impor. Super admin mengelola:
/// pengguna, data master, laporan lengkap, dan pendapatan. Halamannya memang
/// berbeda, bukan satu di atas yang lain -- super admin tidak memegang meja
/// depan.
abstract final class Peran {
  static const superAdmin = 'super_admin';
  static const admin = 'admin';
  static const adminSc = 'admin_sc';
  static const teknisi = 'teknisi';

  /// Tim gudang: membeli part dan memeriksa laporan pemesanan yang dikirim
  /// ke pusat. Hanya melihat pesanan part dan mengisi data pembeliannya.
  static const gudang = 'gudang';

  /// Nama yang ditampilkan ke pengguna.
  static String label(String? peran) => switch (peran) {
    superAdmin => 'Super Admin',
    admin => 'Admin',
    adminSc => 'Admin SC',
    teknisi => 'Teknisi',
    gudang => 'Gudang',
    _ => '',
  };
}
