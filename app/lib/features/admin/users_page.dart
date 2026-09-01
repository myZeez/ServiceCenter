import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/local/database.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/swiss_widgets.dart';

/// Kelola pengguna. Hanya untuk admin.
///
/// Berbeda dari halaman lain, halaman ini butuh koneksi internet: membuat
/// dan mengubah akun tidak bisa diantrekan offline karena menyangkut
/// identitas dan hak akses.
class UsersPage extends ConsumerWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(allProfilesProvider).valueOrNull ?? const <Profile>[];
    final me = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.sm,
        title: const Text('Kelola Pengguna'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            iconSize: 18,
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(syncServiceProvider).syncNow(),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: profiles.isEmpty
          ? const EmptyState(
              icon: Icons.group_outlined,
              title: 'Belum ada pengguna',
              description: 'Tambahkan teknisi agar mereka bisa mencatat klaim.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.s,
                AppSpacing.sm,
                96,
              ),
              itemCount: profiles.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, i) => EntryAnimation(
                index: i,
                child: _UserRow(
                  profile: profiles[i],
                  isSelf: profiles[i].id == me?.id,
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            showDialog(context: context, builder: (_) => const _AddUserDialog()),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('TAMBAH PENGGUNA'),
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: profile.aktif ? AppColors.black : AppColors.grey,
                          decoration:
                              profile.aktif ? null : TextDecoration.lineThrough,
                        ),
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
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isAdmin ? AppColors.black : Colors.transparent,
                        border: Border.all(
                          color: isAdmin ? AppColors.black : AppColors.grey,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                      child: Text(
                        isAdmin ? 'ADMIN' : 'TEKNISI',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isAdmin ? AppColors.white : AppColors.grey,
                        ),
                      ),
                    ),
                    if (!profile.aktif) ...[
                      const SizedBox(width: 6),
                      Text(
                        'NONAKTIF',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
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
              child: Icon(Icons.lock_outline, size: 16, color: AppColors.grey),
            )
          else ...[
            InlineAction(
              label: isAdmin ? 'Jadi Teknisi' : 'Jadi Admin',
              onTap: () => _handle(context, ref, 'role'),
            ),
            const SizedBox(width: AppSpacing.s),
            InlineAction(
              label: profile.aktif ? 'Nonaktifkan' : 'Aktifkan',
              onTap: () => _handle(context, ref, 'aktif'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handle(BuildContext context, WidgetRef ref, String action) async {
    final client = ref.read(supabaseProvider);
    final db = ref.read(databaseProvider);

    try {
      if (action == 'role') {
        final next = profile.role == 'admin' ? 'teknisi' : 'admin';
        await client.from('profiles').update({'role': next}).eq('id', profile.id);
        await db.setProfileRole(profile.id, next);
      } else {
        final next = !profile.aktif;
        await client.from('profiles').update({'aktif': next}).eq('id', profile.id);
        await db.setProfileActive(profile.id, next);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan. Perlu koneksi internet. ($e)')),
      );
    }
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
      await ref.read(supabaseProvider).functions.invoke(
        'create-technician',
        body: {
          'nama': _nama.text.trim(),
          'email': _email.text.trim(),
          'password': _password.text,
          'role': _role,
        },
      );

      await ref.read(syncServiceProvider).syncNow();

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
                      DropdownMenuItem(value: 'teknisi', child: Text('Teknisi')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    ],
                    onChanged: (v) => setState(() => _role = v!),
                  ),
                ),
                if (_role == 'admin') ...[
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(color: AppColors.red, width: 3),
                      ),
                      color: Color(0x0DD82C2C),
                    ),
                    child: const Text(
                      'Admin dapat mengubah semua data klaim dan menambah '
                      'pengguna lain.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.red,
                      ),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.s),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(color: AppColors.red, width: 3),
                      ),
                      color: Color(0x0DD82C2C),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.red,
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
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
