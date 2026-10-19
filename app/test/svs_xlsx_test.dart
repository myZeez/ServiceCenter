// Membaca buku SVS bulanan (xlsx) untuk impor.
//
// Yang paling dijaga: tanggal lembar datang dari judulnya, bukan dari nama
// berkas atau tab. Pada 19 Oktober 2026 berkas "SVS OKTOBER 2026.xlsx"
// ternyata berisi lembar September; dibaca menurut namanya, seluruh isi
// September akan tercatat sebagai Oktober tanpa satu pun galat.

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sc_management/core/import/svs_xlsx.dart';

List<int> _buku(Map<String, List<List<CellValue?>>> lembar) {
  final x = Excel.createExcel();
  final bawaan = x.getDefaultSheet();
  for (final e in lembar.entries) {
    final s = x[e.key];
    for (final b in e.value) {
      s.appendRow(b);
    }
  }
  if (bawaan != null && !lembar.containsKey(bawaan)) x.delete(bawaan);
  return x.encode()!;
}

TextCellValue _t(String s) => TextCellValue(s);

List<List<CellValue?>> _lembar(String judul) => [
  [null, _t(judul)],
  [
    null,
    _t('NAMA'),
    _t('NO NOTA'),
    _t('JENIS BARANG'),
    _t('PERBAIKAN'),
    _t('BIAYA'),
    _t('TANGGAL MASUK'),
    _t('KETERANGAN'),
  ],
  [
    null,
    _t('Josua Christian '),
    const IntCellValue(28578),
    _t('Laptop Lenovo Loq'),
    _t('Pasang SSD'),
    const IntCellValue(300000),
    const DateCellValue(year: 2026, month: 9, day: 30),
    null,
  ],
  [
    null,
    _t('Ahsan'),
    const IntCellValue(28198),
    _t('Printer Canon G2010'),
    _t('Maintenance'),
    const IntCellValue(300000),
    const DateCellValue(year: 2026, month: 9, day: 3),
    _t('QR BTN'),
  ],
  [
    null,
    _t('Marianti'),
    const IntCellValue(28439),
    _t('Laptop Ideapad'),
    _t('Ganti Wifi Card'),
    const IntCellValue(0),
    const DateCellValue(year: 2026, month: 9, day: 20),
    _t('Garansi'),
  ],
  [],
  [
    null,
    _t('NAMA'),
    _t('NO NOTA'),
    _t('NO HP'),
    _t('JENIS BARANG'),
    _t('KELUHAN'),
    _t('TANGGAL LUNAS'),
  ],
  [
    null,
    _t('Tumiwa K'),
    _t('28579'),
    _t('0823-1214-0625'),
    _t('Printer Canon G2020'),
    _t('Tidak Bisa Print'),
    null,
  ],
  [null, _t('-'), const IntCellValue(28580), null, null, null, null],
];

void main() {
  test('membaca tabel keluar dan masuk menurut kepala kolomnya', () {
    final b = bacaSvsXlsx(
      _buku({'01': _lembar('LAPORAN PERHARI TGL 01/10/2026')}),
    );

    expect(b.hari, [DateTime(2026, 10, 1)]);
    expect(b.keluar.keys, containsAll([28578, 28198, 28439]));
    final k = b.keluar[28198]!;
    expect(k.tanggal, DateTime(2026, 10, 1));
    expect(k.biaya, 300000);
    expect(k.keterangan, 'QR BTN');
    expect(k.perbaikan, 'Maintenance');
    expect(b.keluar[28578]!.nama, 'Josua Christian', reason: 'spasi dirapikan');

    final m = b.masuk[28579]!;
    expect(m.nama, 'Tumiwa K');
    expect(m.telp, '0823-1214-0625');
    expect(m.keluhan, 'Tidak Bisa Print');
    expect(
      b.masuk.containsKey(28580),
      false,
      reason: 'nama "-" berarti kosong',
    );
  });

  test('tanggal dari judul lembar, bukan dari nama tab', () {
    // Tab "05" dari berkas bernama Oktober, tetapi judulnya September.
    final b = bacaSvsXlsx(
      _buku({'05': _lembar('LAPORAN PERHARI TGL 01/09/2026')}),
    );
    expect(b.hari, [DateTime(2026, 9, 1)]);
    expect(b.keluar[28198]!.tanggal, DateTime(2026, 9, 1));
  });

  test('lembar tanpa judul bertanggal dilewati dengan peringatan', () {
    final b = bacaSvsXlsx(
      _buku({
        '01': _lembar('LAPORAN PERHARI TGL 01/10/2026'),
        'Catatan': [
          [null, _t('NAMA'), _t('NO NOTA'), _t('NO HP')],
          [null, _t('Siapa'), const IntCellValue(29999), _t('0812')],
        ],
      }),
    );
    expect(b.masuk.containsKey(29999), false);
    expect(b.peringatan.single, contains('Catatan'));
  });

  test('berkas tanpa satu pun lembar SVS ditolak', () {
    expect(
      () => bacaSvsXlsx(
        _buku({
          'Data': [
            [_t('bukan buku SVS')],
          ],
        }),
      ),
      throwsFormatException,
    );
    expect(() => bacaSvsXlsx([1, 2, 3]), throwsFormatException);
  });

  group('nasibKeluarSvs: sama dengan skrip SVS harian', () {
    test('keterangan kosong berarti tunai, lunas', () {
      final n = nasibKeluarSvs(null, 150000);
      expect(
        (n.status, n.caraBayar, n.lunas, n.biaya),
        ('diambil', 'cash', true, 150000),
      );
    });
    test('cancel dan garansi tanpa pembayaran', () {
      final c = nasibKeluarSvs('Cancel', 50000);
      expect(
        (c.status, c.biaya, c.caraBayar, c.lunas),
        ('batal', 0, null, false),
      );
      final g = nasibKeluarSvs('Garansi', 0);
      expect((g.status, g.garansi, g.caraBayar), ('diambil', true, null));
    });
    test('cara bayar dari keterangan', () {
      expect(nasibKeluarSvs('QR BTN', 1).caraBayar, 'qris');
      expect(nasibKeluarSvs('Gesek BRI', 1).caraBayar, 'gesek_bri');
      expect(nasibKeluarSvs('TF BRI', 1).caraBayar, 'transfer_bri');
      expect(nasibKeluarSvs('Transfer', 1).caraBayar, 'transfer_bri');
      expect(nasibKeluarSvs('BTN', 1).caraBayar, 'transfer_btn');
    });
    test('piutang: sudah dibawa pulang, belum lunas', () {
      final p = nasibKeluarSvs('Piutang', 200000);
      expect((p.caraBayar, p.lunas, p.biaya), ('piutang', false, 200000));
    });
  });
}
