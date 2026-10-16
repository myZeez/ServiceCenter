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
          const DateCellValue(year: 2026, month: 9, day: 4),
          TextCellValue('Budi'),
          const DoubleCellValue(150000),
        ],
        [null, TextCellValue('Sari'), const DoubleCellValue(90000)],
      ],
      penutup: penutup,
    ),
  ],
);

ServiceOrderEntry _nota({
  required String noNota,
  required DateTime masuk,
  DateTime? selesai,
  DateTime? diambil,
  double biaya = 150000,
  String status = 'diambil',
}) => ServiceOrderEntry(
  id: noNota,
  noNota: noNota,
  tanggalMasuk: masuk,
  customerNama: 'Budi',
  barangNama: 'ASUS',
  status: status,
  biaya: biaya,
  tanggalSelesai: selesai,
  tanggalDiambil: diambil ?? selesai,
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
        expect(
          gaya?.leftBorder.borderStyle,
          BorderStyle.Thin,
          reason: 'r$r c$c',
        );
        expect(
          gaya?.rightBorder.borderStyle,
          BorderStyle.Thin,
          reason: 'r$r c$c',
        );
        expect(
          gaya?.topBorder.borderStyle,
          BorderStyle.Thin,
          reason: 'r$r c$c',
        );
        expect(
          gaya?.bottomBorder.borderStyle,
          BorderStyle.Thin,
          reason: 'r$r c$c',
        );
      }
    });

    test('kepala kolom ditebalkan', () {
      final sheet = _bolakBalik(_contoh());
      final sel = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      );
      expect(sel.cellStyle?.isBold, isTrue);
    });

    test('tidak berwarna kalau tidak diminta', () {
      // Laporan ini dicetak dan difoto, dan warna yang bagus di layar jadi
      // abu-abu kotor di kertas -- jadi warna hanya muncul di tabel yang
      // memang memintanya lewat warnaBaris, tidak pernah sebagai bawaan.
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
          penutup: [
            null,
            TextCellValue('TOTAL'),
            const DoubleCellValue(240000),
          ],
        ),
      );
      final total = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 3),
      );

      expect((total.value as IntCellValue).value, 240000);
      expect(total.cellStyle?.isBold, isTrue);
      expect(total.cellStyle?.numberFormat.formatCode, '"Rp"#,##0');
    });

    test('kolomnya cukup lebar untuk totalnya, bukan hanya isinya', () {
      // Total sebulan jauh lebih panjang daripada biaya satu nota. Angka
      // yang tidak muat tidak meluber seperti teks -- Excel menggantinya
      // dengan "########".
      final sheet = _bolakBalik(
        _contoh(
          penutup: [
            null,
            TextCellValue('TOTAL'),
            const DoubleCellValue(39865000),
          ],
        ),
      );

      // "Rp39.865.000" -- dua belas huruf, ditambah ruang untuk tebalnya.
      expect(sheet.getColumnWidths[2]!, greaterThan(12));
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
        libur: const {},
      );

      expect(lembar.length, 28, reason: 'Februari 2026 bukan tahun kabisat');
      expect(lembar.first.nama, '1');
      expect(lembar.last.nama, '28');
    });

    test('bulan 31 hari menghasilkan 31 tab', () {
      final lembar = ExcelExport.lembarHarianBulanan(
        semua: [],
        bulan: DateTime(2026, 8),
        libur: const {},
      );
      expect(lembar.length, 31);
    });

    // Berkas SVS yang dipakai toko memang tidak punya lembar Sabtu: toko
    // tutup. Tab kosong di tengah bulan terbaca seperti laporan yang
    // belum diisi.
    test('hari libur tidak diterbitkan tabnya', () {
      final lembar = ExcelExport.lembarHarianBulanan(
        semua: [],
        bulan: DateTime(2026, 9),
      );

      // September 2026 punya 30 hari dan empat Sabtu: 5, 12, 19, 26.
      expect(lembar.map((l) => l.nama), isNot(contains('5')));
      expect(lembar.map((l) => l.nama), isNot(contains('12')));
      expect(lembar.map((l) => l.nama), isNot(contains('19')));
      expect(lembar.map((l) => l.nama), isNot(contains('26')));
      expect(lembar.length, 26);
      expect(lembar.first.nama, '1');
      expect(lembar.last.nama, '30');
    });

    test('hari liburnya bisa hari lain', () {
      final lembar = ExcelExport.lembarHarianBulanan(
        semua: [],
        bulan: DateTime(2026, 9),
        libur: const {DateTime.sunday},
      );

      // Minggu di September 2026: 6, 13, 20, 27.
      expect(lembar.map((l) => l.nama), contains('5'));
      expect(lembar.map((l) => l.nama), isNot(contains('6')));
      expect(lembar.length, 26);
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
      // Keluar: sudah diambil hari itu. Masuk: diterima hari itu.
      expect(lembar.tabel[0].baris.length, 1);
      expect(lembar.tabel[1].baris.length, 1);
    });

    test(
      'nota batal tercetak sebagai unit keluar pada tanggal pengembaliannya',
      () {
        final lembar = ExcelExport.lembarHarian(
          semua: [
            _nota(
              noNota: 'BATAL',
              masuk: DateTime(2026, 9, 3),
              selesai: DateTime(2026, 9, 4),
              status: 'batal',
            ),
          ],
          tanggal: DateTime(2026, 9, 4),
        );

        expect(lembar.tabel[0].baris.length, 1);
        expect(
          (lembar.tabel[0].baris.single[1] as TextCellValue).value.text,
          'BATAL',
        );
      },
    );

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

    test('nota masuk malam tetap di tab hari itu', () {
      // Nota masuk memakai hari kalender. Unit yang diterima jam 19.45
      // tanggal 4 diterima tanggal 4, dan tab tanggal 5 yang memuatnya
      // akan berselisih dengan buku di meja depan.
      //
      // Sempat digeser di jam 17.00 bersama nota keluar. Jam tutup itu
      // milik laporan keluar -- yang dikirim ke pusat sore hari --
      // bukan milik penerimaan barang.
      final lembar = ExcelExport.lembarHarianBulanan(
        semua: [
          _nota(noNota: 'PAGI', masuk: DateTime(2026, 9, 4, 9, 0)),
          _nota(noNota: 'MALAM', masuk: DateTime(2026, 9, 4, 19, 45)),
          _nota(noNota: 'AKHIR', masuk: DateTime(2026, 9, 4, 23, 59)),
        ],
        bulan: DateTime(2026, 9),
      );

      // Tabel kedua tiap lembar adalah nota masuk.
      expect(lembar[3].tabel[1].baris.length, 3, reason: 'tanggal 4');
      expect(lembar[4].tabel[1].baris.length, 0, reason: 'tanggal 5');
    });

    test('nota keluar ikut tanggal pengambilan yang distempel server', () {
      // Jam tutup nota keluar dijalankan server waktu menstempel
      // tanggal_diambil. Ekspor ini tidak menggeser apa pun lagi --
      // menggeser dua kali memindahkan unit sehari terlalu jauh.
      //
      // Unit ini masuk tanggal 4 pagi dan diambil sesudah jam 17.00
      // tanggal 4, jadi server menstempelnya tanggal 5: masuknya di tab
      // 4, keluarnya di tab 5.
      final lembar = ExcelExport.lembarHarianBulanan(
        semua: [
          _nota(
            noNota: 'SORE',
            masuk: DateTime(2026, 9, 4, 10, 0),
            selesai: DateTime(2026, 9, 4),
            diambil: DateTime(2026, 9, 5),
          ),
        ],
        bulan: DateTime(2026, 9),
        // Tanggal 5 jatuh hari Sabtu; di sini yang diuji pergeseran
        // jamnya, bukan hari liburnya.
        libur: const {},
      );

      // Dicari menurut nama tabnya, bukan urutannya: hari libur membuat
      // nomor tab dan urutan daftar tidak lagi sama.
      LembarExcel tab(String nama) => lembar.firstWhere((l) => l.nama == nama);

      expect(tab('4').tabel[1].baris.length, 1, reason: 'masuk tanggal 4');
      expect(tab('4').tabel[0].baris.length, 0, reason: 'keluar tanggal 4');
      expect(tab('5').tabel[0].baris.length, 1, reason: 'keluar tanggal 5');
      expect(tab('5').tabel[1].baris.length, 0, reason: 'masuk tanggal 5');
    });
  });

  group('Keterangan harian', () {
    ServiceOrderEntry batal({double biaya = 0, bool garansi = true}) =>
        ServiceOrderEntry(
          id: 'x',
          noNota: 'x',
          tanggalMasuk: DateTime(2026, 9, 4),
          customerNama: 'Budi',
          barangNama: 'ASUS',
          status: 'batal',
          garansi: garansi,
          biaya: biaya,
          keterangan: 'diambil pelanggan',
          updatedAt: DateTime(2026, 9, 4),
        );

    test('nota batal ditandai Cancel apa pun isinya, dengan biayanya', () {
      // Rp0 di laporan bisa berarti gratis dan bisa berarti belum
      // ditentukan, jadi jawabannya ditulis.
      expect(ExcelExport.keteranganHarian(batal()), 'Cancel Tanpa Biaya');
      expect(
        ExcelExport.keteranganHarian(batal(biaya: 50000, garansi: false)),
        'Cancel Berbiaya',
      );
    });
  });

  // -------------------------------------------------------------------
  // Laporan penerimaan punya DUA kolom yang menjawab dua pertanyaan
  // berbeda, dan keduanya sempat tertukar: kolom keterangan diisi
  // "Service Garansi" dan "Biaya Service" -- jawaban atas pertanyaan
  // status -- sementara perbaikan yang benar-benar dikerjakan tidak
  // muncul di mana pun.
  // -------------------------------------------------------------------
  group('Laporan penerimaan', () {
    ServiceOrderEntry n({
      String status = 'diambil',
      bool garansi = false,
      String? perbaikan = 'Biaya Pasang Keyboard',
      double? biaya,
    }) => ServiceOrderEntry(
      id: 'n1',
      noNota: 'SVR-01092628100',
      tanggalMasuk: DateTime(2026, 9, 1, 9, 0),
      customerNama: 'Budi',
      barangNama: 'Laptop Asus',
      keluhan: 'Keyboard tidak fungsi',
      perbaikan: perbaikan,
      garansi: garansi,
      status: status,
      biaya: biaya ?? (garansi ? 0 : 200000),
      tanggalSelesai: DateTime(2026, 9, 3),
      updatedAt: DateTime(2026, 9, 3),
    );

    test('status menyebut tanggungan dan apakah sudah diambil', () {
      expect(
        ExcelExport.statusServis(n()),
        'Non Garansi (Barang Sudah Diambil)',
      );
      expect(
        ExcelExport.statusServis(n(garansi: true)),
        'Garansi (Barang Sudah Diambil)',
      );
      expect(
        ExcelExport.statusServis(n(status: 'selesai')),
        'Non Garansi (Barang Belum Diambil)',
      );
      expect(
        ExcelExport.statusServis(n(status: 'dikerjakan', garansi: true)),
        'Garansi (Barang Belum Diambil)',
      );
    });

    test(
      'nota batal tidak menulis Cancel di status, dan otomatis sudah diambil',
      () {
        // Status hanya menjawab ditanggung siapa, dan sudah diambil atau
        // belum. Pembatalan berarti unitnya dikembalikan ke pelanggan, jadi
        // otomatis sudah diambil; pembatalannya sendiri ada di keterangan.
        expect(
          ExcelExport.statusServis(n(status: 'batal')),
          'Non Garansi (Barang Sudah Diambil)',
        );
        expect(
          ExcelExport.statusServis(n(status: 'batal', garansi: true)),
          'Garansi (Barang Sudah Diambil)',
        );
      },
    );

    test('Cancel tinggal di keterangan, diikuti perbaikannya', () {
      expect(
        ExcelExport.keteranganPenerimaan(
          n(status: 'batal', perbaikan: 'Battery Problem', biaya: 0),
        ),
        'Servis Cancel Battery Problem (Tanpa Biaya)',
      );
      // Tanpa perbaikan, kata pembatalannya berdiri sendiri.
      expect(
        ExcelExport.keteranganPenerimaan(
          n(status: 'batal', perbaikan: null, biaya: 0),
        ),
        'Servis Cancel (Tanpa Biaya)',
      );
      // Nota arsip dari buku toko sudah menulis kata pembatalannya sendiri;
      // ditulis dua kali terbaca "Servis Cancel (…) Service Cancel Fan
      // Problem".
      expect(
        ExcelExport.keteranganPenerimaan(
          n(status: 'batal', perbaikan: 'Service Cancel Fan Problem', biaya: 0),
        ),
        'Service Cancel Fan Problem (Tanpa Biaya)',
      );
      expect(
        ExcelExport.keteranganPenerimaan(
          n(
            status: 'batal',
            perbaikan: 'Service cancel print head',
            biaya: 75000,
          ),
        ),
        'Service cancel print head (Berbiaya)',
      );
      // Pembatalan berbiaya menyebutnya, dan uangnya ada di kolom CASH atau
      // PIUTANG.
      expect(
        ExcelExport.keteranganPenerimaan(
          n(status: 'batal', perbaikan: 'Cek Battery', biaya: 75000),
        ),
        'Servis Cancel Cek Battery (Berbiaya)',
      );
      // Nota biasa: keterangannya tetap perbaikan apa adanya.
      expect(ExcelExport.keteranganPenerimaan(n()), 'Biaya Pasang Keyboard');
    });

    test('baris batal di lembar: status polos, keterangan memuat Cancel', () {
      final lembar = ExcelExport.lembarKeseluruhan(
        nota: [n(status: 'batal', perbaikan: 'Windows Problem', biaya: 0)],
        teknisi: const {},
        periode: 'September 2026',
      );
      final t = lembar.tabel.single;
      final iKet = t.kolom.indexWhere((k) => k.judul == 'KETERANGAN');
      final iSts = t.kolom.indexWhere((k) => k.judul == 'STATUS');

      expect(
        (t.baris.single[iKet] as TextCellValue).value.text,
        'Servis Cancel Windows Problem (Tanpa Biaya)',
      );
      expect(
        (t.baris.single[iSts] as TextCellValue).value.text,
        isNot(contains('Cancel')),
      );
      // Barisnya tetap merah: yang membaca mencari warna lebih dulu.
      expect(t.warnaBaris!.single, ExcelColor.red300);
    });

    test('keterangan berisi perbaikannya, status berdiri sendiri', () {
      final lembar = ExcelExport.lembarKeseluruhan(
        nota: [n()],
        teknisi: const {},
        periode: 'September 2026',
      );
      final t = lembar.tabel.single;

      expect(
        t.kolom.map((k) => k.judul),
        containsAll(['KETERANGAN', 'STATUS']),
      );

      final iKet = t.kolom.indexWhere((k) => k.judul == 'KETERANGAN');
      final iSts = t.kolom.indexWhere((k) => k.judul == 'STATUS');

      expect(
        (t.baris.single[iKet] as TextCellValue).value.text,
        'Biaya Pasang Keyboard',
      );
      expect(
        (t.baris.single[iSts] as TextCellValue).value.text,
        'Non Garansi (Barang Sudah Diambil)',
      );
    });

    // -----------------------------------------------------------------
    // Bentuk yang diminta: satu kepala BIAYA menaungi Cash, Piutang, dan
    // Pelunasan, dan baris bergaransi maupun batal diberi warna.
    // -----------------------------------------------------------------

    test('baris bergaransi hijau, batal merah, sisanya polos', () {
      expect(ExcelExport.warnaServis(n()), isNull);
      expect(ExcelExport.warnaServis(n(garansi: true)), ExcelColor.green300);
      expect(ExcelExport.warnaServis(n(status: 'batal')), ExcelColor.red300);

      // Nota garansi yang dibatalkan tetap merah.
      expect(
        ExcelExport.warnaServis(n(status: 'batal', garansi: true)),
        ExcelColor.red300,
      );
    });

    test('TOTAL tepat di kiri angkanya, dan angkanya terbaca utuh', () {
      // Sempat ditulis "TOTAL 39.865.000" di kolom keterangan, jauh dari
      // uangnya, sementara total cash di bawahnya tampil "########".
      ServiceOrderEntry lunas(int i) => ServiceOrderEntry(
        id: 'l$i',
        noNota: 'SVR-010926${28000 + i}',
        tanggalMasuk: DateTime(2026, 9, 1),
        customerNama: 'Budi',
        barangNama: 'Laptop',
        status: 'diambil',
        biaya: 950000,
        caraBayar: 'cash',
        tanggalLunas: DateTime(2026, 9, 2),
        tanggalSelesai: DateTime(2026, 9, 2),
        perbaikan: 'Instal Ulang',
        updatedAt: DateTime(2026, 9, 2),
      );

      final lembar = ExcelExport.lembarKeseluruhan(
        nota: [for (var i = 0; i < 42; i++) lunas(i), n()],
        teknisi: const {},
        periode: 'September 2026',
      );
      final t = lembar.tabel.single;
      final judul = t.kolom.map((k) => k.judul).toList();
      final iCash = judul.indexOf('CASH');
      final penutup = t.penutup!;

      expect((penutup[iCash - 1] as TextCellValue).value.text, 'TOTAL');
      expect((penutup[iCash] as DoubleCellValue).value, 42 * 950000);
      expect(
        (penutup[judul.indexOf('PIUTANG')] as DoubleCellValue).value,
        200000,
      );
      // Tidak ada total kedua yang tercecer di kolom teks.
      for (final k in ['KETERANGAN', 'STATUS']) {
        final i = judul.indexOf(k);
        expect(i < penutup.length ? penutup[i] : null, isNull, reason: k);
      }

      final sheet = _bolakBalik(lembar);
      // "Rp39.900.000": dua belas huruf.
      expect(sheet.getColumnWidths[iCash]!, greaterThan(12));
    });

    LembarExcel lembar() => ExcelExport.lembarKeseluruhan(
      nota: [
        n(),
        n(garansi: true),
        n(status: 'batal'),
      ],
      teknisi: const {},
      periode: 'September 2026',
    );

    test('BIAYA jadi satu kepala di atas Cash, Piutang, Pelunasan', () {
      final sheet = _bolakBalik(lembar());

      // Baris 0 judul lembar, 1 kepala grup, 2 nama kolom.
      expect(_teks(sheet, 7, 1), 'BIAYA');
      expect(_teks(sheet, 7, 2), 'CASH');
      expect(_teks(sheet, 8, 2), 'PIUTANG');
      expect(_teks(sheet, 9, 2), 'PELUNASAN');

      expect(
        _digabung(sheet, 7, 1, 9, 1),
        isTrue,
        reason: 'BIAYA tidak menaungi ketiga kolomnya',
      );
    });

    test('kolom tanpa grup memakai kedua baris kepalanya', () {
      final sheet = _bolakBalik(lembar());

      // Kalau tidak digabung menurun, di bawah "NO NOTA" menganga kotak
      // kosong sepanjang tabel.
      expect(_teks(sheet, 0, 1), 'NO NOTA');
      expect(_digabung(sheet, 0, 1, 0, 2), isTrue, reason: 'NO NOTA');
      expect(_digabung(sheet, 11, 1, 11, 2), isTrue, reason: 'STATUS');
    });

    test('warnanya sampai ke dalam berkasnya', () {
      final sheet = _bolakBalik(lembar());

      // Data mulai di baris 3: judul, kepala grup, nama kolom.
      expect(_latar(sheet, 1, 3), anyOf(isNull, ExcelColor.none));
      expect(_latar(sheet, 1, 4), ExcelColor.green300);
      expect(_latar(sheet, 1, 5), ExcelColor.red300);
    });

    // -----------------------------------------------------------------
    // Urutan baris. Laporan ini dibaca dari kolom pertamanya, dan
    // sebelum ini urutannya diserahkan apa adanya ke urutan yang datang
    // dari server -- tanggal masuk terbaru dulu, dan di dalam satu
    // tanggal tidak ditentukan apa pun. Di kolom nomor nota hasilnya
    // terbaca acak.
    // -----------------------------------------------------------------

    ServiceOrderEntry m(String noNota, {bool garansi = false}) =>
        ServiceOrderEntry(
          id: noNota,
          noNota: noNota,
          tanggalMasuk: DateTime(2026, 9, 1, 9, 0),
          customerNama: noNota,
          barangNama: 'Laptop Asus',
          garansi: garansi,
          status: 'diambil',
          biaya: 100000,
          updatedAt: DateTime(2026, 9, 1),
        );

    test('barisnya urut nomor nota, bukan urutan datangnya data', () {
      final lembar = ExcelExport.lembarKeseluruhan(
        nota: [
          m('SRV-09092628265'),
          m('SVR-08092628271'),
          m('SRV-08092628249'),
          m('SVR-07092628259'),
        ],
        teknisi: const {},
        periode: 'September 2026',
      );

      expect(
        lembar.tabel.single.baris
            .map((r) => (r.first as TextCellValue).value.text)
            .toList(),
        [
          'SRV-08092628249',
          'SVR-07092628259',
          'SRV-09092628265',
          'SVR-08092628271',
        ],
      );
    });

    test('warnanya ikut pindah bersama barisnya', () {
      // Warna disimpan sebagai daftar terpisah yang sejajar dengan
      // barisnya. Kalau yang satu diurutkan dan yang lain tidak, hijau
      // menempel pada nota yang salah -- dan tidak ada yang tampak keliru
      // sampai seseorang membaca kolom STATUS-nya.
      final lembar = ExcelExport.lembarKeseluruhan(
        nota: [
          m('SRV-09092628265'),
          m('SRV-08092628249', garansi: true),
          m('SVR-08092628271'),
        ],
        teknisi: const {},
        periode: 'September 2026',
      );
      final t = lembar.tabel.single;

      final iHijau = t.warnaBaris!.indexOf(ExcelColor.green300);
      expect(
        (t.baris[iHijau].first as TextCellValue).value.text,
        'SRV-08092628249',
      );
    });

    test('seluruh sel di baris berwarna ikut berwarna', () {
      // Mewarnai sebagian kolom saja menghasilkan baris belang yang
      // terbaca sebagai dua baris berbeda saat dicetak.
      final sheet = _bolakBalik(lembar());
      for (var c = 0; c < 12; c++) {
        expect(_latar(sheet, c, 4), ExcelColor.green300, reason: 'kolom $c');
      }
    });
  });
  group('Laporan partner', () {
    test(
      'tab lengkap dan ringkas memakai nota yang sama serta menjumlahkan biaya',
      () {
        final nota = _nota(
          noNota: 'SVR-01092628110',
          masuk: DateTime(2026, 9, 1, 9),
          diambil: DateTime(2026, 9, 4),
          biaya: 400000,
        );
        final lembar = ExcelExport.lembarPartner(
          data: [
            PartnerServiceEntry(
              id: 'partner-1',
              serviceOrderId: nota.id,
              status: 'selesai',
              hpp: 270000,
              upBiaya: 400000,
              createdAt: DateTime(2026, 9, 1),
              updatedAt: DateTime(2026, 9, 4),
            ),
          ],
          nota: {nota.id: nota},
          periode: '01 Sep 2026 — 30 Sep 2026',
        );

        expect(lembar.map((l) => l.nama), ['Laporan Partner', 'Ringkas']);

        final lengkap = lembar.first.tabel.single;
        expect(lengkap.kolom.map((k) => k.judul), [
          'NAMA',
          'NO NOTA',
          'JENIS BARANG',
          'PERBAIKAN',
          'HPP',
          'UP BIAYA SERVICE',
          'INCOME/SELISIH',
          'TANGGAL MASUK',
          'TANGGAL KELUAR',
        ]);
        expect(
          (lengkap.baris.single[1] as TextCellValue).value.text,
          nota.noNota,
        );
        expect((lengkap.baris.single[6] as DoubleCellValue).value, 130000);
        expect((lengkap.penutup![4] as DoubleCellValue).value, 270000);
        expect((lengkap.penutup![5] as DoubleCellValue).value, 400000);
        expect((lengkap.penutup![6] as DoubleCellValue).value, 130000);

        final ringkas = lembar.last.tabel.single;
        expect(ringkas.kolom.map((k) => k.judul), [
          'NO',
          'NOTA',
          'HPP',
          'UP',
          'SELISIH',
        ]);
        expect(
          (ringkas.baris.single[1] as TextCellValue).value.text,
          nota.noNota,
        );
      },
    );
  });
}

