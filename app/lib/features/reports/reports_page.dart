import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'reports_view.dart';

/// Pembungkus berhalaman untuk layar sempit. Di layar lebar, ReportsView
/// dipasang langsung di dalam AdminShell tanpa app bar.
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.warna.teredam,
      body: const SafeArea(child: ReportsView()),
    );
  }
}
