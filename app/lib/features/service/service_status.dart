import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Nilai status harus sama persis dengan enum service_status di Postgres.
class ServiceStatus {
  static const masuk = 'masuk';
  static const dikerjakan = 'dikerjakan';
  static const tungguPart = 'tunggu_part';
  static const selesai = 'selesai';
  static const diambil = 'diambil';
  static const batal = 'batal';

  static const all = [
    masuk,
    dikerjakan,
    tungguPart,
    selesai,
    diambil,
    batal,
  ];

  static const _labels = {
    masuk: 'Masuk',
    dikerjakan: 'Dikerjakan',
    tungguPart: 'Tunggu Part',
    selesai: 'Selesai',
    diambil: 'Sudah Diambil',
    batal: 'Batal',
  };

  // Mengikuti pola yang sama dengan status klaim: yang menuntut tindakan
  // diberi bobot visual paling besar, yang sudah tuntas mundur ke belakang.
  static const _colors = {
    masuk: AppColors.blue,
    dikerjakan: AppColors.blue,
    tungguPart: AppColors.red,
    selesai: AppColors.red,
    diambil: AppColors.black,
    batal: AppColors.grey,
  };

  static const _filled = {
    masuk: false,
    dikerjakan: true,
    tungguPart: true,
    // Selesai tapi belum diambil justru perlu ditagih -- itu unit yang
    // menumpuk di rak dan uangnya belum masuk.
    selesai: true,
    diambil: false,
    batal: false,
  };

  static String label(String s) => _labels[s] ?? s;
  static Color color(String s) => _colors[s] ?? AppColors.grey;
  static bool isFilled(String s) => _filled[s] ?? false;
}

class ServiceStatusChip extends StatelessWidget {
  const ServiceStatusChip(this.status, {super.key, this.compact = false});

  final String status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = ServiceStatus.color(status);
    final filled = ServiceStatus.isFilled(status);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? c : Colors.transparent,
        border: Border.all(color: c),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Text(
        ServiceStatus.label(status).toUpperCase(),
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
