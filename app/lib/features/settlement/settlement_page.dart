import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'settlement_view.dart';

/// Pembungkus berhalaman untuk layar sempit. Di layar lebar, SettlementView
/// dipasang langsung di dalam AdminShell tanpa app bar.
class SettlementPage extends StatelessWidget {
  const SettlementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.warna.teredam,
      body: const SafeArea(child: SettlementView()),
    );
  }
}
