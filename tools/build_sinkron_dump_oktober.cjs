// Membangun migrasi sinkronisasi dump aplikasi lama untuk tanggal yang belum masuk.
//
//   node tools/build_sinkron_dump_oktober.cjs <dump.SQL> <dump-sebelumnya.SQL> <versi> <batas-urut-database> <hasil.sql>
//
// Contoh (16-18 Oktober 2026):
//   node tools/build_sinkron_dump_oktober.cjs DATASET/October/18-10-2026_SP4.SQL \
//        DATASET/October/15-10-2026_SP4.SQL 0063 28791 supabase/migrations/0063_sinkron_dump_oktober_16_18.sql
//
// Yang ditulis (dan hanya ini):
//   1. nota baru yang masih terbuka, dan yang sudah keluar sebagai GARANSI;
//   2. nota lama yang sudah keluar sebagai GARANSI atau CANCEL menurut dump;
//   3. teknisi, mengikuti dump (SVS tidak punya kolom teknisi).
// Yang SENGAJA tidak ditulis: nota keluar yang berbayar. Cara bayarnya hanya ada
// di SVS (dump menyimpan semuanya CASH), jadi ditahan sampai SVS yang benar ada.
const fs = require('fs');
const { bacaServisDump } = require('../supabase/scripts/gen/legacy_servis_dump');

const [, , dumpBaru, dumpLama, versi, batasArg, outFile] = process.argv;
if (!dumpBaru || !dumpLama || !/^\d{4}$/.test(versi || '') || !batasArg || !outFile) {
  console.error('pakai: node tools/build_sinkron_dump_oktober.cjs <dump> <dump-sebelumnya> <versi> <urut-tertinggi-di-database> <hasil.sql>');
  process.exit(1);
}
const batas = Number(batasArg);

// Nota kembar di database (satu unit tercatat dua kali, impor SVS dan impor dump).
// Yang dipakai nota resmi, yaitu bernomor tanggal SVS -- sama dengan keputusan
// untuk 28428 di migrasi 0061/0062. Nomor persis nota resmi dikunci di sini.
const NOTA_RESMI_KEMBAR = { 28433: 'SVR-18092628433' };

// Nota yang teknisinya mengikuti dump walau penyelesaiannya ditahan (berbayar).
const TEKNISI_SAJA = [28455];

