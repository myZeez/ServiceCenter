// Menelaah hubungan antara arsip klaim garansi dan arsip nota servis.
//
// Pertanyaannya: unit bergaransi yang sudah selesai kenapa tidak terbaca
// di laporan harian. Dugaannya kedua arsip itu berdiri sendiri-sendiri --
// dan sebelum ada yang diperbaiki, dugaannya harus dihitung dulu.
//
// Tidak mengubah apa pun. Cetak angka, lalu berhenti.
//
//   dart run tool/telaah_klaim_nota.dart

import 'dart:io';

import 'telaah_lib.dart';

final _akar = Directory.current.parent.path;

/// Satu klaim dari arsip per-brand.
class Klaim {
  Klaim({
    required this.brand,
    required this.tanggal,
    required this.nama,
    required this.sn,
    required this.status,
    required this.noPerbaikan,
  });

  final String brand;
  final DateTime tanggal;
  final String nama;
  final String sn;
  final String status;
  final String noPerbaikan;
}

/// Satu nota dari berkas impor servis yang sudah jadi.
class Nota {
  Nota({
    required this.noNota,
    required this.tanggal,
    required this.nama,
    required this.barang,
    required this.garansi,
    required this.status,
  });

  final String noNota;
  final DateTime tanggal;
  final String nama;
  final String barang;
  final bool garansi;
  final String status;
}

DateTime? _tanggal(String s) {
  final p = s.split('/');
  if (p.length != 3) return null;
  final d = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  final y = int.tryParse(p[2]);
  if (d == null || m == null || y == null) return null;
  return DateTime(y < 100 ? 2000 + y : y, m, d);
}

/// Nama tanpa hiasan: huruf dan angka saja, huruf besar semua.
String _bersih(String s) =>
    s.toUpperCase().replaceAll(RegExp('[^A-Z0-9 ]'), ' ').trim();

String _rapat(String s) => _bersih(s).replaceAll(' ', '');

/// Apakah dua nama pelanggan menunjuk orang yang sama.
///
/// Kedua arsip diketik orang yang berbeda pada waktu yang berbeda.
/// "Siti Nur (CC PBUN)" di satu sisi, "SITI NUR" di sisi lain; "BPS Kota
/// Palangka Raya" dan "Bps Kota Palangka Raya". Pencocokan huruf per huruf
/// akan menyatakan keduanya orang yang berlainan.
bool _namaSama(String a, String b) {
  final x = _rapat(a);
  final y = _rapat(b);
  if (x.isEmpty || y.isEmpty) return false;
  if (x == y) return true;
  // Salah satunya versi yang lebih panjang dari yang lain.
  if (x.length >= 6 && y.length >= 6 && (x.startsWith(y) || y.startsWith(x))) {
    return true;
  }
  // Dua kata pertama sama -- cukup khas untuk nama orang.
  final ka = _bersih(a).split(' ').where((s) => s.isNotEmpty).toList();
  final kb = _bersih(b).split(' ').where((s) => s.isNotEmpty).toList();
  if (ka.length >= 2 && kb.length >= 2) {
    return ka[0] == kb[0] && ka[1] == kb[1];
  }
  return false;
}