String? _teks(Sheet sheet, int kolom, int baris) {
  final v = sheet
      .cell(CellIndex.indexByColumnRow(columnIndex: kolom, rowIndex: baris))
      .value;
  return v is TextCellValue ? v.value.text : null;
}

ExcelColor? _latar(Sheet sheet, int kolom, int baris) => sheet
    .cell(CellIndex.indexByColumnRow(columnIndex: kolom, rowIndex: baris))
    .cellStyle
    ?.backgroundColor;

/// Apakah berkasnya benar-benar memuat penggabungan sel itu.
///
/// Dibaca ulang dari berkas hasilnya, bukan dari niat kodenya: penggabungan
/// yang gagal tersimpan tidak menimbulkan galat apa pun -- hanya kepala
/// tabel yang berantakan saat dibuka.
bool _digabung(
  Sheet sheet,
  int kolomAwal,
  int barisAwal,
  int kolomAkhir,
  int barisAkhir,
) => sheet.spannedItems.map((e) => e.split(':')).any((e) {
  final awal = CellIndex.indexByString(e.first);
  final akhir = CellIndex.indexByString(e.last);
  return awal.columnIndex == kolomAwal &&
      awal.rowIndex == barisAwal &&
      akhir.columnIndex == kolomAkhir &&
      akhir.rowIndex == barisAkhir;
});
