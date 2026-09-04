import 'package:flutter_test/flutter_test.dart';
import 'package:sc_management/core/nota/nomor_nota.dart';

void main() {
  final hari = DateTime(2026, 9, 4);

  group('Contoh nomor nota', () {
    test('angka urut selalu 5 digit', () {
      expect(contohNomorNota(1, hari), 'SRV-04092600001');
      expect(contohNomorNota(28177, hari), 'SRV-04092628177');
    });

    test('lima digit terakhir adalah angka urutnya sendiri', () {
      for (final n in [1, 42, 999, 28177, 99999]) {
        final nomor = contohNomorNota(n, hari);
        expect(int.parse(nomor.substring(nomor.length - 5)), n);
      }
    });

    test('tanggal ditulis ddMMyy dengan nol di depan', () {
      expect(contohNomorNota(1, DateTime(2026, 1, 7)), 'SRV-07012600001');
    });

    test('angka di atas 99999 dibiarkan tumbuh, bukan dipotong', () {
      // Nomor kepanjangan masih bisa dibaca orang; nomor yang terpotong
      // diam-diam berubah arti.
      expect(contohNomorNota(123456, hari), 'SRV-040926123456');
    });
  });
}
