import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/local/database.dart';
import '../../core/providers.dart';

/// Kelola pengguna. Hanya untuk admin.
///
/// Berbeda dari halaman lain, halaman ini butuh koneksi internet: membuat
/// dan mengubah akun tidak bisa diantrekan offline karena menyangkut
/// identitas dan hak akses.
class UsersPage extends ConsumerWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(allProfilesProvider);
    final me = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Pengguna'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(syncServiceProvider).syncNow(),
          ),
        ],
      ),
      body: profiles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('Belum ada pengguna.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final p = list[i];
              final isSelf = p.id == me?.id;
              return _UserTile(profile: p, isSelf: isSelf);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(
          context: context,
          builder: (_) => const _AddUserDialog(),
        ),
        icon: const Icon(Icons.person_add),
        label: const Text('Tambah Pengguna'),
      ),
    );
  }
}

class _UserTile extends ConsumerWidget {
  const _UserTile({required this.profile, required this.isSelf});

  final Profile profile;
  final bool isSelf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = profile.role == 'admin';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isAdmin
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(isAdmin ? Icons.shield_outlined : Icons.engineering, size: 20),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              profile.nama,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: profile.aktif ? null : Colors.grey,
                decoration: profile.aktif ? null : TextDecoration.lineThrough,
              ),
            ),
          ),
          if (isSelf)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Text('(kamu)', style: TextStyle(fontSize: 11)),
            ),
        ],
      ),
      subtitle: Text(
        '${isAdmin ? 'Admin' : 'Teknisi'}${profile.aktif ? '' : ' · nonaktif'}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: isSelf
          // Admin tidak boleh menonaktifkan atau menurunkan dirinya sendiri.
          // Tanpa ini, satu klik keliru bisa membuat sistem tidak punya
          // admin sama sekali.
          ? const Tooltip(
              message: 'Akun sendiri tidak bisa diubah dari sini',
              child: Icon(Icons.lock_outline, size: 18, color: Colors.grey),
            )
          : PopupMenuButton<String>(
              onSelected: (v) => _handle(context, ref, v),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'role',
                  child: Text(isAdmin ? 'Jadikan teknisi' : 'Jadikan admin'),
                ),
                PopupMenuItem(
                  value: 'aktif',
                  child: Text(profile.aktif ? 'Nonaktifkan' : 'Aktifkan'),
                ),
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
        SnackBar(
          content: Text('Gagal menyimpan. Perlu koneksi internet. ($e)'),
        ),
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

      // Tarik ulang daftar profil supaya user baru langsung muncul.
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
                TextFormField(
                  controller: _nama,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nama *'),
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Nama wajib diisi'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email *'),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Email tidak valid'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password Awal *',
                    helperText: 'Minimal 8 karakter',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 8)
                      ? 'Password minimal 8 karakter'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Peran'),
                  items: const [
                    DropdownMenuItem(value: 'teknisi', child: Text('Teknisi')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (v) => setState(() => _role = v!),
                ),
                if (_role == 'admin') ...[
                  const SizedBox(height: 8),
                  Text(
                    'Admin bisa mengubah semua data klaim dan menambah '
                    'pengguna lain.',
                    style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Sampaikan password ini langsung ke orangnya, dan minta '
                  'dia menggantinya sendiri nanti.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Tambah'),
        ),
      ],
    );
  }
}
