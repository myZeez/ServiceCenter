// SVS controls daily note identity/settlement; the newest SQL backup supplies technicians.
const fs = require('fs');
const { bacaSVS } = require('../supabase/scripts/gen/svs_baca');
const { bacaServisDump } = require('../supabase/scripts/gen/legacy_servis_dump');
const through = Number(process.argv[2] || 15);
const version = process.argv[3] || '0062';
if (!Number.isInteger(through) || through < 1 || through > 31 || !/^\d{4}$/.test(version)) throw Error('Usage: node tools/reconcile_october_2026.cjs <last day> <migration version>');
const dd = String(through).padStart(2, '0');
const days = bacaSVS('DATASET/SVS OKTOBER 2026.xlsx', 2026, 10).filter(h => h.hari <= through);
const relevant = new Set(days.flatMap(h => [...h.masuk, ...h.keluar].map(r => +r.seq)));
const legacy = bacaServisDump(`DATASET/October/${dd}-10-2026_SP4.SQL`);
const techRows = legacy.filter(r => relevant.has(+String(r[0]).slice(-5)) && String(r[0]).startsWith('SVR-') && String(r[1]).startsWith('2026-'));
const seen = new Set();
const quote = v => "'" + String(v).replace(/'/g, "''") + "'";
const tech = [];
for (const r of techRows) {
  const seq = +r[0].slice(-5);
  if (seen.has(seq)) throw Error('Duplicate legacy technician source: ' + seq);
  seen.add(seq);
  let name = String(r[29] || '').trim().toLowerCase();
  if (name === 'airs') name = 'aris';
  if (name === 'iirwan') name = 'irwan';
  if (name) tech.push(`(${seq},${quote(name)})`);
}
let sql = fs.readFileSync(`supabase/scripts/harian_2026_10_01_sd_${dd}.sql`, 'utf8');
// SVS carries the full device model in one column. Avoid repeating stale type.
sql = sql.replaceAll('    barang_nama   = v.barang,', '    barang_nama   = v.barang,\n    barang_type   = null,');
// Confirmed duplicate historical note 28428: SVS explicitly identifies entry 18 Sep.
sql = sql.replaceAll('where urut_no_nota(so.no_nota) = v.urut',
  "where urut_no_nota(so.no_nota) = v.urut\n  and (v.urut <> 28428 or so.no_nota = 'SVR-18092628428')");
// Include the separate type in the identity comparison so clearing it is not skipped.
sql = sql.replaceAll('so.customer_nama, so.customer_telp, so.barang_nama, so.keluhan)',
  'so.customer_nama, so.customer_telp, so.barang_nama, so.keluhan, so.barang_type)');
sql = sql.replaceAll('v.nama, v.telp, v.barang, v.keluhan);', 'v.nama, v.telp, v.barang, v.keluhan, null);');
const outgoing = [...new Set(days.flatMap(h => h.keluar.map(r => +r.seq)))];
const incoming = new Set(days.flatMap(h => h.masuk.map(r => +r.seq)));
const preexisting = outgoing.filter(n => !incoming.has(n));
const guards = `
do $unique$
declare problem text;
begin
  select string_agg(v.urut::text, ', ') into problem
  from (values ${preexisting.map(n => '(' + n + ')').join(',')}) v(urut)
  where (select count(*) from service_orders s where urut_no_nota(s.no_nota)=v.urut
         and (v.urut<>28428 or s.no_nota='SVR-18092628428')) <> 1;
  if problem is not null then raise exception 'Nota keluar ambigu/tidak ada: %',problem; end if;
end $unique$;
`;
const technicians = `
-- Technician names from ${dd} Oct legacy snapshot, only for notes in SVS.
-- Blank source names preserve existing manual assignments.
do $known$
declare problem text;
begin
  select string_agg(distinct v.nama, ', ') into problem
  from (values ${tech.join(',\n')}) v(urut,nama)
  where (select count(*) from profiles p where lower(btrim(p.nama))=v.nama)<>1;
  if problem is not null then raise exception 'Nama teknisi tidak tunggal: %',problem; end if;
end $known$;
update service_orders s set teknisi_id=p.id
from (values ${tech.join(',\n')}) v(urut,nama), profiles p
where urut_no_nota(s.no_nota)=v.urut and lower(btrim(p.nama))=v.nama
  and (v.urut<>28428 or s.no_nota='SVR-18092628428')
  and s.teknisi_id is distinct from p.id;
`;
const output = `supabase/migrations/${version}_rekonsiliasi_oktober_svs_sql_sd_${dd}.sql`;
if (fs.existsSync(output) && !process.argv.includes('--replace-unapplied')) throw Error('Migration already exists: '+output);
const audit = fs.readFileSync(`tmp/audit_oktober_01_${dd}.sql`,'utf8').replaceAll(
  'on urut_no_nota(s.no_nota) = k.urut',
  "on urut_no_nota(s.no_nota) = k.urut and (k.urut <> 28428 or s.no_nota = 'SVR-18092628428')");
const techAudit = `
select count(*) as sumber_teknisi,
 count(*) filter (where s.teknisi_id is distinct from p.id) as teknisi_belum_sesuai
from (values ${tech.join(',\n')}) v(urut,nama)
join profiles p on lower(btrim(p.nama))=v.nama
join service_orders s on urut_no_nota(s.no_nota)=v.urut
 and (v.urut<>28428 or s.no_nota='SVR-18092628428');
select no_nota,customer_nama from service_orders
where (tanggal_masuk at time zone 'Asia/Jakarta')::date between date '2026-10-01' and date '2026-10-${dd}'
 and teknisi_id is null order by no_nota;
`;
fs.writeFileSync(output, 'begin;\n' + guards + sql + technicians + '\ncommit;\n');
fs.writeFileSync('tmp/audit_oktober_svs_sql_final.sql', audit + techAudit);
fs.writeFileSync('tmp/audit_oktober_svs_only.sql', audit);
fs.writeFileSync('tmp/audit_oktober_teknisi_only.sql', techAudit.split('select no_nota,customer_nama')[0]);
fs.writeFileSync(`tmp/dryrun_oktober_${dd}.sql`, 'begin;\n' + guards + sql + technicians + '\n' + audit + techAudit + '\nrollback;\n');
fs.writeFileSync(`tmp/dryrun_oktober_svs_${dd}.sql`, 'begin;\n' + guards + sql + technicians + '\n' + audit + '\nrollback;\n');
console.log(JSON.stringify({incoming:days.reduce((a,h)=>a+h.masuk.length,0), outgoing:days.reduce((a,h)=>a+h.keluar.length,0), total:days.reduce((a,h)=>a+h.keluar.reduce((b,k)=>b+k.biaya,0),0), technicianSources:tech.length, sourceBlank:techRows.filter(r=>!String(r[29]||'').trim()).map(r=>r[0]), sqlMissing:[...relevant].filter(n=>!seen.has(n)),output}));
