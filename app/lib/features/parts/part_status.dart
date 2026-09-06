import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Posisi sebuah permintaan part. Nilainya harus sama persis dengan enum
/// part_tahap di Postgres.
///
/// Daftarnya diambil dari arsip sheet yang dipakai bertahun-tahun, bukan
/// dikarang: tiap nilai di sini punya ratusan sampai ribuan baris di
/// belakangnya. Satu kolom, bukan dua -- di sheet aslinya "No Stock"
/// memang status, sederajat dengan CANCEL, dan tidak ada satu pun baris
/// yang pernah ditandai "ready".
class PartTahap {
  /// Menunggu teknisi menyebutkan kode part persisnya. Tahap paling awal,
  /// dan yang isinya paling menumpuk.
  static const foto = 'foto';

  /// Sudah ditanyakan ke supplier, harganya belum datang.
  static const harga = 'harga';

  /// Harga sudah keluar, menunggu pelanggan menyetujui dan membayar DP.
  static const konfirmasi = 'konfirmasi';

  static const dipesan = 'dipesan';
  static const dipasang = 'dipasang';

  /// Sudah diambil pelanggan. "CLOSE" di sheet lama.
  static const selesai = 'selesai';

  /// Pelanggan mundur.
  static const batal = 'batal';

  /// Barangnya memang tidak ada. Berbeda dari batal, dan bedanya bukan
  /// soal rasa: yang satu keputusan pelanggan, yang satu kegagalan kita
  /// mencari barang -- dan hanya yang kedua layak dihitung sebagai
  /// peluang yang hilang.
  static const kosong = 'kosong';

  static const all = [
    foto,
    harga,
    konfirmasi,
    dipesan,
    dipasang,
    selesai,
    batal,
    kosong,
  ];

  /// Yang masih di meja tanya-jawab: belum ada uang yang berpindah.
  static const sebelumDp = [foto, harga, konfirmasi, batal, kosong];

  /// Yang sudah jadi pesanan sungguhan. Inilah isi halaman Pemesanan.
  static const sesudahDp = [dipesan, dipasang, selesai];

  static bool sudahDipesan(String tahap) => sesudahDp.contains(tahap);

  /// Tahap yang tidak masuk akal tanpa harga: yang uangnya sudah
  /// berpindah. Dijaga juga oleh constraint di Postgres; daftar ini supaya
  /// layar bisa menolak lebih dulu dengan kalimat yang bisa dibaca.
  ///
  /// 'konfirmasi' sengaja TIDAK termasuk, walau namanya seperti menuntut
  /// angka. Di arsipnya, penawaran sering memuat lebih dari satu part
  /// dengan harga masing-masing ("ORI KB MODULE 1500K, BATT 1300K") dan
  /// ditulis di catatan, bukan di kolom harga. Memaksa satu angka di situ
  /// membuat yang tercatat lebih miskin daripada yang disampaikan.
  static bool perluHarga(String tahap) =>
      const [dipesan, dipasang, selesai].contains(tahap);

  static const _labels = {
    foto: 'Tunggu Kode Part',
    harga: 'Tunggu Harga',
    konfirmasi: 'Tunggu Konfirmasi DP',
    dipesan: 'Part Dipesan',
    dipasang: 'Part Dipasang',
    selesai: 'Close',
    batal: 'Batal',
    kosong: 'No Stock',
  };

  /// Label pendek untuk kolom tabel yang sempit dan chip saringan.
  static const _pendek = {
    foto: 'Kode Part',
    harga: 'Tunggu Harga',
    konfirmasi: 'Tunggu DP',
    dipesan: 'Dipesan',
    dipasang: 'Dipasang',
    selesai: 'Close',
    batal: 'Batal',
    kosong: 'No Stock',
  };

  // Aturannya sama dengan status nota: yang menuntut tindakan diberi
  // bobot paling besar, yang sudah tuntas mundur ke belakang.
  //
  // 'dipasang' sengaja merah dan terisi. Part sudah menempel di unit
  // pelanggan sementara sisa tagihannya belum masuk -- satu-satunya
  // keadaan di seluruh alur ini yang benar-benar bisa merugikan toko
  // kalau terlewat.
  static const _colors = {
    foto: AppColors.grey,
    harga: AppColors.blue,
    konfirmasi: AppColors.blue,
    dipesan: AppColors.blue,
    dipasang: AppColors.red,
    selesai: AppColors.black,
    batal: AppColors.grey,
    kosong: AppColors.red,
  };

  static const _filled = {
    foto: false,
    harga: false,
    konfirmasi: true,
    dipesan: true,
    dipasang: true,
    selesai: false,
    batal: false,
    kosong: false,
  };

  static String label(String t) => _labels[t] ?? t;
  static String pendek(String t) => _pendek[t] ?? _labels[t] ?? t;
  static Color color(String t) => _colors[t] ?? AppColors.grey;
  static bool isFilled(String t) => _filled[t] ?? false;
}

class PartTahapChip extends StatelessWidget {
  const PartTahapChip(this.tahap, {super.key, this.compact = false});

  final String tahap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = PartTahap.color(tahap);
    final filled = PartTahap.isFilled(tahap);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? c : Colors.transparent,
        border: Border.all(color: c),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Text(
        (compact ? PartTahap.pendek(tahap) : PartTahap.label(tahap))
            .toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: filled ? AppColors.white : c,
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
          height: 1.2,
        ),
      ),
    );
  }
}

/// Asal part: OEM, atau saluran resmi merek seperti ASUS ID dan ACER ID.
///
/// Bukan pilihan tertutup. Di arsipnya ada belasan nilai yang tumbuh
/// sendiri sepanjang tahun -- AXIOO ID, MSI ID, Canon ID, sampai nama
/// toko tempat membeli lepasan. Daftar ini hanya bibit untuk pelengkapan
/// otomatis; apa pun yang diketik tetap tersimpan.
const asalPartUmum = [
  'OEM',
  'ORI',
  'ASUS ID',
  'ACER ID',
  'LENOVO ID',
  'HP ID',
  'AXIOO ID',
  'MSI ID',
];
