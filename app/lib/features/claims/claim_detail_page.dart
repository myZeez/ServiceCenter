import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/local/database.dart';
import '../../core/providers.dart';
import '../../core/status.dart';
import '../../core/theme.dart';
import '../../core/widgets/swiss_widgets.dart';
import '../scan/scan_page.dart';
import 'claim_form_page.dart';

final _dateFmt = DateFormat('dd MMMM yyyy · HH:mm');
final _dateOnlyFmt = DateFormat('dd MMMM yyyy');
const _uuid = Uuid();

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

                  _Editable(
                    label: 'Serial Number',
                    value: claim.sn,
                    emphasis: true,
                    editable: isAdmin,
                    onEdit: () => _editText(
                      context, ref, claim,
                      label: 'Serial Number',
                      initial: claim.sn,
                      required: true,
                      scannable: true,
                      // Aman: kolom wajib tidak pernah lolos validasi kosong.
                      build: (v) => ClaimsCompanion(sn: Value(v!)),
                    ),
                  ),
                  _Editable(
                    label: 'Keluhan',
                    value: claim.keluhan ?? '—',
                    editable: isAdmin,
                    onEdit: () => _editText(
                      context, ref, claim,
                      label: 'Keluhan',
                      initial: claim.keluhan ?? '',
                      multiline: true,
                      build: (v) => ClaimsCompanion(keluhan: Value(v)),
                    ),
                  ),
                  _Editable(
                    label: 'No Perbaikan / RMA',
                    value: claim.noPerbaikan ?? '—',
                    editable: isAdmin,
                    onEdit: () => _editText(
                      context, ref, claim,
                      label: 'No Perbaikan / RMA',
                      initial: claim.noPerbaikan ?? '',
                      hint: 'IDD7R20024',
                      build: (v) => ClaimsCompanion(noPerbaikan: Value(v)),
                    ),
                  ),
                  _Editable(
                    label: 'Brand',
                    value: brands[claim.brandId] ?? '—',
                    editable: isAdmin,
                    onEdit: () async {
                      final picked = await _pick(
                        context,
                        title: 'Pilih Brand',
                        options: [
                          for (final e in brands.entries)
                            _Opt(
                              value: '${e.key}',
                              label: e.value,
                              selected: e.key == claim.brandId,
                            ),
                        ],
                      );
                      if (picked == null) return;
                      await _apply(
                        ref,
                        claim.id,
                        ClaimsCompanion(brandId: Value(int.parse(picked))),
                      );
                    },
                  ),
                  _Editable(
                    label: 'Tanggal Masuk',
                    value: _dateOnlyFmt.format(claim.tanggal),
                    editable: isAdmin,
                    onEdit: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: claim.tanggal,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (picked == null) return;
                      // Jam aslinya dipertahankan; yang dikoreksi tanggalnya.
                      final merged = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        claim.tanggal.hour,
                        claim.tanggal.minute,
                      );
                      await _apply(
                        ref,
                        claim.id,
                        ClaimsCompanion(tanggal: Value(merged)),
                      );
                    },
                  ),

                  const SizedBox(height: AppSpacing.sm),
                  const SectionLabel('Pelanggan'),
                  const SizedBox(height: AppSpacing.s),

                  _Editable(
                    label: 'Nama',
                    value: claim.namaPelanggan,
                    editable: isAdmin,
                    onEdit: () => _editText(
                      context, ref, claim,
                      label: 'Nama Pelanggan',
                      initial: claim.namaPelanggan,
                      required: true,
                      build: (v) => ClaimsCompanion(namaPelanggan: Value(v!)),
                    ),
                  ),
                  _Editable(
                    label: 'Telepon',
                    value: claim.telp ?? '—',
                    editable: isAdmin,
                    onEdit: () => _editText(
                      context, ref, claim,
                      label: 'Telepon',
                      initial: claim.telp ?? '',
                      hint: '0812-3456-7890',
                      keyboard: TextInputType.phone,
                      build: (v) => ClaimsCompanion(telp: Value(v)),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.sm),
                  SectionLabel(
                    'Part yang Diklaim',
                    trailing: isAdmin
                        ? InlineAction(
                            label: 'Tambah',
                            onTap: () => _editPart(context, ref, claim.id, null),
                          )
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.s),
                  if (parts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.s),
                      child: Text(
                        'Tidak ada part yang diklaim.',
                        style: TextStyle(color: AppColors.grey),
                      ),
                    )
                  else
                    for (final p in parts)
                      _PartRow(
                        part: p,
                        type: partTypes[p.partTypeId],
                        editable: isAdmin,
                        onEdit: () => _editPart(context, ref, claim.id, p),
                        onDelete: () => _deletePart(context, ref, p),
                      ),

                  const SizedBox(height: AppSpacing.sm),
                  const SectionLabel('Penanganan'),
                  const SizedBox(height: AppSpacing.s),

                  // Teknisi ditonjolkan: satu-satunya kolom yang boleh diubah
                  // teknisi, dan yang menentukan bagi hasil.
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
                  const SizedBox(height: AppSpacing.s),

                  _Editable(
                    label: 'Status',
                    value: ClaimStatus.label(claim.status),
                    editable: isAdmin,
                    onEdit: () => _pickStatus(context, ref, claim),
                  ),
                  _Editable(
                    label: 'Catatan',
                    value: (claim.catatan ?? '').isEmpty ? '—' : claim.catatan!,
                    editable: isAdmin,
                    onEdit: () => _editText(
                      context, ref, claim,
                      label: 'Catatan',
                      initial: claim.catatan ?? '',
                      multiline: true,
                      build: (v) => ClaimsCompanion(catatan: Value(v)),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.sm),
                  if (isAdmin)
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ClaimFormPage(claim: claim),
                        ),
                      ),
                      child: const Text('UBAH SEMUA SEKALIGUS'),
                    )
                  else
                    Text(
                      'Teknisi hanya dapat mengubah nama teknisi. '
                      'Perubahan data lain dilakukan admin.',
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

  // ------------------------------------------------------------------
  // Penyimpanan
  // ------------------------------------------------------------------

  /// Menyimpan satu kolom. updatedAt dan syncPending selalu ikut supaya
  /// perubahan sekecil apa pun tetap masuk antrean kirim.
  static Future<void> _apply(
    WidgetRef ref,
    String claimId,
    ClaimsCompanion values,
  ) async {
    await ref.read(databaseProvider).updateClaimFull(
          claimId,
          values.copyWith(
            updatedAt: Value(DateTime.now()),
            syncPending: const Value(true),
          ),
        );
    ref.read(syncServiceProvider).syncNow();
  }

  Future<void> _editText(
    BuildContext context,
    WidgetRef ref,
    Claim claim, {
    required String label,
    required String initial,
    required ClaimsCompanion Function(String?) build,
    bool required = false,
    bool multiline = false,
    bool scannable = false,
    String? hint,
    TextInputType? keyboard,
  }) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _TextEditDialog(
        label: label,
        initial: initial,
        required: required,
        multiline: multiline,
        scannable: scannable,
        hint: hint,
        keyboard: keyboard,
      ),
    );
    if (result == null) return;

    // String kosong disimpan sebagai null, bukan "", supaya tampilan dan
    // laporan memperlakukan kolom kosong secara seragam.
    final trimmed = result.trim();
    await _apply(ref, claim.id, build(trimmed.isEmpty ? null : trimmed));
  }

  Future<void> _editPart(
    BuildContext context,
    WidgetRef ref,
    String claimId,
    ClaimPart? part,
  ) async {
    final types = ref.read(partTypesProvider).valueOrNull ?? const <PartType>[];

    final result = await showDialog<({int typeId, String? sn})>(
      context: context,
      builder: (_) => _PartEditDialog(types: types, part: part),
    );
    if (result == null) return;

    await ref.read(databaseProvider).upsertPartLocal(
          ClaimPartsCompanion.insert(
            id: part?.id ?? _uuid.v4(),
            claimId: claimId,
            partTypeId: result.typeId,
            snBadPart: Value(result.sn),
            syncPending: const Value(true),
          ),
        );
    ref.read(syncServiceProvider).syncNow();
  }

  Future<void> _deletePart(
    BuildContext context,
    WidgetRef ref,
    ClaimPart part,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Part?'),
        content: const Text(
          'Part ini akan dihapus dari klaim. Tindakan ini tidak bisa '
          'dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('BATAL'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('HAPUS'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await ref.read(databaseProvider).markPartDeleted(part.id);
    ref.read(syncServiceProvider).syncNow();
  }

  Future<void> _pickTechnician(
    BuildContext context,
    WidgetRef ref,
    Claim claim,
  ) async {
    final techs = ref.read(techniciansProvider).valueOrNull ?? const <Profile>[];

    final picked = await _pick(
      context,
      title: 'Pilih Teknisi',
      options: [
        for (final t in techs)
          _Opt(value: t.id, label: t.nama, selected: t.id == claim.teknisiId),
      ],
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
    final picked = await _pick(
      context,
      title: 'Ubah Status',
      options: [
        for (final s in ClaimStatus.all)
          _Opt(
            value: s,
            label: ClaimStatus.label(s),
            selected: s == claim.status,
            chip: StatusChip(s),
          ),
      ],
    );

    if (picked == null || picked == claim.status) return;
    await ref.read(databaseProvider).updateStatus(claim.id, picked);
    ref.read(syncServiceProvider).syncNow();
  }

  static Future<String?> _pick(
    BuildContext context, {
    required String title,
    required List<_Opt> options,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => _PickerDialog(title: title, options: options),
    );
  }
}

// =====================================================================
// Bagian tampilan
// =====================================================================

/// Kolom dengan tindakan ubah di sisi kanan. Untuk pengguna non-admin,
/// tampil sebagai teks biasa tanpa tombol.
class _Editable extends StatelessWidget {
  const _Editable({
    required this.label,
    required this.value,
    required this.editable,
    required this.onEdit,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final bool editable;
  final VoidCallback onEdit;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: FieldValue(label, value, emphasis: emphasis)),
          if (editable)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xs),
              child: InlineAction(label: 'Ubah', onTap: onEdit),
            ),
        ],
      ),
    );
  }
}

