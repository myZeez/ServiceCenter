/// Kredensial Supabase.
///
/// Nilainya tidak ditulis di source code supaya aman waktu repo di-push ke
/// GitHub. Isi lewat --dart-define saat menjalankan aplikasi (lihat README).
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
