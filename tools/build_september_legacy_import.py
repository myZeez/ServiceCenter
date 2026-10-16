import json
import sys
from pathlib import Path


def quote(value: object) -> str:
    return "'" + str(value or "").replace("'", "''") + "'"


source = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))["rows"]
rows = []
for nota, record in source.items():
    if not record["tanggal"].startswith("2026-09-"):
        continue
    barang = " ".join(
        part for part in (record["barang"], record["type"], record["no_imei"]) if part
    ).strip()
    rows.append(
        "("
        + ",".join(
            [
                quote(nota), quote(record["tanggal"]), quote(record["nama_pelanggan"]),
                quote(record["telp_pelanggan"]), quote(barang), quote(record["kerusakan"]),
                quote(record["kerusakan2"]), quote(record["teknisi"]),
                str(record["jasa"] or "0"), quote(record["status"]),
                quote(record["keterangan_saat_sudah_cek"]),
            ]
        )
        + ")"
    )

if len(rows) != 350:
    raise SystemExit(f"Expected 350 September notes, got {len(rows)}")

sql = """begin;
create temp table legacy_sep(
  no_nota text primary key, tanggal date, nama text, telp text, barang text,
  keluhan text, perbaikan text, teknisi text, biaya numeric, status_lama text, ket text
) on commit drop;
insert into legacy_sep values
""" + ",\n".join(rows) + """;
do $$ begin
  if (select count(*) from legacy_sep) <> 350 then
    raise exception 'Expected 350 September notes, got %', (select count(*) from legacy_sep);
  end if;
end $$;

with admin_profile as (
  select id from public.profiles where lower(nama) = 'admin' limit 1
)
insert into public.service_orders(
  no_nota, tanggal_masuk, customer_nama, customer_telp, barang_nama, keluhan,
  perbaikan, biaya, status, garansi, keterangan, created_by
)
select
  l.no_nota,
  (l.tanggal::timestamp + time '09:00') at time zone 'Asia/Jakarta',
  l.nama, nullif(l.telp, ''), l.barang, nullif(l.keluhan, ''),
  nullif(l.perbaikan, ''), l.biaya,
  case when lower(l.status_lama) like '%ambil%' then 'diambil'::public.service_status else 'masuk'::public.service_status end,
  lower(l.ket) like '%garansi%', 'Sumber dump aplikasi lama September 2026', admin_profile.id
from legacy_sep l cross join admin_profile
where not exists (select 1 from public.service_orders s where s.no_nota = l.no_nota);

-- Technician names come directly from the final old-app snapshot.  Only names
-- that have a current profile are assigned; a blank legacy value stays blank.
update public.service_orders s
set teknisi_id = p.id,
    teknisi_nama_histori = null
from legacy_sep l
join public.profiles p on lower(trim(p.nama)) = lower(trim(l.teknisi))
where s.no_nota = l.no_nota
  and nullif(trim(l.teknisi), '') is not null;

update public.service_orders s
set teknisi_id = null,
    teknisi_nama_histori = null
from legacy_sep l
where s.no_nota = l.no_nota
  and nullif(trim(l.teknisi), '') is null;

commit;

select
  count(*) as total_nota_september,
  count(*) filter (where teknisi_id is null) as belum_ada_teknisi,
  count(*) filter (where teknisi_id is not null) as sudah_ada_teknisi
from public.service_orders
where tanggal_masuk >= timestamptz '2026-09-01 00:00:00+07'
  and tanggal_masuk < timestamptz '2026-10-01 00:00:00+07';
"""

Path(sys.argv[2]).write_text(sql, encoding="utf-8")
print(len(rows))
