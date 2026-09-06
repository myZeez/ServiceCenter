// Membaca tiga sheet induk servis lalu menghasilkan satu berkas SQL impor.
//
// Dijalankan sekali; yang disimpan di repo hasilnya, bukan skrip ini.
// Yang perlu diperiksa manusia sebelum dijalankan adalah SQL-nya.

import 'dart:io';
import 'dart:math';

import 'telaah_lib.dart';

// ---------------------------------------------------------------------
// Tanggal dan uang
// ---------------------------------------------------------------------

DateTime? tanggal(String teks) {
  final t = teks.trim();
  final m = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})$').firstMatch(t);
  if (m == null) return null;
  var th = int.parse(m.group(3)!);
  if (th < 100) th += 2000;
  final bl = int.parse(m.group(2)!);
  final hr = int.parse(m.group(1)!);
  if (th < 2015 || th > 2035 || bl < 1 || bl > 12 || hr < 1 || hr > 31) {
    return null;
  }
  return DateTime(th, bl, hr);
}

/// Tanggal masuk dibaca dari nomor notanya sendiri: SVR-DDMMYY + urut.
/// Sheet penerimaan tidak punya kolom tanggal masuk -- nomornya yang
/// membawanya, dan itu memang cara toko membacanya selama ini.
({DateTime tanggal, String urut})? dariNota(String no) {
  final m = RegExp(r'^SVR-(\d{2})(\d{2})(\d{2})(\d+)$').firstMatch(no.trim());
  if (m == null) return null;
  final hr = int.parse(m.group(1)!);
  final bl = int.parse(m.group(2)!);
  final th = 2000 + int.parse(m.group(3)!);
  if (bl < 1 || bl > 12 || hr < 1 || hr > 31) return null;
  return (tanggal: DateTime(th, bl, hr), urut: m.group(4)!);
}

int? uang(String teks) {
  final b = teks.replaceAll(RegExp(r'[^0-9]'), '');
  if (b.isEmpty) return null;
  final n = int.tryParse(b);
  return (n == null || n <= 0) ? null : n;
}

String iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String q(String? v) {
  if (v == null) return 'null';
  final t = v.trim();
  return t.isEmpty ? 'null' : "'${t.replaceAll("'", "''")}'";
}

final _acak = Random(6092026);
String uuid() {
  String h(int n) =>
      List.generate(n, (_) => _acak.nextInt(16).toRadixString(16)).join();
  return '${h(8)}-${h(4)}-4${h(3)}-'
      '${(8 + _acak.nextInt(4)).toRadixString(16)}${h(3)}-${h(12)}';
}

// ---------------------------------------------------------------------
// Status
// ---------------------------------------------------------------------

/// Sheet lama menyatukan dua hal dalam satu kalimat: bergaransi atau
/// tidak, dan di mana unitnya sekarang. Keduanya dipisah di sini.
({bool garansi, String status}) bacaStatus(String teks, String keterangan) {
  final s = teks.toUpperCase();
  final k = keterangan.toUpperCase();

  final garansi = s.contains('GARANSI') && !s.contains('NON GARANSI');

  if (k.contains('CANCEL')) return (garansi: garansi, status: 'batal');
  if (s.isEmpty) return (garansi: garansi, status: 'masuk');
  if (s.contains('BELUM DIAMBIL')) {
    return (garansi: garansi, status: 'selesai');
  }
  // "Sudah Dikirim ke cabang lain" ikut 'diambil': unitnya memang sudah
  // tidak ada di toko, dan itulah yang dijawab status ini.
  return (garansi: garansi, status: 'diambil');
}

class Nota {
  Nota({
    required this.noNota,
    required this.tanggalMasuk,
    required this.nama,
    this.telp,
    required this.barang,
    this.keluhan,
    this.teknisi,
    this.perbaikan,
    required this.garansi,
    required this.status,
    required this.biaya,
    this.caraBayar,
    this.tanggalSelesai,
    this.tanggalLunas,
    this.keterangan,
  });

