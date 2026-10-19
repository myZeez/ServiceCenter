// Membangun supabase/scripts/diagnosa_oktober_2026.sql dari dump aplikasi lama.
//
//   node tools/build_diagnosa_oktober.cjs <dump.SQL> <hasil.sql> [hari-akhir]
//
// Hasilnya HANYA membaca. Isinya sengaja tanpa nama dan telepon pelanggan:
// cukup nomor nota, tanggal, nominal, dan penanda GARANSI/CANCEL.
const fs = require('fs');
const { bacaServisDump } = require('../supabase/scripts/gen/legacy_servis_dump');

const [, , dumpFile, outFile, akhirArg] = process.argv;
if (!dumpFile || !outFile) {
  console.error('pakai: node tools/build_diagnosa_oktober.cjs <dump.SQL> <hasil.sql> [hari-akhir]');
  process.exit(1);
}
const akhir = Number(akhirArg || 18);
const dd = String(akhir).padStart(2, '0');
const batasAwal = '2026-10-01';
const batasAkhir = `2026-10-${dd}`;

const baris = bacaServisDump(dumpFile);
const rapi = (v) => String(v ?? '').trim();
const sebagaiTanggal = (v) => (/^\d{4}-\d{2}-\d{2}$/.test(v) && !v.startsWith('1899') ? v : null);

const ambilSet = [];
const tidakBisaDicocokkan = [];
for (const r of baris) {
  const no = rapi(r[0]);
  const oktober = /^SVR-\d{2}1026\d{5}$/.test(no);
  const diambil = rapi(r[20]).toLowerCase() === 'true';
  const kembali = diambil ? sebagaiTanggal(rapi(r[32])) : null;
  const keluarOktober = kembali !== null && kembali >= batasAwal && kembali <= batasAkhir;
  if (!oktober && !keluarOktober) continue;

  // Sama dengan urut_no_nota() di database: 11 digit atau lebih, ambil 5 digit terakhir.
  if (!/^[A-Za-z]{3}-[0-9]{11,}$/.test(no)) {
    tidakBisaDicocokkan.push(no);
    continue;
  }
  const masuk = rapi(r[1]);
  if (oktober && masuk > batasAkhir) continue; // setelah hari akhir: bukan bagian diagnosa
  const ket = rapi(r[38]).toUpperCase();
  const penanda = /GARANSI/.test(ket) ? 'GARANSI' : /^CANC/.test(ket) ? 'CANCEL' : '';
  ambilSet.push({
    urut: Number(no.slice(-5)),
    no,
    oktober,
    masuk,
    diambil,
    kembali,
    jumlah: Math.round(Number(String(r[10] || '0').replace(/,/g, '')) || 0),
    penanda,
  });
}

const urutGanda = ambilSet.map((x) => x.urut).filter((u, i, a) => a.indexOf(u) !== i);
ambilSet.sort((a, b) => a.urut - b.urut);

const q = (s) => `'${String(s).replace(/'/g, "''")}'`;
const nilai = ambilSet
  .map((x) => `  (${x.urut}, ${q(x.no)}, ${x.oktober}, date ${q(x.masuk)}, ${x.diambil}, ${x.kembali ? `date ${q(x.kembali)}` : 'null::date'}, ${x.jumlah}, ${x.penanda ? q(x.penanda) : 'null::text'})`)
  .join(',\n');

