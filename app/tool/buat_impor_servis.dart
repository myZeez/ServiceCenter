// Membaca arsip servis dari SEMUA sumbernya lalu menghasilkan satu berkas
// SQL impor.
//
// Percobaan pertama hanya membaca sheet Penerimaan dan menyalinnya apa
// adanya. Hasilnya salah, dan salahnya jenis yang paling menipu: nota yang
// sudah lama diambil pelanggan muncul sebagai "baru masuk".
//
// Sebabnya, sheet Penerimaan itu buku TERIMA, bukan buku selesai. Kolom
// teknisi, biaya, dan statusnya diisi belakangan -- dan untuk sebagian
// besar nota tidak pernah diisi sama sekali. Yang menyimpan kabar bahwa
// sebuah nota sudah tuntas adalah sheet Pelunasan, dan cara bayarnya ada
// di laporan harian.
//
// Jadi ketiganya dibaca dan digabung, dengan urutan wewenang yang jelas.

import 'dart:io';
import 'dart:math';

import 'telaah_lib.dart';

// ---------------------------------------------------------------------
// Bacaan dasar
// ---------------------------------------------------------------------

DateTime? tanggal(String teks) {
  final m = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})$')
      .firstMatch(teks.trim());
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

/// Tanggal masuk dibaca dari nomor notanya: SVR-DDMMYY + urut. Sheet
/// Penerimaan tidak punya kolom tanggal masuk sama sekali.
({DateTime tanggal, String urut})? dariNota(String no) {
  final m = RegExp(r'^SVR-(\d{2})(\d{2})(\d{2})(\d+)$').firstMatch(no.trim());
  if (m == null) return null;
  final hr = int.parse(m.group(1)!);
  final bl = int.parse(m.group(2)!);
  if (bl < 1 || bl > 12 || hr < 1 || hr > 31) return null;
  return (
    tanggal: DateTime(2000 + int.parse(m.group(3)!), bl, hr),
    urut: m.group(4)!,
  );
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

final _acak = Random(7092026);
String uuid() {
  String h(int n) =>
      List.generate(n, (_) => _acak.nextInt(16).toRadixString(16)).join();
  return '${h(8)}-${h(4)}-4${h(3)}-'
      '${(8 + _acak.nextInt(4)).toRadixString(16)}${h(3)}-${h(12)}';
}

/// Cara bayar dari kolom keterangan laporan harian.
///
/// "QR BTN" berarti QRIS lewat rekening BTN. Yang tidak dikenali
/// dikembalikan null, bukan ditebak -- dan yang null nanti jatuh ke
/// 'cash', cara bayar yang dipakai hampir seluruh arsip.
String? caraBayarDari(String teks) {
  final t = teks.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.isEmpty) return null;
  if (t.contains('QR')) return 'qris';
  if (t.contains('BRI')) return 'transfer_bri';
  if (t.contains('BTN')) return 'transfer_btn';
  if (t.contains('PIUTANG')) return 'piutang';
  return null;
}

// ---------------------------------------------------------------------

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

/// Apa yang diketahui sheet Pelunasan tentang sebuah nota.
class Selesai {
  Selesai({required this.tanggal, this.perbaikan, this.teknisi, this.biaya});

  final DateTime tanggal;
  final String? perbaikan;
  final String? teknisi;
  final int? biaya;
}

// Januari sampai September 2026. Semula dibatasi tiga bulan supaya
// berkasnya bisa diperiksa baris per baris; jendelanya dilebarkan agar
// sejajar dengan arsip klaim garansi, yang memang diimpor sejak Januari.
// Nota dan klaim yang seharusnya berpasangan tidak bisa dipertemukan
// kalau salah satu sisinya berhenti di bulan Juli.
final mulai = DateTime(2026, 1, 1);
final sampai = DateTime(2026, 10, 1);

