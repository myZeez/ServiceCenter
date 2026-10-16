"""Generate an idempotent import for one exported legacy `servis` month."""

from __future__ import annotations

import json
import sys
from pathlib import Path


def quote(value: object) -> str:
    return "'" + str(value or "").replace("'", "''") + "'"


input_path = Path(sys.argv[1])
month = sys.argv[2]
output_path = Path(sys.argv[3])
source = json.loads(input_path.read_text(encoding="utf-8"))["rows"]
records = [(nota, row) for nota, row in source.items() if row["tanggal"].startswith(month)]
if not records:
    raise SystemExit(f"Tidak ada nota untuk {month}")

values = []
for nota, row in records:
    barang = " ".join(part for part in (row["barang"], row["type"], row["no_imei"]) if part).strip()
    values.append(
        "("
        + ",".join(
            [
                quote(nota), quote(row["tanggal"]), quote(row["nama_pelanggan"]),
                quote(row["telp_pelanggan"]), quote(barang), quote(row["kerusakan"]),
                quote(row["kerusakan2"]), quote(row["teknisi"]), str(row["jasa"] or "0"),
                quote(row["status"]), quote(row["keterangan_saat_sudah_cek"]),
            ]
        )
        + ")"
    )

year, mon = month.split("-")
next_month = f"{year}-{int(mon) + 1:02d}-01" if mon != "12" else f"{int(year) + 1}-01-01"
count = len(values)
sql = f"""begin;
create temp table legacy_month (
  no_nota text primary key, tanggal date, nama text, telp text, barang text,
  keluhan text, perbaikan text, teknisi text, biaya numeric, status_lama text, ket text
) on commit drop;
insert into legacy_month values
""" + ",\n".join(values) + f""";

do $$ begin
  if (select count(*) from legacy_month) <> {count} then
    raise exception 'Audit staging gagal: expected {count}, got %', (select count(*) from legacy_month);
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
  lower(l.ket) like '%garansi%', 'Sumber dump aplikasi lama {month}', a.id
from legacy_month l cross join admin_profile a
where not exists (select 1 from public.service_orders s where s.no_nota = l.no_nota);

-- Sync only the technician identity from the old-app month.  A non-current
-- technician name is retained as historical text, while genuinely blank data stays blank.
update public.service_orders s
set teknisi_id = p.id,
    teknisi_nama_histori = null
from legacy_month l
join public.profiles p on lower(trim(p.nama)) = lower(trim(l.teknisi))
where s.no_nota = l.no_nota
  and nullif(trim(l.teknisi), '') is not null;

update public.service_orders s
set teknisi_id = null,
    teknisi_nama_histori = trim(l.teknisi)
from legacy_month l
where s.no_nota = l.no_nota
  and nullif(trim(l.teknisi), '') is not null
  and not exists (
    select 1 from public.profiles p where lower(trim(p.nama)) = lower(trim(l.teknisi))
  );

update public.service_orders s
set teknisi_id = null,
    teknisi_nama_histori = null
from legacy_month l
where s.no_nota = l.no_nota
  and nullif(trim(l.teknisi), '') is null;

select
  (select count(*) from legacy_month) as sumber_nota,
  count(*) as nota_tercatat,
  count(*) filter (where s.teknisi_id is null and s.teknisi_nama_histori is null) as sumber_teknisi_kosong
from public.service_orders s
where s.no_nota in (select no_nota from legacy_month);

commit;
"""
output_path.write_text(sql, encoding="utf-8")
print(count)
