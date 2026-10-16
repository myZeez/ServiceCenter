import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'part_kembali_view.dart';

/// Pembungkus untuk layar sempit. Windows memasang [PartKembaliView]
/// langsung di dalam sidebar utama.
class PartKembaliPage extends StatelessWidget {
  const PartKembaliPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.warna.teredam,
    appBar: AppBar(title: const Text('Part Kembali')),
    body: const SafeArea(top: false, child: PartKembaliView(showHeader: false)),
  );
}