class _PartRow extends StatelessWidget {
  const _PartRow({
    required this.part,
    required this.type,
    required this.editable,
    required this.onEdit,
    required this.onDelete,
  });

  final ClaimPart part;
  final PartType? type;
  final bool editable;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              type?.kode ?? '—',
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
                Text(type?.nama ?? '—', style: const TextStyle(fontSize: 13)),
                Text(
                  'SN BAD PART  ${part.snBadPart ?? '—'}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          if (editable) ...[
            InlineAction(label: 'Ubah', onTap: onEdit),
            const SizedBox(width: AppSpacing.xs),
            InlineAction(label: 'Hapus', onTap: onDelete),
          ],
        ],
      ),
    );
  }
}

// =====================================================================
// Dialog
// =====================================================================

class _TextEditDialog extends StatefulWidget {
  const _TextEditDialog({
    required this.label,
    required this.initial,
    required this.required,
    required this.multiline,
    required this.scannable,
    this.hint,
    this.keyboard,
  });

  final String label;
  final String initial;
  final bool required;
  final bool multiline;
  final bool scannable;
  final String? hint;
  final TextInputType? keyboard;

  @override
  State<_TextEditDialog> createState() => _TextEditDialogState();
}

class _TextEditDialogState extends State<_TextEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.label),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _controller,
            autofocus: true,
            maxLines: widget.multiline ? 4 : 1,
            keyboardType: widget.keyboard,
            textCapitalization: widget.keyboard == TextInputType.phone
                ? TextCapitalization.none
                : TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: widget.hint,
              suffixIcon: widget.scannable
                  ? ScanFieldButton(
                      onScanned: (v) => setState(() => _controller.text = v),
                    )
                  : null,
            ),
            validator: widget.required
                ? (v) => (v == null || v.trim().isEmpty)
                    ? '${widget.label} wajib diisi'
                    : null
                : null,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('BATAL'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, _controller.text);
          },
          child: const Text('SIMPAN'),
        ),
      ],
    );
  }
}

