import 'package:excel/excel.dart';

/// Satu baris tabel nota masuk di buku SVS harian.
class SvsMasuk {
  const SvsMasuk({
    required this.urut,
    required this.tanggal,
    required this.nama,
    this.telp,
    this.barang,
    this.keluhan,
  });

  final int urut;

  /// Hari lembarnya, dari judul lembar -- bukan dari nama tab.
  final DateTime tanggal;
  final String nama;
  final String? telp;
  final String? barang;
  final String? keluhan;
}

/// Satu baris tabel nota keluar di buku SVS harian.
class SvsKeluar {
  const SvsKeluar({
    required this.urut,
    required this.tanggal,
    required this.nama,
    this.barang,
    this.perbaikan,
    this.biaya,
    this.keterangan,
  });

  final int urut;

  /// Hari laporan unit itu keluar: tanggal lembarnya. Buku SVS sudah
  /// mengikuti jam tutup toko, jadi tanggal ini tidak perlu digeser lagi.
  final DateTime tanggal;
  final String nama;
  final String? barang;
  final String? perbaikan;
  final double? biaya;
  final String? keterangan;
}

/// Isi satu berkas SVS bulanan.
class BukuSvs {
  const BukuSvs({
    required this.masuk,
    required this.keluar,
    required this.hari,
    this.peringatan = const [],
  });

  /// Per nomor urut. Nota yang tercatat dua kali hanya diambil yang pertama.
  final Map<int, SvsMasuk> masuk;
  final Map<int, SvsKeluar> keluar;

  /// Hari-hari yang punya lembar, urut.
  final List<DateTime> hari;
  final List<String> peringatan;

  DateTime get awal => hari.first;
  DateTime get akhir => hari.last;
}

/// Menyatukan beberapa berkas SVS bulanan.
///
/// Akhir bulan butuh dua buku: Sabtu tidak punya lembar, jadi unit yang
/// diambil Sabtu 31 Oktober tercatat di lembar 1 November, di buku berikutnya.
/// Nota yang ada di dua buku memakai catatan dari buku yang lebih awal.
BukuSvs gabungBukuSvs(List<BukuSvs> buku) {
  final urutan = [...buku]..sort((a, b) => a.awal.compareTo(b.awal));
  final masuk = <int, SvsMasuk>{};
  final keluar = <int, SvsKeluar>{};
  final hari = <DateTime>{};
  final peringatan = <String>[];
  for (final b in urutan) {
    hari.addAll(b.hari);
    peringatan.addAll(b.peringatan);
    b.masuk.forEach((urut, m) {
      if (masuk.containsKey(urut)) {
        peringatan.add('Nota masuk $urut ada di dua buku; dipakai yang awal.');
      } else {
        masuk[urut] = m;
      }
    });
    b.keluar.forEach((urut, k) {
      if (keluar.containsKey(urut)) {
        peringatan.add('Nota keluar $urut ada di dua buku; dipakai yang awal.');
      } else {
        keluar[urut] = k;
      }
    });
  }
  return BukuSvs(
    masuk: masuk,
    keluar: keluar,
    hari: hari.toList()..sort(),
    peringatan: peringatan,
  );
}

/// Membaca berkas SVS (xlsx) dari [bytes].
///
/// Tanggal tiap lembar dibaca dari judulnya ("LAPORAN PERHARI TGL
/// 01/10/2026"), bukan dari nama berkas atau nama tab. Berkas "SVS OKTOBER"
/// yang ternyata berisi lembar September pernah hampir terimpor sebagai
/// Oktober -- dengan tanggal dari judul, ia terbaca sebagai September.
BukuSvs bacaSvsXlsx(List<int> bytes) {
  final Excel buku;
  try {
    buku = Excel.decodeBytes(bytes);
  } catch (_) {
    throw const FormatException('Berkas SVS tidak bisa dibuka sebagai xlsx.');
  }
  final masuk = <int, SvsMasuk>{};
  final keluar = <int, SvsKeluar>{};
  final hari = <DateTime>{};
  final peringatan = <String>[];

  for (final tab in buku.tables.keys) {
    final baris = buku.tables[tab]!.rows;
    DateTime? tanggal;
    String? mode;
    for (final b in baris) {
      Object? sel(int i) => i < b.length ? b[i]?.value : null;
      final k1 = _teks(sel(1));
      if (tanggal == null) {
        final m = RegExp(r'TGL\s*(\d{1,2})/(\d{1,2})/(\d{4})')
            .firstMatch((k1 ?? '').toUpperCase());
        if (m != null) {
          tanggal = DateTime(
            int.parse(m.group(3)!),
            int.parse(m.group(2)!),
            int.parse(m.group(1)!),
          );
        }
        continue;
      }
      if ((k1 ?? '').toUpperCase() == 'NAMA') {
        mode = (_teks(sel(3)) ?? '').toUpperCase() == 'NO HP'
            ? 'masuk'
            : 'keluar';
        continue;
      }
      if (mode == null) continue;
      final urut = _urut(sel(2));
      if (urut == null || k1 == null) continue;
      if (mode == 'masuk') {
        if (masuk.containsKey(urut)) {
          peringatan.add(
            'Nota masuk $urut tercatat dua kali; dipakai yang pertama.',
          );
          continue;
        }
        masuk[urut] = SvsMasuk(
          urut: urut,
          tanggal: tanggal,
          nama: k1,
          telp: _teks(sel(3)),
          barang: _teks(sel(4)),
          keluhan: _teks(sel(5)),
        );
      } else {
        if (keluar.containsKey(urut)) {
          peringatan.add(
            'Nota keluar $urut tercatat dua kali; dipakai yang pertama.',
          );
          continue;
        }
        keluar[urut] = SvsKeluar(
          urut: urut,
          tanggal: tanggal,
          nama: k1,
          barang: _teks(sel(3)),
          perbaikan: _teks(sel(4)),
          biaya: _uang(sel(5)),
          keterangan: _teks(sel(7)),
        );
      }
    }
    if (tanggal == null) {
      peringatan.add('Lembar "$tab" tanpa judul bertanggal; dilewati.');
    } else {
      hari.add(tanggal);
    }
  }
  if (hari.isEmpty) {
    throw const FormatException(
      'Tidak ada lembar SVS yang berjudul "LAPORAN PERHARI TGL ...".',
    );
  }
  return BukuSvs(
    masuk: masuk,
    keluar: keluar,
    hari: hari.toList()..sort(),
    peringatan: peringatan,
  );
}

