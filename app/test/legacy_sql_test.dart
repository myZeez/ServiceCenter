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
        '("SVR-12102628723","2026-10-12","O\\"Brien","LAPTOP","AIRS","100000","a; b, c","True","2026-10-12"); DROP TABLE servis;',
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
    expect(rows.single['garansi'], false);
    expect(rows.single['jam_diambil'], null);
  });

  group('keterangan saat diserahkan', () {
    // Kolom yang dipakai backup sungguhan untuk penanda dan jam.
    const lengkap =
        'CREATE TABLE `servis` (\n`kode` text,\n`tanggal` text,\n`nama_pelanggan` text,\n`barang` text,\n`teknisi` text,\n`jumlah` text,\n`kerusakan` text,\n`sudahdiambil` text,\n`dibatalkan` text,\n`tanggal_kembali` text,\n`jam` text,\n`jamkembali` text,\n`keterangan_saat_sudah_cek` text\n);\n';
    Map<String, dynamic> satu(String tuple) =>
        parseLegacySql('$lengkap INSERT INTO servis VALUES $tuple;').single;

    test(
      'CANCEL di keterangan menjadi batal, walau kolom dibatalkan kosong',
      () {
        final r = satu(
          '("SVR-04102628617","2026-10-04","Aula","LAPTOP","AGUS","150000","x","True","False","2026-10-18","10:25:03","","CANCEL")',
        );
        expect(r['status'], 'batal');
        expect(r['biaya'], 0);
        expect(r['garansi'], false);
        expect(r['tanggal_diambil'], '2026-10-18');
      },
    );

    test('GARANSI di keterangan: diambil, bertanda garansi, tanpa biaya', () {
      final r = satu(
        '("SVR-16102628800","2026-10-16","Joseph","LAPTOP","ADMIN","0","x","True","False","2026-10-16","15:05:01","","GARANSI")',
      );
      expect(r['status'], 'diambil');
      expect(r['garansi'], true);
      expect(r['biaya'], 0);
    });

    test('jam penyerahan: jamkembali bila ada, kolom jam bila kosong', () {
      final bayar = satu(
        '("SVR-13092628338","2026-09-13","A","LAPTOP","AGUS","200000","x","True","False","2026-10-16","12:58:52","13:08:56","")',
      );
      expect(bayar['jam_diambil'], '13:08:56');
      final garansi = satu(
        '("SVR-13092628333","2026-09-13","B","LAPTOP","AGUS","0","x","True","False","2026-10-18","17:18:48","","GARANSI")',
      );
      expect(garansi['jam_diambil'], '17:18:48');
    });

    test('nomor urut dan nama teknisi yang salah ketik', () {
      final r = satu(
        '("SVR-18102628828","2026-10-18","Ali","LAPTOP","IIRWAN","0","x","False","False","1899-12-30","17:51:21","","")',
      );
      expect(r['urut'], 28828);
      expect(r['teknisi'], 'IRWAN');
      expect(r['status'], 'masuk');
      expect(r['jam_diambil'], null, reason: 'belum diserahkan');
    });

    test('GARANSI pada nota yang belum diambil tidak menandai apa pun', () {
      final r = satu(
        '("SVR-18102628812","2026-10-18","Ayu","PRINTER","ADMIN","0","x","False","False","1899-12-30","10:00:00","","GARANSI")',
      );
      expect(r['status'], 'masuk');
      expect(r['garansi'], false);
    });
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
