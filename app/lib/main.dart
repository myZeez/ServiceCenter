import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config.dart';
import 'core/data/pemantau_http.dart';
import 'core/data/prefs.dart';
import 'core/data/siklus.dart';
import 'core/providers.dart';
import 'core/theme.dart';
import 'features/auth/login_page.dart';
import 'features/claims/claims_page.dart';
import 'features/shell/admin_shell.dart';
import 'features/shell/peringatan_omset.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Nama hari dan bulan berbahasa Indonesia dipakai di laporan servis.
  // Tanpa pemuatan ini, DateFormat dengan locale 'id' melempar galat saat
  // halamannya dibuka.
  await initializeDateFormatting('id', null);

  if (!AppConfig.isConfigured) {
    runApp(const _ConfigMissingApp());
    return;
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
    // Merekam seluruh percakapan dengan server, tetapi hanya di build
    // debug. Kegagalan yang paling menyusahkan tidak melempar galat apa
    // pun -- UPDATE yang dijawab 200 dengan badan kosong -- dan hanya
    // terlihat kalau lalu lintasnya sendiri yang diamati.
    httpClient: PemantauHttp.bungkus(),
  );

  // Printer dan susunan kartu dibaca lebih dulu supaya layar tidak perlu
  // menunggui berkas pengaturan yang isinya sekadar nama printer.
  final prefs = await Prefs.buka();

  runApp(
    ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs)],
      child: const ScManagementApp(),
    ),
  );
}

class ScManagementApp extends ConsumerWidget {
  const ScManagementApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Selagi pilihannya dibaca dari perangkat, ikut sistem dulu. Nilai itu
    // benar untuk sebagian besar orang, jadi tidak ada kedipan terang ke
    // gelap pada perangkat yang memang disetel gelap.
    final mode = ref.watch(modeTemaProvider).valueOrNull ?? ThemeMode.system;

    return MaterialApp(
      title: 'Klaim Garansi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.terang(),
      darkTheme: AppTheme.gelap(),
      themeMode: mode,
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
  late final AppLifecycleListener _siklus;

  @override
  void initState() {
    super.initState();

    // Android memutus websocket begitu aplikasinya ditidurkan, dan langganan
    // yang terputus begitu tidak melempar galat apa pun -- alirannya hanya
    // berhenti mengirim. Tanpa pemasangan ulang di sini, yang terlihat saat
    // aplikasi dibuka lagi adalah keadaan terakhir sebelum layar dikunci,
    // tanpa satu pun tanda bahwa itu sudah basi.
    _siklus = AppLifecycleListener(
      onResume: () {
        Siklus.aktif = true;
        segarkanData(ref);
      },
      onPause: () => Siklus.aktif = false,
      onHide: () => Siklus.aktif = false,
      onShow: () => Siklus.aktif = true,
    );
  }

  @override
  void dispose() {
    _siklus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(currentUserProvider) == null) return const LoginPage();

    // Layar lebar memakai kerangka bersidebar; layar sempit memakai
    // navigasi berhalaman yang lebih cocok untuk satu tangan.
    final wide = MediaQuery.sizeOf(context).width > 900;
    //
    // Dibungkus pemeriksa peringatan omset: setiap kali aplikasi dibuka, admin
    // diingatkan siapa yang masih di bawah target pada hari-hari terakhir
    // bulan.
    return PeringatanOmsetPembuka(
      child: wide ? const AdminShell() : const ClaimsPage(),
    );
  }
}

/// Ditampilkan kalau aplikasi dijalankan tanpa kredensial Supabase.
class _ConfigMissingApp extends StatelessWidget {
  const _ConfigMissingApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.key_off, size: 48),
                SizedBox(height: 16),
                Text(
                  'Kredensial Supabase belum diisi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
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