/// Arti keterangan nota keluar di buku SVS.
class NasibKeluar {
  const NasibKeluar({
    required this.status,
    required this.garansi,
    required this.biaya,
    this.caraBayar,
    required this.lunas,
  });

  final String status;
  final bool garansi;
  final double biaya;
  final String? caraBayar;

  /// Uangnya sudah diterima pada hari keluarnya. Piutang belum.
  final bool lunas;
}

/// Membaca keterangan nota keluar, sama seperti skrip SVS harian
/// (supabase/scripts/gen/svs_harian_sql.js) supaya impor lewat aplikasi
/// dan lewat skrip tidak pernah berbeda pendapat.
///
/// Keterangan kosong berarti tunai: begitu kebiasaan mencatatnya di toko.
NasibKeluar nasibKeluarSvs(String? keterangan, double? biaya) {
  final t = (keterangan ?? '').toUpperCase();
  if (t.contains('CANCEL')) {
    return const NasibKeluar(
      status: 'batal',
      garansi: false,
      biaya: 0,
      lunas: false,
    );
  }
  if (t.contains('GARANSI')) {
    return const NasibKeluar(
      status: 'diambil',
      garansi: true,
      biaya: 0,
      lunas: false,
    );
  }
  final gesek = RegExp(r'GESEK\s*(BCA|BRI|BNI)').firstMatch(t);
  if (gesek != null) {
    return NasibKeluar(
      status: 'diambil',
      garansi: false,
      biaya: biaya ?? 0,
      caraBayar: 'gesek_${gesek.group(1)!.toLowerCase()}',
      lunas: true,
    );
  }
  if (t.contains('PIUTANG')) {
    // Sudah dibawa pulang, uangnya belum masuk.
    return NasibKeluar(
      status: 'diambil',
      garansi: false,
      biaya: biaya ?? 0,
      caraBayar: 'piutang',
      lunas: false,
    );
  }
  return NasibKeluar(
    status: 'diambil',
    garansi: false,
    biaya: biaya ?? 0,
    caraBayar: _caraBayar(t) ?? 'cash',
    lunas: true,
  );
}

String? _caraBayar(String t) {
  if (t.contains('QR')) return 'qris';
  if (t.contains('BRI')) return 'transfer_bri';
  if (t.contains('BTN')) return 'transfer_btn';
  if (RegExp(r'\bTT\b|TRANSFER').hasMatch(t)) return 'transfer_bri';
  return null;
}

String? _teks(Object? v) {
  if (v == null) return null;
  final s = switch (v) {
    TextCellValue(:final value) => value.text ?? '',
    IntCellValue(:final value) => '$value',
    DoubleCellValue(:final value) =>
      value == value.roundToDouble() ? '${value.toInt()}' : '$value',
    _ => '$v',
  };
  final rapi = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return rapi.isEmpty || rapi == '-' ? null : rapi;
}

int? _urut(Object? v) {
  final angka = switch (v) {
    IntCellValue(:final value) => '$value',
    DoubleCellValue(:final value) => '${value.toInt()}',
    _ => (_teks(v) ?? '').replaceAll(RegExp(r'\D'), ''),
  };
  return angka.isEmpty ? null : int.tryParse(angka);
}

double? _uang(Object? v) => switch (v) {
  IntCellValue(:final value) => value >= 0 ? value.toDouble() : null,
  DoubleCellValue(:final value) => value >= 0 ? value.roundToDouble() : null,
  _ => () {
    final s = (_teks(v) ?? '').replaceAll(RegExp(r'\D'), '');
    return s.isEmpty ? null : double.tryParse(s);
  }(),
};
