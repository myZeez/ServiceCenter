import 'dart:ui';

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

const _uuid = Uuid();
final _dateFmt = DateFormat('dd MMM yyyy');
final _stampFmt = DateFormat('dd MMM yyyy · HH:mm');

/// Membuka klaim sebagai lapisan di atas daftar, bukan halaman terpisah.
///
/// Daftar di belakangnya tetap terlihat samar, jadi tidak ada rasa
/// "berpindah tempat" -- yang mahal ketika admin membuka puluhan klaim
/// berturut-turut. [claim] null berarti membuat klaim baru.
Future<void> showClaimDialog(BuildContext context, {Claim? claim}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Tutup',
    barrierColor: const Color(0x33000000),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) => ClaimDialog(claim: claim),
    transitionBuilder: (context, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 8 * curved.value,
          sigmaY: 8 * curved.value,
        ),
        child: FadeTransition(
          opacity: curved,
          child: Transform.scale(
            scale: 0.985 + (0.015 * curved.value),
            child: child,
          ),
        ),
      );
    },
  );
}

class ClaimDialog extends ConsumerStatefulWidget {
  const ClaimDialog({super.key, this.claim});

  final Claim? claim;

  bool get isNew => claim == null;

  @override
  ConsumerState<ClaimDialog> createState() => _ClaimDialogState();
}

class _PartEntry {
  _PartEntry({this.existingId, this.typeId, String? sn})
      : sn = TextEditingController(text: sn ?? '');

  final String? existingId;
  int? typeId;
  final TextEditingController sn;

  void dispose() => sn.dispose();
}

