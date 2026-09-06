import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bagian aplikasi yang sengaja disimpan dulu, bukan dibuang.
///
/// Tanya Harga dan Pemesanan Part sudah jadi seluruhnya -- tabel, aturan
/// akses, layar, ekspor, dan 946 baris arsip yang sudah diimpor -- tetapi
/// pemakaiannya ditunda. Yang ditutup hanyalah pintu masuknya:
///
///   * dua bagian di sidebar layar lebar
///   * satu butir di menu layar sempit
///   * bagian tanya harga di formulir nota servis
///
/// Datanya tidak disentuh sama sekali. Menyalakannya kembali cukup dengan
/// mengubah `false` di bawah menjadi `true` -- tidak ada migrasi yang
/// perlu diulang, tidak ada baris yang perlu dipulihkan.
///
/// Ditulis sebagai provider, bukan konstanta, dengan satu alasan yang
/// praktis: tes tetap bisa menyalakannya lewat override, jadi kode yang
/// sedang disimpan ini tidak ikut membusuk selama menunggu. Fitur yang
/// disembunyikan dengan cara membiarkan tesnya mati akan kembali dalam
/// keadaan rusak, dan yang menemukannya adalah orang yang memakainya.
final fiturTanyaHargaProvider = Provider<bool>((ref) => false);
