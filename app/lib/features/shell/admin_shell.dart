import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme.dart';
import '../claims/claims_view.dart';
import '../reports/reports_view.dart';
import '../settings/settings_view.dart';

/// Kerangka untuk layar lebar: navigasi tetap di kiri, isi berganti di kanan.
///
/// Bagian admin tidak lagi tersebar sebagai halaman terpisah yang harus
/// dibuka satu per satu -- semuanya dijangkau dari satu tempat.
class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);

    final sections = <_Section>[
      const _Section('Klaim', Icons.description_outlined),
      if (isAdmin) const _Section('Rekap', Icons.insights_outlined),
      if (isAdmin) const _Section('Pengaturan', Icons.tune),
    ];

    // Peran bisa berubah saat sinkronisasi menurunkan profil; jangan sampai
    // tersisa di bagian yang tidak lagi boleh dibuka.
    final index = _index.clamp(0, sections.length - 1);

    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      body: Row(
        children: [
          _Sidebar(
            sections: sections,
            selected: index,
            onSelect: (i) => setState(() => _index = i),
          ),
          Expanded(
            child: switch (sections[index].label) {
              'Rekap' => const ReportsView(),
              'Pengaturan' => const SettingsView(),
              _ => const ClaimsView(),
            },
          ),
        ],
      ),
    );
  }
}

class _Section {
  const _Section(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({
    required this.sections,
    required this.selected,
    required this.onSelect,
  });

  final List<_Section> sections;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;

    return Container(
      width: 232,
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(right: BorderSide(color: Color(0xFFE4E7E7))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          // Penanda merah, bukan logo. Blok warna adalah bahasa poster Swiss.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              children: [
                Container(width: 22, height: 22, color: AppColors.red),
                const SizedBox(width: AppSpacing.xs),
                const Expanded(
                  child: Text(
                    'KLAIM\nGARANSI',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      height: 1.25,
                      color: AppColors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          for (var i = 0; i < sections.length; i++)
            _NavItem(
              section: sections[i],
              selected: i == selected,
              onTap: () => onSelect(i),
            ),

          const Spacer(),
          const _SyncRow(),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?.nama ?? '—',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        (profile?.role ?? '').toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Keluar',
                  iconSize: 18,
                  color: AppColors.grey,
                  icon: const Icon(Icons.logout),
                  onPressed: () => ref.read(supabaseProvider).auth.signOut(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final _Section section;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            color: active
                ? AppColors.lightGrey
                : (_hover ? const Color(0xFFF8F9F9) : Colors.transparent),
            // Batang merah menandai bagian yang sedang dibuka.
            border: Border(
              left: BorderSide(
                color: active ? AppColors.red : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.section.icon,
                size: 17,
                color: active ? AppColors.black : AppColors.grey,
              ),
              const SizedBox(width: AppSpacing.s),
              Text(
                widget.section.label.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  letterSpacing: 0.9,
                  color: active ? AppColors.black : AppColors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncRow extends ConsumerWidget {
  const _SyncRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingCountProvider).valueOrNull ?? 0;
    final status = ref.watch(syncStatusProvider).valueOrNull;
    final state = status?.state ?? SyncState.idle;

    final (icon, color, text) = switch (state) {
      SyncState.syncing => (Icons.sync, AppColors.blue, 'Menyinkronkan'),
      SyncState.offline => (
          Icons.cloud_off_outlined,
          AppColors.red,
          'Offline · $pending antre',
        ),
      SyncState.error => (Icons.error_outline, AppColors.red, 'Sinkron gagal'),
      SyncState.idle => (
          Icons.cloud_done_outlined,
          AppColors.grey,
          pending > 0 ? '$pending menunggu kirim' : 'Tersinkron',
        ),
    };

    return InkWell(
      onTap: () => ref.read(syncServiceProvider).syncNow(),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.s,
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 11, color: color),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
