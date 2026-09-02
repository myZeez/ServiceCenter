import 'package:intl/intl.dart';

import '../local/database.dart';
import 'escpos.dart';

final _tglJam = DateFormat('dd/MM/yyyy HH:mm');
final _tgl = DateFormat('dd/MM/yyyy');
final _rp = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

enum JenisNota {
  masuk('NOTA MASUK'),
  keluar('NOTA KELUAR');

  const JenisNota(this.judul);
  final String judul;
}

/// Menyusun isi nota untuk dicetak.
///
/// Nota masuk dan nota keluar memakai susunan yang sama; yang membedakan
/// hanya bagian penyelesaian -- perbaikan dan biaya -- yang belum ada
/// isinya saat unit baru diterima.
List<int> susunNota({
  required ServiceOrderEntry nota,
  required JenisNota jenis,
  StoreSetting? toko,
  String? namaTeknisi,
  String? namaOperator,
  int lebar = 40,
  int salinan = 1,
}) {
  final p = EscPos(lebar: lebar);
  p.mulai();

  for (var i = 0; i < salinan; i++) {
    _satuNota(
      p,
      nota: nota,
      jenis: jenis,
      toko: toko,
      namaTeknisi: namaTeknisi,
      namaOperator: namaOperator,
    );
    // Jarak antar salinan agar mudah disobek.
    p.kosong(4);
  }

  p.potong();
  return p.selesai();
}

void _satuNota(
  EscPos p, {
  required ServiceOrderEntry nota,
  required JenisNota jenis,
  StoreSetting? toko,
  String? namaTeknisi,
  String? namaOperator,
}) {
  // --- kepala ----------------------------------------------------------
  p.tengah(toko?.nama ?? 'SERVICE CENTER', tebalkan: true, besarkan: true);
  if ((toko?.alamat ?? '').trim().isNotEmpty) p.tengah(toko!.alamat!);
  if ((toko?.telepon ?? '').trim().isNotEmpty) {
    p.tengah('Telp ${toko!.telepon}');
  }
  p.garis('=');

  p.tengah(jenis.judul, tebalkan: true);
  p.kosong();

  p.pasangan('No. Nota', nota.noNota);
  p.pasangan('Masuk', _tglJam.format(nota.tanggalMasuk));
  if (nota.estimasiSelesai != null) {
    p.pasangan('Estimasi', _tgl.format(nota.estimasiSelesai!));
  }
  if (namaOperator != null) p.pasangan('Operator', namaOperator);
  p.garis();

  // --- pelanggan -------------------------------------------------------
  p.kolom('Nama', nota.customerNama);
  p.kolom('Telp', nota.customerTelp);
  p.garis();

  // --- barang ----------------------------------------------------------
  p.kolom('Barang', nota.barangNama);
  p.kolom('Type', nota.barangType);
  p.kolom('No Seri', nota.barangSn);
  p.kolom('Kelengkapan', nota.kelengkapan);
  p.garis();

  // --- servis ----------------------------------------------------------
  p.kolom('Keluhan', nota.keluhan);
  if (namaTeknisi != null) p.kolom('Teknisi', namaTeknisi);
  p.pasangan('Garansi', nota.garansi ? 'YA' : 'TIDAK');

  // --- penyelesaian ----------------------------------------------------
  if (jenis == JenisNota.keluar) {
    p.garis();
    p.kolom('Perbaikan', nota.perbaikan);
    p.tebal(true);
    p.pasangan('BIAYA', _rp.format(nota.biaya));
    p.tebal(false);
    if (nota.caraBayar != null) {
      p.pasangan('Cara bayar', nota.caraBayar!.toUpperCase());
    }
    p.pasangan(
      'Status bayar',
      nota.tanggalLunas == null
          ? 'BELUM LUNAS'
          : 'LUNAS ${_tgl.format(nota.tanggalLunas!)}',
    );
  }

  if ((nota.keterangan ?? '').trim().isNotEmpty) {
    p.garis();
    p.kolom('Keterangan', nota.keterangan);
  }

  // --- kaki ------------------------------------------------------------
  if ((toko?.ketentuan ?? '').trim().isNotEmpty) {
    p.garis();
    for (final baris in toko!.ketentuan!.split('\n')) {
      if (baris.trim().isEmpty) {
        p.kosong();
      } else {
        for (final b in _bungkusKecil(baris.trim(), p.lebar)) {
          p.baris(b);
        }
      }
    }
  }

  p.kosong(2);

  // Dua kolom tanda tangan: pelanggan di kiri, petugas di kanan.
  final setengah = p.lebar ~/ 2;
  p.baris('${'Penerima'.padRight(setengah)}Petugas');
  p.kosong(3);
  p.baris('${'(          )'.padRight(setengah)}(          )');
}

List<String> _bungkusKecil(String teks, int lebar) {
  final hasil = <String>[];
  var kini = '';
  for (final kata in teks.split(' ')) {
    if (kini.isEmpty) {
      kini = kata;
    } else if (kini.length + 1 + kata.length <= lebar) {
      kini = '$kini $kata';
    } else {
      hasil.add(kini);
      kini = kata;
    }
  }
  if (kini.isNotEmpty) hasil.add(kini);
  return hasil;
}

/// Cetak percobaan untuk memastikan lebar kolomnya pas.
List<int> susunUjiCetak({int lebar = 40}) {
  final p = EscPos(lebar: lebar)..mulai();

  p.tengah('UJI CETAK', tebalkan: true, besarkan: true);
  p.garis('=');
  p.baris('Lebar disetel: $lebar karakter');
  p.kosong();
  p.baris('Penggaris di bawah harus pas satu baris');
  p.baris('tanpa terpotong dan tanpa turun ke bawah:');
  p.kosong();

  // Penggaris berangka: kalau baris ini terpotong, lebarnya kekecilan;
  // kalau masih ada sisa kosong, bisa dinaikkan.
  final b = StringBuffer();
  for (var i = 1; i <= lebar; i++) {
    b.write(i % 10);
  }
  p.baris(b.toString());
  p.garis();
  p.baris('Kalau angka terakhir bukan ${lebar % 10},');
  p.baris('ubah lebar di Pengaturan lalu uji lagi.');
  p.kosong(3);
  p.potong();

  return p.selesai();
}
