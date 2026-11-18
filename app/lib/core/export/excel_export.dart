import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';

import '../data/models.dart';
import '../hari_laporan.dart';
import '../nota/nomor_nota.dart';
import '../nota/urutan_harian.dart';

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

  static CellStyle _gayaIsi(JenisKolom j, [ExcelColor? latar]) => CellStyle(
    fontSize: 9,
    horizontalAlign: _rata(j),
    verticalAlign: VerticalAlign.Center,
    numberFormat: _format(j),
    backgroundColorHex: latar ?? ExcelColor.none,
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

  /// Menempelkan gaya tanpa menyentuh isi selnya.
  ///
  /// Sel yang tertutup penggabungan tidak boleh diberi nilai -- termasuk
  /// null. Menulis ke dalam rentang gabungan selalu dialihkan ke sel
  /// jangkarnya, jadi satu null di sel yang tertutup menghapus judul yang
  /// baru saja ditulis di sudut kirinya. Yang tersisa kepala tabel kosong,
  /// tanpa galat apa pun -- dan itu baru terlihat saat berkasnya dibuka.
  static void _gaya(Sheet sheet, int kolom, int baris, CellStyle gaya) {
    sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: kolom, rowIndex: baris),
            )
            .cellStyle =
        gaya;
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

  static void _gabung(
    Sheet sheet,
    int kolomAwal,
    int barisAwal,
    int kolomAkhir,
    int barisAkhir,
  ) => sheet.merge(
    CellIndex.indexByColumnRow(columnIndex: kolomAwal, rowIndex: barisAwal),
    CellIndex.indexByColumnRow(columnIndex: kolomAkhir, rowIndex: barisAkhir),
  );

  /// Kepala kolom dua tingkat: baris atas untuk nama grup, baris bawah
  /// untuk nama kolomnya sendiri.
  ///
  /// Penggabungannya dilakukan lebih dulu, baru selnya diisi. Urutan itu
  /// bukan selera: merge menghapus seluruh sel di dalam rentangnya, jadi
  /// kalau dibalik, sel yang tertutup kehilangan garisnya dan kotak
  /// gabungannya tampak bocor di sisi kanan bawah saat dicetak.
  static void _kepalaBertingkat(Sheet sheet, TabelExcel t, int atas) {
    final bawah = atas + 1;
    var c = 0;

    while (c < t.kolom.length) {
      final grup = t.kolom[c].grup;

      if (grup == null) {
        // Tanpa grup, judulnya menempati kedua baris sekaligus supaya
        // tidak ada kotak kosong menggantung di bawahnya.
        _gabung(sheet, c, atas, c, bawah);
        _sel(sheet, c, atas, TextCellValue(t.kolom[c].judul), _gayaKepala());
        _gaya(sheet, c, bawah, _gayaKepala());
        c++;
        continue;
      }

      var akhir = c;
      while (akhir + 1 < t.kolom.length && t.kolom[akhir + 1].grup == grup) {
        akhir++;
      }

      _gabung(sheet, c, atas, akhir, atas);
      _sel(sheet, c, atas, TextCellValue(grup), _gayaKepala());
      for (var k = c; k <= akhir; k++) {
        if (k > c) _gaya(sheet, k, atas, _gayaKepala());
        _sel(sheet, k, bawah, TextCellValue(t.kolom[k].judul), _gayaKepala());
      }
      c = akhir + 1;
    }
  }

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
    if (t.kolom.any((k) => k.grup != null)) {
      _kepalaBertingkat(sheet, t, baris);
      sheet.setRowHeight(baris, 18);
      sheet.setRowHeight(baris + 1, 26);
      baris += 2;
    } else {
      for (var c = 0; c < t.kolom.length; c++) {
        _sel(sheet, c, baris, TextCellValue(t.kolom[c].judul), _gayaKepala());
      }
      sheet.setRowHeight(baris, 26);
      baris++;
    }

    for (var r = 0; r < t.baris.length; r++) {
      final isi = t.baris[r];
      final warna = t.warnaBaris;
      final latar = warna != null && r < warna.length ? warna[r] : null;
      for (var c = 0; c < t.kolom.length; c++) {
        _sel(
          sheet,
          c,
          baris,
          c < isi.length ? isi[c] : null,
          _gayaIsi(t.kolom[c].jenis, latar),
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
      // Baris total ikut diukur. Totalnya hampir selalu angka terpanjang
      // di kolomnya -- satu bulan penuh, bukan satu nota -- dan angka yang
      // tidak muat tidak meluber seperti teks: Excel menggantinya dengan
      // "########".
      for (final r in [...t.baris, ?t.penutup]) {
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
      ..sort(
        (a, b) => (a.tanggalLunas ?? a.tanggalMasuk).compareTo(
          b.tanggalLunas ?? b.tanggalMasuk,
        ),
      );
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
                if (_hariSama(sebelumnya, n.tanggalLunas))
                  null
                else
                  () {
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
    // Urut nomor nota, seperti buku toko. Sebelumnya laporan ini
    // memakai urutan apa adanya dari server -- tanggal masuk terbaru di
    // atas -- dan di dalam satu tanggal urutannya tidak ditentukan apa
    // pun, jadi nomornya tampak acak persis di kolom pertama.
    final urut = [...nota]
      ..sort((a, b) => bandingNomorNota(a.noNota, b.noNota));

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
            // Ketiganya satu pertanyaan yang dipecah tiga -- berapa,
            // sudah masuk atau belum, dan kapan masuknya -- jadi
            // dinaungi satu kepala bersama seperti di lembar toko.
            KolomExcel('CASH', jenis: JenisKolom.rupiah, grup: 'BIAYA'),
            KolomExcel('PIUTANG', jenis: JenisKolom.rupiah, grup: 'BIAYA'),
            KolomExcel('PELUNASAN', jenis: JenisKolom.tanggal, grup: 'BIAYA'),
            // Dua kolom, dua pertanyaan yang berbeda. Keterangan menjawab
            // "apa yang dikerjakan" -- dan apakah servisnya dibatalkan --
            // status menjawab "ditanggung siapa, dan unitnya sudah diambil
            // belum". Keduanya sempat tertukar:
            // kolom keterangan diisi "Service Garansi" dan "Biaya
            // Service" -- jawaban atas pertanyaan yang kedua -- sementara
            // perbaikan yang benar-benar dikerjakan tidak muncul di mana
            // pun, padahal itulah yang dicari saat membaca ulang notanya.
            KolomExcel('KETERANGAN'),
            KolomExcel('STATUS'),
          ],
          baris: [
            for (final n in urut)
              [
                TextCellValue(n.noNota),
                TextCellValue(n.customerNama),
                TextCellValue(n.customerTelp ?? ''),
                TextCellValue(_barang(n)),
                TextCellValue(n.keluhan ?? ''),
                TextCellValue(teknisi[n.teknisiId] ?? ''),
                _tanggal(n.tanggalSelesai),
                if (n.tanggalLunas != null) DoubleCellValue(n.biaya) else null,
                if (n.tanggalLunas == null && n.biaya > 0)
                  DoubleCellValue(n.biaya)
                else
                  null,
                _tanggal(n.tanggalLunas),
                TextCellValue(keteranganPenerimaan(n)),
                TextCellValue(statusServis(n)),
              ],
          ],
          warnaBaris: [for (final n in urut) warnaServis(n)],
          // Labelnya tepat di kiri angkanya, seperti "Total Mei" di lembar
          // pelunasan toko. Sempat ditulis "TOTAL 39.865.000" di kolom
          // keterangan -- empat kolom jauhnya dari uang yang dijumlahkan,
          // di bawah tulisan perbaikan.
          penutup: [
            for (var i = 0; i < 6; i++) null,
            TextCellValue('TOTAL'),
            DoubleCellValue(
              urut
                  .where((n) => n.tanggalLunas != null)
                  .fold<double>(0, (a, n) => a + n.biaya),
            ),
            DoubleCellValue(
              urut
                  .where((n) => n.tanggalLunas == null)
                  .fold<double>(0, (a, n) => a + n.biaya),
            ),
          ],
        ),
      ],
    );
  }

  /// Warna latar satu baris laporan penerimaan.
  ///
  /// Merah untuk nota batal, hijau untuk unit bergaransi, sisanya polos --
  /// bentuk yang sudah dipakai lembar toko selama ini. Yang membacanya
  /// mencari baris berwarna lebih dulu, sebelum membaca satu kata pun.
  ///
  /// Merah berarti dibatalkan, ada biayanya atau tidak: baris batal yang
  /// berbiaya tetap berwarna, dan uangnya terbaca di kolom CASH atau
  /// PIUTANG.
  ///
  /// Batal diperiksa duluan: nota garansi yang dibatalkan tetap merah.
  ///
  /// Nadanya sengaja satu tingkat lebih muda dari hijau dan merah penuh.
  /// Laporan ini dicetak lalu difoto, dan tulisan hitam 9pt di atas warna
  /// pekat lebih sering hilang daripada terbaca.
  static ExcelColor? warnaServis(ServiceOrderEntry n) {
    if (n.status == 'batal') return ExcelColor.red300;
    if (n.garansi) return ExcelColor.green300;
    return null;
  }

  /// Kolom KETERANGAN pada laporan penerimaan: apa yang dikerjakan, dan
  /// apakah servisnya dibatalkan.
  ///
  /// "Cancel" tinggal di sini, bukan di kolom STATUS -- status hanya
  /// menjawab ditanggung siapa dan sudah diambil atau belum.
  ///
  /// Pembatalan selalu menyebut biayanya di ujung, dalam kurung:
  /// "Servis Cancel Battery Problem (Tanpa Biaya)" atau "(Berbiaya)". Kolom
  /// uang yang kosong tidak menjawab apa-apa -- kosong bisa berarti gratis,
  /// bisa berarti belum ditentukan -- jadi jawabannya ditulis.
  ///
  /// Nota arsip dari buku toko sudah menulis "Service Cancel Fan Problem" di
  /// perbaikannya. Yang begitu dipakai apa adanya, dan hanya biayanya yang
  /// ditambahkan -- awalan "Servis Cancel" di depannya menggandakan kata itu.
  static String keteranganPenerimaan(ServiceOrderEntry n) {
    final isi = (n.perbaikan ?? '').trim();
    if (n.status != 'batal') return isi;

    final sudahMenyebut = RegExp(
      r'cancel|batal',
      caseSensitive: false,
    ).hasMatch(isi);
    final teks = sudahMenyebut
        ? isi
        : (isi.isEmpty ? 'Servis Cancel' : 'Servis Cancel $isi');
    return '$teks (${_biayaBatal(n)})';
  }

  /// "Berbiaya" atau "Tanpa Biaya" untuk nota batal.
  static String _biayaBatal(ServiceOrderEntry n) =>
      n.biaya > 0 ? 'Berbiaya' : 'Tanpa Biaya';

  /// Kolom STATUS pada laporan penerimaan: ditanggung siapa, dan apakah
  /// unitnya sudah diambil.
  ///
  /// Keduanya digabung dalam satu kalimat karena begitulah bentuknya di
  /// lembar yang dipakai toko selama ini -- "Non Garansi (Barang Sudah
  /// Diambil)".
  ///
  /// Nota batal ikut aturan yang sama dan TIDAK berhenti di kata "Cancel":
  /// pembatalannya ada di kolom keterangan. Unit yang dibatalkan otomatis
  /// terbaca "Sudah Diambil" -- pembatalan berarti unitnya dikembalikan ke
  /// pelanggan.
  static String statusServis(ServiceOrderEntry n) {
    final tanggungan = n.garansi ? 'Garansi' : 'Non Garansi';
    // Unit yang sedang dikerjakan di cabang lain menyebut ke mana dan kapan
    // dikirim -- "Barang Belum Diambil" benar, tetapi tidak menjawab
    // pertanyaan pertama yang diajukan pelanggan: unitnya di mana.
    final keadaan =
        n.keteranganKirim ??
        (n.status == 'diambil' || n.status == 'batal'
            ? 'Barang Sudah Diambil'
            : 'Barang Belum Diambil');
    return '$tanggungan ($keadaan)';
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
            // Unit yang dikirim cabang lain ke sini: tanggal ia diterima,
            // lalu (di kolom ke-10) tanggal ia dikirim balik.
            KolomExcel('TANGGAL TERIMA', jenis: JenisKolom.tanggal),
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
                TextCellValue(k.sudahKembali ? 'RETURN' : 'SHIP'),
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
    Set<int> libur = hariLiburBawaan,
  }) => simpanBanyak(
    namaBerkas: 'SVS ${_aman(_bulanTahun.format(bulan)).toUpperCase()}.xlsx',
    lembar: lembarHarianBulanan(semua: semua, bulan: bulan, libur: libur),
  );

  /// Satu tab per tanggal, kecuali hari toko tutup.
  ///
  /// Hari libur tidak diterbitkan sama sekali, bukan diterbitkan kosong.
  /// Begitulah bentuk berkas SVS yang dipakai toko: lembar Sabtu memang
  /// tidak ada di sana, dan tab kosong di tengah bulan terbaca seperti
  /// laporan yang belum diisi.
  static List<LembarExcel> lembarHarianBulanan({
    required List<ServiceOrderEntry> semua,
    required DateTime bulan,
    Set<int> libur = hariLiburBawaan,
  }) {
    final jumlahHari = DateTime(bulan.year, bulan.month + 1, 0).day;

    return [
      for (var h = 1; h <= jumlahHari; h++)
        if (!hariLibur(DateTime(bulan.year, bulan.month, h), libur))
          lembarHarian(
            semua: semua,
            tanggal: DateTime(bulan.year, bulan.month, h),
            namaLembar: '$h',
          ),
    ];
  }

  /// Seminggu, bentuknya sama dengan berkas bulanan: satu tab per tanggal.
  static Future<String?> harianMingguan({
    required List<ServiceOrderEntry> semua,
    required DateTime senin,
    Set<int> libur = hariLiburBawaan,
  }) => simpanBanyak(
    namaBerkas:
        'Laporan Mingguan ${_aman(DateFormat('dd MM yyyy').format(senin))}.xlsx',
    lembar: lembarHarianMingguan(semua: semua, senin: senin, libur: libur),
  );

  static List<LembarExcel> lembarHarianMingguan({
    required List<ServiceOrderEntry> semua,
    required DateTime senin,
    Set<int> libur = hariLiburBawaan,
  }) => [
    for (var i = 0; i < 7; i++)
      if (!hariLibur(DateTime(senin.year, senin.month, senin.day + i), libur))
        lembarHarian(
          semua: semua,
          tanggal: DateTime(senin.year, senin.month, senin.day + i),
          namaLembar: '${DateTime(senin.year, senin.month, senin.day + i).day}',
        ),
  ];

  /// Satu tanggal: dua tabel bertumpuk, nota keluar lalu nota masuk.
  ///
  /// Nota keluar memuat unit yang diambil maupun dibatalkan lalu
  /// dikembalikan. Server mencap tanggal_diambil ketika statusnya berubah
  /// dan menghitungnya dengan tutup_jam dari Pengaturan; di sini tanggal itu
  /// dibandingkan apa adanya.
  ///
  /// Nota masuk memakai hari kalender: unit yang diterima jam 19.45
  /// tercatat hari itu juga, sama seperti di buku meja depan.
  static LembarExcel lembarHarian({
    required List<ServiceOrderEntry> semua,
    required DateTime tanggal,
    String? namaLembar,
  }) {
    // Unit selesai atau dibuka kembali bukan Nota Keluar. Unit Batal sudah
    // kembali ke pelanggan sehingga, seperti Diambil, dicetak pada hari
    // keluarnya.
    final keluar =
        semua
            .where(
              (n) =>
                  (n.status == 'diambil' || n.status == 'batal') &&
                  _hariSama(n.tanggalDiambil, tanggal),
            )
            .toList()
          ..sort(bandingHarian);
    final masuk =
        semua.where((n) => _hariSama(n.tanggalMasuk, tanggal)).toList()
          ..sort((a, b) => bandingNomorNota(a.noNota, b.noNota));

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

  // ------------------------------------------------------------------
  // Servis partner
  // ------------------------------------------------------------------

  /// Laporan biaya pekerjaan yang dikirim ke partner luar.
  ///
  /// Satu berkas berisi dua tampilan dari daftar yang sama: tab lengkap
  /// untuk laporan periode (bulanan atau mingguan), lalu tab ringkas yang
  /// bisa langsung dipakai mengecek HPP, up biaya, dan selisih. Identitas
  /// selalu diambil dari nota sumber agar perubahan nama/unit pada nota
  /// langsung tercermin di laporan ini.
  static Future<String?> partner({
    required List<PartnerServiceEntry> data,
    required Map<String, ServiceOrderEntry> nota,
    required String periode,
  }) => simpanBanyak(
    namaBerkas: 'Biaya Service Luar ${_aman(periode)}.xlsx',
    lembar: lembarPartner(data: data, nota: nota, periode: periode),
  );

  static List<LembarExcel> lembarPartner({
    required List<PartnerServiceEntry> data,
    required Map<String, ServiceOrderEntry> nota,
    required String periode,
  }) {
    final urut =
        [
          for (final p in data)
            if (nota.containsKey(p.serviceOrderId))
              (partner: p, nota: nota[p.serviceOrderId]!),
        ]..sort((a, b) {
          final tanggal = a.partner.createdAt.compareTo(b.partner.createdAt);
          return tanggal != 0
              ? tanggal
              : bandingNomorNota(a.nota.noNota, b.nota.noNota);
        });

    var totalHpp = 0.0;
    var totalUp = 0.0;
    var totalSelisih = 0.0;
    final lengkap = <List<CellValue?>>[];
    final ringkas = <List<CellValue?>>[];

    for (var i = 0; i < urut.length; i++) {
      final p = urut[i].partner;
      final n = urut[i].nota;
      final hpp = p.hpp;
      // Nilai tagihan partner tidak punya input sendiri: satu-satunya
      // sumbernya adalah Biaya di nota. Dengan begitu koreksi biaya nota
      // langsung ikut ke laporan tanpa admin memasukkan angka dua kali.
      final up = n.biaya;
      final selisih = hpp == null ? null : up - hpp;

      totalHpp += hpp ?? 0;
      totalUp += up;
      totalSelisih += selisih ?? 0;

      lengkap.add([
        TextCellValue(n.customerNama),
        TextCellValue(n.noNota),
        TextCellValue(_barang(n)),
        TextCellValue(n.perbaikan ?? n.keluhan ?? ''),
        hpp == null ? null : DoubleCellValue(hpp),
        DoubleCellValue(up),
        selisih == null ? null : DoubleCellValue(selisih),
        _tanggal(n.tanggalMasuk),
        _tanggal(n.tanggalDiambil),
      ]);
      ringkas.add([
        IntCellValue(i + 1),
        TextCellValue(n.noNota),
        hpp == null ? null : DoubleCellValue(hpp),
        DoubleCellValue(up),
        selisih == null ? null : DoubleCellValue(selisih),
      ]);
    }

    return [
      LembarExcel(
        nama: 'Laporan Partner',
        tabel: [
          TabelExcel(
            judul:
                'LAPORAN BIAYA SERVICE LUAR CELLCOM PALANGKA RAYA  ·  ${periode.toUpperCase()}',
            kolom: const [
              KolomExcel('NAMA', lebar: 24),
              KolomExcel('NO NOTA', jenis: JenisKolom.kode, lebar: 22),
              KolomExcel('JENIS BARANG', lebar: 32),
              KolomExcel('PERBAIKAN', lebar: 54),
              KolomExcel('HPP', jenis: JenisKolom.rupiah, lebar: 16),
              KolomExcel(
                'UP BIAYA SERVICE',
                jenis: JenisKolom.rupiah,
                lebar: 19,
              ),
              KolomExcel('INCOME/SELISIH', jenis: JenisKolom.rupiah, lebar: 18),
              KolomExcel('TANGGAL MASUK', jenis: JenisKolom.tanggal, lebar: 16),
              KolomExcel(
                'TANGGAL KELUAR',
                jenis: JenisKolom.tanggal,
                lebar: 16,
              ),
            ],
            baris: lengkap,
            penutup: [
              null,
              null,
              null,
              TextCellValue('TOTAL'),
              DoubleCellValue(totalHpp),
              DoubleCellValue(totalUp),
              DoubleCellValue(totalSelisih),
            ],
          ),
        ],
      ),
      LembarExcel(
        nama: 'Ringkas',
        tabel: [
          TabelExcel(
            judul:
                'BIAYA SERVICE LUAR CELLCOM PALANGKA RAYA  ·  ${periode.toUpperCase()}',
            kolom: const [
              KolomExcel('NO', jenis: JenisKolom.angka, lebar: 8),
              KolomExcel('NOTA', jenis: JenisKolom.kode, lebar: 22),
              KolomExcel('HPP', jenis: JenisKolom.rupiah, lebar: 16),
              KolomExcel('UP', jenis: JenisKolom.rupiah, lebar: 16),
              KolomExcel('SELISIH', jenis: JenisKolom.rupiah, lebar: 16),
            ],
            baris: ringkas,
            penutup: [
              null,
              TextCellValue('TOTAL'),
              DoubleCellValue(totalHpp),
              DoubleCellValue(totalUp),
              DoubleCellValue(totalSelisih),
            ],
          ),
        ],
      ),
    ];
  }

  static Future<String?> part({
    required List<PartOrder> pesanan,
    required Map<String, String> teknisi,
    required Map<String, PartCost> modal,
    required String periode,
    Map<String, String> caraBayar = const {},
  }) => simpanBanyak(
    namaBerkas: 'Penjualan Part ${_aman(periode)}.xlsx',
    lembar: [
      lembarPart(
        pesanan: pesanan,
        teknisi: teknisi,
        modal: modal,
        periode: periode,
        caraBayar: caraBayar,
      ),
    ],
  );

  /// Satu berkas berisi semuanya, satu lembar untuk tiap kelompok: Semua,
  /// Belum Selesai, Selesai, dan Batal. Isinya yang dikirim ke pusat tanpa
  /// ada yang perlu disaring lagi di Excel.
  static Future<String?> partLengkap({
    required Map<String, List<PartOrder>> kelompok,
    required Map<String, String> teknisi,
    required Map<String, PartCost> modal,
    required String periode,
    Map<String, String> caraBayar = const {},
  }) => simpanBanyak(
    namaBerkas: 'Penjualan Part ${_aman(periode)}.xlsx',
    lembar: [
      for (final e in kelompok.entries)
        lembarPart(
          pesanan: e.value,
          teknisi: teknisi,
          modal: modal,
          periode: '$periode - ${e.key}',
          caraBayar: caraBayar,
          namaLembar: e.key,
        ),
    ],
  );

  static LembarExcel lembarPart({
    required List<PartOrder> pesanan,
    required Map<String, String> teknisi,
    required Map<String, PartCost> modal,
    required String periode,
    Map<String, String> caraBayar = const {},
    String namaLembar = 'Penjualan Part',
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
        TextCellValue(caraBayar[p.caraBayar] ?? p.caraBayar ?? ''),
        TextCellValue(p.noPo ?? ''),
        TextCellValue((p.keterangan ?? '').toUpperCase()),
        TextCellValue(p.catatan ?? ''),
      ]);
    }

    return LembarExcel(
      nama: namaLembar,
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
            KolomExcel('CARA BAYAR', jenis: JenisKolom.kode),
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

  /// Kolom keterangan pada laporan harian menampung empat hal berbeda:
  /// pembatalan, pengiriman ke cabang, status garansi, dan cara bayar.
  /// Urutannya disengaja -- yang paling menjelaskan kenapa biayanya nol
  /// atau kenapa unitnya tidak ada di rak didahulukan.
  ///
  /// Pembatalan menyebut biayanya, "Cancel Tanpa Biaya" atau "Cancel
  /// Berbiaya": pembatalan bisa berbiaya dan bisa tidak, dan angka Rp0 saja
  /// tidak menjelaskan yang mana.
  ///
  /// Unit garansi yang dikirim ke cabang menyebut keduanya: kata Garansi
  /// menjelaskan biayanya, kalimat pengirimannya menjelaskan unitnya.
  static String keteranganHarian(ServiceOrderEntry n) {
    if (n.status == 'batal') return 'Cancel ${_biayaBatal(n)}';
    final kirim = n.keteranganKirim;
    if (kirim != null) return n.garansi ? 'Garansi. $kirim' : kirim;
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
  const KolomExcel(
    this.judul, {
    this.jenis = JenisKolom.teks,
    this.lebar,
    this.grup,
  });

  final String judul;
  final JenisKolom jenis;

  /// Lebar tetap. Kosongkan agar dihitung dari isi terpanjangnya.
  final double? lebar;

  /// Nama kepala gabungan di atas kolom ini.
  ///
  /// Kolom berurutan yang grupnya sama dinaungi satu kotak bersama --
  /// "BIAYA" di atas Cash, Piutang, dan Pelunasan. Ketiganya memang satu
  /// pertanyaan yang dipecah tiga, dan dibaca begitu di lembar yang
  /// dipakai toko.
  ///
  /// Kolom tanpa grup kepalanya digabung menurun melintasi kedua baris,
  /// supaya tingginya sama dan tidak ada kotak kosong menggantung.
  final String? grup;
}

/// Satu tabel: judul, kepala kolom, isi, dan baris penutupnya.
class TabelExcel {
  const TabelExcel({
    required this.kolom,
    required this.baris,
    this.judul,
    this.penutup,
    this.warnaBaris,
  });

  final String? judul;
  final List<KolomExcel> kolom;
  final List<List<CellValue?>> baris;

  /// Warna latar tiap baris, sejajar dengan [baris]. Null berarti tanpa
  /// warna.
  ///
  /// Dipakai laporan penerimaan: hijau untuk unit garansi, merah untuk
  /// yang dibatalkan. Bentuk itu datang dari lembar yang sudah dipakai
  /// toko bertahun-tahun -- yang membacanya mencari baris berwarna lebih
  /// dulu, sebelum membaca satu kata pun.
  final List<ExcelColor?>? warnaBaris;

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
