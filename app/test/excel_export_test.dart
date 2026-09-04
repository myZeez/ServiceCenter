// Berkas Excel-nya benar-benar disusun lalu dibaca ulang, bukan sekadar
// dipercaya. Yang menentukan laporan ini rapi atau tidak ada di dalam
// berkasnya -- garis, lebar kolom, format angka, jenis sel -- dan tidak
// satu pun dari itu terlihat oleh flutter analyze.

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/export/excel_export.dart';

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
XmlDocument _styles(List<LembarExcel> lembar) {
  final zip = ZipDecoder().decodeBytes(ExcelExport.susun(lembar)!);
  final berkas = zip.files.firstWhere((f) => f.name == 'xl/styles.xml');
  return XmlDocument.parse(String.fromCharCodes(berkas.content as List<int>));
}

LembarExcel _contoh({String? judul, List<CellValue?>? penutup}) => LembarExcel(
  nama: 'Uji',
  tabel: [
    TabelExcel(
      judul: judul,
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
    ),
  ],
);

ServiceOrderEntry _nota({
  required String noNota,
  required DateTime masuk,
  DateTime? selesai,
  double biaya = 150000,
}) => ServiceOrderEntry(
  id: noNota,
  noNota: noNota,
  tanggalMasuk: masuk,
  customerNama: 'Budi',
  barangNama: 'ASUS',
  status: 'diambil',
  biaya: biaya,
  tanggalSelesai: selesai,
  updatedAt: masuk,
);

