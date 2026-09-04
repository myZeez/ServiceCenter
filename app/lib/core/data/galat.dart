import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'db.dart';

/// Menerjemahkan galat dari server jadi kalimat yang bisa ditindaklanjuti.
///
/// Sebelumnya isi PostgrestException ditampilkan apa adanya. Yang terbaca
/// orang di toko adalah "JWT issued at future code PGRST301" -- tepat, tapi
/// tidak memberi tahu apa pun tentang apa yang harus dilakukan, padahal
/// penyebabnya sepele dan ada di tangan mereka sendiri.
String pesanGalat(Object e) {
  // Penulisan yang diterima server tetapi tidak menyentuh satu baris pun.
  // Dulu ini lolos tanpa suara dan aplikasi berkata "tersimpan".
  if (e is GagalTulis) {
    return 'Perubahan tidak tersimpan: server menolaknya tanpa alasan yang '
        'bisa dibaca.\n\n'
        'Biasanya akun yang dipakai tidak berhak atas ${e.apa} itu, atau '
        'datanya sudah dihapus dari perangkat lain. Coba keluar lalu masuk '
        'lagi; kalau tetap begitu, sebutkan ini ke admin.';
  }

  if (e is PostgrestException) {
    final pesan = e.message.toLowerCase();

    // Jam perangkat lebih maju dari jam server, jadi token sesinya dinilai
    // terbit di masa depan dan ditolak. Sering terjadi di HP yang waktunya
    // disetel manual.
    if (pesan.contains('issued at future') || pesan.contains('not yet valid')) {
      return 'Jam di perangkat ini tidak cocok dengan jam server, jadi '
          'sesinya ditolak.\n\n'
          'Buka Setelan → Tanggal & waktu, nyalakan "Atur waktu otomatis", '
          'lalu buka ulang aplikasi.';
    }

    if (pesan.contains('jwt expired') || pesan.contains('token is expired')) {
      return 'Sesi login sudah kedaluwarsa. Keluar lalu masuk lagi.';
    }

    if (e.code == '42501' || pesan.contains('row-level security')) {
      return 'Akun ini tidak punya hak untuk data tersebut.';
    }

    if (e.code == '23505') {
      return 'Data dengan penanda yang sama sudah ada.';
    }

    if (e.code == '23503') {
      return 'Data yang dirujuk tidak ada atau sudah dihapus.';
    }

    return e.message;
  }

  final teks = e.toString();

  // Langganan Realtime gagal terpasang. Paling sering karena tabelnya belum
  // didaftarkan ke publikasi supabase_realtime -- lihat migrasi 0012.
  if (teks.contains('RealtimeSubscribeException') ||
      teks.contains('Unable to subscribe to changes')) {
    final tabel = RegExp(r'table: (\w+)').firstMatch(teks)?.group(1);
    return 'Realtime belum aktif untuk tabel '
        '${tabel ?? 'yang diminta'} di server.\n\n'
        'Jalankan migrasi 0012_realtime.sql di Supabase SQL Editor. '
        'Sementara itu data tetap ditarik berkala, hanya tidak seketika.';
  }

  if (teks.contains('SocketException') ||
      teks.contains('ClientException') ||
      teks.contains('Failed host lookup')) {
    return 'Tidak tersambung ke server. Periksa koneksi internetnya.';
  }

  return teks;
}

/// Selisih jam perangkat terhadap jam server, positif bila perangkat lebih
/// maju. Null berarti tidak terukur.
///
/// Diukur dari kepala `Date` pada jawaban server -- satu-satunya jam yang
/// pasti benar dari sudut pandang aplikasi. Gunanya memastikan dugaan soal
/// jam, bukan menebaknya.
Future<Duration?> selisihJam(String urlSupabase) async {
  final http = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final kirim = DateTime.now();
    final req = await http.headUrl(Uri.parse(urlSupabase));
    final res = await req.close();
    final terima = DateTime.now();
    await res.drain<void>();

    final kepala = res.headers.value('date');
    if (kepala == null) return null;

    final server = _parseHttpDate(kepala);
    if (server == null) return null;

    // Separuh waktu bolak-balik dikembalikan ke jam server, supaya lamanya
    // perjalanan jaringan tidak terbaca sebagai selisih jam.
    final perjalanan = terima.difference(kirim) ~/ 2;
    return terima.difference(server.toLocal().add(perjalanan));
  } catch (_) {
    return null;
  } finally {
    http.close(force: true);
  }
}

/// Kalimat siap tampil tentang jam perangkat, atau null kalau jamnya wajar.
///
/// Batas satu menit: di bawah itu tidak pernah jadi masalah, dan menegur
/// orang karena selisih beberapa detik hanya melatih mereka mengabaikan
/// peringatan.
String? pesanSelisihJam(Duration? selisih) {
  if (selisih == null) return null;
  final detik = selisih.inSeconds;
  if (detik.abs() < 60) return null;

  final besar = Duration(seconds: detik.abs());
  final lama = besar.inHours >= 1
      ? '${besar.inHours} jam ${besar.inMinutes % 60} menit'
      : '${besar.inMinutes} menit';

  return detik > 0
      ? 'Jam perangkat ini $lama lebih maju daripada jam server.'
      : 'Jam perangkat ini $lama lebih lambat daripada jam server.';
}

/// Kepala Date memakai format RFC 1123, yang tidak dikenali DateTime.parse.
DateTime? _parseHttpDate(String v) {
  const bulan = {
    'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
    'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
  };
  // Contoh: Thu, 04 Sep 2026 10:16:32 GMT
  final m = RegExp(
    r'\w{3}, (\d{2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT',
  ).firstMatch(v);
  if (m == null) return null;

  final b = bulan[m.group(2)];
  if (b == null) return null;

  return DateTime.utc(
    int.parse(m.group(3)!),
    b,
    int.parse(m.group(1)!),
    int.parse(m.group(4)!),
    int.parse(m.group(5)!),
    int.parse(m.group(6)!),
  );
}
