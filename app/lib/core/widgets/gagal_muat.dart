import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';
import '../data/galat.dart';
import '../theme.dart';
import 'swiss_widgets.dart';

/// Layar gagal memuat yang ikut memeriksa jam perangkat.
///
/// Galat yang muncul di HP pertama kali berbunyi "JWT issued at future" --
/// tepat secara teknis, tetapi tidak menyebut satu pun hal yang bisa
/// dilakukan orang yang membacanya. Penyebabnya jam perangkat yang maju,
/// dan itu bisa diukur sendiri oleh aplikasi alih-alih ditebak.
class GagalMuat extends ConsumerStatefulWidget {
  const GagalMuat(this.galat, {super.key});

  final Object galat;

  @override
  ConsumerState<GagalMuat> createState() => _GagalMuatState();
}

class _GagalMuatState extends ConsumerState<GagalMuat> {
  String? _jam;

  @override
  void initState() {
    super.initState();
    _periksaJam();
  }

  Future<void> _periksaJam() async {
    final selisih = await selisihJam(AppConfig.supabaseUrl);
    if (!mounted) return;
    setState(() => _jam = pesanSelisihJam(selisih));
  }

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline,
      title: 'Gagal memuat data',
      description: [
        pesanGalat(widget.galat),
        if (_jam != null) '\n$_jam',
      ].join(),
      action: _jam == null
          ? null
          : OutlinedButton(
              onPressed: _periksaJam,
              child: const Text('PERIKSA LAGI'),
            ),
    );
  }
}

/// Bentuk ringkas untuk dipakai di tengah halaman yang sudah punya
/// kerangkanya sendiri.
class GagalMuatRingkas extends StatelessWidget {
  const GagalMuatRingkas(this.galat, {super.key});

  final Object galat;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          pesanGalat(galat),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.grey),
        ),
      ),
    );
  }
}
