import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/local/database.dart';
import '../../core/providers.dart';
import '../../core/status.dart';
import '../../core/theme.dart';
import '../../core/widgets/swiss_widgets.dart';

final _dateFmt = DateFormat('dd MMMM yyyy · HH:mm');

class ClaimDetailPage extends ConsumerWidget {
  const ClaimDetailPage(this.claimId, {super.key});

  final String claimId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claim = ref.watch(claimByIdProvider(claimId)).valueOrNull;
    final isAdmin = ref.watch(isAdminProvider);

    if (claim == null) {
      return const Scaffold(
        body: Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

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
    final partTypes = {
      for (final p
          in ref.watch(allPartTypesProvider).valueOrNull ?? const <PartType>[])
        p.id: p,
    };
    final parts =
        ref.watch(partsOfClaimProvider(claimId)).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.sm,
        title: Text(claim.noPerbaikan ?? 'Detail Klaim'),
        actions: [
          if (claim.syncPending)
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.sm),
              child: Tooltip(
                message: 'Belum terkirim ke server',
                child: Icon(Icons.schedule, size: 18, color: AppColors.red),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.s,
          AppSpacing.sm,
          AppSpacing.md,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Kepala: pelanggan sebagai judul, status di sampingnya.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          claim.namaPelanggan,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: StatusChip(claim.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${brands[claim.brandId] ?? '—'}   ${_dateFmt.format(claim.tanggal)}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),

                  const SizedBox(height: AppSpacing.md),
                  const SectionLabel('Unit'),
                  const SizedBox(height: AppSpacing.s),
                  FieldValue('Serial Number', claim.sn, emphasis: true),
                  const SizedBox(height: AppSpacing.s),
                  FieldValue('Keluhan', claim.keluhan ?? '—'),
                  const SizedBox(height: AppSpacing.s),
                  FieldValue('No Perbaikan', claim.noPerbaikan ?? '—'),

                  const SizedBox(height: AppSpacing.md),
                  const SectionLabel('Pelanggan'),
                  const SizedBox(height: AppSpacing.s),
                  FieldValue('Telepon', claim.telp ?? '—'),

                  const SizedBox(height: AppSpacing.md),
                  const SectionLabel('Part yang Diklaim'),
                  const SizedBox(height: AppSpacing.s),
                  if (parts.isEmpty)
                    Text(
                      'Tidak ada part yang diklaim.',
                      style: const TextStyle(color: AppColors.grey),
                    )
                  else
                    for (final p in parts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 92,
                              child: Text(
                                partTypes[p.partTypeId]?.kode ?? '—',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    partTypes[p.partTypeId]?.nama ?? '—',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  Text(
                                    'SN BAD PART  ${p.snBadPart ?? '—'}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                  const SizedBox(height: AppSpacing.md),
                  const SectionLabel('Penanganan'),
                  const SizedBox(height: AppSpacing.s),

                  // Teknisi ditonjolkan: ini satu-satunya kolom yang boleh
                  // diubah teknisi, dan yang menentukan bagi hasil.
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.black, width: 1.5),
                      borderRadius: BorderRadius.circular(AppRadius.base),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: FieldValue(
                            'Teknisi',
                            techs[claim.teknisiId] ?? 'Belum ditugaskan',
                            emphasis: true,
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () => _pickTechnician(context, ref, claim),
                          child: const Text('GANTI'),
                        ),
                      ],
                    ),
                  ),

                  if ((claim.catatan ?? '').isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s),
                    FieldValue('Catatan', claim.catatan!),
                  ],

                  const SizedBox(height: AppSpacing.md),
                  if (isAdmin)
                    OutlinedButton(
                      onPressed: () => _pickStatus(context, ref, claim),
                      child: const Text('UBAH STATUS'),
                    )
                  else
                    Text(
                      'Hanya admin yang dapat mengubah status klaim.',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
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
      builder: (ctx) => _PickerDialog(
        title: 'Pilih Teknisi',
        options: [
          for (final t in techs)
            _PickerOption(value: t.id, label: t.nama, selected: t.id == claim.teknisiId),
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
      builder: (ctx) => _PickerDialog(
        title: 'Ubah Status',
        options: [
          for (final s in ClaimStatus.all)
            _PickerOption(
              value: s,
              label: ClaimStatus.label(s),
              selected: s == claim.status,
              chip: StatusChip(s),
            ),
        ],
      ),
    );

    if (picked == null || picked == claim.status) return;

    await ref.read(databaseProvider).updateStatus(claim.id, picked);
    ref.read(syncServiceProvider).syncNow();
  }
}

class _PickerOption {
  _PickerOption({
    required this.value,
    required this.label,
    required this.selected,
    this.chip,
  });

  final String value;
  final String label;
  final bool selected;
  final Widget? chip;
}

class _PickerDialog extends StatelessWidget {
  const _PickerDialog({required this.title, required this.options});

  final String title;
  final List<_PickerOption> options;

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Text(title),
      contentPadding: const EdgeInsets.only(bottom: AppSpacing.xs),
      children: [
        for (final o in options)
          InkWell(
            onTap: () => Navigator.pop(context, o.value),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: o.selected ? AppColors.red : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: o.chip ??
                        Text(
                          o.label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                o.selected ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
