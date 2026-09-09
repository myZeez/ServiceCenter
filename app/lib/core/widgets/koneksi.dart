import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme.dart';

/// Menunjukkan apakah layar masih mengikuti server.
///
/// Dulu di tempat ini ada indikator sinkronisasi dengan angka antrean.
/// Antreannya sudah tidak ada -- data tidak lagi menginap di perangkat --
/// jadi yang tersisa untuk diberitahukan hanyalah tersambung atau tidak.
/// Itu justru yang paling penting sekarang: saat putus, yang terbaca di
/// layar adalah keadaan terakhir sebelum putus, bukan keadaan sekarang.
class IndikatorKoneksi extends ConsumerWidget {
  const IndikatorKoneksi({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Selama keadaannya belum terbaca, dianggap tersambung. Menyalakan
    // peringatan merah sekejap tiap kali aplikasi dibuka hanya mengajari
    // orang untuk mengabaikannya.
    final tersambung = ref.watch(koneksiProvider).valueOrNull ?? true;

    return Tooltip(
      message: tersambung
          ? 'Tersambung — perubahan dari perangkat lain langsung tampil'
          : 'Terputus — yang tampil adalah keadaan terakhir, dan data baru '
                'tidak bisa disimpan',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              tersambung ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
              size: 18,
              color: tersambung ? context.warna.teksLembut : context.warna.bahaya,
            ),
            if (!tersambung) ...[
              const SizedBox(width: 6),
              Text(
                'TERPUTUS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: context.warna.bahaya,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
