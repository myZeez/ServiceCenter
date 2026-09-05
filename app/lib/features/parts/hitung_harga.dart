// Hitungan uang untuk penjualan part.
//
// Fungsi murni, tanpa Flutter dan tanpa Supabase, supaya bisa diuji
// langsung. Uang adalah bagian yang paling mahal kalau salah dan paling
// sunyi kalau salahnya sedikit: selisih seribu rupiah tidak pernah
// terlihat di layar, tetapi menumpuk sepanjang bulan.

import '../../core/data/models.dart';

/// Harga jual dari modal dan persentase yang diambil toko.
///
/// Persentasenya dihitung DI ATAS modal, bukan dipotong dari harga jual.
/// Dua tafsir itu menghasilkan angka berbeda dan sering tertukar:
/// modal 100.000 dengan "ambil 20%" berarti dijual 120.000, bukan
/// 125.000 yang akan keluar bila 20% dibaca sebagai bagian dari harga
/// jualnya.
double hargaJual(double hpp, double upPersen) => hpp + hpp * upPersen / 100;

/// Berapa persen toko mengambil, dibaca mundur dari harga yang sudah
/// ditetapkan.
///
/// Dipakai saat admin mengetik sendiri harga jualnya -- pembulatan ke
/// angka yang enak disebut adalah kebiasaan yang wajar di meja depan, dan
/// sesudah itu persentasenya perlu diperlihatkan supaya yang tercatat
/// tetap jujur terhadap apa yang benar-benar terjadi.
///
/// Modal nol tidak punya persentase: berapa pun harga jualnya, tidak ada
/// bilangan yang bila dikalikan nol menghasilkan sesuatu.
double? upPersenDari(double hpp, double harga) =>
    hpp <= 0 ? null : (harga - hpp) / hpp * 100;

/// Keuntungan toko dalam rupiah.
double margin(double hpp, double harga) => harga - hpp;

/// Yang masih harus dibayar pelanggan.
///
/// Cerminan kolom `sisa` yang dihitung Postgres. Ada di sini supaya layar
/// bisa memperlihatkan angkanya sebelum apa pun tersimpan; yang tercatat
/// tetap hitungan server, dan keduanya sengaja memakai rumus yang sama
/// persis.
double sisaTagihan(double harga, double dp) => harga - dp;

/// Jumlah uang sekumpulan pesanan.
///
/// Dipakai baris ringkasan di halaman Pemesanan Part dan laporan bulanan.
/// Keduanya harus menyebut angka yang sama, jadi penjumlahannya ditulis
/// sekali di sini alih-alih diulang di tiap layar.
class RingkasPesanan {
  const RingkasPesanan({
    required this.jumlah,
    required this.harga,
    required this.dp,
    required this.sisa,
  });

  final int jumlah;
  final double harga;
  final double dp;

  /// Uang yang sudah jadi hak toko tetapi belum diterima. Inilah angka
  /// yang paling perlu dilihat tiap hari.
  final double sisa;
}

RingkasPesanan ringkasPesanan(Iterable<PartOrder> pesanan) {
  var jumlah = 0;
  var harga = 0.0;
  var dp = 0.0;
  var sisa = 0.0;

  for (final p in pesanan) {
    jumlah++;
    harga += p.harga ?? 0;
    dp += p.dp;
    sisa += p.sisa;
  }

  return RingkasPesanan(jumlah: jumlah, harga: harga, dp: dp, sisa: sisa);
}
