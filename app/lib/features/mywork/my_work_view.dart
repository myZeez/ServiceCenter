import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/bento.dart';
import '../claims/widgets/klaim_saya_summary.dart';
import '../service/widgets/omset_saya_card.dart';

/// Ringkasan kerja pribadi untuk layar lebar.
///
/// Di layar sempit, omset ada di Servisku dan ringkasan garansi ada di
/// Klaim Garansi agar teknisi tidak perlu membuka halaman tambahan.
class MyWorkView extends ConsumerWidget {
  const MyWorkView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(title: 'Pekerjaanku', subtitle: profile?.nama),
          const SizedBox(height: AppSpacing.s),
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              children: [
                OmsetSayaCard(),
                SizedBox(height: AppSpacing.s),
                KlaimSayaSummary(judul: 'Laporan Garansi'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
