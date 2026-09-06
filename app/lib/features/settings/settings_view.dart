import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/data/models.dart';
import '../../core/data/galat.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/bento.dart';
import '../../core/widgets/grid_canvas.dart';
import '../../core/widgets/swiss_widgets.dart';
import 'hari_kerja_card.dart';
import 'nomor_nota_card.dart';
import 'omset_card.dart';
import 'print_cards.dart';
import 'revenue_cards.dart';
import 'metode_bayar_card.dart';
import 'up_toko_card.dart';

/// Semua pengaturan dalam satu layar.
///
/// Sebelumnya pengguna, brand, dan jenis part adalah tiga halaman terpisah
/// yang harus dibuka bergantian, padahal isinya pendek-pendek. Berdampingan
/// begini semuanya terbaca sekaligus.
class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  /// Menata susunan adalah tindakan sesekali, bukan keadaan biasa. Di luar
  /// mode ini kartunya diam sepenuhnya.
  bool _menata = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'Pengaturan',
            subtitle: _menata
                ? 'Tarik tepi kanan atau bawah kartu untuk mengubah ukuran, '
                      'tepi kirinya untuk memindah'
                : 'Pengguna dan data master yang dipakai seluruh aplikasi',
            actions: [
              if (_menata &&
                  !(ref.watch(gridLayoutProvider('pengaturan')).valueOrNull ??
                          const GridLayout())
                      .isEmpty)
                TextButton(
                  onPressed: () =>
                      simpanGridLayout(ref, 'pengaturan', const GridLayout()),
                  child: const Text('SUSUNAN AWAL'),
                ),
              const SizedBox(width: AppSpacing.xs),
              // Saat menata, tombolnya jadi tegas supaya jelas ini keadaan
              // sementara yang harus diakhiri.
              _menata
                  ? FilledButton.icon(
                      onPressed: () => setState(() => _menata = false),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('SELESAI MENATA'),
                    )
                  : OutlinedButton.icon(
                      onPressed: () => setState(() => _menata = true),
                      icon: const Icon(
                        Icons.dashboard_customize_outlined,
                        size: 16,
                      ),
                      label: const Text('UBAH LAYOUT'),
                    ),
              const SizedBox(width: AppSpacing.xs),
              // Perubahan datang sendiri lewat Realtime. Tombol ini untuk
              // saat sambungannya sempat putus: langganannya dipasang
              // ulang, bukan datanya ditarik ulang secara manual.
              OutlinedButton.icon(
                onPressed: () {
                  ref.invalidate(allProfilesProvider);
                  ref.invalidate(allBrandsProvider);
                  ref.invalidate(allPartTypesProvider);
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('SAMBUNG ULANG'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s),
            decoration: const BoxDecoration(
              color: Color(0x0D0033A0),
              border: Border(left: BorderSide(color: AppColors.blue, width: 3)),
            ),
            child: const Text(
              'Perubahan di halaman ini berlaku untuk semua perangkat dan '
              'membutuhkan koneksi internet.',
              style: TextStyle(fontSize: 12, color: AppColors.blue),
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          // Ukuran tiap kartu bisa ditarik dari sudut kanan bawahnya, dan
          // pilihannya tersimpan di perangkat ini.
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                if (c.maxWidth > 900) {
                  return GridCanvas(
                    columns: 12,
                    rowHeight: 52,
                    gap: AppSpacing.s,
                    padding: const EdgeInsets.only(bottom: AppSpacing.s),
                    layout:
                        ref
                            .watch(gridLayoutProvider('pengaturan'))
                            .valueOrNull ??
                        const GridLayout(),
                    editable: _menata,
                    onLayoutChanged: (v) =>
                        simpanGridLayout(ref, 'pengaturan', v),
                    areas: const [
                      GridArea(
                        id: 'pengguna',
                        colSpan: 4,
                        rowSpan: 7,
                        child: _UsersCard(),
                      ),
                      GridArea(
                        id: 'brand',
                        colSpan: 4,
                        rowSpan: 7,
                        child: _BrandsCard(),
                      ),
                      GridArea(
                        id: 'part',
                        colSpan: 4,
                        rowSpan: 7,
                        child: _PartTypesCard(),
                      ),
                      GridArea(
                        id: 'fee',
                        colSpan: 5,
                        rowSpan: 9,
                        child: BrandFeesCard(),
                      ),
                      GridArea(
                        id: 'bagi_hasil',
                        colSpan: 7,
                        rowSpan: 9,
                        child: RevenueSplitCard(),
                      ),
                      GridArea(
                        id: 'toko',
                        colSpan: 6,
                        rowSpan: 9,
                        child: StoreCard(),
                      ),
                      GridArea(
                        id: 'printer',
                        colSpan: 6,
                        rowSpan: 9,
                        child: PrinterCard(),
                      ),
                      GridArea(
                        id: 'omset',
                        colSpan: 6,
                        rowSpan: 8,
                        child: OmsetCard(),
                      ),
                      GridArea(
                        id: 'nomor_nota',
                        colSpan: 6,
                        rowSpan: 8,
                        child: NomorNotaCard(),
                      ),
                      GridArea(
                        id: 'up_toko',
                        colSpan: 6,
                        rowSpan: 8,
                        child: UpTokoCard(),
                      ),
                      GridArea(
                        id: 'metode_bayar',
                        colSpan: 6,
                        rowSpan: 8,
                        child: MetodeBayarCard(),
                      ),
                      GridArea(
                        id: 'hari_kerja',
                        colSpan: 6,
                        rowSpan: 8,
                        child: HariKerjaCard(),
                      ),
                    ],
                  );
                }
                return ListView(
                  children: const [
                    SizedBox(height: 340, child: _UsersCard()),
                    SizedBox(height: AppSpacing.s),
                    SizedBox(height: 300, child: _BrandsCard()),
                    SizedBox(height: AppSpacing.s),
                    SizedBox(height: 300, child: _PartTypesCard()),
                    SizedBox(height: AppSpacing.s),
                    SizedBox(height: 400, child: BrandFeesCard()),
                    SizedBox(height: AppSpacing.s),
                    SizedBox(height: 620, child: RevenueSplitCard()),
                    SizedBox(height: AppSpacing.s),
                    SizedBox(height: 520, child: StoreCard()),
                    SizedBox(height: AppSpacing.s),
                    SizedBox(height: 400, child: PrinterCard()),
                    SizedBox(height: AppSpacing.s),
                    SizedBox(height: 460, child: OmsetCard()),
                    SizedBox(height: AppSpacing.s),
                    SizedBox(height: 470, child: NomorNotaCard()),
                    SizedBox(height: AppSpacing.s),
                    SizedBox(height: 450, child: UpTokoCard()),
                    SizedBox(height: AppSpacing.s),
                    SizedBox(height: 440, child: MetodeBayarCard()),
                    SizedBox(height: AppSpacing.s),
                    SizedBox(height: 480, child: HariKerjaCard()),
                    SizedBox(height: AppSpacing.sm),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Pengguna
// =====================================================================

class _UsersCard extends ConsumerWidget {
  const _UsersCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles =
        ref.watch(allProfilesProvider).valueOrNull ?? const <Profile>[];
    final me = ref.watch(currentUserProvider);

    return BentoCard(
      title: 'Pengguna',
      padding: EdgeInsets.zero,
      trailing: InlineAction(
        label: 'Tambah',
        onTap: () => showDialog(
          context: context,
          builder: (_) => const _AddUserDialog(),
        ),
      ),
      child: profiles.isEmpty
          ? const _CardEmpty('Belum ada pengguna.')
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              itemCount: profiles.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, i) => _UserRow(
                profile: profiles[i],
                isSelf: profiles[i].id == me?.id,
              ),
            ),
    );
  }
}

class _UserRow extends ConsumerWidget {
  const _UserRow({required this.profile, required this.isSelf});

  final Profile profile;
  final bool isSelf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = profile.role == 'admin';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        profile.nama,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: profile.aktif
                              ? AppColors.black
                              : AppColors.grey,
                          decoration: profile.aktif
                              ? null
                              : TextDecoration.lineThrough,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelf)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          'KAMU',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    _Tag(isAdmin ? 'ADMIN' : 'TEKNISI', filled: isAdmin),
                    if (!profile.aktif) ...[
                      const SizedBox(width: 5),
                      const _Tag('NONAKTIF'),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isSelf)
            // Admin tidak boleh menonaktifkan atau menurunkan dirinya
            // sendiri. Tanpa ini, satu klik keliru bisa membuat sistem
            // tidak punya admin sama sekali.
            const Tooltip(
              message: 'Akun sendiri tidak bisa diubah dari sini',
              child: Icon(Icons.lock_outline, size: 15, color: AppColors.grey),
            )
          else ...[
            InlineAction(
              label: isAdmin ? 'Jadi Teknisi' : 'Jadi Admin',
              onTap: () => _update(context, ref, {
                'role': isAdmin ? 'teknisi' : 'admin',
              }),
            ),
            const SizedBox(width: AppSpacing.xs),
            InlineAction(
              label: profile.aktif ? 'Nonaktifkan' : 'Aktifkan',
              onTap: () => _update(context, ref, {'aktif': !profile.aktif}),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _update(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> changes,
  ) async {
    try {
      await ref
          .read(supabaseProvider)
          .from('profiles')
          .update(changes)
          .eq('id', profile.id);

      // Dulu perubahannya perlu ditulis ulang ke cermin lokal supaya layar
      // ikut berubah. Sekarang layar berlangganan langsung ke tabelnya.
    } on PostgrestException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(pesanGalat(e))));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan. Perlu koneksi.')),
      );
    }
  }
}

