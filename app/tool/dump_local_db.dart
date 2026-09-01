// Alat bantu diagnosa: menampilkan isi database lokal di perangkat.
//
// Berguna saat tampilan aplikasi tidak sesuai dengan isi server -- biasanya
// artinya sinkronisasi belum menurunkan datanya ke perangkat.
//
// Butuh sqlite3.dll di folder kerja. Salin dulu dari hasil build:
//   copy build\windows\x64\runner\Debug\sqlite3.dll .
//
// Lalu jalankan dari folder app/:
//   dart run tool/dump_local_db.dart

import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

void main() {
  final path =
      '${Platform.environment['USERPROFILE']}\\Documents\\sc_management.sqlite';

  if (!File(path).existsSync()) {
    stderr.writeln('Database lokal tidak ada di $path');
    exit(1);
  }

  final db = sqlite3.open(path);

  for (final table in [
    'profiles',
    'brands',
    'part_types',
    'claims',
    'claim_parts',
    'sync_meta',
  ]) {
    try {
      final rows = db.select('select * from $table');
      stdout.writeln('--- $table (${rows.length} baris) ---');
      for (final r in rows.take(15)) {
        stdout.writeln('  $r');
      }
    } catch (e) {
      stdout.writeln('--- $table: $e');
    }
  }

  db.dispose();
}