void main() {
  const dir = '../SERVIS';

  // ---- Sumber 2: sheet Pelunasan ------------------------------------
  //
  // Inilah yang tahu sebuah nota sudah tuntas. Tanggalnya cuma ditulis
  // di baris pertama tiap hari, jadi barisnya mewarisi dari atasnya.
  final pel = baca(
    File('$dir/Cellcom Palangka Raya  - Pelunasan Service.csv')
        .readAsStringSync(),
  );
  final selesai = <String, Selesai>{};
  DateTime? berjalan;
  for (var i = 1; i < pel.length; i++) {
    final t = tanggal(g(pel[i], 0));
    if (t != null) berjalan = t;
    final no = g(pel[i], 1).replaceAll(RegExp(r'[^0-9]'), '');
    if (no.isEmpty || berjalan == null) continue;
    selesai.putIfAbsent(
      no,
      () => Selesai(
        tanggal: berjalan!,
        perbaikan: g(pel[i], 5),
        teknisi: g(pel[i], 6),
        biaya: uang(g(pel[i], 7)),
      ),
    );
  }

  // ---- Sumber 3: laporan harian -------------------------------------
  //
  // Dua hal diambil dari sini, dari dua bagian yang berbeda:
  //
  //   bagian NOTA KELUAR  -> cara bayarnya. Satu-satunya tempat cara
  //                          bayar tercatat sama sekali.
  //   bagian NOTA MASUK   -> nota September. Sheet Penerimaan yang
  //                          diekspor berhenti di 31 Agustus, jadi tanpa
  //                          bagian ini seluruh September hilang.
  //
  // Cakupannya lima hari saja -- 1, 2, 3, 4, dan 6 September. Tanggal 5
  // memang tidak ada berkasnya.
  final bayar = <String, String>{};
  final masukHarian = <String, List<String>>{};
  final tanggalMasukHarian = <String, DateTime>{};

  for (final berkas in [
    '$dir/SVS SEPTEMBER 2026 DATA 1.csv',
    '$dir/SVS SEPTEMBER 2026 DATA 2.csv',
    '$dir/SVS SEPTEMBER 2026 DATA 3.csv',
    '$dir/SVS SEPTEMBER 2026 DATA 4.csv',
    '../TANYA HARGA/SVS SEPTEMBER 2026.csv',
  ]) {
    final f = File(berkas);
    if (!f.existsSync()) continue;

    DateTime? hariLaporan;
    var bagianMasuk = false;

    for (final b in baca(f.readAsStringSync(), pemisah: ';')) {
      final gabung = b.join(' ').toUpperCase();

      final judul = RegExp(r'LAPORAN PERHARI TGL\s+(\d{1,2}/\d{1,2}/\d{4})')
          .firstMatch(gabung);
      if (judul != null) hariLaporan = tanggal(judul.group(1)!);

      // Kedua bagian memakai susunan kolom yang berbeda, dan barisnya
      // dibedakan dari kepala tabelnya: yang bawah punya kolom NO HP.
      if (gabung.contains('NO HP')) {
        bagianMasuk = true;
        continue;
      }
      if (gabung.contains('TANGGAL MASUK')) {
        bagianMasuk = false;
        continue;
      }

      final no = g(b, 2).replaceAll(RegExp(r'[^0-9]'), '');
      if (no.isEmpty) continue;

      if (!bagianMasuk) {
        if (uang(g(b, 5)) == null) continue;
        final cara = caraBayarDari(g(b, 7));
        if (cara != null) bayar[no] = cara;
        continue;
      }

      // Bagian nota masuk. Nama kosong berarti baris nomor yang sudah
      // disiapkan tetapi belum dipakai -- bukan nota.
      final nama = g(b, 1);
      if (nama.isEmpty || hariLaporan == null) continue;
      masukHarian.putIfAbsent(no, () => [nama, g(b, 3), g(b, 4), g(b, 5)]);
      tanggalMasukHarian.putIfAbsent(no, () => hariLaporan!);
    }
  }

  // ---- Sumber 1: sheet Penerimaan, kerangkanya ----------------------
  final pen = baca(
    File('$dir/Cellcom Palangka Raya  - Penerimaan Service.csv')
        .readAsStringSync(),
  );

  final nota = <Nota>[];
  final perStatus = <String, int>{};
  var dariPelunasan = 0;
  var dariSheetStatus = 0;
  var sisaMasuk = 0;
  var lewat = 0;

  for (var i = 2; i < pen.length; i++) {
    final b = pen[i];
    final asal = dariNota(g(b, 0));
    if (asal == null) continue;
    if (asal.tanggal.isBefore(mulai) || !asal.tanggal.isBefore(sampai)) {
      lewat++;
      continue;
    }

    final nama = g(b, 1);
    final barang = g(b, 3);
    if (nama.isEmpty || barang.isEmpty) {
      lewat++;
      continue;
    }

    final statusSheet = g(b, 11);
    final ketSheet = g(b, 10);
    final tuntas = selesai[asal.urut];

    // ---- garansi -----------------------------------------------------
    final garansi =
        statusSheet.toUpperCase().contains('GARANSI') &&
        !statusSheet.toUpperCase().contains('NON GARANSI');

    // ---- status ------------------------------------------------------
    //
    // Urutan wewenangnya:
    //   1. Ada di sheet Pelunasan  -> sudah dibayar, jadi sudah diambil.
    //      Ini yang paling dipercaya, dan yang paling sering menyelamatkan
    //      baris yang di sheet Penerimaan tertinggal kosong.
    //   2. Kolom STATUS di sheet Penerimaan, kalau memang diisi.
    //   3. Sisanya benar-benar belum ada kabarnya -> masih di meja.
    String status;
    if (ketSheet.toUpperCase().contains('CANCEL')) {
      status = 'batal';
    } else if (tuntas != null) {
      status = 'diambil';
      dariPelunasan++;
    } else if (statusSheet.isNotEmpty) {
      dariSheetStatus++;
      status = statusSheet.toUpperCase().contains('BELUM DIAMBIL')
          ? 'selesai'
          : 'diambil';
    } else {
      status = 'masuk';
      sisaMasuk++;
    }

    // ---- teknisi, biaya, perbaikan -----------------------------------
    //
    // Sheet Pelunasan lebih lengkap daripada Penerimaan untuk ketiganya:
    // ia diisi saat pekerjaannya benar-benar tuntas, bukan saat unitnya
    // diterima.
    final teknisi = (tuntas?.teknisi?.isNotEmpty ?? false)
        ? tuntas!.teknisi
        : (g(b, 5).isEmpty ? null : g(b, 5));

    final biaya = tuntas?.biaya ?? uang(g(b, 7)) ?? uang(g(b, 8)) ?? 0;

    final perbaikan = (tuntas?.perbaikan?.isNotEmpty ?? false)
        ? tuntas!.perbaikan
        : (ketSheet.isEmpty ? null : ketSheet);

    // ---- uang --------------------------------------------------------
    final tglLunas = tuntas?.tanggal;
    final tglSelesai = tanggal(g(b, 6)) ?? tglLunas;

    // Cara bayar: dari laporan harian kalau ada; kalau nota berpiutang di
    // sheet Penerimaan, itu yang dipakai; sisanya tunai -- 16.478 dari
    // 16.484 nota berbiaya di seluruh arsip memang tunai.
    String? caraBayar;
    if (biaya > 0) {
      caraBayar =
          bayar[asal.urut] ??
          (uang(g(b, 8)) != null && uang(g(b, 7)) == null ? 'piutang' : 'cash');
    }

    perStatus.update(status, (v) => v + 1, ifAbsent: () => 1);
    nota.add(
      Nota(
        noNota: g(b, 0),
        tanggalMasuk: asal.tanggal,
        nama: nama,
        telp: g(b, 2),
        barang: barang,
        keluhan: g(b, 4),
        teknisi: teknisi,
        perbaikan: perbaikan,
        garansi: garansi,
        status: status,
        biaya: biaya,
        caraBayar: caraBayar,
        tanggalSelesai: status == 'masuk' ? null : tglSelesai,
        tanggalLunas: tglLunas,
        keterangan: statusSheet.isEmpty ? null : statusSheet,
      ),
    );
  }
  // ---- Nota September, dari bagian nota masuk laporan harian --------
  //
  // Sheet Penerimaan berhenti di 31 Agustus, jadi tanpa bagian ini
  // seluruh September kosong -- dan itu justru bulan yang sedang
  // berjalan, yang paling dibutuhkan di layar.
  //
  // Nomor notanya di laporan harian ditulis telanjang ("28168"). Bentuk
  // lengkapnya dirakit dengan aturan yang sama seperti di sheet
  // Penerimaan: SVR + tanggal masuk + urut.
  final sudahAda = {for (final n in nota) n.noNota};
  var dariHarian = 0;

  for (final e in masukHarian.entries) {
    final urut = e.key;
    final tgl = tanggalMasukHarian[urut];
    if (tgl == null) continue;
    if (tgl.isBefore(mulai) || !tgl.isBefore(sampai)) continue;

    final hari =
        '${tgl.day.toString().padLeft(2, '0')}'
        '${tgl.month.toString().padLeft(2, '0')}'
        '${(tgl.year % 100).toString().padLeft(2, '0')}';
    final noNota = 'SVR-$hari$urut';
    if (sudahAda.contains(noNota)) continue;

    final tuntas = selesai[urut];
    final biaya = tuntas?.biaya ?? 0;

    perStatus.update(
      tuntas == null ? 'masuk' : 'diambil',
      (v) => v + 1,
      ifAbsent: () => 1,
    );
    if (tuntas != null) dariPelunasan++;
    dariHarian++;

    nota.add(
      Nota(
        noNota: noNota,
        tanggalMasuk: tgl,
        nama: e.value[0],
        telp: e.value[1],
        barang: e.value[2],
        keluhan: e.value[3],
        teknisi: tuntas?.teknisi,
        perbaikan: tuntas?.perbaikan,
        garansi: false,
        status: tuntas == null ? 'masuk' : 'diambil',
        biaya: biaya,
        caraBayar: biaya > 0 ? (bayar[urut] ?? 'cash') : null,
        tanggalSelesai: tuntas?.tanggal,
        tanggalLunas: tuntas?.tanggal,
        keterangan: null,
      ),
    );
  }

  nota.sort((a, b) => a.tanggalMasuk.compareTo(b.tanggalMasuk));

  // ---- Kirim antar cabang -------------------------------------------
  final kir = baca(
    File('$dir/Cellcom Palangka Raya  - Kirim-Kirim.csv').readAsStringSync(),
  );
  final kirim = <String>[];
  for (var i = 1; i < kir.length; i++) {
    final b = kir[i];
    final t = tanggal(g(b, 0));
    final barang = g(b, 4);
    if (t == null || barang.isEmpty) continue;
    if (t.isBefore(mulai) || !t.isBefore(sampai)) continue;

    final ket = g(b, 10).toUpperCase();
    final jenis = ket.startsWith('WARRANTY')
        ? 'garansi'
        : (ket.startsWith('NON')
              ? 'non_garansi'
              : (ket == 'CID' ? 'cid' : null));

    kirim.add(
      "  ('${uuid()}', '${iso(t)}', ${q(g(b, 1))}, ${q(g(b, 2))}, "
      "${q(g(b, 3))}, ${q(barang)}, ${q(g(b, 5))}, ${q(g(b, 6))}, "
      "${q(g(b, 7))}, "
      "'${g(b, 8).toUpperCase() == 'RECEIVED' ? 'received' : 'ship'}', "
      "${tanggal(g(b, 9)) == null ? 'null' : "'${iso(tanggal(g(b, 9))!)}'"}, "
      "${jenis == null ? 'null' : "'$jenis'"})",
    );
  }

  final s = StringBuffer()
    ..writeln(
      _kepala(
        nota,
        perStatus,
        dariPelunasan,
        dariSheetStatus,
        sisaMasuk,
        bayar.length,
        kirim.length,
      ),
    )
    ..writeln(_bagianNota(nota))
    ..writeln(_bagianTeknisi(nota))
    ..writeln(_bagianKirim(kirim));
  File('../supabase/scripts/import_servis_2026.sql')
      .writeAsStringSync(s.toString());

  stderr.writeln(
    'nota Jan-Sep 2026 : ${nota.length}  (di luar rentang: $lewat)',
  );
  stderr.writeln('  per status      : $perStatus');
  stderr.writeln('  status dari sheet Pelunasan : $dariPelunasan');
  stderr.writeln('  status dari kolom STATUS    : $dariSheetStatus');
  stderr.writeln('  benar-benar belum ada kabar : $sisaMasuk');
  stderr.writeln('  cara bayar dari laporan harian: ${bayar.length} nota');
  stderr.writeln('  nota Sept dari laporan harian : $dariHarian');
  final perBulan = <String, int>{};
  for (final n in nota) {
    perBulan.update(
      '${n.tanggalMasuk.year}-${n.tanggalMasuk.month.toString().padLeft(2, '0')}',
      (v) => v + 1,
      ifAbsent: () => 1,
    );
  }
  stderr.writeln('  per bulan       : $perBulan');
  stderr.writeln('kirim             : ${kirim.length}');
}