class _ClaimDialogState extends ConsumerState<ClaimDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nama = TextEditingController();
  final _telp = TextEditingController();
  final _snUnit = TextEditingController();
  final _keluhan = TextEditingController();
  final _noPerbaikan = TextEditingController();
  final _catatan = TextEditingController();

  int? _brandId;
  String? _teknisiId;
  String _status = ClaimStatus.open;
  late DateTime _tanggal;

  List<_PartEntry> _parts = [];
  final List<String> _removedPartIds = [];

  bool _ready = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final c = widget.claim;

    if (c == null) {
      _tanggal = DateTime.now();
      _parts = [_PartEntry()];
      _ready = true;
      return;
    }

    _tanggal = c.tanggal;
    _brandId = c.brandId;
    _teknisiId = c.teknisiId;
    _status = c.status;
    _nama.text = c.namaPelanggan;
    _telp.text = c.telp ?? '';
    _snUnit.text = c.sn;
    _keluhan.text = c.keluhan ?? '';
    _noPerbaikan.text = c.noPerbaikan ?? '';
    _catatan.text = c.catatan ?? '';
    _loadParts(c.id);
  }

  Future<void> _loadParts(String claimId) async {
    final rows = await ref.read(databaseProvider).partsOf(claimId);
    if (!mounted) return;
    setState(() {
      _parts = rows.isEmpty
          ? [_PartEntry()]
          : [
              for (final r in rows)
                _PartEntry(
                  existingId: r.id,
                  typeId: r.partTypeId,
                  sn: r.snBadPart,
                ),
            ];
      _ready = true;
    });
  }

  @override
  void dispose() {
    _nama.dispose();
    _telp.dispose();
    _snUnit.dispose();
    _keluhan.dispose();
    _noPerbaikan.dispose();
    _catatan.dispose();
    for (final p in _parts) {
      p.dispose();
    }
    super.dispose();
  }

  String? _nullIfEmpty(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _busy = true);

    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    final claimId = widget.claim?.id ?? _uuid.v4();

    if (widget.isNew) {
      await db.upsertClaimLocal(
        ClaimsCompanion.insert(
          id: claimId,
          tanggal: _tanggal,
          brandId: _brandId!,
          namaPelanggan: _nama.text.trim(),
          telp: Value(_nullIfEmpty(_telp)),
          sn: _snUnit.text.trim(),
          teknisiId: Value(_teknisiId),
          keluhan: Value(_nullIfEmpty(_keluhan)),
          noPerbaikan: Value(_nullIfEmpty(_noPerbaikan)),
          status: Value(_status),
          catatan: Value(_nullIfEmpty(_catatan)),
          createdBy: user.id,
          createdAt: now,
          updatedAt: now,
          syncPending: const Value(true),
        ),
      );
    } else {
      await db.updateClaimFull(
        claimId,
        ClaimsCompanion(
          tanggal: Value(_tanggal),
          brandId: Value(_brandId!),
          namaPelanggan: Value(_nama.text.trim()),
          telp: Value(_nullIfEmpty(_telp)),
          sn: Value(_snUnit.text.trim()),
          teknisiId: Value(_teknisiId),
          keluhan: Value(_nullIfEmpty(_keluhan)),
          noPerbaikan: Value(_nullIfEmpty(_noPerbaikan)),
          status: Value(_status),
          catatan: Value(_nullIfEmpty(_catatan)),
          updatedAt: Value(now),
          syncPending: const Value(true),
        ),
      );
    }

    for (final id in _removedPartIds) {
      await db.markPartDeleted(id);
    }
    for (final p in _parts.where((e) => e.typeId != null)) {
      await db.upsertPartLocal(
        ClaimPartsCompanion.insert(
          id: p.existingId ?? _uuid.v4(),
          claimId: claimId,
          partTypeId: p.typeId!,
          snBadPart: Value(p.sn.text.trim().isEmpty ? null : p.sn.text.trim()),
          syncPending: const Value(true),
        ),
      );
    }

    ref.read(syncServiceProvider).syncNow();

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.isNew ? 'Klaim tersimpan' : 'Perubahan tersimpan'),
      ),
    );
  }

  /// Teknisi hanya boleh menyentuh kolom teknisi. Kunci ini menyusul aturan
  /// yang sudah ditegakkan trigger di server -- di sini agar tidak ada
  /// kolom yang bisa diketik lalu ditolak diam-diam saat sinkron.
  Future<void> _saveTechnicianOnly() async {
    if (widget.claim == null || _teknisiId == null) return;
    setState(() => _busy = true);

    await ref
        .read(databaseProvider)
        .reassignTechnician(widget.claim!.id, _teknisiId!);
    ref.read(syncServiceProvider).syncNow();

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Teknisi diganti. Perubahan ini tercatat di riwayat.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final brands = ref.watch(brandsProvider).valueOrNull ?? const <Brand>[];
    final techs = ref.watch(techniciansProvider).valueOrNull ?? const <Profile>[];
    final types = ref.watch(partTypesProvider).valueOrNull ?? const <PartType>[];
    final allBrands =
        ref.watch(allBrandsProvider).valueOrNull ?? const <Brand>[];

    if (widget.isNew) _teknisiId ??= ref.read(currentUserProvider)?.id;

    final brandName = {for (final b in allBrands) b.id: b.nama}[_brandId];
    final size = MediaQuery.sizeOf(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.base),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: 1040,
            constraints: BoxConstraints(maxHeight: size.height - 80),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.base),
              border: Border.all(color: const Color(0xFFE4E7E7)),
            ),
            child: !_ready
                ? const SizedBox(
                    height: 240,
                    child: Center(
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _header(brandName, isAdmin),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.sm,
                              AppSpacing.s,
                              AppSpacing.sm,
                              AppSpacing.sm,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _leftColumn(brands, isAdmin)),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: _rightColumn(techs, types, isAdmin),
                                ),
                              ],
                            ),
                          ),
                        ),
                        _footer(isAdmin),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------

  Widget _header(String? brandName, bool isAdmin) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.s,
        AppSpacing.s,
        AppSpacing.s,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.black, width: 1.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isNew
                      ? 'Klaim Baru'
                      : (_nama.text.isEmpty ? 'Klaim' : _nama.text),
                  style: Theme.of(context).textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    ?brandName,
                    _dateFmt.format(_tanggal),
                    if (_noPerbaikan.text.trim().isNotEmpty)
                      _noPerbaikan.text.trim(),
                  ].join('  ·  '),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          if (!widget.isNew) ...[
            StatusChip(_status),
            const SizedBox(width: AppSpacing.s),
          ],
          if (!isAdmin && !widget.isNew)
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.xs),
              child: Tooltip(
                message: 'Hanya kolom teknisi yang bisa kamu ubah',
                child: Icon(Icons.lock_outline, size: 15, color: AppColors.grey),
              ),
            ),
          IconButton(
            iconSize: 18,
            color: AppColors.grey,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _leftColumn(List<Brand> brands, bool isAdmin) {
    final editable = isAdmin || widget.isNew;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Unit'),
        const SizedBox(height: AppSpacing.s),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LabeledField(
                label: 'Brand',
                required: true,
                child: DropdownButtonFormField<int>(
                  initialValue: _brandId,
                  isExpanded: true,
                  hint: const Text('Pilih'),
                  onChanged:
                      editable ? (v) => setState(() => _brandId = v) : null,
                  items: [
                    for (final b in brands)
                      DropdownMenuItem(value: b.id, child: Text(b.nama)),
                  ],
                  validator: (v) => v == null ? 'Wajib dipilih' : null,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: LabeledField(
                label: 'Tanggal Masuk',
                child: OutlinedButton(
                  onPressed: editable && !widget.isNew ? _pickDate : null,
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    side: const BorderSide(color: Color(0xFFCFD5D4), width: 1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s,
                      vertical: 13,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _dateFmt.format(_tanggal),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        LabeledField(
          label: 'Serial Number',
          required: true,
          child: TextFormField(
            controller: _snUnit,
            readOnly: !editable,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              suffixIcon: editable
                  ? ScanFieldButton(
                      onScanned: (v) => setState(() => _snUnit.text = v),
                    )
                  : null,
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'SN wajib diisi' : null,
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        LabeledField(
          label: 'Keluhan',
          child: TextFormField(
            controller: _keluhan,
            readOnly: !editable,
            maxLines: 2,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'NO POWER, MATI TOTAL'),
          ),
        ),

        const SizedBox(height: AppSpacing.sm),
        const SectionLabel('Pelanggan'),
        const SizedBox(height: AppSpacing.s),
        LabeledField(
          label: 'Nama',
          required: true,
          child: TextFormField(
            controller: _nama,
            readOnly: !editable,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        LabeledField(
          label: 'Telepon',
          child: TextFormField(
            controller: _telp,
            readOnly: !editable,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(hintText: '0812-3456-7890'),
          ),
        ),
      ],
    );
  }

  Widget _rightColumn(
    List<Profile> techs,
    List<PartType> types,
    bool isAdmin,
  ) {
    final editable = isAdmin || widget.isNew;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Penanganan'),
        const SizedBox(height: AppSpacing.s),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LabeledField(
                // Selalu bisa diubah, apa pun perannya. Ini kolom yang
                // memindahkan pekerjaan dari satu teknisi ke teknisi lain.
                label: 'Teknisi',
                child: DropdownButtonFormField<String>(
                  initialValue: _teknisiId,
                  isExpanded: true,
                  onChanged: (v) => setState(() => _teknisiId = v),
                  items: [
                    for (final t in techs)
                      DropdownMenuItem(value: t.id, child: Text(t.nama)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: LabeledField(
                label: 'Status',
                child: DropdownButtonFormField<String>(
                  initialValue: _status,
                  isExpanded: true,
                  onChanged:
                      editable ? (v) => setState(() => _status = v!) : null,
                  items: [
                    for (final s in ClaimStatus.all)
                      DropdownMenuItem(
                        value: s,
                        child: Text(ClaimStatus.label(s)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        LabeledField(
          label: 'No Perbaikan / RMA',
          child: TextFormField(
            controller: _noPerbaikan,
            readOnly: !editable,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'IDD7R20024'),
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        LabeledField(
          label: 'Catatan',
          child: TextFormField(
            controller: _catatan,
            readOnly: !editable,
            maxLines: 2,
          ),
        ),

        const SizedBox(height: AppSpacing.sm),
        SectionLabel(
          'Part yang Diklaim',
          trailing: editable
              ? InlineAction(
                  label: 'Tambah',
                  onTap: () => setState(() => _parts.add(_PartEntry())),
                )
              : null,
        ),
        const SizedBox(height: AppSpacing.s),
        for (var i = 0; i < _parts.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                SizedBox(
                  width: 128,
                  child: DropdownButtonFormField<int>(
                    initialValue: _parts[i].typeId,
                    isExpanded: true,
                    hint: const Text('Part'),
                    onChanged: editable
                        ? (v) => setState(() => _parts[i].typeId = v)
                        : null,
                    items: [
                      for (final t in types)
                        DropdownMenuItem(value: t.id, child: Text(t.kode)),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: TextFormField(
                    controller: _parts[i].sn,
                    readOnly: !editable,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'SN bad part',
                      suffixIcon: editable
                          ? ScanFieldButton(
                              title: 'Pindai SN Bad Part',
                              onScanned: (v) =>
                                  setState(() => _parts[i].sn.text = v),
                            )
                          : null,
                    ),
                  ),
                ),
                if (editable)
                  IconButton(
                    iconSize: 16,
                    color: AppColors.red,
                    icon: const Icon(Icons.close),
                    onPressed: () => _removePart(i),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _footer(bool isAdmin) {
    final c = widget.claim;
    final editable = isAdmin || widget.isNew;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.s,
        AppSpacing.sm,
        AppSpacing.s,
      ),
      decoration: const BoxDecoration(
        color: AppColors.lightGrey,
        border: Border(top: BorderSide(color: Color(0xFFE4E7E7))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              c == null
                  ? 'Tanggal terisi otomatis. Data tersimpan di perangkat dulu.'
                  : 'Diubah terakhir ${_stampFmt.format(c.updatedAt)}'
                      '${c.syncPending ? '  ·  belum terkirim' : ''}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('BATAL'),
          ),
          const SizedBox(width: AppSpacing.xs),
          FilledButton(
            onPressed: _busy
                ? null
                : (editable ? _save : _saveTechnicianOnly),
            child: _busy
                ? const SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : Text(
                    widget.isNew
                        ? 'SIMPAN KLAIM'
                        : (editable ? 'SIMPAN PERUBAHAN' : 'SIMPAN TEKNISI'),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      _tanggal = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _tanggal.hour,
        _tanggal.minute,
      );
    });
  }

  void _removePart(int i) {
    setState(() {
      final removed = _parts.removeAt(i);
      if (removed.existingId != null) _removedPartIds.add(removed.existingId!);
      removed.dispose();
      if (_parts.isEmpty) _parts.add(_PartEntry());
    });
  }
}
