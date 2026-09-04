import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';

import '../data/models.dart';

final _tgl = DateFormat('dd/MM/yyyy');
final _angka = NumberFormat('#,##0', 'id_ID');

/// Menyusun dan menyimpan berkas .xlsx.
///
/// Sengaja xlsx, bukan CSV: angka biaya ditulis sebagai bilangan dan
/// tanggal sebagai tanggal sungguhan, sehingga bisa langsung dijumlahkan
/// dan diurutkan di Excel tanpa dibersihkan dulu. CSV akan memaksa
/// pembacanya menebak pemisah desimal dan menghilangkan format tanggal.
///
/// Tampilannya sengaja tanpa warna sama sekali. Laporan ini dicetak,
/// difoto, dan diteruskan ke pusat; warna latar yang bagus di layar
/// berubah jadi abu-abu kotor di kertas dan menyulitkan membacanya. Yang
/// dipakai untuk membentuk tabel hanya tiga hal: tebal pada kepala kolom,
/// satu garis tipis di bawahnya, dan lebar kolom yang mengikuti isinya.
class ExcelExport {
  const ExcelExport._();

  // ------------------------------------------------------------------
  // Gaya
  // ------------------------------------------------------------------

  static Border get _garis =>
      Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.black);

  static HorizontalAlign _rata(JenisKolom j) =>
      j == JenisKolom.teks ? HorizontalAlign.Left : HorizontalAlign.Right;

  /// Angka memakai pemisah ribuan tanpa desimal. Nilai jasa servis selalu
  /// bulat dalam rupiah; menampilkan ",00" di tiap baris hanya menambah
  /// lebar kolom tanpa menambah keterangan apa pun.
  static NumFormat _format(JenisKolom j) => switch (j) {
    JenisKolom.rupiah ||
    JenisKolom.angka => const CustomNumericNumFormat(formatCode: '#,##0'),
    JenisKolom.tanggal => const CustomDateTimeNumFormat(
      formatCode: 'dd/mm/yyyy',
    ),
    JenisKolom.teks => NumFormat.standard_0,
  };

  static CellStyle _gayaJudul() => CellStyle(
    bold: true,
    fontSize: 13,
    fontFamily: getFontFamily(FontFamily.Calibri),
  );

  static CellStyle _gayaSubjudul() => CellStyle(fontSize: 10);

  static CellStyle _gayaKepala(JenisKolom j) => CellStyle(
    bold: true,
    fontSize: 10,
    horizontalAlign: _rata(j),
    verticalAlign: VerticalAlign.Bottom,
    bottomBorder: _garis,
  );

  static CellStyle _gayaIsi(JenisKolom j) => CellStyle(
    fontSize: 10,
    horizontalAlign: _rata(j),
    numberFormat: _format(j),
  );

  static CellStyle _gayaTotal(JenisKolom j) => CellStyle(
    bold: true,
    fontSize: 10,
    horizontalAlign: _rata(j),
    numberFormat: _format(j),
    topBorder: _garis,
  );

  // ------------------------------------------------------------------
  // Penulis
  // ------------------------------------------------------------------

  static void _sel(
    Sheet sheet,
    int kolom,
    int baris,
    CellValue? nilai,
    CellStyle gaya,
  ) {
    final sel = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: kolom, rowIndex: baris),
    );
    sel.value = nilai;
    sel.cellStyle = gaya;
  }

  /// Berapa karakter yang ditempati sebuah nilai saat ditampilkan. Dipakai
  /// untuk menentukan lebar kolom, supaya tidak ada yang muncul sebagai
  /// "#####" atau terpotong titik tiga saat berkasnya dibuka.
  static int _panjang(CellValue? v) => switch (v) {
    TextCellValue t => (t.value.text ?? '').length,
    DoubleCellValue d => _angka.format(d.value).length,
    IntCellValue i => _angka.format(i.value).length,
    DateCellValue _ => 10,
    _ => 0,
  };

  static void _tulis(Sheet sheet, LembarExcel l) {
    var baris = 0;

    if (l.judul != null) {
      _sel(sheet, 0, baris++, TextCellValue(l.judul!), _gayaJudul());
    }
    if (l.subjudul != null) {
      _sel(sheet, 0, baris++, TextCellValue(l.subjudul!), _gayaSubjudul());
    }
    // Satu baris kosong memisahkan kepala laporan dari tabelnya. Tanpa itu
    // judul terbaca seolah bagian dari kolom pertama.
    if (baris > 0) baris++;

    for (var c = 0; c < l.kolom.length; c++) {
      final k = l.kolom[c];
      _sel(sheet, c, baris, TextCellValue(k.judul), _gayaKepala(k.jenis));
    }
    baris++;

    for (final r in l.baris) {
      for (var c = 0; c < l.kolom.length; c++) {
        _sel(
          sheet,
          c,
          baris,
          c < r.length ? r[c] : null,
          _gayaIsi(l.kolom[c].jenis),
        );
      }
      baris++;
    }

    // Baris total menempel langsung di bawah data, dipisah garis. Baris
    // kosong di antaranya membuat Excel berhenti menganggapnya satu tabel
    // saat diurutkan atau disaring.
    if (l.penutup != null) {
      for (var c = 0; c < l.kolom.length; c++) {
        _sel(
          sheet,
          c,
          baris,
          c < l.penutup!.length ? l.penutup![c] : null,
          _gayaTotal(l.kolom[c].jenis),
        );
      }
    }

    _lebarkan(sheet, l);
  }

  /// Lebar tiap kolom dihitung dari isi terpanjangnya, bukan diserahkan ke
  /// perataan otomatis Excel -- yang hanya berjalan kalau penggunanya
  /// mengklik, dan itu persis pekerjaan merapikan yang mau dihindari.
  ///
  /// Dibatasi supaya kolom keluhan yang isinya satu paragraf tidak
  /// mendorong seluruh tabel keluar layar.
  static void _lebarkan(Sheet sheet, LembarExcel l) {
    for (var c = 0; c < l.kolom.length; c++) {
      final tetap = l.kolom[c].lebar;
      if (tetap != null) {
        sheet.setColumnWidth(c, tetap);
        continue;
      }

      var maks = l.kolom[c].judul.length;
      for (final r in l.baris) {
        if (c >= r.length) continue;
        final n = _panjang(r[c]);
        if (n > maks) maks = n;
      }
      sheet.setColumnWidth(c, (maks + 3).clamp(10, 46).toDouble());
    }
  }

  /// Menyusun berkasnya tanpa menyimpan. Dipisah supaya hasilnya bisa
  /// diperiksa test: yang menentukan laporan ini rapi atau tidak ada di
  /// dalam berkasnya, bukan di kode yang memanggilnya.
  static List<int>? susun(List<LembarExcel> lembar) {
    final excel = Excel.createExcel();

    for (var i = 0; i < lembar.length; i++) {
      final l = lembar[i];
      // Excel selalu membuat satu lembar bernama Sheet1; yang pertama
      // diganti namanya agar tab di bawah berkas menjelaskan isinya.
      if (i == 0) {
        final bawaan = excel.getDefaultSheet();
        if (bawaan != null) excel.rename(bawaan, l.nama);
      }
      _tulis(excel[l.nama], l);
    }

    return excel.encode();
  }

  static Future<String?> _simpanBerkas(
    List<int>? bytes,
    String namaBerkas,
  ) async {
    if (bytes == null) return null;

    final lokasi = await getSaveLocation(
      suggestedName: namaBerkas,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Excel', extensions: ['xlsx']),
      ],
    );
    if (lokasi == null) return null;

    var jalur = lokasi.path;
    if (!jalur.toLowerCase().endsWith('.xlsx')) jalur = '$jalur.xlsx';

    await File(jalur).writeAsBytes(bytes, flush: true);
    return jalur;
  }

  /// Mengembalikan jalur berkas yang tersimpan, atau null bila dibatalkan.
  static Future<String?> simpan({
    required String namaBerkas,
    required LembarExcel lembar,
  }) => simpanBanyak(namaBerkas: namaBerkas, lembar: [lembar]);

  /// Beberapa tabel dalam satu berkas, masing-masing jadi lembar sendiri.
  ///
  /// Laporan harian memang dibaca sebagai dua tabel berdampingan; memecahnya
  /// jadi dua berkas terpisah akan membuat penerimanya harus menggabungkan
  /// sendiri.
  static Future<String?> simpanBanyak({
    required String namaBerkas,
    required List<LembarExcel> lembar,
  }) => _simpanBerkas(susun(lembar), namaBerkas);

  // ------------------------------------------------------------------
  // Pelunasan
  // ------------------------------------------------------------------

  static Future<String?> pelunasan({
    required List<ServiceOrderEntry> nota,
    required Map<String, String> teknisi,
    required String periode,
  }) => simpan(
    namaBerkas: 'Pelunasan ${_aman(periode)}.xlsx',
    lembar: lembarPelunasan(nota: nota, teknisi: teknisi, periode: periode),
  );

  /// Susunan lembarnya dipisah dari penyimpanannya supaya bisa diperiksa
  /// test dan dibuatkan contoh tanpa membuka dialog simpan.
  static LembarExcel lembarPelunasan({
    required List<ServiceOrderEntry> nota,
    required Map<String, String> teknisi,
    required String periode,
  }) {
    final total = nota.fold<double>(0, (a, n) => a + n.biaya);

    return (LembarExcel(
      nama: 'Pelunasan',
      judul: 'LAPORAN PELUNASAN SERVIS',
      subjudul: 'Periode $periode  ·  ${nota.length} nota',
      kolom: const [
        KolomExcel('Tanggal Lunas', jenis: JenisKolom.tanggal),
        KolomExcel('No Nota'),
        KolomExcel('Nama Customer'),
        KolomExcel('Kerusakan / Keluhan'),
        KolomExcel('Perbaikan'),
        KolomExcel('Teknisi'),
        KolomExcel('Biaya', jenis: JenisKolom.rupiah),
      ],
      baris: [
        for (final n in nota)
          [
            _tanggal(n.tanggalLunas),
            TextCellValue(n.noNota),
            TextCellValue(n.customerNama),
            TextCellValue(n.keluhan ?? ''),
            TextCellValue(n.perbaikan ?? ''),
            TextCellValue(teknisi[n.teknisiId] ?? ''),
            DoubleCellValue(n.biaya),
          ],
      ],
      penutup: [
        null,
        null,
        null,
        null,
        null,
        TextCellValue('TOTAL'),
        DoubleCellValue(total),
      ],
    ));
  }

  // ------------------------------------------------------------------
  // Keseluruhan
  // ------------------------------------------------------------------

  static Future<String?> keseluruhan({
    required List<ServiceOrderEntry> nota,
    required Map<String, String> teknisi,
    required String periode,
  }) => simpan(
    namaBerkas: 'Laporan Servis ${_aman(periode)}.xlsx',
    lembar: lembarKeseluruhan(nota: nota, teknisi: teknisi, periode: periode),
  );

  static LembarExcel lembarKeseluruhan({
    required List<ServiceOrderEntry> nota,
    required Map<String, String> teknisi,
    required String periode,
  }) {
    final total = nota.fold<double>(0, (a, n) => a + n.biaya);

    return (LembarExcel(
      nama: 'Keseluruhan',
      judul: 'LAPORAN KESELURUHAN SERVIS',
      subjudul: 'Periode $periode  ·  ${nota.length} nota',
      // Biaya, cara bayar, dan tanggal lunas dipisah menjadi tiga kolom.
      // Digabung dalam satu sel, angkanya tidak bisa dijumlahkan dan
      // penyaringan piutang harus dilakukan dengan mata.
      kolom: const [
        KolomExcel('No Nota'),
        KolomExcel('Tanggal Masuk', jenis: JenisKolom.tanggal),
        KolomExcel('Nama Customer'),
        KolomExcel('No Telp'),
        KolomExcel('Jenis Barang'),
        KolomExcel('Type'),
        KolomExcel('Kerusakan / Keluhan'),
        KolomExcel('Teknisi'),
        KolomExcel('Biaya', jenis: JenisKolom.rupiah),
        KolomExcel('Cara Bayar'),
        KolomExcel('Tanggal Lunas', jenis: JenisKolom.tanggal),
        KolomExcel('Keterangan'),
        KolomExcel('Garansi'),
        KolomExcel('Status'),
      ],
      baris: [
        for (final n in nota)
          [
            TextCellValue(n.noNota),
            _tanggal(n.tanggalMasuk),
            TextCellValue(n.customerNama),
            TextCellValue(n.customerTelp ?? ''),
            TextCellValue(n.barangNama),
            TextCellValue(n.barangType ?? ''),
            TextCellValue(n.keluhan ?? ''),
            TextCellValue(teknisi[n.teknisiId] ?? ''),
            DoubleCellValue(n.biaya),
            TextCellValue(_caraBayar(n)),
            _tanggal(n.tanggalLunas),
            TextCellValue(n.keterangan ?? ''),
            TextCellValue(n.garansi ? 'GARANSI' : 'NON GARANSI'),
            TextCellValue(_status(n.status)),
          ],
      ],
      penutup: [for (var i = 0; i < 8; i++) null, DoubleCellValue(total)],
    ));
  }

  static String _caraBayar(ServiceOrderEntry n) {
    if (n.biaya == 0) return '';
    if (n.tanggalLunas != null) return 'LUNAS';
    if (n.caraBayar == 'piutang') return 'PIUTANG';
    if (n.caraBayar == 'cash') return 'CASH';
    return '';
  }

  static String _status(String s) => switch (s) {
    'masuk' => 'MASUK',
    'dikerjakan' => 'DIKERJAKAN',
    'tunggu_part' => 'TUNGGU PART',
    'selesai' => 'SELESAI, BELUM DIAMBIL',
    'diambil' => 'SUDAH DIAMBIL',
    'batal' => 'BATAL',
    _ => s.toUpperCase(),
  };

  // ------------------------------------------------------------------
  // Kirim
  // ------------------------------------------------------------------

  static Future<String?> kirim({required List<ShipmentEntry> data}) => simpan(
    namaBerkas: 'Laporan Kirim.xlsx',
    lembar: lembarKirim(data: data),
  );

  static LembarExcel lembarKirim({required List<ShipmentEntry> data}) {
    return (LembarExcel(
      nama: 'Kirim',
      judul: 'LAPORAN KIRIM UNIT',
      subjudul: '${data.length} unit',
      kolom: const [
        KolomExcel('Tanggal Kirim', jenis: JenisKolom.tanggal),
        KolomExcel('Dari Cabang'),
        KolomExcel('Ke Cabang'),
        KolomExcel('Nama User'),
        KolomExcel('Nama Barang'),
        KolomExcel('Serial Number'),
        KolomExcel('Keluhan'),
        KolomExcel('Kelengkapan'),
        KolomExcel('Status'),
        KolomExcel('Tanggal Kembali', jenis: JenisKolom.tanggal),
        KolomExcel('Keterangan'),
      ],
      baris: [
        for (final k in data)
          [
            _tanggal(k.tanggalKirim),
            TextCellValue(k.dariCabang),
            TextCellValue(k.keCabang),
            TextCellValue(k.userNama ?? ''),
            TextCellValue(k.barangNama),
            TextCellValue(k.serialNumber ?? ''),
            TextCellValue(k.keluhan ?? ''),
            TextCellValue(k.kelengkapan ?? ''),
            TextCellValue(k.status == 'ship' ? 'DIKIRIM' : 'DITERIMA'),
            _tanggal(k.tanggalKembali),
            TextCellValue(
              (k.keterangan ?? '').replaceAll('_', ' ').toUpperCase(),
            ),
          ],
      ],
    ));
  }

  // ------------------------------------------------------------------
  // Laporan harian untuk pusat
  // ------------------------------------------------------------------

  static Future<String?> harian({
    required List<ServiceOrderEntry> keluar,
    required List<ServiceOrderEntry> masuk,
    required DateTime tanggal,
  }) => simpanBanyak(
    namaBerkas: 'Laporan Harian ${_aman(_tgl.format(tanggal))}.xlsx',
    lembar: lembarHarian(keluar: keluar, masuk: masuk, tanggal: tanggal),
  );

  static List<LembarExcel> lembarHarian({
    required List<ServiceOrderEntry> keluar,
    required List<ServiceOrderEntry> masuk,
    required DateTime tanggal,
  }) {
    final judul = 'LAPORAN PERHARI TGL ${_tgl.format(tanggal)}';
    final total = keluar.fold<double>(0, (a, n) => a + n.biaya);

    return [
      LembarExcel(
        nama: 'Nota Keluar',
        judul: judul,
        subjudul: '${keluar.length} nota keluar',
        kolom: const [
          KolomExcel('NAMA'),
          KolomExcel('NO NOTA'),
          KolomExcel('JENIS BARANG'),
          KolomExcel('PERBAIKAN'),
          KolomExcel('BIAYA', jenis: JenisKolom.rupiah),
          KolomExcel('TANGGAL MASUK', jenis: JenisKolom.tanggal),
          KolomExcel('KETERANGAN'),
        ],
        baris: [
          for (final n in keluar)
            [
              TextCellValue(n.customerNama),
              TextCellValue(n.noNota),
              TextCellValue(_barang(n)),
              TextCellValue(n.perbaikan ?? ''),
              DoubleCellValue(n.biaya),
              _tanggal(n.tanggalMasuk),
              TextCellValue(keteranganHarian(n)),
            ],
        ],
        // Baris total ditaruh di kolom biaya, sejajar dengan angkanya --
        // begitulah laporan ini dibaca di pusat.
        penutup: [
          null,
          null,
          null,
          TextCellValue('TOTAL'),
          DoubleCellValue(total),
        ],
      ),
      LembarExcel(
        nama: 'Nota Masuk',
        judul: judul,
        subjudul: '${masuk.length} unit diterima',
        kolom: const [
          KolomExcel('NAMA'),
          KolomExcel('NO NOTA'),
          KolomExcel('NO HP'),
          KolomExcel('JENIS BARANG'),
          KolomExcel('KERUSAKAN'),
          KolomExcel('PELUNASAN', jenis: JenisKolom.tanggal),
        ],
        baris: [
          for (final n in masuk)
            [
              TextCellValue(n.customerNama),
              TextCellValue(n.noNota),
              TextCellValue(n.customerTelp ?? ''),
              TextCellValue(_barang(n)),
              TextCellValue(n.keluhan ?? ''),
              _tanggal(n.tanggalLunas),
            ],
        ],
      ),
    ];
  }

  /// Tanggal ditulis sebagai tanggal sungguhan, bukan teks. Yang berbentuk
  /// teks tidak bisa diurutkan menurut waktu -- "01/12/2026" mendahului
  /// "02/01/2027" kalau dibandingkan huruf per huruf.
  static DateCellValue? _tanggal(DateTime? t) => t == null
      ? null
      : DateCellValue(year: t.year, month: t.month, day: t.day);

  static String _barang(ServiceOrderEntry n) => [
    n.barangNama,
    if ((n.barangType ?? '').isNotEmpty) n.barangType!,
  ].join(' ');

  /// Kolom keterangan pada laporan harian menampung tiga hal berbeda:
  /// pembatalan, status garansi, dan cara bayar. Urutannya disengaja --
  /// yang paling menjelaskan kenapa biayanya nol didahulukan.
  static String keteranganHarian(ServiceOrderEntry n) {
    if (n.status == 'batal') return 'Cancel';
    if (n.garansi) return 'Garansi';
    return n.keterangan ?? '';
  }

  /// Nama bulan mengandung spasi; karakter yang dilarang di nama berkas
  /// Windows dibuang agar dialog simpan tidak menolaknya.
  static String _aman(String teks) =>
      teks.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
}

/// Jenis isi sebuah kolom. Menentukan perataan dan format angkanya.
enum JenisKolom { teks, angka, rupiah, tanggal }

/// Satu kolom pada lembar Excel.
class KolomExcel {
  const KolomExcel(this.judul, {this.jenis = JenisKolom.teks, this.lebar});

  final String judul;
  final JenisKolom jenis;

  /// Lebar tetap. Kosongkan agar dihitung dari isi terpanjangnya.
  final double? lebar;
}

/// Satu lembar dalam berkas Excel.
class LembarExcel {
  const LembarExcel({
    required this.nama,
    required this.kolom,
    required this.baris,
    this.judul,
    this.subjudul,
    this.penutup,
  });

  final String nama;
  final String? judul;
  final String? subjudul;
  final List<KolomExcel> kolom;
  final List<List<CellValue?>> baris;

  /// Baris penutup, biasanya total. Ditempel langsung di bawah data dengan
  /// garis pemisah di atasnya.
  final List<CellValue?>? penutup;
}
