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

  // Palet Swiss hanya punya tiga warna kerja, jadi pembeda status memakai
  // warna DAN isian. Yang menuntut tindakan diberi bobot visual paling
  // besar; yang sudah selesai sengaja mundur ke belakang supaya perhatian
  // jatuh ke pekerjaan yang masih berjalan.
  static const _colors = {
    open: AppColors.blue,
    proses: AppColors.blue,
    tungguPart: AppColors.red,
    close: AppColors.black,
    batal: AppColors.grey,
  };

  static const _filled = {
    open: false,
    proses: true,
    tungguPart: true,
    close: false,
    batal: false,
  };

  static String label(String s) => _labels[s] ?? s;
  static Color color(String s) => _colors[s] ?? AppColors.grey;
  static bool isFilled(String s) => _filled[s] ?? false;
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.compact = false});

  final String status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = ClaimStatus.color(status);
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
