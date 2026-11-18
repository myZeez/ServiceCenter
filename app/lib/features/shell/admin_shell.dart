import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/fitur.dart';
import '../../core/kaca/kursor_liquid.dart';
import '../../core/peran.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/koneksi.dart';
import '../claims/claims_view.dart';
import '../claims/part_kembali_view.dart';
import '../mywork/my_work_view.dart';
import '../parts/part_orders_view.dart';
import '../parts/parts_view.dart';
import '../persetujuan/persetujuan_view.dart';
import '../reports/reports_view.dart';
import '../revenue/revenue_view.dart';
import '../service/all_notes_view.dart';
import '../service/kerja_teknisi_view.dart';
import '../service/piutang_view.dart';
import '../service/partner_view.dart';
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
    final isAdminSc = ref.watch(isAdminScProvider);
    final sections = menuUntuk(
      ref.watch(currentProfileProvider)?.role,
      adaPart: ref.watch(fiturTanyaHargaProvider),
    );

    // Peran bisa berubah saat sinkronisasi menurunkan profil; jangan sampai
    // tersisa di bagian yang tidak lagi boleh dibuka.
    final index = _index.clamp(0, sections.length - 1);

    return Scaffold(
      // Latar dan sidebar harus menjadi dua tingkat yang tegas. Bila
      // keduanya memakai teredam, menu kiri tenggelam pada monitor yang
      // kontrasnya kurang baik.
      backgroundColor: context.warna.latar,
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
                'Kerja Teknisi' => const KerjaTeknisiView(),
                'Laporan Servis' => const ServiceReportsView(),
                'Piutang' => const PiutangView(),
                'Kirim Partner' => const PartnerView(),
                'Tanya Harga' => const PartsView(),
                'Pemesanan Part' => const PartOrdersView(),
                'Pekerjaanku' => const MyWorkView(),
                'Part Kembali' => const PartKembaliView(),
                'Rekap' => const ReportsView(),
                'Rekap Brand' => const SettlementView(),
                'Pendapatan' => const RevenueView(),
                'Persetujuan' => const PersetujuanView(),
                'Pengaturan' => const SettingsView(),
                _ => ClaimsView(readOnly: isAdminSc),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Isi navigasi tiap peran.
///
/// Admin dan super admin memegang halaman yang berbeda, bukan satu di atas
/// yang lain: super admin mengelola dan membaca laporan, meja depan tetap di
/// admin. Dikelompokkan supaya dua dunia yang berbeda tidak tercampur --
/// layanan ke pelanggan di satu sisi, pengajuan ke brand di sisi lain.
List<BagianMenu> menuUntuk(
  String? peran, {
  bool adaPart = false,
}) => switch (peran) {
  Peran.superAdmin => [
    const BagianMenu('Semua Nota', Icons.inventory_2_outlined, grup: 'Servis'),
    const BagianMenu('Persetujuan', Icons.rule_outlined),
    const BagianMenu('Laporan Servis', Icons.summarize_outlined),
    const BagianMenu('Kerja Teknisi', Icons.assignment_ind_outlined),
    const BagianMenu('Piutang', Icons.account_balance_wallet_outlined),
    const BagianMenu('Kirim Partner', Icons.handshake_outlined),
    // Super admin membaca harga, HPP, dan up dari seluruh pesanan part.
    // Keduanya sedang disimpan -- lihat fiturTanyaHargaProvider.
    if (adaPart) ...[
      const BagianMenu(
        'Tanya Harga',
        Icons.request_quote_outlined,
        grup: 'Part',
      ),
      const BagianMenu('Pemesanan Part', Icons.local_shipping_outlined),
    ],
    // Super admin memegang seluruh garansi: klaim, part kembali, dan rekap.
    const BagianMenu('Klaim', Icons.description_outlined, grup: 'Garansi'),
    const BagianMenu('Part Kembali', Icons.assignment_return_outlined),
    const BagianMenu('Rekap', Icons.insights_outlined),
    const BagianMenu('Rekap Brand', Icons.fact_check_outlined),
    const BagianMenu('Pendapatan', Icons.payments_outlined, grup: 'Keuangan'),
    const BagianMenu('Pengaturan', Icons.tune, grup: 'Lainnya'),
  ],
  Peran.admin => [
    const BagianMenu('Servis', Icons.receipt_long_outlined, grup: 'Pelanggan'),
    const BagianMenu('Semua Nota', Icons.inventory_2_outlined),
    const BagianMenu('Laporan Servis', Icons.summarize_outlined),
    const BagianMenu('Piutang', Icons.account_balance_wallet_outlined),
    // Dua layar atas satu tabel yang sama: yang pertama meja
    // tanya-jawabnya, yang kedua pesanan yang sudah berjalan.
    // Keduanya sedang disimpan -- lihat fiturTanyaHargaProvider.
    if (adaPart) ...[
      const BagianMenu('Tanya Harga', Icons.request_quote_outlined),
      const BagianMenu('Pemesanan Part', Icons.local_shipping_outlined),
    ],
    const BagianMenu('Klaim', Icons.description_outlined, grup: 'Garansi'),
    const BagianMenu('Part Kembali', Icons.assignment_return_outlined),
    const BagianMenu(
      'Pekerjaanku',
      Icons.engineering_outlined,
      grup: 'Lainnya',
    ),
    const BagianMenu('Persetujuan', Icons.rule_outlined),
    const BagianMenu('Pengaturan', Icons.tune),
  ],
  // Gudang melihat satu hal: pesanan part beserta modalnya. Sengaja tidak
  // bergantung pada fiturTanyaHargaProvider -- ini bukan pintu masuk tanya
  // harga, melainkan laporan yang dikirim ke pusat.
  Peran.gudang => const [
    BagianMenu('Pemesanan Part', Icons.local_shipping_outlined, grup: 'Gudang'),
  ],
  Peran.adminSc => const [
    BagianMenu('Klaim', Icons.description_outlined, grup: 'Garansi'),
    BagianMenu('Part Kembali', Icons.assignment_return_outlined),
    BagianMenu('Rekap', Icons.insights_outlined),
    BagianMenu('Rekap Brand', Icons.fact_check_outlined),
    BagianMenu('Laporan Servis', Icons.summarize_outlined, grup: 'Servis'),
    BagianMenu('Piutang', Icons.account_balance_wallet_outlined),
  ],
  // Terbuka untuk semua peran: tiap orang berhak melihat hasil kerjanya
  // sendiri, dan halaman ini tidak memuat angka rupiah.
  _ => const [
    BagianMenu('Klaim', Icons.description_outlined),
    BagianMenu('Pekerjaanku', Icons.engineering_outlined),
  ],
};

class BagianMenu {
  const BagianMenu(this.label, this.icon, {this.grup});

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

  final List<BagianMenu> sections;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final menunggu = sections.any((s) => s.label == 'Persetujuan')
        ? ref.watch(permintaanMenungguProvider).length
        : 0;

    final isiSidebar = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.sm),
        // Penanda merah, bukan logo. Blok warna adalah bahasa poster Swiss.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(
            children: [
              Container(width: 22, height: 22, color: context.warna.bahaya),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'KLAIM\nGARANSI',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    height: 1.25,
                    color: context.warna.teks,
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
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: context.warna.teksLembut,
                ),
              ),
            ),
          _NavItem(
            section: sections[i],
            selected: i == selected,
            onTap: () => onSelect(i),
            jumlah: sections[i].label == 'Persetujuan' ? menunggu : 0,
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
                      Peran.label(profile?.role).toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Keluar',
                iconSize: 18,
                color: context.warna.teksLembut,
                icon: const Icon(Icons.logout),
                onPressed: () => ref.read(supabaseProvider).auth.signOut(),
              ),
            ],
          ),
        ),
      ],
    );

    return Container(
      width: 228,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.warna.permukaan,
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(color: context.warna.garis),
      ),
      child: isiSidebar,
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.section,
    required this.selected,
    required this.onTap,
    this.jumlah = 0,
  });

  final BagianMenu section;
  final bool selected;
  final VoidCallback onTap;

  /// Yang menunggu ditangani di bagian ini. Nol tidak ditampilkan.
  final int jumlah;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected;
    final kursorLiquid = KursorLiquid.aktifDi(context);

    return MouseRegion(
      cursor: kursorLiquid ? SystemMouseCursors.none : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            color: active
                ? context.warna.teredam
                : (_hover
                      ? context.warna.teks.withValues(alpha: 0.03)
                      : Colors.transparent),
            // Batang merah menandai bagian yang sedang dibuka.
            border: Border(
              left: BorderSide(
                color: active ? context.warna.bahaya : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.section.icon,
                size: 17,
                color: active ? context.warna.teks : context.warna.teksLembut,
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  widget.section.label.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: 0.9,
                    color: active
                        ? context.warna.teks
                        : context.warna.teksLembut,
                  ),
                ),
              ),
              if (widget.jumlah > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: context.warna.bahaya,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${widget.jumlah}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: context.warna.kertas,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
