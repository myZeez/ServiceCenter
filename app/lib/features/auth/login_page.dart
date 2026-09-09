import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/swiss_widgets.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
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
      await ref
          .read(supabaseProvider)
          .auth
          .signInWithPassword(
            email: _email.text.trim(),
            password: _password.text,
          );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Gagal terhubung. Periksa koneksi internet.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.sizeOf(context).height -
                  MediaQuery.paddingOf(context).vertical,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.md,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    // Rata kiri, bukan tengah. Komposisi asimetris adalah
                    // ciri gaya ini, dan mata membaca dari satu sumbu tetap.
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Blok merah sebagai penanda, bukan logo.
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 48,
                            height: 8,
                            color: context.warna.bahaya,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Klaim\nGaransi',
                          style: Theme.of(context).textTheme.displayLarge,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'CELLCOM PLK',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: context.warna.teksLembut),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        LabeledField(
                          label: 'Email',
                          child: TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.username],
                            decoration: const InputDecoration(
                              hintText: 'nama@perusahaan.com',
                            ),
                            validator: (v) => (v == null || !v.contains('@'))
                                ? 'Email tidak valid'
                                : null,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s),
                        LabeledField(
                          label: 'Password',
                          child: TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              suffixIcon: IconButton(
                                iconSize: 18,
                                color: context.warna.teksLembut,
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Password wajib diisi'
                                : null,
                          ),
                        ),

                        if (_error != null) ...[
                          const SizedBox(height: AppSpacing.s),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.s),
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: context.warna.bahaya,
                                  width: 3,
                                ),
                              ),
                              color: const Color(0x0DD82C2C),
                            ),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: context.warna.bahaya,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: AppSpacing.sm),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: context.warna.permukaan,
                                  ),
                                )
                              : const Text('MASUK'),
                        ),
                        const SizedBox(height: AppSpacing.s),
                        Text(
                          'Login pertama kali membutuhkan koneksi internet.',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
