import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/local/database.dart';
import '../../core/providers.dart';
import '../../core/status.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme.dart';
import '../../core/widgets/swiss_widgets.dart';
import '../admin/master_data_page.dart';
import '../admin/users_page.dart';
import '../reports/reports_page.dart';
import '../scan/scan_page.dart';
import 'claim_detail_page.dart';
import 'claim_form_page.dart';

final _dateFmt = DateFormat('dd/MM/yy');
final _dateFmtLong = DateFormat('dd/MM/yyyy');

class ClaimsPage extends ConsumerWidget {
  const ClaimsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claims = ref.watch(claimsProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.sm,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Klaim Garansi'),
            if (profile != null)
              Text(
                '${profile.nama} — ${profile.role}'.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: AppColors.grey,
                ),
              ),
          ],
        ),
        actions: [
          const _SyncIndicator(),
          // Menu tunggal agar app bar di HP tidak penuh ikon.
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            position: PopupMenuPosition.under,
            onSelected: (v) {
              switch (v) {
                case 'rekap':
                  _push(context, const ReportsPage());
                case 'pengguna':
                  _push(context, const UsersPage());
                case 'master':
                  _push(context, const MasterDataPage());
                case 'keluar':
                  ref.read(supabaseProvider).auth.signOut();
              }
            },
            itemBuilder: (_) => [
              if (isAdmin) ...[
                const PopupMenuItem(value: 'rekap', child: Text('Rekap')),
                const PopupMenuItem(
                  value: 'pengguna',
                  child: Text('Kelola Pengguna'),
                ),
                const PopupMenuItem(
                  value: 'master',
                  child: Text('Data Master'),
                ),
                const PopupMenuDivider(),
              ],
              const PopupMenuItem(value: 'keluar', child: Text('Keluar')),
            ],
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Column(
        children: [
          const _FilterBar(),
          Expanded(
            child: claims.when(
              loading: () => const Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (e, _) => EmptyState(
                icon: Icons.error_outline,
                title: 'Gagal memuat data',
                description: '$e',
              ),
              data: (list) {
                if (list.isEmpty) {
                  return EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'Belum ada klaim',
                    description:
                        'Klaim yang kamu catat akan muncul di sini, '
                        'termasuk saat perangkat sedang offline.',
                    action: OutlinedButton(
                      onPressed: () => _push(context, const ClaimFormPage()),
                      child: const Text('CATAT KLAIM PERTAMA'),
                    ),
                  );
                }
                return LayoutBuilder(
                  builder: (context, c) =>
                      c.maxWidth > 900 ? _ClaimTable(list) : _ClaimCards(list),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _push(context, const ClaimFormPage()),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('KLAIM BARU'),
      ),
    );
  }

  static void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

/// Lampu status sinkron. Angka = perubahan yang belum sampai server.
class _SyncIndicator extends ConsumerWidget {
  const _SyncIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingCountProvider).valueOrNull ?? 0;
    final status = ref.watch(syncStatusProvider).valueOrNull;
    final state = status?.state ?? SyncState.idle;

    final (icon, color) = switch (state) {
      SyncState.syncing => (Icons.sync, AppColors.blue),
      SyncState.offline => (Icons.cloud_off_outlined, AppColors.red),
      SyncState.error => (Icons.error_outline, AppColors.red),
      SyncState.idle => (Icons.cloud_done_outlined, AppColors.grey),
    };

    return Tooltip(
      message: switch (state) {
        SyncState.offline => 'Offline — $pending menunggu dikirim',
        SyncState.error => 'Sinkron gagal: ${status?.message ?? ''}',
        SyncState.syncing => 'Menyinkronkan',
        SyncState.idle =>
          pending > 0 ? '$pending menunggu dikirim' : 'Semua tersinkron',
      },
      child: InkWell(
        onTap: () => ref.read(syncServiceProvider).syncNow(),
        borderRadius: BorderRadius.circular(AppRadius.small),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              if (pending > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.red,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '$pending',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
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

class _FilterBar extends ConsumerStatefulWidget {
  const _FilterBar();

  @override
  ConsumerState<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends ConsumerState<_FilterBar> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setQuery(String v) {
    ref.read(claimFilterProvider.notifier).update((s) => s.copyWith(query: v));
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(claimFilterProvider);
    final brands = ref.watch(brandsProvider).valueOrNull ?? const <Brand>[];

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.black, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        0,
        AppSpacing.sm,
        AppSpacing.s,
      ),
      child: Column(
        children: [
          TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Cari nama, SN, no perbaikan, telp',
              prefixIcon:
                  const Icon(Icons.search, size: 18, color: AppColors.grey),
              prefixIconConstraints: const BoxConstraints(minWidth: 38),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (filter.query.isNotEmpty)
                    IconButton(
                      tooltip: 'Hapus pencarian',
                      iconSize: 18,
                      color: AppColors.grey,
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _search.clear();
                        _setQuery('');
                      },
                    ),
                  // Pindai unit yang baru datang untuk langsung melihat
                  // apakah SN-nya pernah masuk sebelumnya.
                  ScanFieldButton(
                    title: 'Pindai SN untuk mencari',
                    onScanned: (v) {
                      _search.text = v;
                      _setQuery(v);
                    },
                  ),
                ],
              ),
            ),
            onChanged: _setQuery,
          ),
          const SizedBox(height: AppSpacing.s),
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              children: [
                _Chip(
                  label: 'Semua',
                  selected: filter.brandId == null,
                  onTap: () => ref
                      .read(claimFilterProvider.notifier)
                      .update((s) => s.copyWith(clearBrand: true)),
                ),
                for (final b in brands)
                  _Chip(
                    label: b.nama,
                    selected: filter.brandId == b.id,
                    onTap: () => ref
                        .read(claimFilterProvider.notifier)
                        .update((s) => s.copyWith(brandId: b.id)),
                  ),
                const _ChipDivider(),
                _Chip(
                  label: 'Semua Status',
                  selected: filter.status == null,
                  onTap: () => ref
                      .read(claimFilterProvider.notifier)
                      .update((s) => s.copyWith(clearStatus: true)),
                ),
                for (final s in ClaimStatus.all)
                  _Chip(
                    label: ClaimStatus.label(s),
                    selected: filter.status == s,
                    accent: ClaimStatus.color(s),
                    onTap: () => ref
                        .read(claimFilterProvider.notifier)
                        .update((f) => f.copyWith(status: s)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final c = accent ?? AppColors.black;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.small),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c : AppColors.white,
            border: Border.all(
              color: selected ? c : const Color(0xFFCFD5D4),
            ),
            borderRadius: BorderRadius.circular(AppRadius.small),
          ),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: selected ? AppColors.white : AppColors.black,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipDivider extends StatelessWidget {
  const _ChipDivider();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        margin: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
        color: const Color(0xFFCFD5D4),
      );
}

/// Tampilan HP. Hierarki dibangun dari bobot dan ukuran huruf, bukan warna.
class _ClaimCards extends ConsumerWidget {
  const _ClaimCards(this.items);

  final List<Claim> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brands = {
      for (final b
          in ref.watch(allBrandsProvider).valueOrNull ?? const <Brand>[])
        b.id: b.nama,
    };
    final techs = {
      for (final p
          in ref.watch(techniciansProvider).valueOrNull ?? const <Profile>[])
        p.id: p.nama,
    };

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.s,
        AppSpacing.sm,
        96,
      ),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, i) {
        final c = items[i];
        return EntryAnimation(
          index: i,
          child: _ClaimCard(
            claim: c,
            brand: brands[c.brandId] ?? '—',
            technician: techs[c.teknisiId],
          ),
        );
      },
    );
  }
}

