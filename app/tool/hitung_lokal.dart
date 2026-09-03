// Menghitung isi cermin lokal langsung dari berkasnya, tanpa lewat Flutter.
// Dipakai sebelum mengosongkan data supaya jelas berapa yang akan hilang.
//
// Jalankan: dart run tool/hitung_lokal.dart
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final berkas =
      '${Platform.environment['USERPROFILE']}/Documents/sc_management.sqlite';
  if (!File(berkas).existsSync()) {
    print('Tidak ada berkas: $berkas');
    return;
  }

  final db = sqlite3.open(berkas, mode: OpenMode.readOnly);
  final tabel = db.select(
    "select name from sqlite_master where type='table' "
    "and name not like 'sqlite_%' order by name",
  );
  for (final t in tabel) {
    final nama = t['name'] as String;
    final n = db.select('select count(*) c from "$nama"').first['c'];
    print('${nama.toString().padRight(24)} $n');
  }
  db.dispose();
}