const q = (v) => (v === null || v === undefined ? 'null' : "'" + String(v).replace(/'/g, "''") + "'");
const bersih = (v) => { const t = String(v ?? '').trim(); return t || null; };
const tanggal = (v) => (/^\d{4}-\d{2}-\d{2}$/.test(v) && !v.startsWith('1899') ? v : null);
const teknisiDari = (v) => {
  let n = String(v || '').trim().toLowerCase();
  if (n === 'airs') n = 'aris';
  if (n === 'iirwan') n = 'irwan';
  return n || null;
};
const penandaDari = (r) => {
  const k = String(r[38] || '').trim().toUpperCase();
  return /GARANSI/.test(k) ? 'GARANSI' : /^CANC/.test(k) ? 'CANCEL' : 'BAYAR';
};

const baru = bacaServisDump(dumpBaru).filter((r) => /^SVR-\d{11,}$/.test(String(r[0])));
const lama = new Map(bacaServisDump(dumpLama).map((r) => [String(r[0]), r]));
const urut = (r) => Number(String(r[0]).slice(-5));
const diambil = (r) => String(r[20]).toLowerCase() === 'true';

const sudahDiambilDiDumpLama = (r) => { const o = lama.get(String(r[0])); return !!o && diambil(o); };

const hitungBaru = [];   // nota yang belum ada di database
const tahanBayar = [];   // nota baru yang keluar berbayar -> ditahan
const barisLama = [];    // nota lama yang baru keluar sebagai garansi/cancel
const teknisiList = [];

for (const r of baru) {
  const no = String(r[0]);
  const u = urut(r);
  const okt = /^SVR-\d{2}1026/.test(no);
  const pen = penandaDari(r);
  const kembali = diambil(r) ? tanggal(String(r[32])) : null;

  if (okt && u > batas) {
    if (diambil(r) && pen === 'BAYAR') { tahanBayar.push(no); continue; }
    const nama = bersih(r[26]);
    if (!nama) throw new Error('Nama pelanggan kosong: ' + no);
    const keluhan = [r[6], r[22], r[23]].map(bersih).filter(Boolean).join(' & ') || null;
    const jam = bersih(r[33]) || '12:00:00';
    hitungBaru.push({
      no, u, masuk: String(r[1]), nama, telp: bersih(r[28]), barang: bersih(r[3]) || 'UNIT',
      tipe: bersih(r[4]), sn: bersih(r[5]), keluhan, kelengkapan: bersih(r[16]),
      teknisi: teknisiDari(r[29]),
      status: diambil(r) ? 'diambil' : 'masuk',
      garansi: diambil(r) && pen === 'GARANSI',
      kembali: diambil(r) ? kembali : null,
      jam: diambil(r) ? jam : null,
    });
    if (diambil(r) && pen === 'CANCEL') throw new Error('Nota baru cancel belum ditangani: ' + no);
    continue;
  }

  // Nota lama (sudah di database): hanya yang baru keluar sejak dump sebelumnya.
  if (u <= batas && diambil(r) && !sudahDiambilDiDumpLama(r) && pen !== 'BAYAR') {
    if (!kembali) throw new Error('Tanggal ambil kosong: ' + no);
    barisLama.push({ no, u, pen, kembali, jam: bersih(r[33]) || '12:00:00', teknisi: teknisiDari(r[29]) });
  }
  if (TEKNISI_SAJA.includes(u)) teknisiList.push({ u, teknisi: teknisiDari(r[29]), no: null });
}
for (const l of barisLama) teknisiList.push({ u: l.u, teknisi: l.teknisi, no: NOTA_RESMI_KEMBAR[l.u] || null });
teknisiList.sort((a, b) => a.u - b.u);
hitungBaru.sort((a, b) => a.u - b.u);
barisLama.sort((a, b) => a.u - b.u);

const tanpaTeknisi = teknisiList.filter((t) => !t.teknisi);
if (tanpaTeknisi.length) throw new Error('Teknisi kosong di dump untuk: ' + tanpaTeknisi.map((t) => t.u).join(', '));

const nilaiBaru = hitungBaru.map((b) => `    (${b.u}, ${q(b.no)}, date ${q(b.masuk)}, ${q(b.nama)}, ${q(b.telp)}, ${q(b.barang)}, ${q(b.tipe)}, ${q(b.sn)}, ${q(b.keluhan)}, ${q(b.kelengkapan)}, ${q(b.teknisi)}, ${q(b.status)}, ${b.garansi}, ${b.kembali ? 'date ' + q(b.kembali) : 'null::date'}, ${b.jam ? 'time ' + q(b.jam) : 'null::time'})`).join(',\n');
const nilaiLama = barisLama.map((l) => `    (${l.u}, ${q(NOTA_RESMI_KEMBAR[l.u] || null)}, ${q(l.pen)}, date ${q(l.kembali)}, time ${q(l.jam)})`).join(',\n');
const nilaiTeknisi = teknisiList.map((t) => `    (${t.u}, ${q(t.no)}, ${q(t.teknisi)})`).join(',\n');

const nBaruTerbuka = hitungBaru.filter((b) => b.status === 'masuk').length;
const nBaruGaransi = hitungBaru.filter((b) => b.status === 'diambil').length;
const nGaransi = barisLama.filter((l) => l.pen === 'GARANSI').length;
const nCancel = barisLama.filter((l) => l.pen === 'CANCEL').length;
const urutBaru = hitungBaru.map((b) => b.u);

const sql = `-- =====================================================================
-- SINKRONISASI DUMP APLIKASI LAMA: ${hitungBaru[0].masuk} s.d. ${hitungBaru[hitungBaru.length - 1].masuk}
-- Sumber: ${dumpBaru.replace(/^.*[\\/]/, '')} (dibanding ${dumpLama.replace(/^.*[\\/]/, '')})
--
-- Database terakhir memuat nota sampai urut ${batas}. Berkas ini menambah yang
-- belum ada dan menutup nota lama yang sudah keluar sebagai garansi/cancel:
--
--   nota baru terbuka ........ ${nBaruTerbuka}   (status masuk)
--   nota baru garansi keluar . ${nBaruGaransi}
--   nota lama garansi ........ ${nGaransi}   (status diambil, garansi, biaya 0)
--   nota lama cancel ......... ${nCancel}   (status batal, biaya 0)
--
-- DITAHAN, tidak ditulis: ${tahanBayar.length} nota baru yang keluar dengan bayar (${tahanBayar.map((n) => n.slice(-5)).join(', ')})
-- dan nota lama berbayar yang masih terbuka di database. Cara bayarnya hanya ada
-- di SVS (dump menyimpan semuanya CASH); semuanya menunggu SVS yang benar.
--
-- Tanggal keluar memakai aturan buku toko: hari berganti jam tutup (hari_laporan),
-- jadi nota yang diambil sesudah jam itu, atau pada hari libur, masuk hari buku
-- berikutnya. Jam ambil diambil dari kolom jam dump.
--
-- Nota kembar: satu unit tercatat dua kali di database (impor SVS dan impor dump).
-- Yang dipakai nota resmi bernomor tanggal SVS; kembarannya tidak disentuh.
${Object.entries(NOTA_RESMI_KEMBAR).map(([u, n]) => `--   urut ${u}: ${n}`).join('\n')}
--
-- Satu blok, jadi semuanya berhasil atau tidak ada yang berubah. Nota lama hanya
-- diubah bila masih terbuka. Aman dijalankan ulang.
-- =====================================================================

do $sinkron$
declare
  admin_id uuid;
  salah    text;
  n_baru   int;
  n_lama   int;
  n_tekn   int;
  n_lewat  int;
begin
  select id into admin_id from profiles where lower(btrim(nama)) = 'admin';
  if admin_id is null then
    raise exception 'Profil admin tidak ditemukan. Tidak ada yang ditulis.';
  end if;

  -- Sumber, sebagai tabel sementara supaya dipakai berkali-kali tanpa mengulang nilai.
  create temp table _baru (
    urut int, no_nota text, masuk date, nama text, telp text, barang text, tipe text, sn text,
    keluhan text, kelengkapan text, teknisi text, status text, garansi boolean, kembali date, jam time
  ) on commit drop;
  insert into _baru values
${nilaiBaru};

  create temp table _lama (urut int, no_nota_db text, penanda text, kembali date, jam time) on commit drop;
  insert into _lama values
${nilaiLama};

  create temp table _teknisi (urut int, no_nota_db text, nama text) on commit drop;
  insert into _teknisi values
${nilaiTeknisi};

  -- 1. Setiap nama teknisi harus tepat satu profil.
  select string_agg(distinct x.nama, ', ') into salah
  from (select teknisi as nama from _baru where teknisi is not null
        union select nama from _teknisi) x
  where (select count(*) from profiles p where lower(btrim(p.nama)) = x.nama) <> 1;
  if salah is not null then
    raise exception 'Nama teknisi tidak tunggal: %. Tidak ada yang ditulis.', salah;
  end if;

  -- 2. Setiap nota lama harus ditemukan tepat satu (nota kembar dikunci nomornya).
  select string_agg(l.urut::text, ', ' order by l.urut) into salah
  from _lama l
  where (select count(*) from service_orders s
         where urut_no_nota(s.no_nota) = l.urut
           and (l.no_nota_db is null or s.no_nota = l.no_nota_db)) <> 1;
  if salah is not null then
    raise exception 'Nota keluar ambigu/tidak ada: %. Tidak ada yang ditulis.', salah;
  end if;

  select string_agg(t.urut::text, ', ' order by t.urut) into salah
  from _teknisi t
  where (select count(*) from service_orders s
         where urut_no_nota(s.no_nota) = t.urut
           and (t.no_nota_db is null or s.no_nota = t.no_nota_db)) <> 1;
  if salah is not null then
    raise exception 'Nota teknisi ambigu/tidak ada: %. Tidak ada yang ditulis.', salah;
  end if;

  -- 3. Nota baru: nomor urutnya tidak boleh sudah dipakai lebih dari satu nota.
  select string_agg(b.urut::text, ', ' order by b.urut) into salah
  from _baru b
  where (select count(*) from service_orders s where urut_no_nota(s.no_nota) = b.urut) > 1;
  if salah is not null then
    raise exception 'Nomor urut nota baru sudah ganda di database: %. Tidak ada yang ditulis.', salah;
  end if;

  -- 4. Nota baru. Yang nomor urutnya sudah dipakai dilewati.
  insert into service_orders (no_nota, tanggal_masuk, customer_nama, customer_telp, barang_nama,
                              barang_type, barang_sn, keluhan, kelengkapan, teknisi_id, status,
                              garansi, biaya, tanggal_selesai, tanggal_diambil, created_by)
  select b.no_nota,
         (b.masuk::text || ' 00:00:00+07')::timestamptz,
         b.nama, b.telp, b.barang, b.tipe, b.sn, b.keluhan, b.kelengkapan,
         (select p.id from profiles p where lower(btrim(p.nama)) = b.teknisi),
         b.status::service_status,
         b.garansi,
         0,
         case when b.kembali is not null then hari_laporan((b.kembali + b.jam) at time zone 'Asia/Jakarta') end,
         case when b.kembali is not null then hari_laporan((b.kembali + b.jam) at time zone 'Asia/Jakarta') end,
         admin_id
  from _baru b
  where not exists (select 1 from service_orders s where urut_no_nota(s.no_nota) = b.urut);
  get diagnostics n_baru = row_count;

  -- 5. Nota lama yang keluar sebagai garansi/cancel. Hanya yang masih terbuka.
  update service_orders so
  set status          = (case l.penanda when 'CANCEL' then 'batal' else 'diambil' end)::service_status,
      garansi         = (l.penanda = 'GARANSI'),
      tanggal_selesai = hari_laporan((l.kembali + l.jam) at time zone 'Asia/Jakarta'),
      tanggal_diambil = hari_laporan((l.kembali + l.jam) at time zone 'Asia/Jakarta'),
      waktu_diambil   = null,
      biaya           = 0,
      cara_bayar      = null,
      tanggal_lunas   = null,
      waktu_lunas     = null
  from _lama l
  where urut_no_nota(so.no_nota) = l.urut
    and (l.no_nota_db is null or so.no_nota = l.no_nota_db)
    and so.status in ('masuk', 'dikerjakan', 'tunggu_part', 'dikirim_cabang');
  get diagnostics n_lama = row_count;

  select count(*) into n_lewat
  from _lama l
  where exists (select 1 from service_orders s
                where urut_no_nota(s.no_nota) = l.urut
                  and (l.no_nota_db is null or s.no_nota = l.no_nota_db)
                  and s.status in ('masuk', 'dikerjakan', 'tunggu_part', 'dikirim_cabang'));
  if n_lewat > 0 then
    raise exception 'Masih ada % nota lama yang tetap terbuka setelah diubah. Tidak ada yang ditulis.', n_lewat;
  end if;

  -- 6. Teknisi mengikuti dump.
  update service_orders so
  set teknisi_id = p.id
  from _teknisi t
  join profiles p on lower(btrim(p.nama)) = t.nama
  where urut_no_nota(so.no_nota) = t.urut
    and (t.no_nota_db is null or so.no_nota = t.no_nota_db)
    and so.teknisi_id is distinct from p.id;
  get diagnostics n_tekn = row_count;

  -- 7. Pemeriksaan akhir: setiap nota baru ada tepat satu.
  select string_agg(b.urut::text, ', ' order by b.urut) into salah
  from _baru b
  where (select count(*) from service_orders s where urut_no_nota(s.no_nota) = b.urut) <> 1;
  if salah is not null then
    raise exception 'Nota baru tidak tunggal setelah ditulis: %. Tidak ada yang ditulis.', salah;
  end if;

  raise notice 'Sinkron dump: % nota baru, % nota lama diubah, % penugasan teknisi diubah.',
    n_baru, n_lama, n_tekn;
end
$sinkron$;
`;

fs.writeFileSync(outFile, sql);
console.log(JSON.stringify({
  versi, batas, baruTerbuka: nBaruTerbuka, baruGaransi: nBaruGaransi, lamaGaransi: nGaransi, lamaCancel: nCancel,
  tahanBayar: tahanBayar.map((n) => n.slice(-5)), teknisi: teknisiList.length,
  urutBaru: [urutBaru[0], urutBaru[urutBaru.length - 1]], ukuran: sql.length, keluar: outFile,
}));
