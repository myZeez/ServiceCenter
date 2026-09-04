import 'package:intl/intl.dart';

final _tglNota = DateFormat('ddMMyy');

/// Bentuk nomor nota: `SRV-` + tanggal + angka urut 5 digit.
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
    'SRV-${_tglNota.format(tanggal)}${nomor.toString().padLeft(5, '0')}';