// =====================================================================
// Brand & jenis part
// =====================================================================

class _BrandsCard extends ConsumerWidget {
  const _BrandsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brands = ref.watch(allBrandsProvider).valueOrNull ?? const <Brand>[];

    return BentoCard(
      title: 'Brand',
      padding: EdgeInsets.zero,
      trailing: InlineAction(label: 'Tambah', onTap: () => _form(context, ref)),
      child: brands.isEmpty
          ? const _CardEmpty('Belum ada brand.')
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              itemCount: brands.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, i) {
                final b = brands[i];
                return _MasterRow(
                  title: b.nama,
                  aktif: b.aktif,
                  onEdit: () => _form(context, ref, brand: b),
                  onToggle: () => _write(
                    context,
                    ref,
                    () => ref
                        .read(supabaseProvider)
                        .from('brands')
                        .update({'aktif': !b.aktif})
                        .eq('id', b.id),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _form(
    BuildContext context,
    WidgetRef ref, {
    Brand? brand,
  }) async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => _MasterFormDialog(
        title: brand == null ? 'Tambah Brand' : 'Ubah Brand',
        fields: [_Field('Nama Brand', brand?.nama ?? '', hint: 'ASUS, ACER')],
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

class _PartTypesCard extends ConsumerWidget {
  const _PartTypesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parts =
        ref.watch(allPartTypesProvider).valueOrNull ?? const <PartType>[];

    return BentoCard(
      title: 'Jenis Part',
      padding: EdgeInsets.zero,
      trailing: InlineAction(label: 'Tambah', onTap: () => _form(context, ref)),
      child: parts.isEmpty
          ? const _CardEmpty('Belum ada jenis part.')
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              itemCount: parts.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, i) {
                final p = parts[i];
                return _MasterRow(
                  title: p.kode,
                  subtitle: p.nama,
                  aktif: p.aktif,
                  onEdit: () => _form(context, ref, part: p),
                  onToggle: () => _write(
                    context,
                    ref,
                    () => ref
                        .read(supabaseProvider)
                        .from('part_types')
                        .update({'aktif': !p.aktif})
                        .eq('id', p.id),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _form(
    BuildContext context,
    WidgetRef ref, {
    PartType? part,
  }) async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => _MasterFormDialog(
        title: part == null ? 'Tambah Jenis Part' : 'Ubah Jenis Part',
        fields: [
          _Field('Kode', part?.kode ?? '', hint: 'Singkatan harian, mis. MB'),
          _Field('Nama Lengkap', part?.nama ?? '', hint: 'Mainboard'),
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
            .update({'kode': kode, 'nama': nama})
            .eq('id', part.id);
      }
    });
  }
}

/// Menjalankan perubahan ke server, menerjemahkan errornya ke bahasa yang
/// bisa ditindaklanjuti, lalu menarik ulang data master.
Future<void> _write(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() action,
) async {
  try {
    await action();
  } on PostgrestException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          e.code == '23505'
              ? 'Nama atau kode itu sudah dipakai.'
              : 'Gagal menyimpan: ${pesanGalat(e)}',
        ),
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gagal menyimpan. Perlu koneksi.')),
    );
  }
}

// =====================================================================
// Bagian kecil
// =====================================================================

class _MasterRow extends StatelessWidget {
  const _MasterRow({
    required this.title,
    required this.aktif,
    required this.onEdit,
    required this.onToggle,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool aktif;
  final VoidCallback onEdit;
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
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: aktif ? AppColors.black : AppColors.grey,
                    decoration: aktif ? null : TextDecoration.lineThrough,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(fontSize: 12, color: AppColors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          InlineAction(label: 'Ubah', onTap: onEdit),
          const SizedBox(width: AppSpacing.xs),
          InlineAction(
            label: aktif ? 'Nonaktifkan' : 'Aktifkan',
            onTap: onToggle,
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {this.filled = false});

  final String text;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? AppColors.black : Colors.transparent,
        border: Border.all(color: filled ? AppColors.black : AppColors.grey),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
          color: filled ? AppColors.white : AppColors.grey,
        ),
      ),
    );
  }
}

class _CardEmpty extends StatelessWidget {
  const _CardEmpty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.grey, fontSize: 13),
      ),
    ),
  );
}