const sql = `-- Diagnosa: hanya membaca; tidak mengubah apa pun.
--
-- Oktober 2026, 1 sampai ${akhir} Oktober. Sumber: ${dumpFile.replace(/^.*[\\/]/, '')}
-- (dump aplikasi lama). Memuat ${ambilSet.filter((x) => x.oktober).length} nota bernomor Oktober dan
-- ${ambilSet.filter((x) => !x.oktober).length} nota lama yang diambil pada ${batasAwal} s.d. ${batasAkhir}.
-- Tanpa nama dan telepon pelanggan.
--
-- Yang ditanyakan ke database, hasilnya satu tabel:
--
-- 1. Nota masuk Oktober per hari: berapa menurut dump, berapa yang sudah ada.
-- 2. Nota yang diambil per hari: sudah ada di database? sudah selesai/diambil/
--    batal di sana? Tanggal selesainya yang lain tidak selalu salah: nota yang
--    selesai lebih dulu lalu diambil kemudian memang punya dua tanggal.
-- 3. Nota di database (masuk Oktober) yang TIDAK ada di dump. Harapannya nol;
--    kalau ada, nomornya disebut.
-- 4. Ringkasan isi database untuk Oktober.
-- 5. Contoh nota yang diambil menurut dump tetapi belum rampung di database
--    (paling banyak 40, yang terbaru dulu).
--
-- Dicocokkan menurut NOMOR URUT (5 digit terakhir nomor nota), sama seperti
-- diagnosa Juli: nomor lengkap memuat tanggal masuk dan ada yang salah ketik.
-- Cara bayar TIDAK diperiksa di sini: dump menyimpan semuanya sebagai CASH.
${urutGanda.length ? `--\n-- PERHATIAN: nomor urut ganda di dump: ${[...new Set(urutGanda)].join(', ')}\n` : ''}${tidakBisaDicocokkan.length ? `--\n-- PERHATIAN: ${tidakBisaDicocokkan.length} nota berformat nomor lama tidak bisa dicocokkan: ${tidakBisaDicocokkan.join(', ')}\n` : ''}
with dump(urut, no_nota, oktober, masuk, diambil, kembali, jumlah, penanda) as (
  values
${nilai}
),
db as (
  select urut_no_nota(o.no_nota) as urut,
         o.no_nota,
         o.status::text as status,
         o.tanggal_selesai,
         (o.tanggal_masuk at time zone 'Asia/Jakarta')::date as masuk
  from service_orders o
),
-- Nota yang diambil menurut dump, dengan keadaannya di database.
keluar as (
  select d.*,
         exists (select 1 from db where db.urut = d.urut) as ada,
         exists (select 1 from db where db.urut = d.urut
                   and db.status in ('selesai', 'diambil', 'batal')) as rampung,
         exists (select 1 from db where db.urut = d.urut
                   and db.status in ('selesai', 'diambil', 'batal')
                   and db.tanggal_selesai = d.kembali) as tanggal_sama
  from dump d
  where d.diambil and d.kembali between date '${batasAwal}' and date '${batasAkhir}'
),
hasil as (
  -- 1. Nota masuk Oktober per hari
  select '1. Nota masuk Oktober' as bagian,
         d.masuk::text as kunci,
         count(*)::text as di_dump,
         (count(*) filter (where exists (select 1 from db where db.urut = d.urut)))::text as di_database,
         case when count(*) filter (where not exists (select 1 from db where db.urut = d.urut)) = 0
              then 'lengkap'
              else 'BELUM ADA: ' || (count(*) filter (where not exists (select 1 from db where db.urut = d.urut)))::text || ' nota'
         end as catatan
  from dump d
  where d.oktober
  group by d.masuk

  union all
  select '1. Nota masuk Oktober', 'TOTAL',
         count(*)::text,
         (count(*) filter (where exists (select 1 from db where db.urut = d.urut)))::text,
         case when count(*) filter (where not exists (select 1 from db where db.urut = d.urut)) = 0
              then 'lengkap'
              else 'BELUM ADA: ' || (count(*) filter (where not exists (select 1 from db where db.urut = d.urut)))::text || ' nota'
         end
  from dump d
  where d.oktober

  -- 2. Nota yang diambil, per tanggal ambil
  union all
  select '2. Nota diambil (menurut dump)',
         k.kembali::text,
         count(*)::text,
         (count(*) filter (where k.rampung))::text,
         concat_ws('; ',
           case when count(*) filter (where not k.ada) > 0
                then 'tidak ada di DB: ' || (count(*) filter (where not k.ada))::text end,
           case when count(*) filter (where k.ada and not k.rampung) > 0
                then 'ada tapi belum selesai/diambil: ' || (count(*) filter (where k.ada and not k.rampung))::text end,
           case when count(*) filter (where k.rampung and not k.tanggal_sama) > 0
                then 'tanggal selesai lain: ' || (count(*) filter (where k.rampung and not k.tanggal_sama))::text end,
           case when count(*) filter (where k.penanda = 'GARANSI') > 0
                then 'garansi: ' || (count(*) filter (where k.penanda = 'GARANSI'))::text end,
           case when count(*) filter (where k.penanda = 'CANCEL') > 0
                then 'cancel: ' || (count(*) filter (where k.penanda = 'CANCEL'))::text end
         )
  from keluar k
  group by k.kembali

  union all
  select '2. Nota diambil (menurut dump)', 'TOTAL',
         count(*)::text,
         (count(*) filter (where k.rampung))::text,
         concat_ws('; ',
           'tidak ada di DB: ' || (count(*) filter (where not k.ada))::text,
           'ada tapi belum selesai/diambil: ' || (count(*) filter (where k.ada and not k.rampung))::text,
           'tanggal selesai lain: ' || (count(*) filter (where k.rampung and not k.tanggal_sama))::text)
  from keluar k

  -- 3. Ada di database, tidak ada di dump
  union all
  select '3. Di database tapi tidak di dump',
         'masuk ' || '${batasAwal}' || ' s.d. ' || '${batasAkhir}',
         '0',
         count(*)::text,
         case when count(*) = 0 then 'tidak ada'
              else 'PERIKSA: ' || coalesce((select string_agg(x.no_nota, ', ' order by x.no_nota)
                                            from (select b.no_nota from db b
                                                  where b.masuk between date '${batasAwal}' and date '${batasAkhir}'
                                                    and not exists (select 1 from dump d where d.urut = b.urut)
                                                  order by b.no_nota limit 15) x), '')
         end
  from db b
  where b.masuk between date '${batasAwal}' and date '${batasAkhir}'
    and not exists (select 1 from dump d where d.urut = b.urut)

  -- 4. Ringkasan database
  union all
  select '4. Ringkasan database', 'nota dengan nomor urut 28579 ke atas (Oktober)',
         (select count(*) from dump where oktober)::text,
         count(*)::text,
         'urut tertinggi di DB: ' || coalesce(max(b.urut)::text, '-')
  from db b
  where b.urut >= 28579

  union all
  select '4. Ringkasan database', 'tanggal masuk terbaru di database',
         '${batasAkhir}',
         coalesce(max(b.masuk)::text, '-'),
         case when max(b.masuk) is null then 'belum ada satu pun nota Oktober'
              when max(b.masuk) >= date '${batasAkhir}' then 'sudah sampai hari akhir'
              else 'tertinggal ' || (date '${batasAkhir}' - max(b.masuk))::text || ' hari' end
  from db b
  where b.urut >= 28579

  -- 5. Contoh yang belum rampung
  union all
  select '5. Contoh belum rampung (maks 40)',
         x.no_nota,
         concat_ws(' ', 'diambil', x.kembali::text, 'Rp' || x.jumlah::text, x.penanda),
         case when not x.ada then 'TIDAK ADA di database'
              else coalesce((select 'status ' || b.status || ', tgl selesai ' || coalesce(b.tanggal_selesai::text, '-')
                             from db b where b.urut = x.urut limit 1), '?') end,
         ''
  from (select * from keluar k where not k.rampung order by k.kembali desc, k.urut desc limit 40) x
)
select bagian, kunci, di_dump, di_database, catatan
from hasil
order by bagian, kunci;
`;

fs.writeFileSync(outFile, sql);
console.log(JSON.stringify({
  nota_oktober: ambilSet.filter((x) => x.oktober).length,
  diambil_lama: ambilSet.filter((x) => !x.oktober).length,
  urutGanda: [...new Set(urutGanda)],
  tidakBisaDicocokkan,
  ukuranBerkas: sql.length,
  keluar: outFile,
}));
