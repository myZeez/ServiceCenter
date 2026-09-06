import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/fitur.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/koneksi.dart';
import '../claims/claims_view.dart';
import '../mywork/my_work_view.dart';
import '../parts/part_orders_view.dart';
import '../parts/parts_view.dart';
import '../reports/reports_view.dart';
import '../revenue/revenue_view.dart';
import '../service/all_notes_view.dart';
import '../service/service_reports_view.dart';
import '../service/service_view.dart';
import '../settings/settings_view.dart';
import '../settlement/settlement_view.dart';

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
    final adaPart = ref.watch(fiturTanyaHargaProvider);

    // Dikelompokkan supaya dua dunia yang berbeda tidak tercampur: layanan
    // ke pelanggan di satu sisi, pengajuan ke brand di sisi lain. Keduanya
    // menyangkut unit yang sama tetapi lawan bicaranya berbeda.
    final sections = <_Section>[
      if (isAdmin) ...[
        const _Section(
          'Servis',
          Icons.receipt_long_outlined,
          grup: 'Pelanggan',
        ),
        const _Section('Semua Nota', Icons.inventory_2_outlined),
        const _Section('Laporan Servis', Icons.summarize_outlined),
        // Dua layar atas satu tabel yang sama: yang pertama meja
        // tanya-jawabnya, yang kedua pesanan yang sudah berjalan.
        // Keduanya sedang disimpan -- lihat fiturTanyaHargaProvider.
        if (adaPart) ...[
          const _Section('Tanya Harga', Icons.request_quote_outlined),
          const _Section('Pemesanan Part', Icons.local_shipping_outlined),
        ],
      ],
      _Section(
        'Klaim',
        Icons.description_outlined,
        grup: isAdmin ? 'Garansi' : null,
      ),
      if (isAdmin) ...[
        const _Section('Rekap', Icons.insights_outlined),
        const _Section('Rekap Brand', Icons.fact_check_outlined),
        const _Section('Pendapatan', Icons.payments_outlined),
      ],
      // Terbuka untuk semua peran: tiap orang berhak melihat hasil kerjanya
      // sendiri, dan halaman ini tidak memuat angka rupiah.
      _Section(
        'Pekerjaanku',
        Icons.engineering_outlined,
        grup: isAdmin ? 'Lainnya' : null,
      ),
      if (isAdmin) const _Section('Pengaturan', Icons.tune),
    ];

    // Peran bisa berubah saat sinkronisasi menurunkan profil; jangan sampai
    // tersisa di bagian yang tidak lagi boleh dibuka.
    final index = _index.clamp(0, sections.length - 1);

    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      body: Padding(
        // Jarak di keempat sisi membuat sidebar tampak mengambang di atas
        // bidang, bukan menempel pada tepi jendela.
        padding: const EdgeInsets.all(AppSpacing.s),
        child: Row(
          children: [
            _Sidebar(
              sections: sections,
              selected: index,
              onSelect: (i) => setState(() => _index = i),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: switch (sections[index].label) {
                'Servis' => const ServiceView(),
                'Semua Nota' => const AllNotesView(),
                'Laporan Servis' => const ServiceReportsView(),
                'Tanya Harga' => const PartsView(),
                'Pemesanan Part' => const PartOrdersView(),
                'Pekerjaanku' => const MyWorkView(),
                'Rekap' => const ReportsView(),
                'Rekap Brand' => const SettlementView(),
                'Pendapatan' => const RevenueView(),
                'Pengaturan' => const SettingsView(),
                _ => const ClaimsView(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Section {
  const _Section(this.label, this.icon, {this.grup});

  final String label;
  final IconData icon;

  /// Judul kelompok yang dicetak di atas item ini. Hanya diisi pada item
  /// pertama tiap kelompok.
  final String? grup;
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
    final profile = ref.watch(currentProfileProvider);

    return Container(
      width: 228,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(color: const Color(0xFFE4E7E7)),
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

          for (var i = 0; i < sections.length; i++) ...[
            if (sections[i].grup != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  i == 0 ? 0 : AppSpacing.s,
                  AppSpacing.sm,
                  6,
                ),
                child: Text(
                  sections[i].grup!.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: AppColors.grey,
                  ),
                ),
              ),
            _NavItem(
              section: sections[i],
              selected: i == selected,
              onTap: () => onSelect(i),
            ),
          ],

          const Spacer(),
          const IndikatorKoneksi(),
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

