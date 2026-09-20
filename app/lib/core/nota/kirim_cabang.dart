import 'package:intl/intl.dart';

final _tglKirim = DateFormat('dd-MM-yyyy');

/// Nilai status nota yang berarti unitnya sedang dikerjakan di cabang lain.
/// Harus sama persis dengan nilai enum service_status di migrasi 0032.
const statusDikirimCabang = 'dikirim_cabang';

/// Kalimat yang dibaca di nota, layar, dan laporan:
///
///     Unit dikirim ke Cabang Pangkalan Bun Tanggal 08-09-2026
///
/// Satu tempat, supaya yang tampil di layar dan yang tercetak di Excel
/// tidak bisa berbeda satu kata pun.
String keteranganKirimCabang(String cabang, DateTime tanggal) =>
    'Unit dikirim ke Cabang ${cabang.trim()} '
    'Tanggal ${_tglKirim.format(tanggal)}';
