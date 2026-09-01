import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/local/database.dart';
import '../../core/providers.dart';
import '../../core/status.dart';
import '../../core/theme.dart';
import '../../core/widgets/swiss_widgets.dart';
import '../scan/scan_page.dart';

const _uuid = Uuid();

/// Satu baris part yang diklaim, beserta SN part rusaknya.
class _PartEntry {
  _PartEntry();
  int? partTypeId;
  final snController = TextEditingController();
  void dispose() => snController.dispose();
}

class ClaimFormPage extends ConsumerStatefulWidget {
  const ClaimFormPage({super.key});

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
  final List<_PartEntry> _parts = [_PartEntry()];
  bool _busy = false;

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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _busy = true);

    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    final claimId = _uuid.v4();

    await db.upsertClaimLocal(
      ClaimsCompanion.insert(
        id: claimId,
        // Jam lokal saat diinput, bukan saat tersinkron ke server.
        tanggal: now,
        brandId: _brandId!,
        namaPelanggan: _nama.text.trim(),
        telp: Value(_telp.text.trim().isEmpty ? null : _telp.text.trim()),
        sn: _sn.text.trim(),
        teknisiId: Value(_teknisiId),
        keluhan: Value(_keluhan.text.trim().isEmpty ? null : _keluhan.text.trim()),
        noPerbaikan: Value(
          _noPerbaikan.text.trim().isEmpty ? null : _noPerbaikan.text.trim(),
        ),
        status: Value(_status),
        catatan: Value(_catatan.text.trim().isEmpty ? null : _catatan.text.trim()),
        createdBy: user.id,
        createdAt: now,
        updatedAt: now,
        syncPending: const Value(true),
      ),
    );

    for (final p in _parts.where((e) => e.partTypeId != null)) {
      await db.upsertPartLocal(
        ClaimPartsCompanion.insert(
          id: _uuid.v4(),
          claimId: claimId,
          partTypeId: p.partTypeId!,
          snBadPart: Value(
            p.snController.text.trim().isEmpty ? null : p.snController.text.trim(),
          ),
          syncPending: const Value(true),
        ),
      );
    }

    // Tidak menunggu hasil sinkron: data sudah aman di perangkat, dan
    // pengiriman ke server berjalan di latar belakang.
    ref.read(syncServiceProvider).syncNow();

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Klaim tersimpan')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brands = ref.watch(brandsProvider).valueOrNull ?? const <Brand>[];
    final techs = ref.watch(techniciansProvider).valueOrNull ?? const <Profile>[];
    final partTypes =
        ref.watch(partTypesProvider).valueOrNull ?? const <PartType>[];

    // Default teknisi = yang sedang login, karena umumnya dialah yang
    // menerima unit di meja.
    _teknisiId ??= ref.read(currentUserProvider)?.id;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.sm,
        title: const Text('Klaim Baru'),
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
                            if (_parts.length > 1)
                              IconButton(
                                iconSize: 18,
                                color: AppColors.red,
                                icon: const Icon(Icons.close),
                                onPressed: () => setState(() {
                                  _parts.removeAt(i).dispose();
                                }),
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
                      label: 'No Perbaikan',
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
                      child: TextFormField(
                        controller: _catatan,
                        maxLines: 3,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: _busy ? null : _save,
                      child: const Text('SIMPAN KLAIM'),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    Text(
                      'Tanggal terisi otomatis. Data tersimpan di perangkat '
                      'lebih dulu, lalu dikirim begitu ada koneksi.',
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
