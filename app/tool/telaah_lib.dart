// Pembaca CSV sederhana untuk skrip di folder ini.
//
// Sengaja ditulis sendiri, bukan memakai paket: berkas-berkas arsip ini
// dibaca sekali saat menyusun impor, dan menambah dependensi ke aplikasi
// yang dipasang di toko untuk keperluan sekali itu tidak sepadan.
/// [pemisah] karena tidak semua arsipnya berkoma: laporan harian yang
/// diekspor dari Excel memakai titik koma.
List<List<String>> baca(String isi, {String pemisah = ','}) {
  final hasil = <List<String>>[];
  var baris = <String>[];
  final sel = StringBuffer();
  var kutip = false;
  for (var i = 0; i < isi.length; i++) {
    final c = isi[i];
    if (kutip) {
      if (c == '"') {
        if (i + 1 < isi.length && isi[i + 1] == '"') { sel.write('"'); i++; }
        else { kutip = false; }
      } else { sel.write(c); }
    } else if (c == '"') { kutip = true; }
    else if (c == pemisah) { baris.add(sel.toString()); sel.clear(); }
    else if (c == '\n') { baris.add(sel.toString()); sel.clear(); hasil.add(baris); baris = <String>[]; }
    else if (c != '\r') { sel.write(c); }
  }
  if (sel.isNotEmpty || baris.isNotEmpty) { baris.add(sel.toString()); hasil.add(baris); }
  return hasil;
}

String g(List<String> b, int i) => i < b.length ? b[i].trim() : '';
