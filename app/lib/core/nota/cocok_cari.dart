import '../data/models.dart';

/// Apakah sebuah nota cocok dengan kata yang diketik di kotak pencarian.
///
/// Yang dicocokkan adalah hal-hal yang biasa disebut orang saat mencari
/// unitnya: nomor nota (cukup ekornya), nama dan telepon pelanggan, nomor
/// seri, serta nama dan tipe barang. Kata kosong cocok dengan semuanya,
/// jadi kotak yang belum diisi tidak menyaring apa pun.
bool cocokCariNota(ServiceOrderEntry n, String kata) {
  final q = kata.trim().toLowerCase();
  if (q.isEmpty) return true;

  for (final s in [
    n.noNota,
    n.customerNama,
    n.customerTelp,
    n.barangSn,
    n.barangNama,
    n.barangType,
  ]) {
    if (s != null && s.toLowerCase().contains(q)) return true;
  }
  return false;
}
