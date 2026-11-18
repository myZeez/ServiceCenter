/// Implementasi dummy RawPrinter untuk platform tanpa dart:ffi (misalnya Web).
class RawPrinter {
  const RawPrinter._();

  static bool get didukung => false;

  static List<String> daftar() => const [];

  static String? kirim(String namaPrinter, List<int> data) =>
      'Cetak hanya tersedia di Windows.';
}
