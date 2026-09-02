import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';

import '../local/database.dart';

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

  /// Nama bulan mengandung spasi; karakter yang dilarang di nama berkas
  /// Windows dibuang agar dialog simpan tidak menolaknya.
  static String _aman(String teks) =>
      teks.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
}