void main() {
  // -------------------------------------------------------------------
  // 1. Klaim dari delapan berkas per-brand
  // -------------------------------------------------------------------
  //  Susunan kolomnya TIDAK sama di semua berkas. LENOVO menyisipkan
  //  EMAIL sesudah Telp, jadi SN dan Status di sana bergeser satu. Kolom
  //  dicari lewat judulnya, bukan lewat nomor yang diketik di sini.
  final klaim = <Klaim>[];
  for (final f in Directory(_akar).listSync().whereType<File>()) {
    final namaBerkas = f.path.split(Platform.pathSeparator).last;
    if (!namaBerkas.startsWith('SERVICE CLAIM GARANSI')) continue;
    final brand = namaBerkas.split(' - ').last.replaceAll('.csv', '');

    final baris = baca(f.readAsStringSync());
    if (baris.isEmpty) continue;

    final judul = baris.first.map((s) => s.trim().toUpperCase()).toList();
    int kolom(String cari, int bawaan) {
      final i = judul.indexWhere((j) => j == cari);
      return i < 0 ? bawaan : i;
    }

    final kSn = kolom('SN', 3);
    final kStatus = kolom('STATUS', 8);
    final kPerbaikan = kolom('NO PERBAIKAN', 6);

    for (var i = 1; i < baris.length; i++) {
      final b = baris[i];
      final t = _tanggal(g(b, 0));
      if (t == null) continue;
      klaim.add(
        Klaim(
          brand: brand,
          tanggal: t,
          nama: g(b, 1),
          sn: g(b, kSn),
          status: g(b, kStatus),
          noPerbaikan: g(b, kPerbaikan),
        ),
      );
    }
  }

  // -------------------------------------------------------------------
  // 2. Nota dari berkas impor servis yang sudah jadi
  // -------------------------------------------------------------------
  final nota = <Nota>[];
  final sql = File('$_akar/supabase/scripts/import_servis_2026.sql')
      .readAsStringSync();
  // Nomor notanya ikut dituntut berawalan SVR-/SRV-. Tanpa itu, 94 baris
  // pengiriman antar cabang di bagian bawah berkas ikut terbaca sebagai
  // nota -- susunan kolomnya kebetulan sama-sama diawali teks lalu
  // tanggal, dan yang terbaca sebagai nama pelanggan adalah nama cabang.
  final pola = RegExp(
    r"^  \('((?:SVR|SRV)-[^']*)', '(\d{4})-(\d{2})-(\d{2})', '([^']*)', "
    r"(?:'[^']*'|null), '([^']*)'",
    multiLine: true,
  );
  for (final m in pola.allMatches(sql)) {
    final baris = sql.substring(m.start, sql.indexOf('\n', m.start));
    nota.add(
      Nota(
        noNota: m.group(1)!,
        tanggal: DateTime(
          int.parse(m.group(2)!),
          int.parse(m.group(3)!),
          int.parse(m.group(4)!),
        ),
        nama: m.group(5)!,
        barang: m.group(6)!,
        garansi: baris.contains(', true, '),
        status:
            RegExp(r", (?:true|false), '([a-z_]+)'")
                .firstMatch(baris)
                ?.group(1) ??
            '?',
      ),
    );
  }

  // -------------------------------------------------------------------
  // 3. Angkanya
  // -------------------------------------------------------------------
  bool diJendela(DateTime t) => t.year == 2026 && t.month <= 9;

  final klaimJendela = klaim.where((k) => diJendela(k.tanggal)).toList();
  final notaGaransi = nota.where((n) => n.garansi).toList();

  stderr.writeln('ARSIP KLAIM GARANSI');
  stderr.writeln('  seluruhnya          ${klaim.length}');
  stderr.writeln(
    '  tahun 2026          ${klaim.where((k) => k.tanggal.year == 2026).length}',
  );
  stderr.writeln('  Januari-September 2026 ${klaimJendela.length}');

  stderr.writeln('');
  stderr.writeln('ARSIP NOTA SERVIS (berkas impor, Januari-September 2026)');
  stderr.writeln('  seluruhnya          ${nota.length}');
  stderr.writeln('  bertanda garansi    ${notaGaransi.length}');

  // -------------------------------------------------------------------
  // 4. Berapa yang benar-benar pasangan
  // -------------------------------------------------------------------
  //  Hanya lewat nama dan tanggal. Nomor seri tidak bisa dipakai: sheet
  //  Penerimaan tidak punya kolom SN sama sekali, jadi nota hasil impor
  //  memang tidak menyimpannya.
  //  Dicari di SELURUH nota, bukan cuma yang bertanda garansi. Tanda
  //  garansi di sheet Penerimaan berasal dari kolom STATUS, dan kolom itu
  //  baru terisi setelah unitnya tuntas -- unit yang masih dikerjakan
  //  belum bertanda apa-apa. Mencari hanya di antara yang bertanda berarti
  //  menyimpulkan bahwa unit yang sedang berjalan tidak punya nota.
  var keGaransi = 0;
  var keBiasa = 0;
  final yatim = <Klaim>[];
  final terpakai = <String>{};
  final salahTanda = <(Klaim, Nota)>[];

  for (final k in klaimJendela) {
    Nota? cocok;
    var selisihTerbaik = 99;
    for (final n in nota) {
      if (terpakai.contains(n.noNota)) continue;
      if (!_namaSama(k.nama, n.nama)) continue;
      final selisih = n.tanggal.difference(k.tanggal).inDays.abs();
      if (selisih <= 30 && selisih < selisihTerbaik) {
        cocok = n;
        selisihTerbaik = selisih;
      }
    }
    if (cocok == null) {
      yatim.add(k);
      continue;
    }
    terpakai.add(cocok.noNota);
    if (cocok.garansi) {
      keGaransi++;
    } else {
      keBiasa++;
      salahTanda.add((k, cocok));
    }
  }

  stderr.writeln('');
  stderr.writeln(
    'PASANGANNYA (lewat nama pelanggan, selisih tanggal <= 30 hari)',
  );
  stderr.writeln('  klaim -> nota yang sudah bertanda garansi  $keGaransi');
  stderr.writeln('  klaim -> nota yang BELUM bertanda garansi  $keBiasa');
  stderr.writeln(
    '  klaim tanpa nota sama sekali               ${yatim.length}',
  );
  stderr.writeln(
    '  nota bertanda garansi tanpa klaim          '
    '${notaGaransi.where((n) => !terpakai.contains(n.noNota)).length}',
  );

  stderr.writeln('');
  stderr.writeln('KLAIM YANG NOTANYA BELUM BERTANDA GARANSI');
  for (final (k, n) in salahTanda.take(15)) {
    stderr.writeln('  ${n.noNota}  ${n.status.padRight(11)} ${k.nama}');
  }

  stderr.writeln('');
  stderr.writeln('KLAIM YANG TIDAK PUNYA NOTA SAMA SEKALI');
  var stok = 0;
  var cabang = 0;
  for (final k in yatim) {
    final n = k.nama.toUpperCase();
    if (n.contains('STOCK') || n.contains('STOK')) {
      stok++;
    } else if (RegExp(r'\bCC\b|CELLCOM|PBUN|SAMPIT|KASONGAN').hasMatch(n)) {
      cabang++;
    }
  }
  stderr.writeln('  unit stok toko sendiri     $stok');
  stderr.writeln('  unit dari cabang lain      $cabang');
  stderr.writeln(
    '  sisanya                    ${yatim.length - stok - cabang}',
  );
  for (final k in yatim) {
    final t =
        '${k.tanggal.day.toString().padLeft(2, '0')}/'
        '${k.tanggal.month.toString().padLeft(2, '0')}';
    stderr.writeln(
      '  $t  ${k.brand.padRight(7)} ${k.status.padRight(22)} ${k.nama}',
    );
  }

  stderr.writeln('');
  stderr.writeln('STATUS KLAIM DI JENDELA ITU');
  final perStatus = <String, int>{};
  for (final k in klaimJendela) {
    perStatus.update(
      k.status.isEmpty ? '(kosong)' : k.status,
      (v) => v + 1,
      ifAbsent: () => 1,
    );
  }
  for (final e in perStatus.entries) {
    stderr.writeln('  ${e.key.padRight(24)} ${e.value}');
  }

  // -------------------------------------------------------------------
  // 5. Yang cukup yakin untuk ditautkan otomatis
  // -------------------------------------------------------------------
  //  Hanya nama yang sama persis sesudah dirapikan, dalam 21 hari, dan
  //  hanya kalau calonnya cuma satu. Tautan yang salah jauh lebih mahal
  //  daripada tautan yang tidak jadi dipasang: sekali tertaut, perubahan
  //  status klaim akan menggerakkan nota orang lain.
  final pasangan = <(Klaim, Nota)>[];
  final ragu = <Klaim>[];
  final dipakai = <String>{};

  for (final k in klaimJendela) {
    final calon = [
      for (final n in nota)
        if (!dipakai.contains(n.noNota) &&
            _rapat(k.nama) == _rapat(n.nama) &&
            n.tanggal.difference(k.tanggal).inDays.abs() <= 21)
          n,
    ];
    if (calon.length == 1) {
      dipakai.add(calon.first.noNota);
      pasangan.add((k, calon.first));
    } else if (calon.length > 1) {
      ragu.add(k);
    }
  }

  stderr.writeln('');
  stderr.writeln('YANG AKAN DITAUTKAN OTOMATIS');
  stderr.writeln('  nama sama persis, satu calon saja  ${pasangan.length}');
  stderr.writeln('  calonnya lebih dari satu (dilewat) ${ragu.length}');
  stderr.writeln(
    '  sisanya diurus manual              '
    '${klaimJendela.length - pasangan.length - ragu.length}',
  );

  _tulisSkrip(pasangan);
  stderr.writeln('');
  stderr.writeln('Ditulis: supabase/scripts/hubungkan_klaim_nota.sql');
}

