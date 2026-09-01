import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/local/database.dart';
import '../../core/providers.dart';
import '../../core/status.dart';

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
    final partTypes = ref.watch(partTypesProvider).valueOrNull ?? const <PartType>[];

    // Default teknisi = yang sedang login, karena umumnya dialah yang
    // menerima unit di meja.
    _teknisiId ??= ref.read(currentUserProvider)?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Klaim Baru')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: _brandId,
                      decoration: const InputDecoration(labelText: 'Brand *'),
                      items: [
                        for (final b in brands)
                          DropdownMenuItem(value: b.id, child: Text(b.nama)),
                      ],
                      onChanged: (v) => setState(() => _brandId = v),
                      validator: (v) => v == null ? 'Brand wajib dipilih' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nama,
                      textCapitalization: TextCapitalization.characters,
                      decoration:
                          const InputDecoration(labelText: 'Nama Pelanggan *'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Nama wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _telp,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Telp',
                        hintText: '0812-3456-7890',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _sn,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Serial Number *',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'SN wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _teknisiId,
                      decoration: const InputDecoration(labelText: 'Teknisi'),
                      items: [
                        for (final t in techs)
                          DropdownMenuItem(value: t.id, child: Text(t.nama)),
                      ],
                      onChanged: (v) => setState(() => _teknisiId = v),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _keluhan,
                      textCapitalization: TextCapitalization.characters,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Keluhan',
                        hintText: 'NO POWER, LCD ABNORMAL LINE, ...',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _noPerbaikan,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'No Perbaikan',
                        hintText: 'IDD7R20024',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: [
                        for (final s in ClaimStatus.all)
                          DropdownMenuItem(
                            value: s,
                            child: Text(ClaimStatus.label(s)),
                          ),
                      ],
                      onChanged: (v) => setState(() => _status = v!),
                    ),

                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Text(
                          'Part yang Diklaim',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => _parts.add(_PartEntry())),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Tambah'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    for (var i = 0; i < _parts.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<int>(
                                initialValue: _parts[i].partTypeId,
                                isExpanded: true,
                                decoration:
                                    const InputDecoration(labelText: 'Part'),
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
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _parts[i].snController,
                                textCapitalization: TextCapitalization.characters,
                                decoration: const InputDecoration(
                                  labelText: 'SN Bad Part',
                                ),
                              ),
                            ),
                            if (_parts.length > 1)
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => setState(() {
                                  _parts.removeAt(i).dispose();
                                }),
                              ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _catatan,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Catatan',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _busy ? null : _save,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.save),
                      label: const Text('Simpan Klaim'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tanggal terisi otomatis. Data tersimpan di perangkat '
                      'dulu, lalu dikirim ke server begitu ada koneksi.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 32),
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
