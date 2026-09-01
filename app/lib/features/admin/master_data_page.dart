import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/local/database.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/swiss_widgets.dart';

/// Kelola brand dan jenis part. Hanya admin.
///
/// Seperti halaman pengguna, ini butuh koneksi: data master dipakai bersama
/// semua perangkat, jadi perubahannya tidak boleh diantrekan offline lalu
/// bentrok satu sama lain.
class MasterDataPage extends StatelessWidget {
  const MasterDataPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: AppSpacing.sm,
          title: const Text('Data Master'),
          bottom: const TabBar(
            tabs: [Tab(text: 'BRAND'), Tab(text: 'JENIS PART')],
          ),
        ),
        body: const TabBarView(children: [_BrandTab(), _PartTab()]),
      ),
    );
  }
}

// =====================================================================
// Brand
// =====================================================================

class _BrandTab extends ConsumerWidget {
  const _BrandTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brands = ref.watch(allBrandsProvider).valueOrNull ?? const <Brand>[];

    return Scaffold(
      body: brands.isEmpty
          ? const EmptyState(
              icon: Icons.label_outline,
              title: 'Belum ada brand',
              description: 'Tambahkan brand yang unitnya kamu tangani.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.s,
                AppSpacing.sm,
                96,
              ),
              itemCount: brands.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, i) {
                final b = brands[i];
                return EntryAnimation(
                  index: i,
                  child: _MasterRow(
                    title: b.nama,
                    aktif: b.aktif,
                    onRename: () => _showBrandForm(context, ref, brand: b),
                    onToggle: () => _write(
                      context,
                      ref,
                      () => ref
                          .read(supabaseProvider)
                          .from('brands')
                          .update({'aktif': !b.aktif}).eq('id', b.id),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBrandForm(context, ref),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('TAMBAH BRAND'),
      ),
    );
  }

  Future<void> _showBrandForm(
    BuildContext context,
    WidgetRef ref, {
    Brand? brand,
  }) async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => _MasterFormDialog(
        title: brand == null ? 'Tambah Brand' : 'Ubah Brand',
        fields: [
          _FieldSpec('Nama Brand', brand?.nama ?? '', hint: 'ASUS, ACER, ...'),
        ],
      ),
    );
    if (result == null || !context.mounted) return;

    final nama = result[0].trim().toUpperCase();
    final client = ref.read(supabaseProvider);

    await _write(context, ref, () async {
      if (brand == null) {
        await client.from('brands').insert({'nama': nama});
      } else {
        await client.from('brands').update({'nama': nama}).eq('id', brand.id);
      }
    });
  }
}

// =====================================================================
// Jenis part
// =====================================================================

class _PartTab extends ConsumerWidget {
  const _PartTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parts =
        ref.watch(allPartTypesProvider).valueOrNull ?? const <PartType>[];

    return Scaffold(
      body: parts.isEmpty
          ? const EmptyState(
              icon: Icons.memory_outlined,
              title: 'Belum ada jenis part',
              description:
                  'Tambahkan jenis part yang bisa diklaim, misalnya '
                  'Mainboard atau LCD.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.s,
                AppSpacing.sm,
                96,
              ),
              itemCount: parts.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, i) {
                final p = parts[i];
                return EntryAnimation(
                  index: i,
                  child: _MasterRow(
                    title: p.kode,
                    subtitle: p.nama,
                    aktif: p.aktif,
                    onRename: () => _showPartForm(context, ref, part: p),
                    onToggle: () => _write(
                      context,
                      ref,
                      () => ref
                          .read(supabaseProvider)
                          .from('part_types')
                          .update({'aktif': !p.aktif}).eq('id', p.id),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPartForm(context, ref),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('TAMBAH PART'),
      ),
    );
  }

  Future<void> _showPartForm(
    BuildContext context,
    WidgetRef ref, {
    PartType? part,
  }) async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => _MasterFormDialog(
        title: part == null ? 'Tambah Jenis Part' : 'Ubah Jenis Part',
        fields: [
          _FieldSpec(
            'Kode',
            part?.kode ?? '',
            hint: 'Singkatan yang dipakai sehari-hari, mis. MB',
          ),
          _FieldSpec('Nama Lengkap', part?.nama ?? '', hint: 'Mainboard'),
        ],
      ),
    );
    if (result == null || !context.mounted) return;

    final kode = result[0].trim().toUpperCase().replaceAll(' ', '_');
    final nama = result[1].trim();
    final client = ref.read(supabaseProvider);

    await _write(context, ref, () async {
      if (part == null) {
        await client.from('part_types').insert({'kode': kode, 'nama': nama});
      } else {
        await client
            .from('part_types')
            .update({'kode': kode, 'nama': nama}).eq('id', part.id);
      }
    });
  }
}

// =====================================================================
// Bagian bersama
// =====================================================================

/// Menjalankan perubahan ke server, menerjemahkan errornya ke bahasa yang
/// bisa ditindaklanjuti, lalu menarik ulang data master.
Future<void> _write(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() action,
) async {
  try {
    await action();
    await ref.read(syncServiceProvider).syncNow();
  } on PostgrestException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          e.code == '23505'
              ? 'Nama atau kode itu sudah dipakai.'
              : 'Gagal menyimpan: ${e.message}',
        ),
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gagal menyimpan. Perubahan data master perlu koneksi.'),
      ),
    );
  }
}

class _MasterRow extends StatelessWidget {
  const _MasterRow({
    required this.title,
    required this.aktif,
    required this.onRename,
    required this.onToggle,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool aktif;
  final VoidCallback onRename;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: aktif ? AppColors.black : AppColors.grey,
                    decoration: aktif ? null : TextDecoration.lineThrough,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle!,
                    style: const TextStyle(fontSize: 12, color: AppColors.grey),
                  ),
                ],
                if (!aktif) ...[
                  const SizedBox(height: 3),
                  Text(
                    'NONAKTIF',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ],
            ),
          ),
          InlineAction(label: 'Ubah', onTap: onRename),
          const SizedBox(width: AppSpacing.s),
          InlineAction(label: aktif ? 'Nonaktifkan' : 'Aktifkan', onTap: onToggle),
        ],
      ),
    );
  }
}

class _FieldSpec {
  _FieldSpec(this.label, this.initial, {this.hint});
  final String label;
  final String initial;
  final String? hint;
}

/// Dialog isian sederhana yang mengembalikan nilai tiap kolom.
class _MasterFormDialog extends StatefulWidget {
  const _MasterFormDialog({required this.title, required this.fields});

  final String title;
  final List<_FieldSpec> fields;

  @override
  State<_MasterFormDialog> createState() => _MasterFormDialogState();
}

class _MasterFormDialogState extends State<_MasterFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final List<TextEditingController> _controllers = [
    for (final f in widget.fields) TextEditingController(text: f.initial),
  ];

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < widget.fields.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.s),
                LabeledField(
                  label: widget.fields[i].label,
                  required: true,
                  child: TextFormField(
                    controller: _controllers[i],
                    autofocus: i == 0,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(hintText: widget.fields[i].hint),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Wajib diisi'
                        : null,
                  ),
                ),
              ],
            ],
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
            Navigator.pop(context, [for (final c in _controllers) c.text]);
          },
          child: const Text('SIMPAN'),
        ),
      ],
    );
  }
}
