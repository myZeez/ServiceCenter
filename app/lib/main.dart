import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config.dart';
import 'core/providers.dart';
import 'core/theme.dart';
import 'features/auth/login_page.dart';
import 'features/claims/claims_page.dart';
import 'features/shell/admin_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!AppConfig.isConfigured) {
    runApp(const _ConfigMissingApp());
    return;
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: ScManagementApp()));
}

class ScManagementApp extends StatelessWidget {
  const ScManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Klaim Garansi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: const _AuthGate(),
    );
  }
}

/// Menentukan layar pertama: login atau daftar klaim.
class _AuthGate extends ConsumerStatefulWidget {
  const _AuthGate();

  @override
  ConsumerState<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<_AuthGate> {
  bool _syncStarted = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      _syncStarted = false;
      return const LoginPage();
    }

    // Sinkronisasi baru berjalan setelah ada yang login, karena semua
    // aturan akses di server bergantung pada identitas user.
    if (!_syncStarted) {
      _syncStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(syncServiceProvider).start();
      });
    }

    // Layar lebar memakai kerangka bersidebar; layar sempit memakai
    // navigasi berhalaman yang lebih cocok untuk satu tangan.
    final wide = MediaQuery.sizeOf(context).width > 900;
    return wide ? const AdminShell() : const ClaimsPage();
  }
}

/// Ditampilkan kalau aplikasi dijalankan tanpa kredensial Supabase.
class _ConfigMissingApp extends StatelessWidget {
  const _ConfigMissingApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.key_off, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Kredensial Supabase belum diisi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Jalankan aplikasi dengan --dart-define-from-file=env.json.\n'
                  'Lihat README untuk contohnya.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