class _ClaimCard extends StatelessWidget {
  const _ClaimCard({
    required this.claim,
    required this.brand,
    required this.technician,
  });

  final Claim claim;
  final String brand;
  final String? technician;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ClaimDetailPage(claim.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Baris penanda: brand, tanggal, status.
              Row(
                children: [
                  Text(
                    brand.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _dateFmt.format(claim.tanggal),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.4,
                      color: AppColors.grey,
                    ),
                  ),
                  const Spacer(),
                  if (claim.syncPending)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.schedule,
                        size: 13,
                        color: AppColors.red,
                      ),
                    ),
                  StatusChip(claim.status, compact: true),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),

              Text(
                claim.namaPelanggan,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                claim.sn,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.grey,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              if ((claim.keluhan ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  claim.keluhan!,
                  style: const TextStyle(fontSize: 13, height: 1.35),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: AppSpacing.xs),
              const Divider(),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      technician ?? 'Belum ditugaskan',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            technician == null ? FontWeight.w400 : FontWeight.w600,
                        color:
                            technician == null ? AppColors.grey : AppColors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if ((claim.noPerbaikan ?? '').isNotEmpty)
                    Text(
                      claim.noPerbaikan!,
                      style: const TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.5,
                        color: AppColors.grey,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tampilan desktop, tetap menyerupai spreadsheet lama.
class _ClaimTable extends ConsumerWidget {
  const _ClaimTable(this.items);

  final List<Claim> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brands = {
      for (final b
          in ref.watch(allBrandsProvider).valueOrNull ?? const <Brand>[])
        b.id: b.nama,
    };
    final techs = {
      for (final p
          in ref.watch(techniciansProvider).valueOrNull ?? const <Profile>[])
        p.id: p.nama,
    };

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 28,
          headingRowHeight: 44,
          dataRowMinHeight: 44,
          dataRowMaxHeight: 56,
          headingTextStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: AppColors.black,
          ),
          dataTextStyle: const TextStyle(fontSize: 13, color: AppColors.black),
          columns: const [
            DataColumn(label: Text('TANGGAL')),
            DataColumn(label: Text('BRAND')),
            DataColumn(label: Text('PELANGGAN')),
            DataColumn(label: Text('TELP')),
            DataColumn(label: Text('SN')),
            DataColumn(label: Text('TEKNISI')),
            DataColumn(label: Text('KELUHAN')),
            DataColumn(label: Text('NO PERBAIKAN')),
            DataColumn(label: Text('STATUS')),
          ],
          rows: [
            for (final c in items)
              DataRow(
                onSelectChanged: (_) => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ClaimDetailPage(c.id)),
                ),
                cells: [
                  DataCell(Text(_dateFmtLong.format(c.tanggal))),
                  DataCell(Text(brands[c.brandId] ?? '—')),
                  DataCell(Text(c.namaPelanggan)),
                  DataCell(Text(c.telp ?? '—')),
                  DataCell(Text(c.sn)),
                  DataCell(Text(techs[c.teknisiId] ?? '—')),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(
                        c.keluhan ?? '—',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(Text(c.noPerbaikan ?? '—')),
                  DataCell(StatusChip(c.status)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
