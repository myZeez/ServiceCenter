import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';

import '../data/models.dart';

final _tgl = DateFormat('dd/MM/yyyy');
final _bulanTahun = DateFormat('MMMM yyyy', 'id');
final _angka = NumberFormat('#,##0', 'id_ID');

/// Menyusun dan menyimpan berkas .xlsx.
///
/// Bentuknya mengikuti laporan yang selama ini dipakai toko: tabel bergaris
/// kotak penuh, judul di tengah atas, dan angka rupiah lengkap dengan
/// awalannya. Yang sengaja tidak diikuti hanyalah warnanya -- laporan ini
/// dicetak dan difoto untuk pusat, dan latar berwarna berubah jadi abu-abu
/// kotor di kertas.
///
/// Angka ditulis sebagai bilangan dan tanggal sebagai tanggal sungguhan,
/// bukan teks, supaya bisa langsung dijumlahkan dan diurutkan tanpa
/// dibersihkan dulu.
class ExcelExport {
  const ExcelExport._();

  // ------------------------------------------------------------------
  // Gaya
  // ------------------------------------------------------------------

  static Border get _garis =>
      Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.black);

  static HorizontalAlign _rata(JenisKolom j) => switch (j) {
    JenisKolom.teks => HorizontalAlign.Left,
    JenisKolom.kode || JenisKolom.tanggal => HorizontalAlign.Center,
    JenisKolom.angka || JenisKolom.rupiah => HorizontalAlign.Right,
  };

  /// Rupiah ditulis lengkap dengan awalannya, seperti di laporan yang
  /// selama ini dipakai. Tanpa desimal: nilai jasa servis selalu bulat, dan
  /// ",00" di tiap baris hanya melebarkan kolom tanpa menambah keterangan.
  static NumFormat _format(JenisKolom j) => switch (j) {
    JenisKolom.rupiah => const CustomNumericNumFormat(formatCode: '"Rp"#,##0'),
    JenisKolom.angka => const CustomNumericNumFormat(formatCode: '#,##0'),
    JenisKolom.tanggal => const CustomDateTimeNumFormat(
      formatCode: 'dd/mm/yyyy',
    ),
    JenisKolom.teks || JenisKolom.kode => NumFormat.standard_0,
  };

  /// Judul tabel: digabung selebar tabelnya lalu ditaruh di tengah.
  static CellStyle _gayaJudul() => CellStyle(
    bold: true,
    fontSize: 11,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
  );

  /// Kepala kolom. Semuanya di tengah, apa pun jenis kolomnya -- judul yang
  /// ikut rata kanan tampak seperti terlepas dari kolomnya saat kolomnya
  /// lebar.
  static CellStyle _gayaKepala() => CellStyle(
    bold: true,
    fontSize: 9,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    textWrapping: TextWrapping.WrapText,
    leftBorder: _garis,
    rightBorder: _garis,
    topBorder: _garis,
    bottomBorder: _garis,
  );

  static CellStyle _gayaIsi(JenisKolom j) => CellStyle(
    fontSize: 9,
    horizontalAlign: _rata(j),
    verticalAlign: VerticalAlign.Center,
    numberFormat: _format(j),
    leftBorder: _garis,
    rightBorder: _garis,
    topBorder: _garis,
    bottomBorder: _garis,
  );

  static CellStyle _gayaTotal(JenisKolom j) => CellStyle(
    bold: true,
    fontSize: 9,
    horizontalAlign: _rata(j),
    verticalAlign: VerticalAlign.Center,
    numberFormat: _format(j),
    leftBorder: _garis,
    rightBorder: _garis,
    topBorder: _garis,
    bottomBorder: _garis,
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
  /// "#####" atau terpotong saat berkasnya dibuka.
  static int _panjang(CellValue? v) => switch (v) {
    TextCellValue t => (t.value.text ?? '').length,
    DoubleCellValue d => _angka.format(d.value).length + 2,
    IntCellValue i => _angka.format(i.value).length + 2,
    DateCellValue _ => 10,
    _ => 0,
  };

  /// Menulis satu tabel mulai dari [mulai], mengembalikan baris kosong
  /// pertama sesudahnya.
  static int _tabel(Sheet sheet, TabelExcel t, int mulai) {
    var baris = mulai;

    if (t.judul != null) {
      _sel(sheet, 0, baris, TextCellValue(t.judul!), _gayaJudul());
      // Judul digabung selebar tabelnya supaya benar-benar berada di
      // tengah, bukan menumpuk di kolom pertama.
      if (t.kolom.length > 1) {
        sheet.merge(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: baris),
          CellIndex.indexByColumnRow(
            columnIndex: t.kolom.length - 1,
            rowIndex: baris,
          ),
        );
      }
      sheet.setRowHeight(baris, 20);
      baris++;
    }

    final barisKepala = baris;
    for (var c = 0; c < t.kolom.length; c++) {
      _sel(sheet, c, baris, TextCellValue(t.kolom[c].judul), _gayaKepala());
    }
    sheet.setRowHeight(baris, 26);
    baris++;

    for (final r in t.baris) {
      for (var c = 0; c < t.kolom.length; c++) {
        _sel(
          sheet,
          c,
          baris,
          c < r.length ? r[c] : null,
          _gayaIsi(t.kolom[c].jenis),
        );
      }
      baris++;
    }

    // Baris total menempel langsung di bawah data. Baris kosong di
    // antaranya membuat Excel berhenti menganggapnya satu tabel saat
    // diurutkan atau disaring.
    if (t.penutup != null) {
      for (var c = 0; c < t.kolom.length; c++) {
        _sel(
          sheet,
          c,
          baris,
          c < t.penutup!.length ? t.penutup![c] : null,
          _gayaTotal(t.kolom[c].jenis),
        );
      }
      baris++;
    }

    _lebarkan(sheet, t, barisKepala);
    return baris;
  }

  static void _tulis(Sheet sheet, LembarExcel l) {
    var baris = 0;
    for (final t in l.tabel) {
      baris = _tabel(sheet, t, baris);
      // Dua baris kosong memisahkan tabel yang satu dari berikutnya, cukup
      // jelas terlihat tanpa membuang setengah halaman.
      baris += 2;
    }
  }

  /// Lebar tiap kolom dihitung dari isi terpanjangnya, bukan diserahkan ke
  /// perataan otomatis Excel -- yang hanya berjalan kalau penggunanya
  /// mengklik, dan itu persis pekerjaan merapikan yang mau dihindari.
  ///
  /// Kalau sebuah lembar memuat beberapa tabel, yang paling lebar menang:
  /// kolom hanya ada satu untuk seluruh lembar.
  static void _lebarkan(Sheet sheet, TabelExcel t, int barisKepala) {
    for (var c = 0; c < t.kolom.length; c++) {
      final tetap = t.kolom[c].lebar;
      if (tetap != null) {
        sheet.setColumnWidth(c, tetap);
        continue;
      }

      var maks = t.kolom[c].judul.length;
      for (final r in t.baris) {
        if (c >= r.length) continue;
        final n = _panjang(r[c]);
        if (n > maks) maks = n;
      }

      final usul = (maks + 3).clamp(10, 46).toDouble();
      final ada = sheet.getColumnWidths[c];
      if (ada == null || usul > ada) sheet.setColumnWidth(c, usul);
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
  }) => simpanBanyak(
    namaBerkas: 'Pelunasan ${_aman(periode)}.xlsx',
    lembar: [lembarPelunasan(nota: nota, teknisi: teknisi, periode: periode)],
  );

  /// Susunan lembarnya dipisah dari penyimpanannya supaya bisa diperiksa
  /// test dan dibuatkan contoh tanpa membuka dialog simpan.
  static LembarExcel lembarPelunasan({
    required List<ServiceOrderEntry> nota,
    required Map<String, String> teknisi,
    required String periode,
  }) {
    final urut = [...nota]
      ..sort((a, b) => (a.tanggalLunas ?? a.tanggalMasuk).compareTo(
        b.tanggalLunas ?? b.tanggalMasuk,
      ));
    final total = urut.fold<double>(0, (a, n) => a + n.biaya);

    // Tanggal hanya ditulis pada baris pertama tiap harinya, seperti di
    // laporan yang selama ini dipakai: yang dibaca adalah kelompok
    // hariannya, dan tanggal berulang justru menyamarkan batas kelompok.
    DateTime? sebelumnya;

    return LembarExcel(
      nama: 'Pelunasan',
      tabel: [
        TabelExcel(
          judul: 'LAPORAN PELUNASAN SERVIS  ·  ${periode.toUpperCase()}',
          kolom: const [
            KolomExcel('TANGGAL', jenis: JenisKolom.tanggal),
            KolomExcel('NO. NOTA', jenis: JenisKolom.kode),
            KolomExcel('NAMA KONSUMEN'),
            KolomExcel('NAMA BARANG MERK/ TYPE'),
            KolomExcel('JENIS PERBAIKAN'),
            KolomExcel('TEKNISI', jenis: JenisKolom.kode),
            KolomExcel('BIAYA SERVICE', jenis: JenisKolom.rupiah),
          ],
          baris: [
            for (final n in urut)
              [
                if (_hariSama(sebelumnya, n.tanggalLunas)) null else () {
                  sebelumnya = n.tanggalLunas;
                  return _tanggal(n.tanggalLunas);
                }(),
                TextCellValue(n.noNota),
                TextCellValue(n.customerNama),
                TextCellValue(_barang(n)),
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
        ),
      ],
    );
  }

  static bool _hariSama(DateTime? a, DateTime? b) =>
      a != null &&
      b != null &&
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day;

  // ------------------------------------------------------------------
  // Penerimaan servis (keseluruhan)
  // ------------------------------------------------------------------

  static Future<String?> keseluruhan({
    required List<ServiceOrderEntry> nota,
    required Map<String, String> teknisi,
    required String periode,
  }) => simpanBanyak(
    namaBerkas: 'Penerimaan Servis ${_aman(periode)}.xlsx',
    lembar: [lembarKeseluruhan(nota: nota, teknisi: teknisi, periode: periode)],
  );

  static LembarExcel lembarKeseluruhan({
    required List<ServiceOrderEntry> nota,
    required Map<String, String> teknisi,
    required String periode,
  }) {
    final total = nota.fold<double>(0, (a, n) => a + n.biaya);

    return LembarExcel(
      nama: 'Penerimaan Servis',
      tabel: [
        TabelExcel(
          judul: 'PENERIMAAN SERVIS  ·  ${periode.toUpperCase()}',
          // Cash dan piutang dipisah jadi dua kolom, bukan satu kolom biaya
          // plus keterangan. Digabung, jumlah uang yang benar-benar masuk
          // harus dihitung dengan mata.
          kolom: const [
            KolomExcel('NO NOTA', jenis: JenisKolom.kode),
            KolomExcel('NAMA'),
            KolomExcel('NO. TELP', jenis: JenisKolom.kode),
            KolomExcel('JENIS BARANG'),
            KolomExcel('KERUSAKAN'),
            KolomExcel('TEKNISI', jenis: JenisKolom.kode),
            KolomExcel('TGL SELESAI', jenis: JenisKolom.tanggal),
            KolomExcel('CASH', jenis: JenisKolom.rupiah),
            KolomExcel('PIUTANG', jenis: JenisKolom.rupiah),
            KolomExcel('PELUNASAN', jenis: JenisKolom.tanggal),
            KolomExcel('KETERANGAN'),
          ],
          baris: [
            for (final n in nota)
              [
                TextCellValue(n.noNota),
                TextCellValue(n.customerNama),
                TextCellValue(n.customerTelp ?? ''),
                TextCellValue(_barang(n)),
                TextCellValue(n.keluhan ?? ''),
                TextCellValue(teknisi[n.teknisiId] ?? ''),
                _tanggal(n.tanggalSelesai),
                if (n.tanggalLunas != null)
                  DoubleCellValue(n.biaya)
                else
                  null,
                if (n.tanggalLunas == null && n.biaya > 0)
                  DoubleCellValue(n.biaya)
                else
                  null,
                _tanggal(n.tanggalLunas),
                TextCellValue(_keteranganServis(n)),
              ],
          ],
          penutup: [
            for (var i = 0; i < 7; i++) null,
            DoubleCellValue(
              nota
                  .where((n) => n.tanggalLunas != null)
                  .fold<double>(0, (a, n) => a + n.biaya),
            ),
            DoubleCellValue(
              nota
                  .where((n) => n.tanggalLunas == null)
                  .fold<double>(0, (a, n) => a + n.biaya),
            ),
            null,
            TextCellValue('TOTAL ${_angka.format(total)}'),
          ],
        ),
      ],
    );
  }

  static String _keteranganServis(ServiceOrderEntry n) {
    if (n.status == 'batal') return 'Service Cancel';
    if (n.garansi) return 'Service Garansi';
    if ((n.keterangan ?? '').isNotEmpty) return n.keterangan!;
    return 'Biaya Service';
  }

  // ------------------------------------------------------------------
  // Kirim
  // ------------------------------------------------------------------

  static Future<String?> kirim({required List<ShipmentEntry> data}) =>
      simpanBanyak(
        namaBerkas: 'Laporan Kirim.xlsx',
        lembar: [lembarKirim(data: data)],
      );

  static LembarExcel lembarKirim({required List<ShipmentEntry> data}) {
    return LembarExcel(
      nama: 'Kirim',
      tabel: [
        TabelExcel(
          judul: 'LAPORAN KIRIM UNIT',
          kolom: const [
            KolomExcel('TANGGAL KIRIM', jenis: JenisKolom.tanggal),
            KolomExcel('DARI BRANCH', jenis: JenisKolom.kode),
            KolomExcel('KE BRANCH', jenis: JenisKolom.kode),
            KolomExcel('NAMA USER'),
            KolomExcel('NAMA BARANG'),
            KolomExcel('SERIAL NO (SN)', jenis: JenisKolom.kode),
            KolomExcel('KELUHAN'),
            KolomExcel('KELENGKAPAN'),
            KolomExcel('STATUS', jenis: JenisKolom.kode),
            KolomExcel('TANGGAL KEMBALI', jenis: JenisKolom.tanggal),
            KolomExcel('KETERANGAN', jenis: JenisKolom.kode),
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
                TextCellValue(k.status == 'ship' ? 'SHIP' : 'RETURN'),
                _tanggal(k.tanggalKembali),
                TextCellValue(
                  (k.keterangan ?? '').replaceAll('_', ' ').toUpperCase(),
                ),
              ],
          ],
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Laporan harian untuk pusat
  // ------------------------------------------------------------------

  /// Satu berkas untuk sebulan penuh, satu tab per tanggal.
  ///
  /// Tanggal yang tidak ada transaksinya tetap dibuatkan tabnya. Tab yang
  /// hilang membuat pembacanya harus memeriksa apakah hari itu memang sepi
  /// atau laporannya yang belum diisi.
  static Future<String?> harianBulanan({
    required List<ServiceOrderEntry> semua,
    required DateTime bulan,
  }) => simpanBanyak(
    namaBerkas: 'SVS ${_aman(_bulanTahun.format(bulan)).toUpperCase()}.xlsx',
    lembar: lembarHarianBulanan(semua: semua, bulan: bulan),
  );

  static List<LembarExcel> lembarHarianBulanan({
    required List<ServiceOrderEntry> semua,
    required DateTime bulan,
  }) {
    final jumlahHari = DateTime(bulan.year, bulan.month + 1, 0).day;

    return [
      for (var h = 1; h <= jumlahHari; h++)
        lembarHarian(
          semua: semua,
          tanggal: DateTime(bulan.year, bulan.month, h),
          namaLembar: '$h',
        ),
    ];
  }

  /// Satu tanggal: dua tabel bertumpuk, nota keluar lalu nota masuk.
  static LembarExcel lembarHarian({
    required List<ServiceOrderEntry> semua,
    required DateTime tanggal,
    String? namaLembar,
  }) {
    final keluar =
        semua.where((n) => _hariSama(n.tanggalSelesai, tanggal)).toList()
          ..sort((a, b) => a.noNota.compareTo(b.noNota));
    final masuk =
        semua.where((n) => _hariSama(n.tanggalMasuk, tanggal)).toList()
          ..sort((a, b) => a.noNota.compareTo(b.noNota));

    final judul = 'LAPORAN PERHARI TGL ${_tgl.format(tanggal)}';
    final total = keluar.fold<double>(0, (a, n) => a + n.biaya);

    return LembarExcel(
      nama: namaLembar ?? _aman(_tgl.format(tanggal)),
      tabel: [
        TabelExcel(
          judul: judul,
          kolom: const [
            KolomExcel('NAMA'),
            KolomExcel('NO NOTA', jenis: JenisKolom.kode),
            KolomExcel('JENIS BARANG'),
            KolomExcel('PERBAIKAN'),
            KolomExcel('BIAYA', jenis: JenisKolom.rupiah),
            KolomExcel('TANGGAL MASUK', jenis: JenisKolom.tanggal),
            KolomExcel('KETERANGAN', jenis: JenisKolom.kode),
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
        TabelExcel(
          judul: judul,
          kolom: const [
            KolomExcel('NAMA'),
            KolomExcel('NO NOTA', jenis: JenisKolom.kode),
            KolomExcel('NO HP', jenis: JenisKolom.kode),
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
      ],
    );
  }

  /// Tanggal ditulis sebagai tanggal sungguhan, bukan teks. Yang berbentuk
  /// teks tidak bisa diurutkan menurut waktu -- "01/12/2026" mendahului
  /// "02/01/2027" kalau dibandingkan huruf per huruf.
  // ------------------------------------------------------------------
  // Penjualan part
  //
  // Sengaja berkas sendiri, tidak digabung ke laporan servis. Yang dijual
  // di sini barang, yang dijual di sana jasa -- dan margin barang bukan
  // hasil kerja teknisi. Menyatukannya membuat kedua angka itu tidak bisa
  // dibaca lagi sebagai apa pun.
  // ------------------------------------------------------------------

  static Future<String?> part({
    required List<PartOrder> pesanan,
    required Map<String, String> teknisi,
    required Map<String, PartCost> modal,
    required String periode,
  }) => simpanBanyak(
    namaBerkas: 'Penjualan Part ${_aman(periode)}.xlsx',
    lembar: [
      lembarPart(
        pesanan: pesanan,
        teknisi: teknisi,
        modal: modal,
        periode: periode,
      ),
    ],
  );

  static LembarExcel lembarPart({
    required List<PartOrder> pesanan,
    required Map<String, String> teknisi,
    required Map<String, PartCost> modal,
    required String periode,
  }) {
    final urut = [...pesanan]..sort((a, b) => a.tanggal.compareTo(b.tanggal));

    var totalHpp = 0.0;
    var totalHarga = 0.0;
    var totalUntung = 0.0;
    var totalDp = 0.0;
    var totalSisa = 0.0;

    final baris = <List<CellValue?>>[];
    for (final p in urut) {
      final hpp = modal[p.id]?.hpp;
      final harga = p.harga;
      // Untung hanya bisa dihitung kalau kedua sisinya diketahui. Nol di
      // kolom ini akan terbaca sebagai "jualan tanpa untung", bukan
      // sebagai "modalnya belum diisi".
      final untung = (hpp != null && harga != null) ? harga - hpp : null;

      totalHpp += hpp ?? 0;
      totalHarga += harga ?? 0;
      totalUntung += untung ?? 0;
      totalDp += p.dp;
      totalSisa += p.sisa;

      baris.add([
        // Tanggal DP kalau sudah ada, kalau belum tanggal orangnya
        // bertanya. Kolom pertama sheet pemesanan memang Tanggal DP, dan
        // itulah yang dipakai mengelompokkan per bulan.
        _tanggal(p.tanggalDp ?? p.tanggal),
        TextCellValue(p.customerNama),
        TextCellValue(p.customerTelp ?? ''),
        TextCellValue(p.barangSn ?? ''),
        TextCellValue(p.barangType ?? ''),
        TextCellValue(p.partReq),
        TextCellValue(_tahapTeks(p.tahap)),
        _tanggal(p.tanggalOrder),
        TextCellValue(teknisi[p.teknisiId] ?? ''),
        hpp == null ? null : DoubleCellValue(hpp),
        modal[p.id]?.upPersen == null
            ? null
            : DoubleCellValue(modal[p.id]!.upPersen!),
        harga == null ? null : DoubleCellValue(harga),
        untung == null ? null : DoubleCellValue(untung),
        p.dp == 0 ? null : DoubleCellValue(p.dp),
        p.sisa == 0 ? null : DoubleCellValue(p.sisa),
        TextCellValue(p.noPo ?? ''),
        TextCellValue((p.keterangan ?? '').toUpperCase()),
        TextCellValue(p.catatan ?? ''),
      ]);
    }

    return LembarExcel(
      nama: 'Penjualan Part',
      tabel: [
        TabelExcel(
          judul: 'LAPORAN PENJUALAN PART  ·  ${periode.toUpperCase()}',
          // Urutannya mengikuti sheet yang selama ini dipakai, supaya yang
          // membacanya tidak perlu mencari-cari kolom di tempat baru.
          kolom: const [
            KolomExcel('TANGGAL DP', jenis: JenisKolom.tanggal),
            KolomExcel('NAMA CUSTOMER'),
            KolomExcel('NO TELP', jenis: JenisKolom.kode),
            KolomExcel('SN', jenis: JenisKolom.kode),
            KolomExcel('MERK/TIPE'),
            KolomExcel('PART'),
            KolomExcel('STATUS', jenis: JenisKolom.kode),
            KolomExcel('TANGGAL ORDER', jenis: JenisKolom.tanggal),
            KolomExcel('TEKNISI', jenis: JenisKolom.kode),
            KolomExcel('HARGA HPP', jenis: JenisKolom.rupiah),
            KolomExcel('UP %', jenis: JenisKolom.angka),
            KolomExcel('HARGA JUAL', jenis: JenisKolom.rupiah),
            KolomExcel('UNTUNG', jenis: JenisKolom.rupiah),
            KolomExcel('DP USER', jenis: JenisKolom.rupiah),
            KolomExcel('SISA', jenis: JenisKolom.rupiah),
            KolomExcel('NO PO', jenis: JenisKolom.kode),
            KolomExcel('KETERANGAN', jenis: JenisKolom.kode),
            KolomExcel('CATATAN'),
          ],
          baris: baris,
          penutup: [
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            TextCellValue('TOTAL'),
            DoubleCellValue(totalHpp),
            null,
            DoubleCellValue(totalHarga),
            DoubleCellValue(totalUntung),
            DoubleCellValue(totalDp),
            DoubleCellValue(totalSisa),
            null,
            null,
            null,
          ],
        ),
      ],
    );
  }

  /// Ditulis dengan kata yang dipakai di sheet lama, bukan dengan nilai
  /// yang tersimpan di basis data. Yang membaca laporannya sudah mengenali
  /// istilah-istilah ini bertahun-tahun.
  static String _tahapTeks(String t) => switch (t) {
    'foto' => 'WAIT FOTO/KODE PART',
    'harga' => 'TUNGGU HARGA',
    'konfirmasi' => 'WAIT CONFIRM USER DP',
    'dipesan' => 'ORDERED',
    'dipasang' => 'PART DIPASANG',
    'selesai' => 'CLOSE',
    'batal' => 'CANCEL',
    'kosong' => 'NO STOCK',
    _ => t.toUpperCase(),
  };

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
enum JenisKolom {
  /// Kalimat bebas: rata kiri, karena yang dibaca awalnya.
  teks,

  /// Penanda pendek -- nomor nota, nama teknisi, status. Rata tengah.
  kode,

  angka,
  rupiah,
  tanggal,
}

/// Satu kolom pada tabel.
class KolomExcel {
  const KolomExcel(this.judul, {this.jenis = JenisKolom.teks, this.lebar});

  final String judul;
  final JenisKolom jenis;

  /// Lebar tetap. Kosongkan agar dihitung dari isi terpanjangnya.
  final double? lebar;
}

/// Satu tabel: judul, kepala kolom, isi, dan baris penutupnya.
class TabelExcel {
  const TabelExcel({
    required this.kolom,
    required this.baris,
    this.judul,
    this.penutup,
  });

  final String? judul;
  final List<KolomExcel> kolom;
  final List<List<CellValue?>> baris;

  /// Baris penutup, biasanya total. Menempel langsung di bawah data.
  final List<CellValue?>? penutup;
}

/// Satu lembar (tab) dalam berkas Excel. Bisa memuat lebih dari satu tabel
/// bertumpuk, seperti laporan harian yang memang dibaca sebagai dua tabel.
class LembarExcel {
  const LembarExcel({required this.nama, required this.tabel});

  final String nama;
  final List<TabelExcel> tabel;
}
