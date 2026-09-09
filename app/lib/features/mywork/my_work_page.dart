import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'my_work_view.dart';

/// Pembungkus berhalaman untuk layar sempit. Di layar lebar, MyWorkView
/// dipasang langsung di dalam AdminShell tanpa app bar.
class MyWorkPage extends StatelessWidget {
  const MyWorkPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.warna.teredam,
      body: const SafeArea(child: MyWorkView()),
    );
  }
}