  final String noNota;
  final DateTime tanggalMasuk;
  final String nama;
  final String? telp;
  final String barang;
  final String? keluhan;
  final String? teknisi;
  final String? perbaikan;
  final bool garansi;
  final String status;
  final int biaya;
  final String? caraBayar;
  final DateTime? tanggalSelesai;
  final DateTime? tanggalLunas;
  final String? keterangan;

  String get nilai =>
      "  (${q(noNota)}, '${iso(tanggalMasuk)}', ${q(nama)}, ${q(telp)}, "
      "${q(barang)}, ${q(keluhan)}, ${q(teknisi)}, ${q(perbaikan)}, "
      "$garansi, '$status', $biaya, ${q(caraBayar)}, "
      "${tanggalSelesai == null ? 'null' : "'${iso(tanggalSelesai!)}'"}, "
      "${tanggalLunas == null ? 'null' : "'${iso(tanggalLunas!)}'"}, "
      "${q(keterangan)})";
}

final batas = DateTime(2026, 1, 1);

void main() {
  const dir = '../SERVIS';

  // ---- Pelunasan: tanggal lunas per nomor nota ----------------------
  //
  // Tanggalnya hanya ditulis di baris pertama tiap hari; sisanya
  // mewarisinya dari atas. Kalau tidak diwariskan, 15.008 dari 16.824
  // baris kehilangan tanggalnya.
  final pel = baca(
    File('$dir/Cellcom Palangka Raya  - Pelunasan Service.csv')
        .readAsStringSync(),
  );
  final lunas = <String, DateTime>{};
  DateTime? berjalan;
  for (var i = 1; i < pel.length; i++) {
    final t = tanggal(g(pel[i], 0));
    if (t != null) berjalan = t;
    final no = g(pel[i], 1).replaceAll(RegExp(r'[^0-9]'), '');
    if (no.isEmpty || berjalan == null) continue;
    // Nota yang muncul dua kali diambil pelunasan pertamanya: yang
    // berikutnya biasanya baris koreksi atau cicilan kedua.
    lunas.putIfAbsent(no, () => berjalan!);
  }

  // ---- Penerimaan: nota servisnya -----------------------------------
  final pen = baca(
    File('$dir/Cellcom Palangka Raya  - Penerimaan Service.csv')
        .readAsStringSync(),
  );

  final nota = <Nota>[];
  var lewatTanggal = 0;
  var lewatNomor = 0;
  var dapatLunas = 0;
  var dariCadangan = 0;
  final perStatus = <String, int>{};

  for (var i = 2; i < pen.length; i++) {
    final b = pen[i];
    final no = g(b, 0);
    final asal = dariNota(no);
    if (asal == null) {
      if (no.isNotEmpty) lewatNomor++;
      continue;
    }
    if (asal.tanggal.isBefore(batas)) {
      lewatTanggal++;
      continue;
    }

    final nama = g(b, 1);
    final barang = g(b, 3);
    if (nama.isEmpty || barang.isEmpty) {
      lewatNomor++;
      continue;
    }

    final keterangan = g(b, 10);
    final st = bacaStatus(g(b, 11), keterangan);

    final cash = uang(g(b, 7));
    final piutang = uang(g(b, 8));
    final biaya = cash ?? piutang ?? 0;

    // Kolom mana yang terisi itulah cara bayarnya. Nota tanpa angka di
    // keduanya tidak diberi cara bayar sama sekali -- bukan ditebak
    // 'cash', karena banyak di antaranya memang belum selesai.
    final caraBayar = biaya == 0
        ? null
        : (cash != null ? 'cash' : 'piutang');

    final selesai = tanggal(g(b, 6));
    var tglLunas = lunas[asal.urut];
    if (tglLunas != null) dapatLunas++;

    // Nota tunai yang unitnya sudah diambil pasti sudah dibayar; kalau
    // sheet pelunasan tidak memuatnya, tanggal selesainya yang dipakai.
    // Dibiarkan kosong akan membuatnya muncul sebagai piutang menahun di
    // laporan.
    if (tglLunas == null && st.status == 'diambil' && caraBayar == 'cash') {
      tglLunas = selesai;
      if (selesai != null) dariCadangan++;
    }

    // Constraint di server: tanggal lunas tanpa cara bayar ditolak.
    final bayarAkhir = tglLunas != null ? (caraBayar ?? 'cash') : caraBayar;

    perStatus.update(st.status, (v) => v + 1, ifAbsent: () => 1);
    nota.add(
      Nota(
        noNota: no,
        tanggalMasuk: asal.tanggal,
        nama: nama,
        telp: g(b, 2),
        barang: barang,
        keluhan: g(b, 4),
        teknisi: g(b, 5),
        perbaikan: keterangan,
        garansi: st.garansi,
        status: st.status,
        biaya: biaya,
        caraBayar: bayarAkhir,
        tanggalSelesai: selesai,
        tanggalLunas: tglLunas,
        keterangan: g(b, 11),
      ),
    );
  }
  nota.sort((a, b) => a.tanggalMasuk.compareTo(b.tanggalMasuk));

  // ---- Kirim antar cabang -------------------------------------------
  final kir = baca(
    File('$dir/Cellcom Palangka Raya  - Kirim-Kirim.csv').readAsStringSync(),
  );
  final kirim = <String>[];
  var kirimLewat = 0;
  for (var i = 1; i < kir.length; i++) {
    final b = kir[i];
    final t = tanggal(g(b, 0));
    final barang = g(b, 4);
    if (t == null || barang.isEmpty) continue;
    if (t.isBefore(batas)) {
      kirimLewat++;
      continue;
    }

    final ket = g(b, 10).toUpperCase();
    final jenis = ket.startsWith('WARRANTY')
        ? 'garansi'
        : (ket.startsWith('NON') ? 'non_garansi' : (ket == 'CID' ? 'cid' : null));

    kirim.add(
      "  ('${uuid()}', '${iso(t)}', ${q(g(b, 1))}, ${q(g(b, 2))}, "
      "${q(g(b, 3))}, ${q(barang)}, ${q(g(b, 5))}, ${q(g(b, 6))}, "
      "${q(g(b, 7))}, '${g(b, 8).toUpperCase() == 'RECEIVED' ? 'received' : 'ship'}', "
      "${tanggal(g(b, 9)) == null ? 'null' : "'${iso(tanggal(g(b, 9))!)}'"}, "
      "${jenis == null ? 'null' : "'$jenis'"})",
    );
  }

  final s = StringBuffer()
    ..writeln(_kepala(nota, perStatus, dapatLunas, kirim.length))
    ..writeln(_bagianNota(nota))
    ..writeln(_bagianKirim(kirim));
  File(
    '../supabase/scripts/import_servis_2026.sql',
  ).writeAsStringSync(s.toString());

  final berbiaya = nota.where((n) => n.biaya > 0).toList();
  final perStatusBerbiaya = <String, int>{};
  for (final n in berbiaya) {
    perStatusBerbiaya.update(n.status, (v) => v + 1, ifAbsent: () => 1);
  }

  stderr.writeln('nota servis  : ${nota.length}');
  stderr.writeln('  per status : $perStatus');
  stderr.writeln('  berbiaya   : ${berbiaya.length} -> $perStatusBerbiaya');
  stderr.writeln('  dapat tanggal lunas dari sheet pelunasan: $dapatLunas');
  stderr.writeln('  dari tanggal selesai (cadangan)        : $dariCadangan');
  stderr.writeln('kirim        : ${kirim.length} (sebelum 2026: $kirimLewat)');
  stderr.writeln('lewat tanggal: $lewatTanggal, nomor/nama tak terbaca: $lewatNomor');
}

