import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/peran.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../parts/part_orders_view.dart';

/// Layar gudang di perangkat sempit.
///
/// Gudang hanya punya satu halaman: pesanan part beserta modalnya. Tabelnya
/// lebar -- ada harga, modal, dan nomor PO -- jadi di layar sempit ia digeser
/// ke samping alih-alih dipaksa muat.
class GudangPage extends ConsumerWidget {
  const GudangPage({super.key});

  static const lebarMinimum = 1100.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.sm,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pemesanan Part'),
            if (profile != null)
              Text(
                '${profile.nama} — ${Peran.label(profile.role)}'.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: context.warna.teksLembut,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout, size: 20),
            onPressed: () => ref.read(supabaseProvider).auth.signOut(),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: math.max(c.maxWidth, lebarMinimum),
            height: c.maxHeight,
            child: const PartOrdersView(),
          ),
        ),
      ),
    );
  }
}
