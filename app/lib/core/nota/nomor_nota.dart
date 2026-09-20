import 'package:intl/intl.dart';

final _tglNota = DateFormat('ddMMyy');

/// Bentuk nomor nota: `SVR-` + tanggal + angka urut 5 digit.
///
/// Ini salinan aturan yang dipakai `buat_no_nota()` di server, dan hanya
/// untuk memperlihatkan contoh di layar. Nomor yang sungguhan tetap
/// diterbitkan server: dua orang yang menyimpan nota pada detik yang sama
/// harus dijamin tidak pernah menerima angka yang sama, dan jaminan itu
/// hanya bisa diberikan dari satu tempat.
///
/// Lima digit karena pusat membaca nomor nota dengan mengambil 5 digit
/// terakhirnya. Angka yang melewati 99999 sengaja dibiarkan tumbuh, bukan
/// dipotong -- nomor yang kepanjangan masih bisa dibaca orang, nomor yang
/// terpotong diam-diam berubah arti.
String contohNomorNota(int nomor, DateTime tanggal) =>
    'SVR-${_tglNota.format(tanggal)}${nomor.toString().padLeft(5, '0')}';

/// Angka urut di ujung sebuah nomor nota, atau null kalau bentuknya tidak
/// dikenal.
///
/// Bentuknya `SVR-DDMMYY` lalu angka urut, jadi enam angka pertama sesudah
/// tanda hubung adalah tanggalnya, bukan urutannya.
int? urutanNota(String noNota) {
  final pisah = noNota.indexOf('-');
  final angka = pisah < 0 ? noNota : noNota.substring(pisah + 1);
  if (angka.length <= 6) return null;
  return int.tryParse(angka.substring(6));
}

/// Membandingkan dua nomor nota menurut angka urutnya -- urutan buku toko.
///
/// Membandingkan seluruh teksnya begitu saja salah dua kali. Pertama,
/// bagian tanggal di tengah ditulis DDMMYY, jadi tanggal 30 September
/// berdiri sebelum 1 Oktober karena "30" mendahului "01". Kedua,
/// awalannya pernah tidak seragam: 3.009 nota lama dari buku toko memakai
/// `SVR-` sementara yang diterbitkan aplikasi memakai `SRV-` (keliru; sejak
/// migrasi 0031 semuanya `SVR-`), dan 'R' mendahului 'V' -- seluruh nota
/// buatan aplikasi berbaris duluan, berapa pun nomornya. Urutan menurut
/// angka tidak peduli awalan, jadi tetap benar untuk data yang belum
/// diseragamkan.
///
/// Nomor yang tidak terbaca bentuknya ditaruh di belakang, diurutkan
/// menurut teksnya sendiri. Nomor kembar -- ada beberapa, sisa dari saat
/// penghitung aplikasi tertinggal dari buku -- juga jatuh ke situ, supaya
/// urutannya tetap sama setiap kali laporannya dibuat.
int bandingNomorNota(String a, String b) {
  final ua = urutanNota(a);
  final ub = urutanNota(b);

  if (ua == null && ub != null) return 1;
  if (ua != null && ub == null) return -1;
  if (ua != null && ub != null && ua != ub) return ua.compareTo(ub);

  return a.compareTo(b);
}
