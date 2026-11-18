import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Mengirim byte mentah ke printer Windows.
///
/// Nota dicetak sebagai teks ESC/POS, bukan gambar. Epson M-188D adalah
/// mekanisme impact -- kepala cetaknya memukul kertas, itulah sebabnya nota
/// lapis bisa tembus ke karbon di bawahnya. Mencetak gambar di mekanisme
/// seperti ini bisa saja, tapi satu nota memakan puluhan detik dan berisik.
///
/// Karena itu jalurnya bukan lewat driver cetak yang merasterkan halaman,
/// melainkan langsung ke antrean printer dengan tipe data RAW.
class RawPrinter {
  const RawPrinter._();

  static bool get didukung => Platform.isWindows;

  /// Daftar printer yang terpasang di komputer ini.
  static List<String> daftar() {
    if (!didukung) return const [];

    final perlu = calloc<Uint32>();
    final jumlah = calloc<Uint32>();
    final hasil = <String>[];
    // Printer yang terpasang langsung maupun yang dibagikan lewat jaringan.
    const bendera = PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS;

    try {
      // Panggilan pertama hanya untuk mengetahui berapa besar penyangga
      // yang dibutuhkan.
      EnumPrinters(bendera, null, 2, null, 0, perlu, jumlah);
      if (perlu.value == 0) return const [];

      final penyangga = calloc<Uint8>(perlu.value);
      try {
        final ok = EnumPrinters(
          bendera,
          null,
          2,
          penyangga,
          perlu.value,
          perlu,
          jumlah,
        );
        if (!ok.value) return const [];

        final info = penyangga.cast<PRINTER_INFO_2>();
        for (var i = 0; i < jumlah.value; i++) {
          final nama = (info + i).ref.pPrinterName;
          if (nama != nullptr) hasil.add(nama.toDartString());
        }
      } finally {
        free(penyangga);
      }
    } finally {
      free(perlu);
      free(jumlah);
    }

    return hasil;
  }

  /// Mengirim [data] apa adanya ke [namaPrinter].
  ///
  /// Mengembalikan null bila berhasil, atau keterangan kesalahan bila gagal.
  static String? kirim(String namaPrinter, List<int> data) {
    if (!didukung) return 'Cetak hanya tersedia di Windows.';
    if (namaPrinter.trim().isEmpty) {
      return 'Printer belum dipilih di Pengaturan.';
    }

    final nama = namaPrinter.toNativeUtf16();
    final phPrinter = calloc<Pointer>();
    final docInfo = calloc<DOC_INFO_1>();
    final namaDok = 'Nota Servis'.toNativeUtf16();
    final tipe = 'RAW'.toNativeUtf16();
    final isi = calloc<Uint8>(data.length);
    final terkirim = calloc<Uint32>();

    var terbuka = false;

    try {
      final buka = OpenPrinter(PCWSTR(nama), phPrinter, null);
      if (!buka.value) {
        return 'Printer "$namaPrinter" tidak bisa dibuka. Periksa apakah '
            'namanya masih sama dan printernya menyala.';
      }
      terbuka = true;
      final pegangan = PRINTER_HANDLE(phPrinter.value);

      docInfo.ref.pDocName = PWSTR(namaDok);
      docInfo.ref.pDatatype = PWSTR(tipe);

      if (StartDocPrinter(pegangan, 1, docInfo) == 0) {
        return 'Antrean cetak menolak dokumen.';
      }
      if (!StartPagePrinter(pegangan)) {
        EndDocPrinter(pegangan);
        return 'Antrean cetak menolak halaman.';
      }

      isi.asTypedList(data.length).setAll(0, data);
      final ok = WritePrinter(pegangan, isi, data.length, terkirim);

      EndPagePrinter(pegangan);
      EndDocPrinter(pegangan);

      if (!ok || terkirim.value != data.length) {
        return 'Data tidak terkirim seluruhnya ke printer.';
      }
      return null;
    } finally {
      if (terbuka) ClosePrinter(PRINTER_HANDLE(phPrinter.value));
      free(nama);
      free(phPrinter);
      free(docInfo);
      free(namaDok);
      free(tipe);
      free(isi);
      free(terkirim);
    }
  }
}
