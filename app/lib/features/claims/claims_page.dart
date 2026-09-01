import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/local/database.dart';
import '../../core/providers.dart';
import '../../core/status.dart';
import '../../core/sync/sync_service.dart';
import '../admin/users_page.dart';
import '../reports/reports_page.dart';
import 'claim_detail_page.dart';
import 'claim_form_page.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

class ClaimsPage extends ConsumerWidget {
  const ClaimsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claims = ref.watch(claimsProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Klaim Garansi'),
            if (profile != null)
              Text(
                '${profile.nama} · ${profile.role}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          const _SyncIndicator(),
          if (isAdmin) ...[
            IconButton(
              tooltip: 'Rekap',
              icon: const Icon(Icons.bar_chart),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReportsPage()),
              ),
            ),
            IconButton(
              tooltip: 'Kelola Pengguna',
              icon: const Icon(Icons.group_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UsersPage()),
              ),
            ),
          ],
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(supabaseProvider).auth.signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          const _FilterBar(),
          const Divider(height: 1),
          Expanded(
            child: claims.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Gagal memuat data: $e')),
              data: (list) {
                if (list.isEmpty) return const _EmptyState();
                return LayoutBuilder(
                  builder: (context, c) => c.maxWidth > 900
                      ? _ClaimTable(list)
                      : _ClaimCards(list),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ClaimFormPage()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Klaim Baru'),
      ),
    );
  }
}

/// Lampu status sinkron. Angka di badge = perubahan yang belum sampai server.
class _SyncIndicator extends ConsumerWidget {
  const _SyncIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingCountProvider).valueOrNull ?? 0;
    final status = ref.watch(syncStatusProvider).valueOrNull;
    final state = status?.state ?? SyncState.idle;

    final (icon, color) = switch (state) {
      SyncState.syncing => (Icons.sync, Colors.blue),
      SyncState.offline => (Icons.cloud_off, Colors.orange),
      SyncState.error => (Icons.error_outline, Colors.red),
      SyncState.idle => (Icons.cloud_done, Colors.green),
    };

    return IconButton(
      tooltip: switch (state) {
        SyncState.offline => 'Offline · $pending menunggu dikirim',
        SyncState.error => 'Sinkron gagal: ${status?.message ?? ''}',
        SyncState.syncing => 'Menyinkronkan...',
        SyncState.idle => pending > 0
            ? '$pending menunggu dikirim'
            : 'Semua data tersinkron',
      },
      onPressed: () => ref.read(syncServiceProvider).syncNow(),
      icon: Badge(
        isLabelVisible: pending > 0,
        label: Text('$pending'),
        child: Icon(icon, color: color),
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(claimFilterProvider);
    final brands = ref.watch(brandsProvider).valueOrNull ?? const [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Cari nama, SN, no perbaikan, atau telp',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => ref
                .read(claimFilterProvider.notifier)
                .update((s) => s.copyWith(query: v)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _Chip(
                  label: 'Semua Brand',
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
                const VerticalDivider(width: 16),
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
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: FilterChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          visualDensity: VisualDensity.compact,
        ),
      );
}

/// Tampilan desktop: mirip spreadsheet lama, supaya tim tidak perlu
/// menyesuaikan kebiasaan.
class _ClaimTable extends ConsumerWidget {
  const _ClaimTable(this.items);

  final List<Claim> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brands = {
      for (final b in ref.watch(brandsProvider).valueOrNull ?? const []) b.id: b.nama
    };
    final techs = {
      for (final p in ref.watch(techniciansProvider).valueOrNull ?? const [])
        p.id: p.nama
    };

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('Tanggal')),
            DataColumn(label: Text('Brand')),
            DataColumn(label: Text('Pelanggan')),
            DataColumn(label: Text('Telp')),
            DataColumn(label: Text('SN')),
            DataColumn(label: Text('Teknisi')),
            DataColumn(label: Text('Keluhan')),
            DataColumn(label: Text('No Perbaikan')),
            DataColumn(label: Text('Status')),
          ],
          rows: [
            for (final c in items)
              DataRow(
                onSelectChanged: (_) => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ClaimDetailPage(c.id)),
                ),
                cells: [
                  DataCell(Text(_dateFmt.format(c.tanggal))),
                  DataCell(Text(brands[c.brandId] ?? '-')),
                  DataCell(Text(c.namaPelanggan)),
                  DataCell(Text(c.telp ?? '-')),
                  DataCell(Text(c.sn)),
                  DataCell(Text(techs[c.teknisiId] ?? '-')),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(
                        c.keluhan ?? '-',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(Text(c.noPerbaikan ?? '-')),
                  DataCell(StatusChip(c.status)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Tampilan HP.
class _ClaimCards extends ConsumerWidget {
  const _ClaimCards(this.items);

  final List<Claim> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brands = {
      for (final b in ref.watch(brandsProvider).valueOrNull ?? const []) b.id: b.nama
    };
    final techs = {
      for (final p in ref.watch(techniciansProvider).valueOrNull ?? const [])
        p.id: p.nama
    };

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final c = items[i];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ClaimDetailPage(c.id)),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    c.namaPelanggan,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (c.syncPending)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.schedule, size: 14, color: Colors.orange),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text('${brands[c.brandId] ?? '-'} · ${c.sn}'),
                Text(
                  c.keluhan ?? 'Tanpa keterangan keluhan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    StatusChip(c.status),
                    const SizedBox(width: 8),
                    Text(
                      techs[c.teknisiId] ?? 'Belum ditugaskan',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Text(
              _dateFmt.format(c.tanggal),
              style: const TextStyle(fontSize: 11),
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Belum ada klaim yang cocok',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
}
