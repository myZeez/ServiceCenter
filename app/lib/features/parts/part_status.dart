import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Posisi sebuah pesanan part. Nilainya harus sama persis dengan enum
/// part_tahap di Postgres.
class PartTahap {
  static const tanya = 'tanya';
  static const dipesan = 'dipesan';
  static const dipasang = 'dipasang';
  static const selesai = 'selesai';
  static const batal = 'batal';

  static const all = [tanya, dipesan, dipasang, selesai, batal];

  /// Yang sudah lewat meja tanya-jawab dan menjadi pesanan sungguhan.
  /// Inilah isi halaman Pemesanan Part.
  static const dipesanKeAtas = [dipesan, dipasang, selesai];

  static bool sudahDipesan(String tahap) => dipesanKeAtas.contains(tahap);

  static const _labels = {
    tanya: 'Tanya Harga',
    dipesan: 'Part Dipesan',
    dipasang: 'Part Dipasang',
    selesai: 'Selesai',
    batal: 'Batal',
  };

  // Mengikuti aturan yang sama dengan status nota: yang menuntut tindakan
  // diberi bobot paling besar, yang sudah tuntas mundur ke belakang.
  //
  // 'dipasang' sengaja merah. Part sudah menempel di unit pelanggan
  // sementara sisa tagihannya belum masuk -- itu keadaan paling rawan di
  // seluruh alur ini, dan satu-satunya yang benar-benar bisa merugikan
  // toko kalau terlewat.
  static const _colors = {
    tanya: AppColors.blue,
    dipesan: AppColors.blue,
    dipasang: AppColors.red,
    selesai: AppColors.black,
    batal: AppColors.grey,
  };

  static const _filled = {
    tanya: false,
    dipesan: true,
    dipasang: true,
    selesai: false,
    batal: false,
  };

  static String label(String t) => _labels[t] ?? t;
  static Color color(String t) => _colors[t] ?? AppColors.grey;
  static bool isFilled(String t) => _filled[t] ?? false;
}

/// Keadaan barangnya di tangan supplier. Berbeda dari tahap, dan sengaja
/// dipisah: part bisa ready sementara pelanggannya belum tentu jadi.
class PartStok {
  static const ready = 'ready';
  static const kosong = 'kosong';

  static const all = [ready, kosong];

  static const _labels = {ready: 'Ready Stok', kosong: 'No Stok'};

  static String label(String? s) =>
      s == null ? 'Belum dicek' : (_labels[s] ?? s);

  static Color color(String? s) => switch (s) {
    ready => AppColors.black,
    kosong => AppColors.red,
    _ => AppColors.grey,
  };
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
        PartTahap.label(tahap).toUpperCase(),
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

/// Penanda stok. Sengaja bukan chip berbingkai seperti tahap -- dua chip
/// bersebelahan dengan bobot yang sama membuat mata harus membaca
/// keduanya untuk tahu mana yang penting.
class PartStokLabel extends StatelessWidget {
  const PartStokLabel(this.stok, {super.key});

  final String? stok;

  @override
  Widget build(BuildContext context) => Text(
    PartStok.label(stok).toUpperCase(),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontSize: 9.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.7,
      color: PartStok.color(stok),
    ),
  );
}
