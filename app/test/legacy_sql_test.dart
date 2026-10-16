import 'package:flutter_test/flutter_test.dart';
import 'package:sc_management/core/import/legacy_sql.dart';

void main() {
  const header =
      'CREATE TABLE `servis` (\n`kode` text,\n`tanggal` text,\n`nama_pelanggan` text,\n`barang` text,\n`teknisi` text,\n`jumlah` text,\n`kerusakan` text,\n`sudahdiambil` text,\n`tanggal_kembali` text\n);\n';
  test(
    'quoted semicolons, commas and escapes are data; SQL is never executed',
    () {
      final rows = parseLegacySql(
        '$header INSERT INTO servis VALUES '
        '("SVR-12102628723","2026-10-12","O\\\"Brien","LAPTOP","AIRS","100000","a; b, c","True","2026-10-12"); DROP TABLE servis;',
      );
      expect(rows.single['customer_nama'], 'O"Brien');
      expect(rows.single['keluhan'], 'a; b, c');
      expect(rows.single['teknisi'], 'ARIS');
      expect(rows.single['status'], 'diambil');
      expect(rows.single.containsKey('tanggal_lunas'), false);
    },
  );
  test('empty technician and default zero do not imply warranty/payment', () {
    final rows = parseLegacySql(
      '$header INSERT INTO servis VALUES '
      '("SVR-12102628723","2026-10-12","Nama","LAPTOP","","0","keluhan","False","1899-12-30");',
    );
    expect(rows.single['teknisi'], '');
    expect(rows.single['tanggal_diambil'], null);
    expect(rows.single.containsKey('garansi'), false);
  });
  test('truncated backup is rejected', () {
    expect(
      () => parseLegacySql('$header INSERT INTO servis VALUES ("SVR-'),
      throwsFormatException,
    );
  });
  test('missing schema and duplicate notes are rejected', () {
    expect(() => parseLegacySql('DROP TABLE servis;'), throwsFormatException);
    const tuple =
        '("SVR-12102628723","2026-10-12","Nama","LAPTOP","","0","k","False","1899-12-30")';
    expect(
      () => parseLegacySql('$header INSERT INTO servis VALUES $tuple,$tuple;'),
      throwsFormatException,
    );
  });
}
