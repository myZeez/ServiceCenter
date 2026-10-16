/// Reads MySQL backups from the legacy admin application, without executing SQL.
List<Map<String, dynamic>> parseLegacySql(String text) {
  final create = RegExp(
    r'CREATE TABLE\s+`?servis`?\s*\((.*?)\);',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(text);
  if (create == null) {
    throw const FormatException('Tabel servis tidak ditemukan.');
  }
  final columns = RegExp(
    r'^\s*`([^`]+)`',
    multiLine: true,
  ).allMatches(create.group(1)!).map((m) => m.group(1)!).toList();
  for (final key in [
    'kode',
    'tanggal',
    'nama_pelanggan',
    'barang',
    'teknisi',
  ]) {
    if (!columns.contains(key)) {
      throw FormatException(
        'Format backup tidak sesuai: kolom $key tidak ada.',
      );
    }
  }
  final marker = RegExp(
    r'INSERT INTO\s+`?servis`?\s+VALUES\s*',
    caseSensitive: false,
  );
  final records = <String, Map<String, dynamic>>{};
  for (final match in marker.allMatches(text)) {
    var i = match.end;
    var finished = false;
    while (i < text.length) {
      while (i < text.length && RegExp(r'[\s,]').hasMatch(text[i])) {
        i++;
      }
      if (i < text.length && text[i] == ';') {
        finished = true;
        break;
      }
      if (i >= text.length || text[i] != '(') {
        throw const FormatException('Blok INSERT servis tidak lengkap.');
      }
      i++;
      final values = <String?>[];
      while (true) {
        while (i < text.length && RegExp(r'\s').hasMatch(text[i])) {
          i++;
        }
        final value = StringBuffer();
        final quote = i < text.length && (text[i] == '"' || text[i] == "'")
            ? text[i++]
            : null;
        if (quote != null) {
          var closed = false;
          while (i < text.length) {
            final c = text[i++];
            if (c == r'\') {
              if (i >= text.length) break;
              final escaped = text[i++];
              value.write(switch (escaped) {
                'n' => '\n',
                'r' => '\r',
                't' => '\t',
                _ => escaped,
              });
            } else if (c == quote) {
              if (i < text.length && text[i] == quote) {
                value.write(quote);
                i++;
              } else {
                closed = true;
                break;
              }
            } else {
              value.write(c);
            }
          }
          if (!closed) throw const FormatException('Teks SQL terpotong.');
        } else {
          while (i < text.length && text[i] != ',' && text[i] != ')') {
            value.write(text[i++]);
          }
        }
        final raw = quote == null ? value.toString().trim() : value.toString();
        values.add(quote == null && raw.toUpperCase() == 'NULL' ? null : raw);
        while (i < text.length && RegExp(r'\s').hasMatch(text[i])) {
          i++;
        }
        if (i >= text.length) {
          throw const FormatException('Tuple SQL terpotong.');
        }
        if (text[i] == ')') {
          i++;
          break;
        }
        if (text[i++] != ',') {
          throw const FormatException('Tuple SQL tidak valid.');
        }
      }
      if (values.length != columns.length) {
        throw const FormatException('Jumlah kolom servis tidak sesuai.');
      }
      final row = Map<String, String?>.fromIterables(columns, values);
      String field(String key) => (row[key] ?? '').trim();
      final number = field('kode');
      if (!RegExp(r'^SVR-\d{11}$').hasMatch(number)) continue;
      final incoming = field('tanggal');
      final parsed = DateTime.tryParse(incoming);
      if (parsed == null ||
          incoming != parsed.toIso8601String().substring(0, 10)) {
        throw FormatException('Tanggal masuk tidak valid pada $number.');
      }
      final cost = double.tryParse(field('jumlah'));
      if (cost == null || !cost.isFinite || cost < 0) {
        throw FormatException('Biaya tidak valid pada $number.');
      }
      final taken = field('sudahdiambil').toLowerCase() == 'true';
      final cancelled = field('dibatalkan').toLowerCase() == 'true';
      final returned = field('tanggal_kembali');
      final outgoing = returned == '1899-12-30' || returned.isEmpty
          ? null
          : returned;
      if ((taken || cancelled) &&
          (outgoing == null || DateTime.tryParse(outgoing) == null)) {
        throw FormatException(
          'Tanggal keluar kosong/tidak valid pada $number.',
        );
      }
      var tech = field('teknisi');
      if (tech.toUpperCase() == 'AIRS') tech = 'ARIS';
      final record = <String, dynamic>{
        'no_nota': number, 'tanggal_masuk': incoming,
        'customer_nama': field('nama_pelanggan'),
        'customer_telp': field('telp_pelanggan'),
        // Legacy no_imei often contains the remaining model, not a serial number.
        'barang_nama': [
          'barang',
          'type',
          'no_imei',
        ].map(field).where((s) => s.isNotEmpty).join(' '),
        'keluhan': [
          'kerusakan',
          'kerusakan2',
          'kerusakan3',
        ].map(field).where((s) => s.isNotEmpty).join(' & '),
        'kelengkapan': [
          'kelengkapan',
          'kelengkapan2',
          'kelengkapan3',
        ].map(field).where((s) => s.isNotEmpty).join(', '),
        'teknisi': tech, 'biaya': cancelled ? 0 : cost,
        'status': cancelled
            ? 'batal'
            : taken
            ? 'diambil'
            : field('selesai').toLowerCase() == 'true'
            ? 'selesai'
            : 'masuk',
        'tanggal_diambil': taken || cancelled ? outgoing : null,
      };
      if (records.containsKey(number)) {
        throw FormatException('Nota ganda dalam file: $number.');
      }
      records[number] = record;
    }
    if (!finished) {
      throw const FormatException('INSERT servis tidak diakhiri titik koma.');
    }
  }
  if (records.isEmpty) {
    throw const FormatException('Tidak ada data nota servis pada file.');
  }
  return records.values.toList();
}
