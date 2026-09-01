import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/local/database.dart';
import '../../core/providers.dart';
import '../../core/status.dart';

final _dateFmt = DateFormat('dd MMMM yyyy, HH:mm');

class ClaimDetailPage extends ConsumerWidget {
  const ClaimDetailPage(this.claimId, {super.key});

  final String claimId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claim = ref.watch(claimByIdProvider(claimId)).valueOrNull;
    final isAdmin = ref.watch(isAdminProvider);

    if (claim == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final brands = {
      for (final b in ref.watch(brandsProvider).valueOrNull ?? const []) b.id: b.nama
    };
    final techs = {
      for (final p in ref.watch(techniciansProvider).valueOrNull ?? const [])
        p.id: p.nama
    };
    final partTypes = {
      for (final p in ref.watch(partTypesProvider).valueOrNull ?? const [])
        p.id: p.nama
    };
    final parts = ref.watch(partsOfClaimProvider(claimId)).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(claim.noPerbaikan ?? 'Detail Klaim'),
        actions: [
          if (claim.syncPending)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Tooltip(
                message: 'Belum terkirim ke server',
                child: Icon(Icons.schedule, color: Colors.orange),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      StatusChip(claim.status),
                      const Spacer(),
                      Text(
                        _dateFmt.format(claim.tanggal),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _Field('Brand', brands[claim.brandId] ?? '-'),
                  _Field('Nama Pelanggan', claim.namaPelanggan),
                  _Field('Telp', claim.telp ?? '-'),
                  _Field('Serial Number', claim.sn),
                  _Field('Keluhan', claim.keluhan ?? '-'),
                  _Field('No Perbaikan', claim.noPerbaikan ?? '-'),
                  _Field('Catatan', claim.catatan ?? '-'),

                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Teknisi ditonjolkan karena ini satu-satunya kolom yang
                  // boleh diubah teknisi, dan yang menentukan bagi hasil.
                  Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.engineering),
                      title: const Text('Teknisi'),
                      subtitle: Text(
                        techs[claim.teknisiId] ?? 'Belum ditugaskan',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: TextButton(
                        onPressed: () => _pickTechnician(context, ref, claim),
                        child: const Text('Ganti'),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'Part yang Diklaim',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (parts.isEmpty)
                    Text(
                      'Tidak ada part yang diklaim.',
                      style: TextStyle(color: Colors.grey.shade600),
                    )
                  else
                    for (final p in parts)
                      Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.memory, size: 20),
                          title: Text(partTypes[p.partTypeId] ?? '-'),
                          subtitle: Text('SN bad part: ${p.snBadPart ?? '-'}'),
                        ),
                      ),

                  const SizedBox(height: 24),
                  if (isAdmin)
                    OutlinedButton.icon(
                      onPressed: () => _pickStatus(context, ref, claim),
                      icon: const Icon(Icons.flag_outlined),
                      label: const Text('Ubah Status'),
                    )
                  else
                    Text(
                      'Hanya admin yang dapat mengubah status klaim.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTechnician(
    BuildContext context,
    WidgetRef ref,
    Claim claim,
  ) async {
    final techs = ref.read(techniciansProvider).valueOrNull ?? const <Profile>[];

    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Pilih Teknisi'),
        children: [
          for (final t in techs)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, t.id),
              child: Row(
                children: [
                  if (t.id == claim.teknisiId)
                    const Icon(Icons.check, size: 18)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Text(t.nama),
                ],
              ),
            ),
        ],
      ),
    );

    if (picked == null || picked == claim.teknisiId) return;

    await ref.read(databaseProvider).reassignTechnician(claim.id, picked);
    ref.read(syncServiceProvider).syncNow();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Teknisi diganti. Perubahan ini tercatat di riwayat.'),
      ),
    );
  }

  Future<void> _pickStatus(
    BuildContext context,
    WidgetRef ref,
    Claim claim,
  ) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Ubah Status'),
        children: [
          for (final s in ClaimStatus.all)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, s),
              child: Row(
                children: [
                  if (s == claim.status)
                    const Icon(Icons.check, size: 18)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  StatusChip(s),
                ],
              ),
            ),
        ],
      ),
    );

    if (picked == null || picked == claim.status) return;

    await ref.read(databaseProvider).updateStatus(claim.id, picked);
    ref.read(syncServiceProvider).syncNow();
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 15)),
          ],
        ),
      );
}
