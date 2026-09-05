// Laporan penjualan part.
//
// Berkasnya benar-benar disusun lalu dibaca ulang. Yang paling mudah salah
// di sini bukan angkanya melainkan barisnya: kolom yang bergeser satu
// membuat modal terbaca sebagai harga jual, dan laporan yang salah kolom
// tetap terlihat rapi.

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sc_management/core/data/models.dart';
import 'package:sc_management/core/export/excel_export.dart';

PartOrder _pesanan({
  required String id,
  String nama = 'Jamal',
  String tahap = 'selesai',
  String? stok = 'ready',
  double? harga = 120000,
  double dp = 0,
  double sisa = 0,
}) => PartOrder(
  id: id,
  tanggal: DateTime(2026, 9, 4),
  customerNama: nama,
  barangType: 'ASUS X441',
  barangSn: 'SN$id',
  partReq: 'KEYBOARD',
  keterangan: 'oem',
  teknisiId: 't1',
  stok: stok,
  tahap: tahap,
  harga: harga,
  dp: dp,
  sisa: sisa,
  updatedAt: DateTime(2026, 9, 4),
);

LembarExcel _lembar(
  List<PartOrder> pesanan, {
  Map<String, PartCost> modal = const {},
}) => ExcelExport.lembarPart(
  pesanan: pesanan,
  teknisi: const {'t1': 'Reza'},
  modal: modal,
  periode: 'September 2026',
);

Sheet _bolakBalik(LembarExcel lembar) {
  final bytes = ExcelExport.susun([lembar]);
  expect(bytes, isNotNull);
  return Excel.decodeBytes(bytes!)[lembar.nama];
}

void main() {
  test('judul menyebut periodenya', () {
    final l = _lembar([_pesanan(id: '1')]);
    expect(l.tabel.single.judul, contains('SEPTEMBER 2026'));
  });

  test('kolomnya lengkap dan berurutan', () {
    final judul = _lembar([]).tabel.single.kolom.map((k) => k.judul);
    expect(judul, [
      'TANGGAL',
      'NAMA PELANGGAN',
      'TIPE',
      'SN',
      'PART REQ',
      'KET',
      'TEKNISI',
      'STOK',
      'TAHAP',
      'HPP',
      'UP %',
      'HARGA JUAL',
      'UNTUNG',
      'DP USER',
      'SISA',
    ]);
  });

  test('modal dan margin ikut saat datanya ada', () {
    final l = _lembar(
      [_pesanan(id: '1', harga: 120000)],
      modal: {
        '1': const PartCost(partOrderId: '1', hpp: 100000, upPersen: 20),
      },
    );

    final baris = l.tabel.single.baris.single;
    expect((baris[9] as DoubleCellValue).value, 100000); // HPP
    expect((baris[10] as DoubleCellValue).value, 20); // UP %
    expect((baris[11] as DoubleCellValue).value, 120000); // HARGA JUAL
    expect((baris[12] as DoubleCellValue).value, 20000); // UNTUNG
  });

  test('untung dikosongkan, bukan ditulis nol, saat modalnya belum diisi', () {
    // Nol di kolom ini akan terbaca sebagai jualan tanpa untung. Kosong
    // menyatakan yang sebenarnya: angkanya memang belum diketahui.
    final baris = _lembar([_pesanan(id: '1')]).tabel.single.baris.single;
    expect(baris[9], isNull);
    expect(baris[12], isNull);
  });

  test('stok dan tahap ditulis sebagai kata, bukan kode basis data', () {
    final baris = _lembar([
      _pesanan(id: '1', stok: 'kosong', tahap: 'dipasang'),
    ]).tabel.single.baris.single;

    expect((baris[7] as TextCellValue).value.toString(), 'NO STOK');
    expect((baris[8] as TextCellValue).value.toString(), 'PART DIPASANG');
  });

  test('stok yang belum dicek ditulis kosong, bukan tanda hubung', () {
    final baris = _lembar([
      _pesanan(id: '1', stok: null),
    ]).tabel.single.baris.single;
    expect((baris[7] as TextCellValue).value.toString(), '');
  });

  test('baris penutup menjumlahkan kolom uangnya', () {
    final l = _lembar(
      [
        _pesanan(id: '1', harga: 120000, dp: 50000, sisa: 70000),
        _pesanan(id: '2', harga: 80000, dp: 80000),
      ],
      modal: {
        '1': const PartCost(partOrderId: '1', hpp: 100000, upPersen: 20),
        '2': const PartCost(partOrderId: '2', hpp: 60000, upPersen: 33),
      },
    );

    final tutup = l.tabel.single.penutup!;
    expect((tutup[8] as TextCellValue).value.toString(), 'TOTAL');
    expect((tutup[9] as DoubleCellValue).value, 160000); // HPP
    expect((tutup[11] as DoubleCellValue).value, 200000); // Harga
    expect((tutup[12] as DoubleCellValue).value, 40000); // Untung
    expect((tutup[13] as DoubleCellValue).value, 130000); // DP
    expect((tutup[14] as DoubleCellValue).value, 70000); // Sisa
  });

  test('urut menurut tanggal, bukan urutan datangnya dari server', () {
    final l = ExcelExport.lembarPart(
      pesanan: [
        PartOrder(
          id: 'b',
          tanggal: DateTime(2026, 9, 20),
          customerNama: 'Belakangan',
          partReq: 'LCD',
          tahap: 'selesai',
          updatedAt: DateTime(2026, 9, 20),
        ),
        PartOrder(
          id: 'a',
          tanggal: DateTime(2026, 9, 2),
          customerNama: 'Duluan',
          partReq: 'LCD',
          tahap: 'selesai',
          updatedAt: DateTime(2026, 9, 2),
        ),
      ],
      teknisi: const {},
      modal: const {},
      periode: 'September 2026',
    );

    final nama = l.tabel.single.baris
        .map((b) => (b[1] as TextCellValue).value.toString())
        .toList();
    expect(nama, ['Duluan', 'Belakangan']);
  });

  test('berkasnya benar-benar tersusun dan bisa dibaca ulang', () {
    final sheet = _bolakBalik(
      _lembar(
        [_pesanan(id: '1', harga: 120000, dp: 50000, sisa: 70000)],
        modal: {
          '1': const PartCost(partOrderId: '1', hpp: 100000, upPersen: 20),
        },
      ),
    );

    // Judul, kepala kolom, satu baris data, satu baris penutup.
    expect(sheet.maxRows, 4);
    expect(sheet.maxColumns, 15);
  });
}