String _kepala(
  List<Nota> nota,
  Map<String, int> perStatus,
  int dapatLunas,
  int kirim,
) {
  final rincian = (perStatus.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)))
      .map((e) => '--       ${e.key.padRight(10)} ${e.value}')
      .join('\n');
  final berbiaya = nota.where((n) => n.biaya > 0).length;
  final belum = nota.where((n) => n.biaya > 0 && n.tanggalLunas == null).length;

  // Pemisah ribuan dihitung di sini, bukan di dalam template: escape di
  // dalam interpolasi string bertanda tiga tidak selalu berarti yang
  // dikira, dan hasilnya angka tanpa titik sama sekali.
  final nilai = nota
      .fold<int>(0, (a, n) => a + n.biaya)
      .toString()
      .replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'),
        (m) => '${m[1]}.',
      );

  return '''
-- =====================================================================
--  Impor arsip servis -- Januari 2026 dan seterusnya
--
--  Sumbernya tiga sheet induk yang dipakai toko selama ini:
--
--    Cellcom Palangka Raya - Penerimaan Service.csv   23.834 baris
--    Cellcom Palangka Raya - Pelunasan Service.csv    16.824 baris
--    Cellcom Palangka Raya - Kirim-Kirim.csv           1.030 baris
--
--  DIBATASI mulai 1 Januari 2026, sesuai permintaan. Riwayat 2021-2025
--  sengaja tidak ikut supaya berkas ini masih bisa dibaca dan diperiksa
--  sebelum dijalankan.
--
--  DITARUH DI supabase/scripts/, BUKAN supabase/migrations/ -- operasi
--  sekali jalan atas arsip yang isinya sudah tetap. Alasan yang sama ada
--  di kosongkan_transaksi.sql.
--
--  AMAN DIJALANKAN ULANG. Nota disisipkan hanya kalau nomornya belum ada;
--  baris kirim hanya kalau id tetapnya belum ada.
--
--  YANG MASUK
--    service_orders  ${nota.length} nota
$rincian
--       berbiaya      $berbiaya nota, jumlah jasanya Rp $nilai
--       belum lunas   $belum nota
--    shipments       $kirim baris
--
--  ---------------------------------------------------------------------
--  KEPUTUSAN YANG DIAMBIL SAAT MENYUSUN BERKAS INI
--  ---------------------------------------------------------------------
--
--  1. TANGGAL MASUK DIBACA DARI NOMOR NOTANYA. Sheet penerimaan tidak
--     punya kolom tanggal masuk sama sekali -- nomornya yang membawanya
--     (SVR-DDMMYY + urut), dan itu memang cara toko membacanya selama
--     ini. Nota yang nomornya tidak berbentuk begitu dilewati, bukan
--     ditebak tanggalnya.
--
--  2. AWALAN NOMORNYA "SVR-", BUKAN "SRV-". Itu yang tertulis di arsip
--     dan di kertas. Aplikasi sendiri menerbitkan "SRV-" (lihat migrasi
--     0007). Keduanya dibiarkan apa adanya di sini: nomor yang sudah
--     tercetak tidak boleh diubah. Yang perlu diputuskan terpisah adalah
--     mana yang dipakai untuk nota BARU.
--
--  3. TANGGAL LUNAS DIAMBIL DARI SHEET PELUNASAN, dicocokkan lewat angka
--     urut notanya -- $dapatLunas nota dapat tanggalnya dari sana.
--     Tanggal di sheet itu hanya ditulis pada baris pertama tiap hari,
--     jadi barisnya mewarisi tanggal dari atasnya; tanpa itu 15.008 dari
--     16.824 baris kehilangan tanggalnya.
--
--     Nota tunai yang unitnya sudah diambil tetapi tidak ada di sheet
--     pelunasan memakai tanggal selesainya sebagai cadangan. Dibiarkan
--     kosong akan membuatnya muncul sebagai piutang menahun di laporan.
--     Cadangan itu ternyata hampir tidak terpakai: hanya SATU nota yang
--     membutuhkannya. Sisanya, sheet pelunasan memang memuat semuanya --
--     dan itu sebabnya angka "belum lunas" di atas nol. Bukan karena
--     ditebak lunas, melainkan karena arsipnya memang mencatat semuanya
--     sudah tertagih.
--
--  4. CARA BAYAR DARI KOLOM MANA ANGKANYA BERADA. Sheet penerimaan
--     memisahkan Cash dan Piutang sebagai dua kolom; yang terisi itulah
--     cara bayarnya. Nota tanpa angka di keduanya tidak diberi cara bayar
--     -- bukan ditebak 'cash', karena banyak di antaranya memang belum
--     selesai dikerjakan.
--
--  5. STATUS dipisah dari satu kalimat jadi dua kolom:
--       "Non Garansi(Barang Sudah Diambil)"  -> garansi=false, diambil
--       "Garansi ( Barang Belum Diambil)"    -> garansi=true,  selesai
--       "... Barang Sudah Dikirim ..."       -> diambil (unitnya memang
--                                               sudah tidak di toko)
--       keterangan mengandung "Cancel"       -> batal
--       kosong                               -> masuk
--
--     Kalimat aslinya tetap disimpan utuh di kolom keterangan, jadi
--     "Sudah Dikirim ke CC PBUN pada 02-08-26" tidak hilang.
--
--  6. KLAIM GARANSI TIDAK IKUT DIBUAT. Nota bergaransi ditandai
--     garansi=true tetapi claim_id-nya kosong: klaim ke brand punya
--     arsipnya sendiri, dan sudah diimpor terpisah lewat
--     import_klaim_2026.sql. Membuat klaim kedua dari sini akan
--     menggandakan unit yang sama di Rekap Brand.
--
--  7. PELANGGAN TIDAK DIBUATKAN KARTU, sama seperti impor part. Nama dan
--     telepon disimpan sebagai teks di notanya dan tetap bisa dicari.
--
--  JALANKAN SETELAH migrasi 0020.
-- =====================================================================
''';
}

