import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'settings_view.dart';

/// Pembungkus berhalaman untuk layar sempit. Di layar lebar, SettingsView
/// dipasang langsung di dalam AdminShell tanpa app bar.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.lightGrey,
      body: SafeArea(child: SettingsView()),
    );
  }
}
