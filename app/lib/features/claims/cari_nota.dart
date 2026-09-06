import '../../core/data/models.dart';

/// Mencari nota servis yang bisa diangkat menjadi klaim garansi.
///
/// Ada karena urutan kerja yang sebenarnya jarang serapi asumsinya. Unit
/// masuk sebagai servis biasa, dan baru setelah dibongkar teknisi melihat
/// unitnya masih bergaransi. Yang menemukannya bukan orang di meja depan,
/// dan yang ada di tangannya bukan berkas nota melainkan HP.
///
/// Jadi yang dicari cukup nama seperti tertulis di nota. Nomor nota, nomor
/// seri, merek dan tipe ikut dicocokkan supaya cara mencari yang mana pun
/// tetap ketemu.
List<ServiceOrderEntry> cariNota(
  List<ServiceOrderEntry> semua,
  String teks, {
  int batas = 8,
}) {
  final q = teks.trim().toLowerCase();
  if (q.isEmpty) return const [];

  bool cocok(ServiceOrderEntry n) => [
    n.customerNama,
    n.noNota,
    n.barangSn ?? '',
    n.barangNama,
    n.barangType ?? '',
    n.customerTelp ?? '',
  ].any((s) => s.toLowerCase().contains(q));

  // Nota yang sudah punya klaim tidak ikut. Satu nota yang menunjuk dua
  // klaim membuat sinkronisasi status di server tarik-menarik, dan yang
  // kalah adalah unit yang statusnya berubah sendiri tanpa ada yang
  // menyentuhnya.
  //
  // Yang berstatus batal justru tetap ditampilkan, lengkap dengan
  // statusnya. Menyembunyikannya hanya memindahkan kebingungan: yang
  // mencari tahu notanya ada, tidak menemukannya di sini, dan tidak
  // pernah diberi tahu kenapa.
  final hasil = [
    for (final n in semua)
      if (n.claimId == null && cocok(n)) n,
  ]..sort((a, b) => b.tanggalMasuk.compareTo(a.tanggalMasuk));

  return hasil.length <= batas ? hasil : hasil.sublist(0, batas);
}

/// Menebak brand dari sebutan barang pada nota.
///
/// Nota menulis unitnya sebagai kalimat bebas -- "Laptop Hp 14", "ASUS
/// X441BA" -- sementara klaim butuh brand dari daftar. Tebakan ini hanya
/// mengisi bawaan awal dropdown; yang memilih tetap orangnya.
///
/// Sengaja menyerah bila cocoknya lebih dari satu. Bawaan yang salah lebih
/// buruk daripada kolom kosong: kolom kosong menuntut dipilih, tebakan
/// yang salah tampak seperti sudah benar dan ikut tersimpan.
Brand? tebakBrand(List<Brand> brands, String teks) {
  final t = teks.toUpperCase();
  Brand? ketemu;

  for (final b in brands) {
    final nama = b.nama.trim().toUpperCase();
    if (nama.isEmpty) continue;

    // Sebagai kata utuh, bukan potongan. Tanpa ini "HP" tercocokkan di
    // dalam "SHARP", dan klaimnya berangkat ke brand yang keliru.
    final pola = RegExp('(^|[^A-Z0-9])${RegExp.escape(nama)}([^A-Z0-9]|\$)');
    if (!pola.hasMatch(t)) continue;

    if (ketemu != null && ketemu.id != b.id) return null;
    ketemu = b;
  }

  return ketemu;
}
