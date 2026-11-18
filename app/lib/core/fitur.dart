import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bagian aplikasi yang bisa dimatikan tanpa membuang apa pun.
///
/// Tanya Harga dan Pemesanan Part: tabel, aturan akses, layar, dan ekspor.
/// Menyala sejak 11 November 2026. Tanya harga biasanya lahir dari nota
/// servis dan tertaut kembali ke sana, seperti klaim garansi. Pelanggan yang
/// hanya bertanya harga tanpa meninggalkan unit tidak punya nota, jadi
/// halaman Tanya Harga juga bisa mencatatnya manual.
///
/// Yang ditutup bila dimatikan hanyalah pintu masuknya:
///
///   * dua bagian di sidebar layar lebar
///   * satu butir di menu layar sempit
///   * bagian tanya harga di formulir nota servis
///
/// Datanya tidak disentuh sama sekali.
///
/// Ditulis sebagai provider, bukan konstanta, dengan satu alasan yang
/// praktis: tes bisa mengubahnya lewat override, jadi kode di balik pintu
/// ini tetap diuji walau pintunya ditutup.
final fiturTanyaHargaProvider = Provider<bool>((ref) => true);
