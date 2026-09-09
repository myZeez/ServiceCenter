import 'package:flutter/material.dart';

import 'theme.dart';

/// Nilai status harus sama persis dengan enum claim_status di Postgres.
class ClaimStatus {
  static const open = 'open';
  static const proses = 'proses';
  static const tungguPart = 'tunggu_part';
  static const close = 'close';
  static const batal = 'batal';

  static const all = [open, proses, tungguPart, close, batal];

  static const _labels = {
    open: 'Baru Masuk',
    proses: 'Dikerjakan',
    tungguPart: 'Tunggu Part',
    close: 'Selesai',
    batal: 'Batal',
  };

  static const _filled = {
    open: false,
    proses: true,
    tungguPart: true,
    close: false,
    batal: false,
  };

  static String label(String s) => _labels[s] ?? s;
  static bool isFilled(String s) => _filled[s] ?? false;

  /// Warna status, diambil dari palet yang sedang berlaku.
  ///
  /// Dulu ini peta tetap. Peta tetap tidak bisa lagi menampung warnanya
  /// begitu ada dua tema: warna yang sama harus berbeda rupanya di siang
  /// dan malam, dan yang tetap hanyalah perannya.
  ///
  /// Pembeda status memakai warna DAN isian, karena paletnya cuma punya
  /// tiga warna kerja. Yang menuntut tindakan diberi bobot visual paling
  /// besar; yang sudah selesai sengaja mundur ke belakang supaya perhatian
  /// jatuh ke pekerjaan yang masih berjalan.
  static Color color(BuildContext context, String s) {
    final w = context.warna;
    return switch (s) {
      open || proses => w.aksen,
      tungguPart => w.bahaya,
      close => w.teks,
      _ => w.teksLembut,
    };
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.compact = false});

  final String status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = ClaimStatus.color(context, status);
    final filled = ClaimStatus.isFilled(status);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? c : Colors.transparent,
        border: Border.all(color: c, width: 1),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Text(
        ClaimStatus.label(status).toUpperCase(),
        style: TextStyle(
          color: filled ? context.warna.permukaan : c,
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
          height: 1.2,
        ),
      ),
    );
  }
}

/// Jenis garansi. Nilainya harus sama persis dengan check `jenis` pada
/// tabel claims.
///
/// Keduanya sama-sama berbiaya nol bagi pelanggan; yang membedakan siapa
/// yang menanggungnya. Yang ke brand ditagihkan dan masuk Rekap Brand,
/// yang ke toko ditanggung sendiri dan tidak ditagihkan ke mana pun.
class ClaimJenis {
  static const brand = 'brand';
  static const toko = 'toko';

  static const all = [brand, toko];

  static const _labels = {brand: 'Garansi Brand', toko: 'Garansi Toko'};

  /// Keterangan sebaris untuk dipasang di bawah pilihannya. Perbedaannya
  /// bukan soal nama melainkan soal akibat, dan akibat itu harus terbaca
  /// di tempat orang memilih.
  static const _hints = {
    brand:
        'Part diminta ke brand. Nomor seri wajib — brand mengenali unit '
        'dari situ. Masuk Rekap Brand.',
    toko:
        'Ditanggung toko sendiri, misalnya unit yang rusak lagi dalam masa '
        'garansi servis. Nomor seri tidak diperlukan, dan tidak masuk '
        'Rekap Brand.',
  };

  static String label(String j) => _labels[j] ?? j;
  static String hint(String j) => _hints[j] ?? '';

  /// Apakah jenis ini menuntut nomor seri.
  static bool perluSn(String j) => j == brand;

  /// Apakah jenis ini ditagihkan ke brand. Dipakai Rekap Brand dan bagi
  /// hasil untuk menyaring; toko tidak menagih dirinya sendiri.
  static bool ditagihkan(String j) => j == brand;
}
