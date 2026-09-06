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
  double? harga = 120000,
  double dp = 0,
  double sisa = 0,
  DateTime? tanggalDp,
  DateTime? tanggalOrder,
  String? noPo,
  String? catatan,
}) => PartOrder(
  id: id,
  tanggal: DateTime(2026, 9, 4),
  customerNama: nama,
  customerTelp: '0812',
  barangType: 'ASUS X441',
  barangSn: 'SN$id',
  partReq: 'KEYBOARD',
  keterangan: 'asus id',
  teknisiId: 't1',
  tahap: tahap,
  harga: harga,
  dp: dp,
  sisa: sisa,
  tanggalDp: tanggalDp,
  tanggalOrder: tanggalOrder,
  noPo: noPo,
  catatan: catatan,
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

  test('kolomnya mengikuti urutan sheet yang selama ini dipakai', () {
    final judul = _lembar([]).tabel.single.kolom.map((k) => k.judul);
    expect(judul, [
      'TANGGAL DP',
      'NAMA CUSTOMER',
      'NO TELP',
      'SN',
      'MERK/TIPE',
      'PART',
      'STATUS',
      'TANGGAL ORDER',
      'TEKNISI',
      'HARGA HPP',
      'UP %',
      'HARGA JUAL',
      'UNTUNG',
      'DP USER',
      'SISA',
      'NO PO',
      'KETERANGAN',
      'CATATAN',
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
    expect((baris[9] as DoubleCellValue).value, 100000); // HARGA HPP
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

  test('status ditulis dengan istilah sheet lama, bukan kode basis data', () {
    for (final (tahap, teks) in const [
      ('foto', 'WAIT FOTO/KODE PART'),
      ('harga', 'TUNGGU HARGA'),
      ('konfirmasi', 'WAIT CONFIRM USER DP'),
      ('dipesan', 'ORDERED'),
      ('selesai', 'CLOSE'),
      ('batal', 'CANCEL'),
      ('kosong', 'NO STOCK'),
    ]) {
      final baris = _lembar([
        _pesanan(id: '1', tahap: tahap, harga: null),
      ]).tabel.single.baris.single;
      expect((baris[6] as TextCellValue).value.toString(), teks);
    }
  });

  test('tanggal DP dipakai kalau ada, tanggal bertanya kalau belum', () {
    final adaDp = _lembar([
      _pesanan(id: '1', tanggalDp: DateTime(2026, 9, 20)),
    ]).tabel.single.baris.single;
    expect((adaDp[0] as DateCellValue).day, 20);

    final belum = _lembar([_pesanan(id: '2')]).tabel.single.baris.single;
    expect((belum[0] as DateCellValue).day, 4);
  });

  test('kolom pemesanan ikut: tanggal order, no PO, dan catatan', () {
    final baris = _lembar([
      _pesanan(
        id: '1',
        tanggalOrder: DateTime(2026, 9, 8),
        noPo: 'IDD7510006',
        catatan: 'ORI KB MODULE 3-6 WEEK',
      ),
    ]).tabel.single.baris.single;

    expect((baris[7] as DateCellValue).day, 8);
    expect((baris[15] as TextCellValue).value.toString(), 'IDD7510006');
    expect((baris[16] as TextCellValue).value.toString(), 'ASUS ID');
    expect(
      (baris[17] as TextCellValue).value.toString(),
      'ORI KB MODULE 3-6 WEEK',
    );
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
    // Penutupnya harus selebar tabelnya, atau garis tepinya putus di
    // tengah baris total.
    expect(tutup.length, l.tabel.single.kolom.length);
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
    expect(sheet.maxColumns, 18);
  });
}