String _q(String s) => "'${s.replaceAll("'", "''")}'";

String _iso(DateTime t) =>
    '${t.year}-${t.month.toString().padLeft(2, '0')}-'
    '${t.day.toString().padLeft(2, '0')}';

void _tulisSkrip(List<(Klaim, Nota)> pasangan) {
  final b = StringBuffer();

  b.writeln('''
-- =====================================================================
--  Menautkan nota servis lama ke klaim garansinya
--
--  Kedua arsip ditulis terpisah sejak sebelum ada aplikasi ini: nota
--  pelanggan di sheet Penerimaan, klaim ke brand di delapan sheet
--  per-brand. Waktu diimpor, keterpisahan itu ikut terbawa -- tidak satu
--  pun nota hasil impor punya claim_id.
--
--  Akibatnya sebuah unit bergaransi tercatat dua kali tanpa saling
--  mengenal. Menutup klaimnya tidak menggerakkan notanya, dan sebaliknya.
--  Sinkronisasi dua arah yang dibangun di migrasi 0016 tidak pernah
--  berjalan untuk baris-baris ini, karena yang dijalankannya adalah
--  tautan yang memang belum ada.
--
--  ---------------------------------------------------------------------
--  YANG DITAUTKAN DI SINI, DAN YANG TIDAK
--  ---------------------------------------------------------------------
--  Kedua arsip tidak punya kunci bersama. Sheet Penerimaan tidak punya
--  kolom nomor seri sama sekali, dan sheet klaim tidak punya nomor nota.
--  Yang tersisa cuma nama pelanggan dan tanggal -- dan itu bukan kunci,
--  itu petunjuk.
--
--  Jadi yang dipasangkan hanya yang paling tidak meragukan:
--
--    * nama pelanggannya SAMA PERSIS sesudah dirapikan
--    * tanggalnya terpaut paling jauh 21 hari
--    * hanya ada SATU nota yang cocok
--
--  Selebihnya sengaja dibiarkan. Tautan yang salah jauh lebih mahal
--  daripada tautan yang tidak jadi dipasang: sekali tertaut, mengubah
--  status sebuah klaim akan ikut menggerakkan nota milik orang lain.
--  Sisanya bisa ditautkan satu per satu dari aplikasi.
--
--  ---------------------------------------------------------------------
--  KENAPA TRIGGER SINKRONISASI DIMATIKAN SEBENTAR
--  ---------------------------------------------------------------------
--  Memasang claim_id membangunkan trg_so_sinkron_status, yang menyalin
--  status nota ke klaimnya. Untuk baris yang baru, itu memang yang
--  diinginkan. Untuk arsip, tidak: kedua sisi punya sejarahnya sendiri
--  yang sudah dilaporkan ke tempat berbeda, dan menyalin salah satunya di
--  atas yang lain akan menulis ulang sejarah yang sudah terlanjur
--  dikirim -- klaim "Wait Part" berubah jadi selesai hanya karena
--  pelanggannya sudah mengambil unitnya.
--
--  Yang dipasang skrip ini cuma tautannya. Status kedua sisi dibiarkan
--  apa adanya, dan mulai berjalan bersama pada perubahan BERIKUTNYA.
--
--  AMAN DIJALANKAN ULANG. Tiap perintah hanya mengenai nota yang
--  claim_id-nya masih kosong.
-- =====================================================================
''');

  b.writeln('begin;');
  b.writeln();
  b.writeln(
    'alter table service_orders disable trigger trg_so_sinkron_status;',
  );
  b.writeln();

  for (final (k, n) in pasangan) {
    b.writeln('-- ${n.noNota}  ${k.brand}  ${k.nama}');
    b.writeln('update service_orders so');
    b.writeln('set claim_id = c.id, garansi = true');
    b.writeln('from claims c');
    b.writeln('where so.no_nota = ${_q(n.noNota)}');
    b.writeln('  and so.claim_id is null');
    // Tanggalnya ikut disebut walau nomor perbaikannya sudah khas.
    // "update ... from" yang cocok dengan dua baris memilih salah satunya
    // tanpa memberi tahu siapa pun, dan arsip klaim ini memuat empat tahun
    // -- nomor yang terpakai ulang di tahun lain cukup untuk merusaknya.
    b.writeln(
      "  and (c.tanggal at time zone 'Asia/Jakarta')::date = "
      '${_q(_iso(k.tanggal))}::date',
    );
    if (k.noPerbaikan.isNotEmpty) {
      b.writeln('  and c.no_perbaikan = ${_q(k.noPerbaikan)};');
    } else {
      b.writeln('  and upper(c.nama_pelanggan) = upper(${_q(k.nama)});');
    }
    b.writeln();
  }

  b.writeln('alter table service_orders enable trigger trg_so_sinkron_status;');
  b.writeln();
  b.writeln('commit;');
  b.writeln();
  b.writeln('''
-- ---------------------------------------------------------------------
--  Periksa sesudahnya
-- ---------------------------------------------------------------------
--  Berapa nota yang sekarang punya klaim, dan berapa yang bertanda
--  garansi tetapi masih berdiri sendiri:
--
--    select
--      count(*) filter (where claim_id is not null) as tertaut,
--      count(*) filter (where garansi and claim_id is null) as sendirian
--    from service_orders;
--
--  Klaim yang belum punya nota -- ini yang perlu ditengok satu per satu:
--
--    select (c.tanggal at time zone 'Asia/Jakarta')::date as tanggal,|--           b.nama as brand, c.nama_pelanggan, c.status
--    from claims c
--    join brands b on b.id = c.brand_id
--    where not exists (
--      select 1 from service_orders so where so.claim_id = c.id
--    )
--    and c.tanggal >= '2026-01-01'
--    order by c.tanggal;''');

  File(
    '${Directory.current.parent.path}/supabase/scripts/'
    'hubungkan_klaim_nota.sql',
  ).writeAsStringSync(b.toString());
}
