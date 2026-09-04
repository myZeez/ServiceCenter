// Penerjemah galat server. Yang diuji bukan kalimatnya, melainkan bahwa
// keadaan yang sudah pernah terjadi sungguhan tidak lagi sampai ke layar
// sebagai istilah teknis.

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sc_management/core/data/galat.dart';

void main() {
  group('Pesan galat', () {
    test('jam perangkat yang maju dijelaskan beserta cara membetulkannya', () {
      // Ini yang muncul di HP: PGRST301, "JWT issued at future". Tepat
      // secara teknis, tapi tidak menyebut satu pun hal yang bisa dilakukan
      // orang yang membacanya.
      final pesan = pesanGalat(
        const PostgrestException(
          message: 'JWT issued at future',
          code: 'PGRST301',
        ),
      );

      expect(pesan, contains('Jam'));
      expect(pesan, contains('Atur waktu otomatis'));
      expect(pesan.toLowerCase(), isNot(contains('jwt')));
    });

    test('sesi kedaluwarsa menyuruh masuk lagi', () {
      final pesan = pesanGalat(
        const PostgrestException(message: 'JWT expired', code: 'PGRST301'),
      );
      expect(pesan.toLowerCase(), contains('masuk lagi'));
    });

    test('ditolak aturan akses tidak disebut sebagai galat sistem', () {
      final pesan = pesanGalat(
        const PostgrestException(
          message: 'new row violates row-level security policy',
          code: '42501',
        ),
      );
      expect(pesan.toLowerCase(), contains('hak'));
    });

    test('koneksi putus dikenali dari galat soket', () {
      final pesan = pesanGalat(
        Exception('SocketException: Failed host lookup'),
      );
      expect(pesan.toLowerCase(), contains('koneksi'));
    });

    test('galat yang tidak dikenali diteruskan apa adanya', () {
      // Lebih baik pesan mentah daripada kalimat menenangkan yang salah:
      // yang mentah masih bisa dicari, yang salah menyesatkan.
      final pesan = pesanGalat(
        const PostgrestException(message: 'sesuatu yang aneh', code: 'XX000'),
      );
      expect(pesan, 'sesuatu yang aneh');
    });
  });

  group('Selisih jam', () {
    test('selisih di bawah semenit tidak dilaporkan', () {
      expect(pesanSelisihJam(const Duration(seconds: 30)), isNull);
      expect(pesanSelisihJam(const Duration(seconds: -45)), isNull);
    });

    test('yang tidak terukur tidak dilaporkan', () {
      expect(pesanSelisihJam(null), isNull);
    });

    test('perangkat yang maju dan yang lambat dibedakan', () {
      expect(
        pesanSelisihJam(const Duration(minutes: 7)),
        contains('lebih maju'),
      );
      expect(
        pesanSelisihJam(const Duration(minutes: -7)),
        contains('lebih lambat'),
      );
    });

    test('selisih berjam-jam ditulis dalam jam dan menit', () {
      final pesan = pesanSelisihJam(
        const Duration(hours: 2, minutes: 15),
      );
      expect(pesan, contains('2 jam 15 menit'));
    });
  });
}
