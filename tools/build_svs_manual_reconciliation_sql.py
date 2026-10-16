"""Build an audited Supabase reconciliation script from parsed SVS manual data."""

from __future__ import annotations

import json
import sys
from datetime import datetime
from pathlib import Path


source = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))["rows"]
destination = Path(sys.argv[2])


def sql(value: object | None) -> str:
    if value is None:
        return "null"
    return "'" + str(value).replace("'", "''") + "'"


def date(value: str) -> str:
    return datetime.strptime(value, "%d/%m/%Y").date().isoformat()


columns = [
    "jenis", "tanggal_laporan", "no_nota", "customer_nama", "customer_telp",
    "barang_nama", "keluhan", "perbaikan", "biaya", "keterangan", "source_row",
]
values: list[str] = []
for row in source:
    record = {
        "jenis": row["jenis"],
        "tanggal_laporan": date(str(row["tanggal_laporan"])),
        "no_nota": row["no_nota"],
        "customer_nama": row.get("customer_nama", ""),
        "customer_telp": row.get("customer_telp", ""),
        "barang_nama": row.get("barang_nama", ""),
        "keluhan": row.get("keluhan", ""),
        "perbaikan": row.get("perbaikan", ""),
        "biaya": row.get("biaya", 0),
        "keterangan": row.get("keterangan", ""),
        "source_row": row["baris"],
    }
    values.append("(" + ", ".join(sql(record[col]) if col not in {"biaya", "source_row"} else str(record[col]) for col in columns) + ")")

script = f"""-- Dibangun dari laporan SVS manual 01--23 September 2026.
-- Teknisi tidak diubah; jika belum dapat dicocokkan, tetap NULL.
begin;

create temp table svs_manual_sep (
  jenis text not null,
  tanggal_laporan date not null,
  no_nota text not null,
  customer_nama text not null,
  customer_telp text,
  barang_nama text not null,
  keluhan text,
  perbaikan text,
  biaya numeric not null,
  keterangan text,
  source_row integer not null
) on commit drop;

insert into svs_manual_sep ({', '.join(columns)}) values
{',\n'.join(values)};

do $$
declare masuk_count integer;
declare keluar_count integer;
begin
  select count(*) into masuk_count from svs_manual_sep where jenis = 'masuk';
  select count(*) into keluar_count from svs_manual_sep where jenis = 'keluar';
  if masuk_count <> 338 or keluar_count <> 333 then
    raise exception 'Dibatalkan: sumber manual berubah (masuk %, keluar %).', masuk_count, keluar_count;
  end if;
end $$;

-- Lengkapi detail nota yang sudah ada dengan laporan penerimaan manual.
update public.service_orders o
set customer_nama = s.customer_nama,
    customer_telp = nullif(s.customer_telp, ''),
    barang_nama = s.barang_nama,
    keluhan = nullif(s.keluhan, ''),
    updated_at = now()
from svs_manual_sep s
where s.jenis = 'masuk'
  and right(o.no_nota, 5) = s.no_nota;

-- Nota masuk yang belum pernah diimpor tetap dimasukkan, tanpa teknisi.
with admin as (
  select p.id from public.profiles p join auth.users u on u.id = p.id
  where u.email = 'admin@cellcom.pky'
)
insert into public.service_orders (
  no_nota, tanggal_masuk, customer_nama, customer_telp, barang_nama, keluhan,
  garansi, status, biaya, teknisi_id, keterangan, created_by
)
select
  'SVR-' || to_char(s.tanggal_laporan, 'DDMMYY') || s.no_nota,
  (s.tanggal_laporan::timestamp + time '09:00') at time zone 'Asia/Jakarta',
  s.customer_nama,
  nullif(s.customer_telp, ''),
  s.barang_nama,
  nullif(s.keluhan, ''),
  false,
  'masuk'::public.service_status,
  0,
  null,
  'Sumber: laporan SVS manual September 2026, baris ' || s.source_row,
  admin.id
from svs_manual_sep s
cross join admin
where s.jenis = 'masuk'
  and not exists (
    select 1 from public.service_orders o where right(o.no_nota, 5) = s.no_nota
  );

-- Sinkronkan nota keluar. Metode pembayaran lama dipertahankan; bila belum
-- ada, gunakan metode historis. Nama teknisi tidak disentuh.
alter table public.service_orders disable trigger user;

update public.service_orders o
set customer_nama = s.customer_nama,
    barang_nama = s.barang_nama,
    perbaikan = s.perbaikan,
    biaya = s.biaya,
    garansi = lower(s.keterangan) like '%garansi%',
    status = case when lower(s.keterangan) like '%cancel%' then 'batal'::public.service_status else 'diambil'::public.service_status end,
    tanggal_selesai = s.tanggal_laporan,
    tanggal_diambil = s.tanggal_laporan,
    tanggal_lunas = case when s.biaya > 0 and lower(s.keterangan) not like '%piutang%' then s.tanggal_laporan else null end,
    cara_bayar = case when s.biaya > 0 and lower(s.keterangan) not like '%piutang%' then coalesce(o.cara_bayar, 'historis') else null end,
    keterangan = case when coalesce(o.keterangan, '') like '%laporan SVS manual September 2026%' then o.keterangan else concat_ws(E'\\n', o.keterangan, 'Sumber: laporan SVS manual September 2026, baris ' || s.source_row) end,
    updated_at = now()
from svs_manual_sep s
where s.jenis = 'keluar'
  and right(o.no_nota, 5) = s.no_nota;

alter table public.service_orders enable trigger user;

do $$
declare masuk_hilang integer;
declare keluar_hilang integer;
begin
  select count(*) into masuk_hilang
  from svs_manual_sep s
  where s.jenis = 'masuk' and not exists (select 1 from public.service_orders o where right(o.no_nota, 5) = s.no_nota);
  select count(*) into keluar_hilang
  from svs_manual_sep s
  where s.jenis = 'keluar' and not exists (select 1 from public.service_orders o where right(o.no_nota, 5) = s.no_nota);
  if masuk_hilang <> 0 or keluar_hilang <> 0 then
    raise exception 'Dibatalkan: setelah sinkronisasi masih hilang masuk %, keluar %.', masuk_hilang, keluar_hilang;
  end if;
end $$;

commit;
"""
destination.write_text(script, encoding="utf-8")
print(f"Wrote {{destination}} with {{len(source)}} source rows")