class _PartEditDialog extends StatefulWidget {
  const _PartEditDialog({required this.types, this.part});

  final List<PartType> types;
  final ClaimPart? part;

  @override
  State<_PartEditDialog> createState() => _PartEditDialogState();
}

class _PartEditDialogState extends State<_PartEditDialog> {
  late int? _typeId = widget.part?.partTypeId;
  late final _sn = TextEditingController(text: widget.part?.snBadPart ?? '');
  String? _error;

  @override
  void dispose() {
    _sn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.part == null ? 'Tambah Part' : 'Ubah Part'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LabeledField(
              label: 'Jenis Part',
              required: true,
              child: DropdownButtonFormField<int>(
                initialValue: _typeId,
                isExpanded: true,
                hint: const Text('Pilih part'),
                items: [
                  for (final t in widget.types)
                    DropdownMenuItem(
                      value: t.id,
                      child: Text('${t.kode} — ${t.nama}'),
                    ),
                ],
                onChanged: (v) => setState(() {
                  _typeId = v;
                  _error = null;
                }),
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            LabeledField(
              label: 'SN Bad Part',
              child: TextField(
                controller: _sn,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  suffixIcon: ScanFieldButton(
                    title: 'Pindai SN Bad Part',
                    onScanned: (v) => setState(() => _sn.text = v),
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.red, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('BATAL'),
        ),
        FilledButton(
          onPressed: () {
            if (_typeId == null) {
              setState(() => _error = 'Jenis part wajib dipilih.');
              return;
            }
            final sn = _sn.text.trim();
            Navigator.pop(context, (
              typeId: _typeId!,
              sn: sn.isEmpty ? null : sn,
            ));
          },
          child: const Text('SIMPAN'),
        ),
      ],
    );
  }
}

class _Opt {
  _Opt({
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
  final List<_Opt> options;

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
          ),
      ],
    );
  }
}