void main() {
  group('Bentuk tabel', () {
    test('setiap sel bergaris kotak penuh', () {
      // Bentuk yang dipakai laporan toko selama ini. Tanpa garis, kolom
      // yang isinya kosong tidak kelihatan batasnya saat dicetak.
      final sheet = _bolakBalik(_contoh());

      for (final (r, c) in [(0, 0), (0, 2), (1, 1), (2, 2)]) {
        final gaya = sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
            .cellStyle;
        expect(gaya?.leftBorder.borderStyle, BorderStyle.Thin, reason: 'r$r c$c');
        expect(gaya?.rightBorder.borderStyle, BorderStyle.Thin, reason: 'r$r c$c');
        expect(gaya?.topBorder.borderStyle, BorderStyle.Thin, reason: 'r$r c$c');
        expect(gaya?.bottomBorder.borderStyle, BorderStyle.Thin, reason: 'r$r c$c');
      }
    });

    test('kepala kolom ditebalkan', () {
      final sheet = _bolakBalik(_contoh());
      final sel = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      );
      expect(sel.cellStyle?.isBold, isTrue);
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

      for (var c = 0; c < 3; c++) {
        expect(lebar[c], isNotNull, reason: 'kolom $c tanpa lebar');
        expect(lebar[c]!, greaterThanOrEqualTo(10));
        expect(lebar[c]!, lessThanOrEqualTo(46));
      }
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

    test('rupiah ditulis lengkap dengan awalannya', () {
      final sheet = _bolakBalik(_contoh());
      final sel = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 1),
      );
      expect(sel.cellStyle?.numberFormat.formatCode, '"Rp"#,##0');
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

    test('rupiah rata kanan, tanggal rata tengah', () {
      // Diperiksa dari XML-nya langsung: decoder paket excel tidak membaca
      // kembali perataan sel, jadi bolak-balik lewat sana selalu menjawab
      // "rata kiri" betapa pun berkasnya benar.
      final gaya = _styles([_contoh()]);

      String? rataUntuk(String kodeFormat) {
        final id = gaya
            .findAllElements('numFmt')
            .firstWhere((e) => e.getAttribute('formatCode') == kodeFormat)
            .getAttribute('numFmtId');
        return gaya
            .findAllElements('cellXfs')
            .single
            .findElements('xf')
            .firstWhere((e) => e.getAttribute('numFmtId') == id)
            .findElements('alignment')
            .single
            .getAttribute('horizontal');
      }

      expect(rataUntuk('"Rp"#,##0'), 'right');
      expect(rataUntuk('dd/mm/yyyy'), 'center');
    });
  });

  group('Judul tabel', () {
    test('digabung selebar tabel dan ditaruh di tengah', () {
      final bytes = ExcelExport.susun([
        _contoh(judul: 'LAPORAN PERHARI TGL 04/09/2026'),
      ]);
      final sheet = Excel.decodeBytes(bytes!)['Uji'];

      // Tiga kolom, jadi A1:C1.
      expect(sheet.spannedItems, contains('A1:C1'));

      final v = sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
          .value;
      expect((v as TextCellValue).value.text, 'LAPORAN PERHARI TGL 04/09/2026');
    });

    test('tanpa judul, kepala kolom ada di baris pertama', () {
      final sheet = _bolakBalik(_contoh());
      final v = sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
          .value;
      expect((v as TextCellValue).value.text, 'Tanggal Lunas');
    });
  });

  group('Baris total', () {
    test('menempel di bawah data dengan garis', () {
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
      expect(total.cellStyle?.numberFormat.formatCode, '"Rp"#,##0');
    });
  });

  group('Laporan harian sebulan', () {
    test('satu tab untuk tiap tanggal di kalender', () {
      // Tanggal yang sepi tetap dibuatkan tabnya. Tab yang hilang membuat
      // pembacanya harus memeriksa apakah hari itu memang tidak ada
      // transaksi atau laporannya yang belum diisi.
      final lembar = ExcelExport.lembarHarianBulanan(
        semua: [],
        bulan: DateTime(2026, 2),
      );

      expect(lembar.length, 28, reason: 'Februari 2026 bukan tahun kabisat');
      expect(lembar.first.nama, '1');
      expect(lembar.last.nama, '28');
    });

    test('bulan 31 hari menghasilkan 31 tab', () {
      final lembar = ExcelExport.lembarHarianBulanan(
        semua: [],
        bulan: DateTime(2026, 8),
      );
      expect(lembar.length, 31);
    });

    test('nota masuk dan nota keluar dipisah jadi dua tabel', () {
      final lembar = ExcelExport.lembarHarian(
        semua: [
          _nota(
            noNota: 'A',
            masuk: DateTime(2026, 9, 3),
            selesai: DateTime(2026, 9, 4),
          ),
          _nota(noNota: 'B', masuk: DateTime(2026, 9, 4)),
        ],
        tanggal: DateTime(2026, 9, 4),
      );

      expect(lembar.tabel.length, 2);
      // Keluar: selesai hari itu. Masuk: diterima hari itu.
      expect(lembar.tabel[0].baris.length, 1);
      expect(lembar.tabel[1].baris.length, 1);
    });

    test('tiap tanggal hanya memuat transaksinya sendiri', () {
      final lembar = ExcelExport.lembarHarianBulanan(
        semua: [
          _nota(
            noNota: 'A',
            masuk: DateTime(2026, 9, 1),
            selesai: DateTime(2026, 9, 1),
          ),
        ],
        bulan: DateTime(2026, 9),
      );

      expect(lembar[0].tabel[0].baris.length, 1, reason: 'tanggal 1');
      expect(lembar[1].tabel[0].baris.length, 0, reason: 'tanggal 2');
    });
  });

  group('Keterangan harian', () {
    test('nota batal ditandai Cancel apa pun isinya', () {
      final n = ServiceOrderEntry(
        id: 'x',
        noNota: 'x',
        tanggalMasuk: DateTime(2026, 9, 4),
        customerNama: 'Budi',
        barangNama: 'ASUS',
        status: 'batal',
        garansi: true,
        keterangan: 'diambil pelanggan',
        updatedAt: DateTime(2026, 9, 4),
      );
      expect(ExcelExport.keteranganHarian(n), 'Cancel');
    });
  });
}
