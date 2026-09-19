import 'package:flutter/material.dart';

import 'theme.dart';

/// Nilai status harus sama persis dengan check status_klaim_dikenal pada
/// tabel claims (migrasi 0027).
///
/// Daftarnya diambil dari buku garansi toko, bukan dikarang, dan urut
/// menurut jalannya pekerjaan -- dropdown dibaca dari atas ke bawah.
class ClaimStatus {
  static const open = 'open';
  static const waitApproval = 'wait_approval';
  static const waitEskalasi = 'wait_eskalasi';
  static const waitStokToko = 'wait_stok_toko';
  static const proses = 'proses';
  static const tungguPart = 'tunggu_part';
  static const ship = 'ship';
  static const partReady = 'part_ready';

  /// Unit dikirim ke pusat brand. Labelnya memuat nama brand klaimnya --
  /// lihat [label].
  static const shipPusat = 'ship_pusat';
  static const ok = 'ok';

  /// Perbaikan tuntas, unit masih di rak. Padanan "Selesai" pada nota.
  static const selesai = 'selesai';

  /// Unit sudah kembali ke pelanggan. Padanan "Sudah Diambil" pada nota.
  static const close = 'close';
  static const batal = 'batal';

  static const all = [
    open,
    waitApproval,
    waitEskalasi,
    waitStokToko,
    proses,
    tungguPart,
    ship,
    partReady,
    shipPusat,
    ok,
    selesai,
    close,
    batal,
  ];

  /// Yang dianggap tuntas bagi brand: masuk Rekap Brand, bagi hasil, dan
  /// hitungan unit selesai.
  ///
  /// Keduanya, bukan Close saja. Brand membayar perbaikannya, bukan
  /// kedatangan pelanggan mengambil unitnya -- menunggu Close berarti unit
  /// yang lama tidak diambil jatuh ke rekap bulan yang salah, atau tidak
  /// masuk sama sekali.
  static const tuntas = [selesai, close];

  static bool isTuntas(String s) => tuntas.contains(s);

  /// Status yang selalu tampil sebagai penyaring, walau jumlahnya nol.
  /// Selebihnya hanya muncul saat memang ada klaim di sana.
  static const utama = [open, proses, tungguPart, selesai, close, batal];

  static const _labels = {
    open: 'Baru Masuk',
    waitApproval: 'Wait Approval Warranty',
    waitEskalasi: 'Wait Eskalasi Teknikal',
    waitStokToko: 'Wait Approval Stok Toko',
    proses: 'Dikerjakan',
    tungguPart: 'Tunggu Part',
    ship: 'Ship',
    partReady: 'Part Ready',
    ok: 'OK',
    selesai: 'Selesai',
    close: 'Close',
    batal: 'Batal',
  };

  /// Untuk chip di kolom tabel yang sempit.
  static const _pendek = {
    waitApproval: 'Wait Approval',
    waitEskalasi: 'Wait Eskalasi',
    waitStokToko: 'Wait Stok Toko',
  };

  static const _filled = {
    proses: true,
    tungguPart: true,
    partReady: true,
    selesai: true,
  };

  /// Nama status seperti yang ditulis di buku garansi.
  ///
  /// [brand] hanya dipakai "Ship Pusat": klaim ASUS terbaca "Ship ASUS
  /// Pusat", klaim MSI "Ship MSI Pusat". Tanpa brand -- di penyaring yang
  /// memuat banyak brand sekaligus -- cukup "Ship Pusat".
  static String label(String s, {String? brand}) {
    if (s == shipPusat) {
      // Tanda pengganti seperti "—" dari daftar yang brandnya belum
      // termuat dihitung kosong: "Ship — Pusat" lebih membingungkan
      // daripada tidak menyebut brand sama sekali.
      final b = brand?.trim() ?? '';
      return RegExp(r'[A-Za-z0-9]').hasMatch(b)
          ? 'Ship ${b.toUpperCase()} Pusat'
          : 'Ship Pusat';
    }
    return _labels[s] ?? s;
  }

  static String pendek(String s, {String? brand}) =>
      _pendek[s] ?? label(s, brand: brand);

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
  ///
  /// Merah untuk semua yang tertahan di luar meja: menunggu brand,
  /// menunggu part, menunggu kiriman. Itu unit yang paling mudah
  /// terlupakan justru karena tidak ada yang bisa dikerjakan atasnya.
  static Color color(BuildContext context, String s) {
    final w = context.warna;
    return switch (s) {
      open || proses || partReady || ok => w.aksen,
      waitApproval ||
      waitEskalasi ||
      waitStokToko ||
      tungguPart ||
      ship ||
      shipPusat => w.bahaya,
      selesai || close => w.teks,
      _ => w.teksLembut,
    };
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(
    this.status, {
    super.key,
    this.compact = false,
    this.brand,
  });

  final String status;
  final bool compact;

  /// Nama brand klaimnya, untuk "Ship `BRAND` Pusat".
  final String? brand;

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
        (compact
                ? ClaimStatus.pendek(status, brand: brand)
                : ClaimStatus.label(status, brand: brand))
            .toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
