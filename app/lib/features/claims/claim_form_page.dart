import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/data/models.dart';
import '../../core/providers.dart';
import '../../core/status.dart';
import '../../core/theme.dart';
import '../../core/widgets/swiss_widgets.dart';
import '../scan/scan_page.dart';

const _uuid = Uuid();
final _dateFmt = DateFormat('dd MMMM yyyy');

/// Satu baris part yang diklaim, beserta SN part rusaknya.
class _PartEntry {
  _PartEntry({this.existingId, this.partTypeId, String? sn})
      : snController = TextEditingController(text: sn ?? '');

  /// Terisi bila baris ini sudah tersimpan sebelumnya.
  final String? existingId;
  int? partTypeId;
  final TextEditingController snController;

  void dispose() => snController.dispose();
}

/// Formulir klaim. Tanpa argumen berarti membuat baru; dengan [claim]
/// berarti menyunting -- dan penyuntingan penuh hanya dibuka untuk admin.
class ClaimFormPage extends ConsumerStatefulWidget {
  const ClaimFormPage({super.key, this.claim});

  final Claim? claim;

  bool get isEdit => claim != null;

  @override
  ConsumerState<ClaimFormPage> createState() => _ClaimFormPageState();
}

class _ClaimFormPageState extends ConsumerState<ClaimFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _nama = TextEditingController();
  final _telp = TextEditingController();
  final _sn = TextEditingController();
  final _keluhan = TextEditingController();
  final _noPerbaikan = TextEditingController();
  final _catatan = TextEditingController();

  int? _brandId;
  String? _teknisiId;
  String _status = ClaimStatus.open;
  late DateTime _tanggal;

  List<_PartEntry> _parts = [];

  /// Part yang dibuang di layar tapi belum dihapus dari basis data.
  final List<String> _removedPartIds = [];

  bool _busy = false;
  bool _partsLoaded = false;

  @override
  void initState() {
    super.initState();

    final c = widget.claim;
    if (c == null) {
      _tanggal = DateTime.now();
      _parts = [_PartEntry()];
      _partsLoaded = true;
      return;
    }

    _tanggal = c.tanggal;
    _brandId = c.brandId;
    _teknisiId = c.teknisiId;
    _status = c.status;
    _nama.text = c.namaPelanggan;
    _telp.text = c.telp ?? '';
    _sn.text = c.sn;
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
                  partTypeId: r.partTypeId,
                  sn: r.snBadPart,
                ),
            ];
      _partsLoaded = true;
    });
  }

  @override
  void dispose() {
    _nama.dispose();
    _telp.dispose();
    _sn.dispose();
    _keluhan.dispose();
    _noPerbaikan.dispose();
    _catatan.dispose();
    for (final p in _parts) {
      p.dispose();
    }
    super.dispose();
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
      // Jam aslinya dipertahankan; yang dikoreksi biasanya tanggalnya.
      _tanggal = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _tanggal.hour,
        _tanggal.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _busy = true);

    final db = ref.read(databaseProvider);
    final claimId = widget.claim?.id ?? _uuid.v4();

    String? nullIfEmpty(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();

    final isi = {
      // Jam lokal saat diinput, bukan saat baris ini sampai di server.
      'tanggal': _tanggal.toUtc().toIso8601String(),
      'brand_id': _brandId!,
      'nama_pelanggan': _nama.text.trim(),
      'telp': nullIfEmpty(_telp),
      'sn': _sn.text.trim(),
      'teknisi_id': _teknisiId,
      'keluhan': nullIfEmpty(_keluhan),
      'no_perbaikan': nullIfEmpty(_noPerbaikan),
      'status': _status,
      'catatan': nullIfEmpty(_catatan),
    };

    if (widget.isEdit) {
      await db.ubahClaim(claimId, isi);
    } else {
      await db.simpanClaim({...isi, 'id': claimId, 'created_by': user.id});
    }

    for (final id in _removedPartIds) {
      await db.hapusPart(id);
    }

    for (final p in _parts.where((e) => e.partTypeId != null)) {
      await db.simpanPart({
        'id': p.existingId ?? _uuid.v4(),
        'claim_id': claimId,
        'part_type_id': p.partTypeId!,
        'sn_bad_part': p.snController.text.trim().isEmpty
            ? null
            : p.snController.text.trim(),
      });
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.isEdit ? 'Perubahan tersimpan' : 'Klaim tersimpan',
        ),
      ),
    );
  }

  void _removePart(int i) {
    setState(() {
      final removed = _parts.removeAt(i);
      if (removed.existingId != null) _removedPartIds.add(removed.existingId!);
      removed.dispose();
      if (_parts.isEmpty) _parts.add(_PartEntry());
    });
  }

  @override
  Widget build(BuildContext context) {
    final brands = ref.watch(brandsProvider).valueOrNull ?? const <Brand>[];
    final techs = ref.watch(techniciansProvider).valueOrNull ?? const <Profile>[];
    final partTypes =
        ref.watch(partTypesProvider).valueOrNull ?? const <PartType>[];

    // Default teknisi = yang sedang login, karena umumnya dialah yang
    // menerima unit di meja.
    if (!widget.isEdit) _teknisiId ??= ref.read(currentUserProvider)?.id;

    if (!_partsLoaded) {
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

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.sm,
        title: Text(widget.isEdit ? 'Ubah Klaim' : 'Klaim Baru'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
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
                    const SectionLabel('Unit'),
                    const SizedBox(height: AppSpacing.s),

                    // Tanggal hanya bisa dikoreksi saat menyunting. Pada
                    // klaim baru ia terisi otomatis dan tidak boleh diutak-atik.
                    if (widget.isEdit) ...[
                      LabeledField(
                        label: 'Tanggal Masuk',
                        child: OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(_dateFmt.format(_tanggal)),
                          ),
                          style: OutlinedButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            side: const BorderSide(
                              color: Color(0xFFCFD5D4),
                              width: 1,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s),
                    ],

                    LabeledField(
                      label: 'Brand',
                      required: true,
                      child: DropdownButtonFormField<int>(
                        initialValue: _brandId,
                        isExpanded: true,
                        hint: const Text('Pilih brand'),
                        items: [
                          for (final b in brands)
                            DropdownMenuItem(value: b.id, child: Text(b.nama)),
                        ],
                        onChanged: (v) => setState(() => _brandId = v),
                        validator: (v) => v == null ? 'Brand wajib dipilih' : null,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    LabeledField(
                      label: 'Serial Number',
                      required: true,
                      hint: scanSupported
                          ? 'Pindai barcode untuk menghindari salah ketik.'
                          : null,
                      child: TextFormField(
                        controller: _sn,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          suffixIcon: ScanFieldButton(
                            onScanned: (v) => setState(() => _sn.text = v),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'SN wajib diisi'
                            : null,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    LabeledField(
                      label: 'Keluhan',
                      child: TextFormField(
                        controller: _keluhan,
                        textCapitalization: TextCapitalization.characters,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'NO POWER, LCD ABNORMAL LINE',
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),
                    const SectionLabel('Pelanggan'),
                    const SizedBox(height: AppSpacing.s),

                    LabeledField(
                      label: 'Nama',
                      required: true,
                      child: TextFormField(
                        controller: _nama,
                        textCapitalization: TextCapitalization.characters,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Nama wajib diisi'
                            : null,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    LabeledField(
                      label: 'Telepon',
                      child: TextFormField(
                        controller: _telp,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          hintText: '0812-3456-7890',
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),
                    SectionLabel(
                      'Part yang Diklaim',
                      trailing: InlineAction(
                        label: 'Tambah',
                        onTap: () => setState(() => _parts.add(_PartEntry())),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),

                    for (var i = 0; i < _parts.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              flex: 2,
                              child: LabeledField(
                                label: 'Part',
                                child: DropdownButtonFormField<int>(
                                  initialValue: _parts[i].partTypeId,
                                  isExpanded: true,
                                  hint: const Text('—'),
                                  items: [
                                    for (final p in partTypes)
                                      DropdownMenuItem(
                                        value: p.id,
                                        child: Text(p.kode),
                                      ),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _parts[i].partTypeId = v),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              flex: 3,
                              child: LabeledField(
                                label: 'SN Bad Part',
                                child: TextFormField(
                                  controller: _parts[i].snController,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  decoration: InputDecoration(
                                    suffixIcon: ScanFieldButton(
                                      title: 'Pindai SN Bad Part',
                                      onScanned: (v) => setState(
                                        () => _parts[i].snController.text = v,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              iconSize: 18,
                              color: AppColors.red,
                              icon: const Icon(Icons.close),
                              onPressed: () => _removePart(i),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: AppSpacing.sm),
                    const SectionLabel('Penanganan'),
                    const SizedBox(height: AppSpacing.s),

                    LabeledField(
                      label: 'Teknisi',
                      child: DropdownButtonFormField<String>(
                        initialValue: _teknisiId,
                        isExpanded: true,
                        items: [
                          for (final t in techs)
                            DropdownMenuItem(value: t.id, child: Text(t.nama)),
                        ],
                        onChanged: (v) => setState(() => _teknisiId = v),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    LabeledField(
                      label: 'Status',
                      child: DropdownButtonFormField<String>(
                        initialValue: _status,
                        isExpanded: true,
                        items: [
                          for (final s in ClaimStatus.all)
                            DropdownMenuItem(
                              value: s,
                              child: Text(ClaimStatus.label(s)),
                            ),
                        ],
                        onChanged: (v) => setState(() => _status = v!),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    LabeledField(
                      label: 'No Perbaikan / RMA',
                      child: TextFormField(
                        controller: _noPerbaikan,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          hintText: 'IDD7R20024',
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    LabeledField(
                      label: 'Catatan',
                      child: TextFormField(controller: _catatan, maxLines: 3),
                    ),

                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: _busy ? null : _save,
                      child: Text(
                        widget.isEdit ? 'SIMPAN PERUBAHAN' : 'SIMPAN KLAIM',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    Text(
                      widget.isEdit
                          ? 'Perubahan tersimpan di perangkat lebih dulu, '
                              'lalu dikirim begitu ada koneksi.'
                          : 'Tanggal terisi otomatis. Data tersimpan di '
                              'perangkat lebih dulu, lalu dikirim begitu ada '
                              'koneksi.',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
