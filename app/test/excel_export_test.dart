// Berkas Excel-nya benar-benar disusun lalu dibaca ulang, bukan sekadar
// dipercaya. Yang menentukan laporan ini rapi atau tidak ada di dalam
// berkasnya -- lebar kolom, format angka, jenis sel -- dan tidak satu pun
// dari itu terlihat oleh flutter analyze.

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'package:sc_management/core/export/excel_export.dart';

/// Menyusun lalu membaca ulang, seperti yang dilakukan Excel saat berkasnya
/// dibuka.
Sheet _bolakBalik(LembarExcel lembar) {
  final bytes = ExcelExport.susun([lembar]);
  expect(bytes, isNotNull);
  return Excel.decodeBytes(bytes!)[lembar.nama];
}

/// Isi `xl/styles.xml` dari berkas yang dihasilkan.
///
/// Berkas xlsx adalah zip berisi XML. Sebagian gaya -- perataan sel --
/// tidak dibaca kembali oleh decoder paket excel, jadi satu-satunya cara
/// memastikannya adalah membaca berkasnya seperti yang dibaca Excel.
XmlDocument _styles(LembarExcel lembar) {
  final zip = ZipDecoder().decodeBytes(ExcelExport.susun([lembar])!);
  final berkas = zip.files.firstWhere((f) => f.name == 'xl/styles.xml');
  return XmlDocument.parse(String.fromCharCodes(berkas.content as List<int>));
}

LembarExcel _contoh({String? judul, List<CellValue?>? penutup}) => LembarExcel(
  nama: 'Uji',
  judul: judul,
  subjudul: judul == null ? null : 'Periode September 2026',
  kolom: const [
    KolomExcel('Tanggal Lunas', jenis: JenisKolom.tanggal),
    KolomExcel('Nama Customer'),
    KolomExcel('Biaya', jenis: JenisKolom.rupiah),
  ],
  baris: [
    [
      DateCellValue(year: 2026, month: 9, day: 4),
      TextCellValue('Budi'),
      DoubleCellValue(150000),
    ],
    [null, TextCellValue('Sari'), DoubleCellValue(90000)],
  ],
  penutup: penutup,
);