String _kepala(
  List<Nota> nota,
  Map<String, int> perStatus,
  int dariPelunasan,
  int dariSheetStatus,
  int sisaMasuk,
  int adaCaraBayar,
  int kirim,
) {
  final rincian =
      (perStatus.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
          .map((e) => '--       ${e.key.padRight(10)} ${e.value}')
          .join('\n');
  final berbiaya = nota.where((n) => n.biaya > 0).length;
  final perBulan = <String, int>{};
  for (final n in nota) {
    perBulan.update(
      '${n.tanggalMasuk.year}-'
      '${n.tanggalMasuk.month.toString().padLeft(2, '0')}',
      (v) => v + 1,
      ifAbsent: () => 1,
    );
  }
  final bulan =
      (perBulan.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
          .map((e) => '--       ${e.key}  ${e.value}')
          .join('\n');
  final nilai = nota
      .fold<int>(0, (a, n) => a + n.biaya)
      .toString()
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');

  return '''
-- =====================================================================
--  Impor arsip servis -- Januari - September 2026
--
--  MENGGANTIKAN versi sebelumnya, yang hasilnya salah. Kosongkan dulu
--  isinya dengan supabase/scripts/kosongkan_servis.sql, baru jalankan
--  berkas ini.
--
--  ---------------------------------------------------------------------
--  APA YANG SALAH SEBELUMNYA
--  ---------------------------------------------------------------------
--  Versi pertama hanya membaca sheet Penerimaan dan menyalinnya apa
--  adanya. Akibatnya nota yang sudah lama diambil pelanggan muncul
--  sebagai "baru masuk", tanpa teknisi dan tanpa biaya.
--
--  Sebabnya: sheet Penerimaan adalah buku TERIMA, bukan buku selesai.
--  Kolom teknisi, biaya, dan statusnya diisi belakangan -- dan untuk
--  sebagian besar nota tidak pernah diisi sama sekali. Contohnya nota
--  28114 atas nama Amri: di sheet Penerimaan seluruh kolom sesudah
--  kerusakan kosong, padahal sheet Pelunasan mencatatnya lunas 01/09/2026
--  oleh Aris sebesar Rp50.000.
--
--  Sekarang ketiga sumber dibaca dan digabung:
--
--    Penerimaan Service   kerangkanya: nomor nota, tanggal masuk,
--                         pelanggan, barang, keluhan
--    Pelunasan Service    kabar bahwa nota sudah tuntas: tanggal,
--                         teknisi, biaya, jenis perbaikan
--    Laporan harian SVS   cara bayarnya ("QR BTN" dan sejenisnya), DAN
--                         seluruh nota September
--
--  Bagian terakhir itu perlu disebut khusus. Sheet Penerimaan yang
--  diekspor berhenti di SVR-31082628151 -- 31 Agustus. September belum
--  masuk ke sana sama sekali, padahal itu bulan yang sedang berjalan dan
--  paling dibutuhkan di layar. Notanya diambil dari bagian "nota masuk"
--  di laporan harian, yang nomornya ditulis telanjang ("28168") dan
--  dirakit di sini jadi bentuk lengkapnya: SVR + tanggal + urut, aturan
--  yang sama dengan sheet Penerimaan.
--
--  Cakupan laporan harian hanya lima hari: 1, 2, 3, 4, dan 6 September.
--  TANGGAL 5 SEPTEMBER TIDAK ADA BERKASNYA, jadi nota yang masuk hari itu
--  tidak ikut. Begitu pula seluruh September sesudah tanggal 6.
--
--  ---------------------------------------------------------------------
--  YANG MASUK
--  ---------------------------------------------------------------------
--    service_orders  ${nota.length} nota (1 Januari - 30 September 2026)
$rincian
--       berbiaya      $berbiaya nota, jumlah jasanya Rp $nilai
--
--    Per bulan:
$bulan
--
--    shipments       $kirim baris
--
--    Asal status:
--       dari sheet Pelunasan          $dariPelunasan
--       dari kolom STATUS Penerimaan  $dariSheetStatus
--       belum ada kabarnya di mana pun $sisaMasuk
--
--    Cara bayar diketahui pasti untuk $adaCaraBayar nota dari laporan
--    harian; sisanya yang berbiaya diisi 'cash'.
--
--  ---------------------------------------------------------------------
--  KEPUTUSAN YANG DIAMBIL
--  ---------------------------------------------------------------------
--
--  1. URUTAN WEWENANG STATUS:
--       a. keterangan mengandung "Cancel"      -> batal
--       b. ada di sheet Pelunasan              -> diambil (sudah dibayar,
--          jadi unitnya pasti sudah diserahkan)
--       c. kolom STATUS Penerimaan, bila diisi -> diambil / selesai
--       d. sisanya                             -> masuk
--
--     Sheet Pelunasan didahulukan atas kolom STATUS dengan sengaja: ia
--     diisi saat uangnya diterima, dan itu kejadian yang tidak pernah
--     lupa dicatat. Kolom STATUS diisi belakangan, dan sering tidak.
--
--  2. TEKNISI, BIAYA, DAN PERBAIKAN juga didahulukan dari sheet
--     Pelunasan. Sheet itu diisi saat pekerjaannya tuntas -- yang
--     mengerjakan sudah pasti, angkanya sudah pasti. Sheet Penerimaan
--     dipakai hanya kalau Pelunasan tidak memuat notanya.
--
--  3. TANGGAL MASUK DIBACA DARI NOMOR NOTANYA (SVR-DDMMYY + urut). Sheet
--     Penerimaan tidak punya kolom itu sama sekali.
--
--  4. AWALAN "SVR-", bukan "SRV-". Itu yang tertulis di kertas. Aplikasi
--     sendiri menerbitkan "SRV-"; keduanya dibiarkan apa adanya, karena
--     nomor yang sudah tercetak tidak boleh diubah.
--
--  5. KLAIM GARANSI TIDAK IKUT DIBUAT. Nota bergaransi ditandai
--     garansi=true tetapi tanpa claim_id: klaim ke brand punya arsipnya
--     sendiri (import_klaim_2026.sql), dan membuatnya lagi dari sini akan
--     menggandakan unit yang sama di Rekap Brand.
--
--  6. PELANGGAN TIDAK DIBUATKAN KARTU. Nama dan telepon disimpan sebagai
--     teks di notanya dan tetap bisa dicari.
--
--  AMAN DIJALANKAN ULANG: nota disisipkan hanya kalau nomornya belum ada.
--  JALANKAN SETELAH migrasi 0020.
-- =====================================================================
''';
}

String _bagianNota(List<Nota> nota) =>
    '''

-- ---------------------------------------------------------------------
--  LANGKAH 1 -- nota servis
--
--    Trigger sentuh_service_order() hanya berjalan pada UPDATE, jadi
--    tanggal yang ditulis di sini tidak akan ditimpa server.
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

/// Menempelkan teknisi yang akunnya baru dibuat sesudah impor berjalan.
///
/// Nota disisipkan dengan `left join profiles`: nama yang tidak punya akun
/// menghasilkan teknisi_id kosong, tanpa galat dan tanpa kabar. Setelah
/// itu namanya hilang -- tidak ada kolom di service_orders yang
/// menyimpannya, jadi tidak ada yang bisa dipulihkan belakangan.
///
/// Jendela impor yang melebar sampai Januari memunculkan dua nama yang
/// tidak ada di jendela sebelumnya. Salah satunya mengerjakan puluhan
/// nota. Kalau akunnya belum ada saat berkas ini dijalankan, puluhan nota
/// itu tercatat tanpa pengerja -- dan yang membacanya nanti akan mengira
/// memang tidak ada yang mengerjakannya.
///
/// Bagian ini membuat urutannya tidak lagi menentukan.
String _bagianTeknisi(List<Nota> nota) {
  final nama = <String>{
    for (final n in nota)
      if ((n.teknisi ?? '').trim().isNotEmpty) n.teknisi!.trim(),
  }.toList()..sort();

  final pasangan = [
    for (final n in nota)
      if ((n.teknisi ?? '').trim().isNotEmpty)
        "  (${q(n.noNota)}, ${q(n.teknisi!.trim())})",
  ];

  return '''

-- ---------------------------------------------------------------------
--  LANGKAH 2 -- teknisi yang akunnya belum ada
--
--    Nama yang dipakai arsip ini:
--      ${nama.join(', ')}
--
--    Yang belum punya akun akan tercatat sebagai nota tanpa pengerja --
--    diam-diam, karena penyisipannya memakai left join. Periksa dulu:
--
--      select v.nama
--      from (values ${nama.map((n) => "(${q(n)})").join(', ')})
--             as v(nama)
--      where not exists (
--        select 1 from profiles p
--        where lower(trim(p.nama)) = lower(trim(v.nama))
--      );
--
--    Yang muncul di situ dibuatkan akunnya lewat aplikasi -- Pengaturan
--    -> Pengguna. Tidak bisa dari sini: profiles.id menunjuk ke
--    auth.users, dan pengguna hanya lahir lewat Edge Function.
--
--    Sesudah akunnya ada, jalankan blok di bawah untuk menempelkan
--    namanya ke nota yang terlanjur kosong. Aman dijalankan ulang, dan
--    aman dijalankan walau tidak ada yang perlu ditempel.
-- ---------------------------------------------------------------------
update service_orders so
set teknisi_id = p.id
from (values
${pasangan.join(',\n')}
) as v(no_nota, teknisi_nama)
join profiles p on lower(trim(p.nama)) = lower(trim(v.teknisi_nama))
where so.no_nota = v.no_nota
  and so.teknisi_id is null;
''';
}

String _bagianKirim(List<String> kirim) =>
    '''

-- ---------------------------------------------------------------------
--  LANGKAH 3 -- kirim antar cabang
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
-- Dicocokkan lewat isinya, BUKAN lewat id di berkas ini.
--
-- Idnya dibuat acak saat berkas ini disusun, jadi menyusun ulang
-- berkasnya menghasilkan id yang lain -- dan penjaga yang bersandar pada
-- id akan menganggap baris yang sama sebagai baris baru. Satu unit yang
-- dikirim ke cabang yang sama pada hari yang sama hanya terjadi sekali,
-- jadi keempat kolom ini cukup mengenalinya.
where not exists (
  select 1 from shipments s
  where s.tanggal_kirim = v.tanggal_kirim::date
    and s.barang_nama = v.barang
    and s.dari_cabang = v.dari
    and coalesce(s.serial_number, '') = coalesce(v.sn, '')
);


-- ---------------------------------------------------------------------
--  LANGKAH 4 -- periksa hasilnya
-- ---------------------------------------------------------------------
--  Jalankan ini sesudahnya. Angkanya harus cocok dengan yang tertulis di
--  kepala berkas ini.
--
--    select status, count(*), sum(biaya)
--    from service_orders
--    where tanggal_masuk >= '2026-01-01' and tanggal_masuk < '2026-10-01'
--    group by status order by 2 desc;
--
--  Dan periksa satu nota yang dulu salah -- harusnya 'diambil', teknisi
--  Aris, Rp50.000:
--
--    select no_nota, status, biaya, tanggal_lunas,
--           (select nama from profiles where id = teknisi_id) as teknisi
--    from service_orders where no_nota = 'SVR-28082628114';
''';
