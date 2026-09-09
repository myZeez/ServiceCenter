import 'package:flutter_test/flutter_test.dart';
import 'package:sc_management/core/providers.dart';
import 'package:sc_management/core/status.dart';

void main() {
  group('ClaimStatus', () {
    test('nilai status cocok dengan enum claim_status di Postgres', () {
      expect(ClaimStatus.all, [
        'open',
        'proses',
        'tunggu_part',
        'close',
        'batal',
      ]);
    });

    test('setiap status punya label bahasa Indonesia', () {
      for (final s in ClaimStatus.all) {
        expect(ClaimStatus.label(s), isNot(equals(s)));
      }
    });

    test('status tak dikenal tidak bikin crash', () {
      expect(ClaimStatus.label('entah'), 'entah');
    });
  });

  group('ClaimFilter', () {
    test('copyWith mempertahankan nilai yang tidak diubah', () {
      const f = ClaimFilter(brandId: 1, status: 'open', query: 'asus');
      final next = f.copyWith(query: 'acer');

      expect(next.brandId, 1);
      expect(next.status, 'open');
      expect(next.query, 'acer');
    });

    test('clearBrand mengosongkan filter brand', () {
      const f = ClaimFilter(brandId: 1, status: 'open');
      final next = f.copyWith(clearBrand: true);

      expect(next.brandId, isNull);
      expect(next.status, 'open');
    });

    test('clearStatus mengosongkan filter status', () {
      const f = ClaimFilter(brandId: 1, status: 'open');
      final next = f.copyWith(clearStatus: true);

      expect(next.status, isNull);
      expect(next.brandId, 1);
    });
  });
}