void main() {
  group('Bentuk tabel', () {
    test('kepala kolom ditebalkan dan diberi garis bawah', () {
      final sheet = _bolakBalik(_contoh());
      final sel = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      );

      expect(sel.cellStyle?.isBold, isTrue);
      expect(sel.cellStyle?.bottomBorder.borderStyle, BorderStyle.Thin);
    });

    test('tidak ada warna latar sama sekali', () {
      // Laporan ini dicetak dan difoto. Warna latar yang bagus di layar
      // jadi abu-abu kotor di kertas.
      final sheet = _bolakBalik(_contoh());
      for (final baris in sheet.rows) {
        for (final sel in baris) {
          expect(
            sel?.cellStyle?.backgroundColor,
            anyOf(isNull, ExcelColor.none),
            reason: 'sel berwarna: ${sel?.value}',
          );
        }
      }
    });

    test('lebar kolom mengikuti isi terpanjangnya', () {
      final sheet = _bolakBalik(_contoh());
      final lebar = sheet.getColumnWidths;

      // Semua kolom harus punya lebar tersetel -- kalau tidak, Excel
      // memakai lebar bawaan dan angka panjang muncul sebagai "#####".
      for (var c = 0; c < 3; c++) {
        expect(lebar[c], isNotNull, reason: 'kolom $c tanpa lebar');
        expect(lebar[c]!, greaterThanOrEqualTo(10));
        expect(lebar[c]!, lessThanOrEqualTo(46));
      }

      // "Tanggal Lunas" lebih panjang daripada "Biaya", jadi kolomnya juga.
      expect(lebar[0]!, greaterThan(lebar[2]!));
    });
  });

  group('Jenis sel', () {
    test('biaya tetap angka, bukan teks', () {
      // Kalau jadi teks, penerimanya tidak bisa menjumlahkan tanpa
      // membersihkannya dulu -- persis pekerjaan yang mau dihindari.
      final sheet = _bolakBalik(_contoh());
      final sel = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 1),
      );

      expect(sel.value, isA<IntCellValue>());
      expect((sel.value as IntCellValue).value, 150000);
    });

    test('biaya memakai pemisah ribuan tanpa desimal', () {
      final sheet = _bolakBalik(_contoh());
      final sel = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 1),
      );

      expect(sel.cellStyle?.numberFormat.formatCode, '#,##0');
    });

    test('tanggal tetap tanggal, bukan teks', () {
      // Tanggal berbentuk teks tidak bisa diurutkan menurut waktu:
      // "01/12/2026" mendahului "02/01/2027" kalau dibandingkan per huruf.
      final sheet = _bolakBalik(_contoh());
      final sel = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
      );

      expect(sel.value, isA<DateCellValue>());
      expect(sel.cellStyle?.numberFormat.formatCode, 'dd/mm/yyyy');
    });

    test('tanggal kosong dibiarkan kosong, bukan diisi tanda hubung', () {
      final sheet = _bolakBalik(_contoh());
      final sel = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2),
      );

      expect(sel.value, isNull);
    });

    test('angka dan tanggal rata kanan di dalam berkasnya', () {
      // Diperiksa dari XML-nya langsung, bukan lewat Excel.decodeBytes:
      // decoder paket excel tidak membaca kembali perataan sel, jadi
      // bolak-balik lewat sana selalu menjawab "rata kiri" betapa pun
      // berkasnya benar. Yang menentukan apa yang dilihat Excel adalah isi
      // styles.xml ini.
      final gaya = _styles(_contoh());

      // Tiap format angka bikinan sendiri harus dipakai oleh xf yang rata
      // kanan. Kalau perataannya hilang, angka menempel di tepi kiri kolom
      // dan kolom biaya jadi tidak bisa dibaca berderet.
      for (final kode in ['#,##0', 'dd/mm/yyyy']) {
        final id = gaya
            .findAllElements('numFmt')
            .firstWhere((e) => e.getAttribute('formatCode') == kode)
            .getAttribute('numFmtId');

        final xf = gaya
            .findAllElements('cellXfs')
            .single
            .findElements('xf')
            .where((e) => e.getAttribute('numFmtId') == id);

        expect(xf, isNotEmpty, reason: 'tidak ada sel berformat $kode');
        for (final e in xf) {
          expect(
            e.findElements('alignment').single.getAttribute('horizontal'),
            'right',
            reason: 'format $kode tidak rata kanan',
          );
        }
      }
    });
  });

  group('Kepala laporan', () {
    test('judul dan periode ditulis di atas tabel', () {
      final sheet = _bolakBalik(_contoh(judul: 'LAPORAN PELUNASAN SERVIS'));

      String? teks(int baris) {
        final v = sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: baris))
            .value;
        return v is TextCellValue ? v.value.text : null;
      }

      expect(teks(0), 'LAPORAN PELUNASAN SERVIS');
      expect(teks(1), contains('September 2026'));
      // Baris kosong pemisah, lalu kepala kolom.
      expect(teks(3), 'Tanggal Lunas');
    });

    test('tanpa judul, tabel mulai dari baris pertama', () {
      final sheet = _bolakBalik(_contoh());
      final sel = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      );

      expect((sel.value as TextCellValue).value.text, 'Tanggal Lunas');
    });
  });

  group('Baris total', () {
    test('menempel di bawah data dengan garis pemisah', () {
      // Baris kosong di antaranya membuat Excel berhenti menganggapnya satu
      // tabel saat diurutkan atau disaring.
      final sheet = _bolakBalik(
        _contoh(
          penutup: [null, TextCellValue('TOTAL'), DoubleCellValue(240000)],
        ),
      );

      final total = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 3),
      );

      expect((total.value as IntCellValue).value, 240000);
      expect(total.cellStyle?.isBold, isTrue);
      expect(total.cellStyle?.topBorder.borderStyle, BorderStyle.Thin);
      expect(total.cellStyle?.numberFormat.formatCode, '#,##0');
    });
  });
}