class _Field {
  _Field(this.label, this.initial, {this.hint});
  final String label;
  final String initial;
  final String? hint;
}

class _MasterFormDialog extends StatefulWidget {
  const _MasterFormDialog({required this.title, required this.fields});

  final String title;
  final List<_Field> fields;

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
                    decoration: InputDecoration(
                      hintText: widget.fields[i].hint,
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
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

class _AddUserDialog extends ConsumerStatefulWidget {
  const _AddUserDialog();

  @override
  ConsumerState<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends ConsumerState<_AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nama = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  String _role = 'teknisi';
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _nama.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // Pembuatan akun ditangani Edge Function di server, karena butuh
      // service_role key yang tidak boleh ada di dalam aplikasi.
      await ref
          .read(supabaseProvider)
          .functions
          .invoke(
            'create-technician',
            body: {
              'nama': _nama.text.trim(),
              'email': _email.text.trim(),
              'password': _password.text,
              'role': _role,
            },
          );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_nama.text.trim()} berhasil ditambahkan')),
      );
    } on FunctionException catch (e) {
      final detail = e.details;
      setState(() {
        _error = detail is Map && detail['error'] != null
            ? detail['error'].toString()
            : 'Gagal membuat akun (kode ${e.status}).';
      });
    } catch (e) {
      setState(() => _error = 'Gagal terhubung ke server. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah Pengguna'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LabeledField(
                  label: 'Nama',
                  required: true,
                  child: TextFormField(
                    controller: _nama,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v == null || v.trim().length < 2)
                        ? 'Nama wajib diisi'
                        : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                LabeledField(
                  label: 'Email',
                  required: true,
                  child: TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v == null || !v.contains('@'))
                        ? 'Email tidak valid'
                        : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                LabeledField(
                  label: 'Password Awal',
                  required: true,
                  hint: 'Minimal 8 karakter. Sampaikan langsung ke orangnya.',
                  child: TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      suffixIcon: IconButton(
                        iconSize: 18,
                        color: AppColors.grey,
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 8)
                        ? 'Password minimal 8 karakter'
                        : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                LabeledField(
                  label: 'Peran',
                  child: DropdownButtonFormField<String>(
                    initialValue: _role,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: 'teknisi',
                        child: Text('Teknisi'),
                      ),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    ],
                    onChanged: (v) => setState(() => _role = v!),
                  ),
                ),
                if (_role == 'admin') ...[
                  const SizedBox(height: AppSpacing.xs),
                  const _Notice(
                    'Admin dapat mengubah semua data klaim dan menambah '
                    'pengguna lain.',
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.s),
                  _Notice(_error!),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('BATAL'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.white,
                  ),
                )
              : const Text('TAMBAH'),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.xs),
    decoration: const BoxDecoration(
      color: Color(0x0DD82C2C),
      border: Border(left: BorderSide(color: AppColors.red, width: 3)),
    ),
    child: Text(
      text,
      style: const TextStyle(color: AppColors.red, fontSize: 12, height: 1.4),
    ),
  );
}
