import 'package:flutter/material.dart';

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

  static const _colors = {
    open: Color(0xFF0EA5E9),
    proses: Color(0xFFF59E0B),
    tungguPart: Color(0xFFA855F7),
    close: Color(0xFF10B981),
    batal: Color(0xFF6B7280),
  };

  static String label(String s) => _labels[s] ?? s;
  static Color color(String s) => _colors[s] ?? const Color(0xFF6B7280);
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final c = ClaimStatus.color(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Text(
        ClaimStatus.label(status),
        style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
