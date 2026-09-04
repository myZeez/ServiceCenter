import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';

import '../data/models.dart';

final _tgl = DateFormat('dd/MM/yyyy');

/// Menyusun dan menyimpan berkas .xlsx.
///
/// Sengaja xlsx, bukan CSV: angka biaya ditulis sebagai bilangan, bukan
/// teks, sehingga bisa langsung dijumlahkan di Excel tanpa dibersihkan
/// dulu. CSV akan memaksa pembacanya menebak pemisah desimal dan
/// menghilangkan format tanggal.
class ExcelExport {
  const ExcelExport._();

  /// Mengembalikan jalur berkas yang tersimpan, atau null bila dibatalkan.
  static Future<String?> simpan({
    required String namaBerkas,
    required String namaLembar,
    required List<String> kepala,
    required List<List<CellValue?>> baris,
  }) async {
    final excel = Excel.createExcel();

    // Excel selalu membuat satu lembar bernama Sheet1; diganti namanya agar
    // tab di bawah berkas menjelaskan isinya.
    final lamaNama = excel.getDefaultSheet();
    if (lamaNama != null) excel.rename(lamaNama, namaLembar);
    final sheet = excel[namaLembar];

    sheet.appendRow([for (final k in kepala) TextCellValue(k)]);
    for (final b in baris) {
      sheet.appendRow(b);
    }

    // Kolom judul dibekukan supaya tetap terlihat saat menggulir laporan
    // yang panjang.
    sheet.setColumnAutoFit(0);

    final bytes = excel.encode();
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

  /// Beberapa tabel dalam satu berkas, masing-masing jadi lembar sendiri.
  ///
  /// Laporan harian memang dibaca sebagai dua tabel berdampingan; memecahnya
  /// jadi dua berkas terpisah akan membuat penerimanya harus menggabungkan
  /// sendiri.
  static Future<String?> simpanBanyak({
    required String namaBerkas,
    required List<LembarExcel> lembar,
  }) async {
    final excel = Excel.createExcel();

    for (var i = 0; i < lembar.length; i++) {
      final l = lembar[i];
      if (i == 0) {
        final bawaan = excel.getDefaultSheet();
        if (bawaan != null) excel.rename(bawaan, l.nama);
      }
      final sheet = excel[l.nama];

      if (l.judul != null) {
        sheet.appendRow([TextCellValue(l.judul!)]);
        sheet.appendRow([]);
      }
      sheet.appendRow([for (final k in l.kepala) TextCellValue(k)]);
      for (final b in l.baris) {
        sheet.appendRow(b);
      }
      if (l.penutup != null) {
        sheet.appendRow([]);
        sheet.appendRow(l.penutup!);
      }
      sheet.setColumnAutoFit(0);
    }

    final bytes = excel.encode();
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

  // ------------------------------------------------------------------
  // Pelunasan
  // ------------------------------------------------------------------

  static Future<String?> pelunasan({
    required List<ServiceOrderEntry> nota,
    required Map<String, String> teknisi,
    required String periode,
  }) {
    return simpan(
      namaBerkas: 'Pelunasan ${_aman(periode)}.xlsx',
      namaLembar: 'Pelunasan',
      kepala: const [
        'Tanggal Lunas',
        'No Nota',
        'Nama Customer',
        'Kerusakan / Keluhan',
        'Perbaikan',
        'Teknisi',
        'Biaya',
      ],
      baris: [
        for (final n in nota)
          [
            n.tanggalLunas == null
                ? null
                : TextCellValue(_tgl.format(n.tanggalLunas!)),
            TextCellValue(n.noNota),
            TextCellValue(n.customerNama),
            TextCellValue(n.keluhan ?? ''),
            TextCellValue(n.perbaikan ?? ''),
            TextCellValue(teknisi[n.teknisiId] ?? ''),
            DoubleCellValue(n.biaya),
          ],
      ],
    );
  }

  // ------------------------------------------------------------------
  // Keseluruhan
  // ------------------------------------------------------------------

  static Future<String?> keseluruhan({
    required List<ServiceOrderEntry> nota,
    required Map<String, String> teknisi,
    required String periode,
  }) {
    return simpan(
      namaBerkas: 'Laporan Servis ${_aman(periode)}.xlsx',
      namaLembar: 'Keseluruhan',
      // Biaya, cara bayar, dan tanggal lunas dipisah menjadi tiga kolom.
      // Digabung dalam satu sel, angkanya tidak bisa dijumlahkan dan
      // penyaringan piutang harus dilakukan dengan mata.
      kepala: const [
        'No Nota',
        'Tanggal Masuk',
        'Nama Customer',
        'No Telp',
        'Jenis Barang',
        'Type',
        'Kerusakan / Keluhan',
        'Teknisi',
        'Biaya',
        'Cara Bayar',
        'Tanggal Lunas',
        'Keterangan',
        'Garansi',
        'Status',
      ],
      baris: [
        for (final n in nota)
          [
            TextCellValue(n.noNota),
            TextCellValue(_tgl.format(n.tanggalMasuk)),
            TextCellValue(n.customerNama),
            TextCellValue(n.customerTelp ?? ''),
            TextCellValue(n.barangNama),
            TextCellValue(n.barangType ?? ''),
            TextCellValue(n.keluhan ?? ''),
            TextCellValue(teknisi[n.teknisiId] ?? ''),
            DoubleCellValue(n.biaya),
            TextCellValue(_caraBayar(n)),
            n.tanggalLunas == null
                ? null
                : TextCellValue(_tgl.format(n.tanggalLunas!)),
            TextCellValue(n.keterangan ?? ''),
            TextCellValue(n.garansi ? 'GARANSI' : 'NON GARANSI'),
            TextCellValue(_status(n.status)),
          ],
      ],
    );
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

  static Future<String?> kirim({required List<ShipmentEntry> data}) {
    return simpan(
      namaBerkas: 'Laporan Kirim.xlsx',
      namaLembar: 'Kirim',
      kepala: const [
        'Tanggal Kirim',
        'Dari Cabang',
        'Ke Cabang',
        'Nama User',
        'Nama Barang',
        'Serial Number',
        'Keluhan',
        'Kelengkapan',
        'Status',
        'Tanggal Kembali',
        'Keterangan',
      ],
      baris: [
        for (final k in data)
          [
            TextCellValue(_tgl.format(k.tanggalKirim)),
            TextCellValue(k.dariCabang),
            TextCellValue(k.keCabang),
            TextCellValue(k.userNama ?? ''),
            TextCellValue(k.barangNama),
            TextCellValue(k.serialNumber ?? ''),
            TextCellValue(k.keluhan ?? ''),
            TextCellValue(k.kelengkapan ?? ''),
            TextCellValue(k.status == 'ship' ? 'DIKIRIM' : 'DITERIMA'),
            k.tanggalKembali == null
                ? null
                : TextCellValue(_tgl.format(k.tanggalKembali!)),
            TextCellValue(
              (k.keterangan ?? '').replaceAll('_', ' ').toUpperCase(),
            ),
          ],
      ],
    );
  }

  // ------------------------------------------------------------------
  // Laporan harian untuk pusat
  // ------------------------------------------------------------------

  static Future<String?> harian({
    required List<ServiceOrderEntry> keluar,
    required List<ServiceOrderEntry> masuk,
    required DateTime tanggal,
  }) {
    final judul = 'LAPORAN PERHARI TGL ${_tgl.format(tanggal)}';
    final total = keluar.fold<double>(0, (a, n) => a + n.biaya);

    return simpanBanyak(
      namaBerkas: 'Laporan Harian ${_aman(_tgl.format(tanggal))}.xlsx',
      lembar: [
        LembarExcel(
          nama: 'Nota Keluar',
          judul: judul,
          kepala: const [
            'NAMA',
            'NO NOTA',
            'JENIS BARANG',
            'PERBAIKAN',
            'BIAYA',
            'TANGGAL MASUK',
            'KETERANGAN',
          ],
          baris: [
            for (final n in keluar)
              [
                TextCellValue(n.customerNama),
                TextCellValue(n.noNota),
                TextCellValue(_barang(n)),
                TextCellValue(n.perbaikan ?? ''),
                DoubleCellValue(n.biaya),
                TextCellValue(_tgl.format(n.tanggalMasuk)),
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
          kepala: const [
            'NAMA',
            'NO NOTA',
            'NO HP',
            'JENIS BARANG',
            'KERUSAKAN',
            'PELUNASAN',
          ],
          baris: [
            for (final n in masuk)
              [
                TextCellValue(n.customerNama),
                TextCellValue(n.noNota),
                TextCellValue(n.customerTelp ?? ''),
                TextCellValue(_barang(n)),
                TextCellValue(n.keluhan ?? ''),
                n.tanggalLunas == null
                    ? null
                    : TextCellValue(_tgl.format(n.tanggalLunas!)),
              ],
          ],
        ),
      ],
    );
  }

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

/// Satu lembar dalam berkas Excel.
class LembarExcel {
  const LembarExcel({
    required this.nama,
    required this.kepala,
    required this.baris,
    this.judul,
    this.penutup,
  });

  final String nama;
  final String? judul;
  final List<String> kepala;
  final List<List<CellValue?>> baris;
  final List<CellValue?>? penutup;
}
