import json, sys
from pathlib import Path

src=json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))['rows']
rows=[]
for n,r in src.items():
    if r['tanggal'].startswith('2026-08-'):
        def q(x): return "'"+str(x or '').replace("'", "''")+"'"
        barang=' '.join(x for x in (r['barang'],r['type'],r['no_imei']) if x).strip()
        rows.append('('+','.join([q(n),q(r['tanggal']),q(r['nama_pelanggan']),q(r['telp_pelanggan']),q(barang),q(r['kerusakan']),q(r['kerusakan2']),q(r['teknisi']),str(r['jasa'] or '0'),q(r['status']),q(r['keterangan_saat_sudah_cek'])])+')')
sql='''begin;
create temp table legacy_aug(no_nota text primary key,tanggal date,nama text,telp text,barang text,keluhan text,perbaikan text,teknisi text,biaya numeric,status_lama text,ket text) on commit drop;
insert into legacy_aug values\n'''+',\n'.join(rows)+''';
do $$ begin if (select count(*) from legacy_aug) <> 371 then raise exception 'Expected 371 August notes, got %',(select count(*) from legacy_aug); end if; end $$;
with a as (select id from public.profiles p where lower(p.nama)='admin')
insert into public.service_orders(no_nota,tanggal_masuk,customer_nama,customer_telp,barang_nama,keluhan,perbaikan,biaya,status,garansi,keterangan,created_by)
select l.no_nota,(l.tanggal::timestamp+time '09:00') at time zone 'Asia/Jakarta',l.nama,nullif(l.telp,''),l.barang,nullif(l.keluhan,''),nullif(l.perbaikan,''),l.biaya,case when lower(l.status_lama) like '%ambil%' then 'diambil'::public.service_status else 'masuk'::public.service_status end,lower(l.ket) like '%garansi%','Sumber dump aplikasi lama Agustus 2026',a.id from legacy_aug l cross join a where not exists(select 1 from public.service_orders s where s.no_nota=l.no_nota);
commit;\nselect count(*) as total_nota_agustus from public.service_orders where tanggal_masuk >= timestamptz '2026-08-01 00:00:00+07' and tanggal_masuk < timestamptz '2026-09-01 00:00:00+07';'''
Path(sys.argv[2]).write_text(sql,encoding='utf-8')
print(len(rows))