String _bagianNota(List<Nota> nota) => '''

-- ---------------------------------------------------------------------
--  LANGKAH 1 -- nota servis
--
--    Trigger sentuh_service_order() hanya berjalan pada UPDATE, jadi
--    tanggal lunas dan tanggal selesai yang ditulis di sini tidak akan
--    ditimpa server.
-- ---------------------------------------------------------------------
insert into service_orders (
  no_nota, tanggal_masuk, customer_nama, customer_telp, barang_nama,
  keluhan, teknisi_id, perbaikan, garansi, status, biaya, cara_bayar,
  tanggal_selesai, tanggal_lunas, keterangan, created_by
)
select
  v.no_nota,
  (v.tanggal_masuk::date)::timestamp at time zone 'Asia/Jakarta',
  v.nama, v.telp, v.barang, v.keluhan,
  p.id,
  v.perbaikan,
  v.garansi,
  v.status::service_status,
  v.biaya,
  v.cara_bayar,
  v.tanggal_selesai::date,
  v.tanggal_lunas::date,
  v.keterangan,
  admin_akun.id
from (values
${nota.map((n) => n.nilai).join(',\n')}
) as v(no_nota, tanggal_masuk, nama, telp, barang, keluhan, teknisi_nama,
       perbaikan, garansi, status, biaya, cara_bayar, tanggal_selesai,
       tanggal_lunas, keterangan)
left join profiles p on lower(trim(p.nama)) = lower(trim(v.teknisi_nama))
cross join (
  select id from profiles where role = 'admin' and aktif
  order by created_at limit 1
) as admin_akun
where not exists (
  select 1 from service_orders so where so.no_nota = v.no_nota
);
''';

String _bagianKirim(List<String> kirim) => '''

-- ---------------------------------------------------------------------
--  LANGKAH 2 -- kirim antar cabang
-- ---------------------------------------------------------------------
insert into shipments (
  id, tanggal_kirim, dari_cabang, ke_cabang, user_nama, barang_nama,
  serial_number, keluhan, kelengkapan, status, tanggal_kembali,
  keterangan, created_by
)
select
  v.id::uuid, v.tanggal_kirim::date, v.dari, v.ke, v.user_nama,
  v.barang, v.sn, v.keluhan, v.kelengkapan,
  v.status::status_kirim,
  v.tanggal_kembali::date,
  v.keterangan::jenis_kirim,
  admin_akun.id
from (values
${kirim.join(',\n')}
) as v(id, tanggal_kirim, dari, ke, user_nama, barang, sn, keluhan,
       kelengkapan, status, tanggal_kembali, keterangan)
cross join (
  select id from profiles where role = 'admin' and aktif
  order by created_at limit 1
) as admin_akun
where not exists (
  select 1 from shipments s where s.id = v.id::uuid
);
''';
