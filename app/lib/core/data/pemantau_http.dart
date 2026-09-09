import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart';

/// Merekam setiap percakapan dengan Supabase.
///
/// Dipasang sebagai pembungkus klien HTTP milik Supabase, jadi seluruh lalu
/// lintas lewat sini: baca, tulis, dan pembaruan token. Itu yang
/// membedakannya dari mencatat galat di tempat penulisan -- kegagalan yang
/// paling menyusahkan justru yang tidak melempar galat sama sekali.
///
/// Yang paling sering ditemukan di sini: UPDATE yang dijawab 200 dengan
/// badan `[]`. Bagi Postgres itu berhasil, bagi orang yang menekan tombol
/// itu berarti datanya tersimpan, dan keduanya salah -- yang sebenarnya
/// terjadi adalah aturan akses menyaring barisnya keluar tanpa sepatah kata
/// penolakan.
///
/// Hanya hidup di build debug. Di rilis, [PemantauHttp.bungkus] mengembalikan
/// klien aslinya tanpa perubahan apa pun.
class PemantauHttp extends BaseClient {
  PemantauHttp(this._dalam);

  final Client _dalam;

  /// Membungkus hanya saat debug. Di rilis, catatan selengkap ini akan
  /// membocorkan isi data pelanggan ke log perangkat.
  static Client? bungkus([Client? asli]) {
    if (!kDebugMode) return asli;
    return PemantauHttp(asli ?? Client());
  }

  var _nomor = 0;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final n = ++_nomor;
    final mulai = DateTime.now();

    // Jalurnya saja, tanpa tuan rumah: yang menjelaskan adalah tabel dan
    // penyaringnya, dan alamat proyek hanya memenuhi baris.
    final jalur =
        '${request.url.path}${request.url.hasQuery ? '?${request.url.query}' : ''}';
    final punyaToken = request.headers.keys.any(
      (k) => k.toLowerCase() == 'authorization',
    );

    String? badanKirim;
    if (request is Request && request.body.isNotEmpty) {
      badanKirim = _potong(request.body);
    }

    debugPrint(
      '[http #$n] → ${request.method} $jalur'
      '${punyaToken ? '' : '  (TANPA TOKEN)'}'
      '${badanKirim == null ? '' : '\n[http #$n]   kirim: $badanKirim'}',
    );

    try {
      final jawab = await _dalam.send(request);

      // Badannya harus dibaca untuk dicatat, lalu dirakit ulang -- aliran
      // hanya bisa dibaca sekali, dan yang memanggil masih membutuhkannya.
      final isi = await jawab.stream.toBytes();
      final teks = utf8.decode(isi, allowMalformed: true);
      final lama = DateTime.now().difference(mulai).inMilliseconds;

      // Larik kosong hanya mencurigakan pada perintah yang seharusnya
      // mengubah sesuatu. Pada GET itu cuma berarti tabelnya memang kosong,
      // dan menandainya sebagai peringatan hanya melatih orang mengabaikan
      // peringatan.
      final menulis = const {
        'POST',
        'PATCH',
        'PUT',
        'DELETE',
      }.contains(request.method);
      final kosong = menulis && teks.trim() == '[]';

      debugPrint(
        '[http #$n] ← ${jawab.statusCode} ${lama}ms'
        '${kosong ? '  ⚠ TIDAK ADA BARIS TERSENTUH' : ''}'
        '${teks.isEmpty ? '' : '\n[http #$n]   terima: ${_potong(teks)}'}',
      );

      return StreamedResponse(
        Stream.value(isi),
        jawab.statusCode,
        contentLength: isi.length,
        request: jawab.request,
        headers: jawab.headers,
        isRedirect: jawab.isRedirect,
        persistentConnection: jawab.persistentConnection,
        reasonPhrase: jawab.reasonPhrase,
      );
    } catch (e) {
      debugPrint('[http #$n] ✖ gagal: $e');
      rethrow;
    }
  }

  static String _potong(String s, [int batas = 400]) =>
      s.length <= batas ? s : '${s.substring(0, batas)}… (${s.length} huruf)';
}
