"""Generate an audited technician reconciliation from DATASET/2026.txt."""

from __future__ import annotations

import re
import sys
from collections import Counter
from pathlib import Path


source, output = map(Path, sys.argv[1:3])
rows: list[tuple[str, str]] = []
for line in source.read_text(encoding="utf-8-sig").splitlines():
    cells = [cell.strip() for cell in line.split("\t")]
    if len(cells) >= 6 and re.fullmatch(r"SVR-\d{6,}\d{5}", cells[0]):
        rows.append((cells[0], cells[5]))

counts = Counter(name for _, name in rows)
if len(rows) != 3268 or len(set(note for note, _ in rows)) != 3268:
    raise SystemExit("Source must contain exactly 3,268 unique service notes.")


def quoted(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


values = ",\n".join(f"({quoted(note)}, {quoted(name)})" for note, name in rows)
output.write_text(f"""-- Teknisi dari DATASET/2026.txt (Januari--September 2026).
-- Nama yang cocok dengan profil saat ini diisi sebagai teknisi_id.
-- Deril disimpan sebagai histori; nama kosong tidak dipaksa.
begin;

create temp table teknisi_sumber_2026 (
  no_nota text primary key,
  teknisi_nama text not null
) on commit drop;

insert into teknisi_sumber_2026 (no_nota, teknisi_nama) values
{values};

do $$
declare jumlah integer;
declare deril integer;
declare kosong integer;
begin
  select count(*) into jumlah from teknisi_sumber_2026;
  select count(*) into deril from teknisi_sumber_2026 where lower(teknisi_nama) = 'deril';
  select count(*) into kosong from teknisi_sumber_2026 where teknisi_nama = '';
  if jumlah <> 3268 or deril <> 79 or kosong <> 263 then
    raise exception 'Dibatalkan: audit sumber teknisi tidak cocok (nota %, Deril %, kosong %).', jumlah, deril, kosong;
  end if;
end $$;

-- Hanya enam nama yang ada sebagai akun teknisi saat ini yang dipetakan.
update public.service_orders o
set teknisi_id = p.id,
    teknisi_nama_histori = null,
    updated_at = now()
from teknisi_sumber_2026 s
join public.profiles p on lower(trim(p.nama)) = lower(trim(s.teknisi_nama))
where o.no_nota = s.no_nota
  and lower(trim(s.teknisi_nama)) in ('admin', 'agus', 'aris', 'budi', 'irwan', 'reza');

-- Deril tidak memiliki akun aktif, tetapi sumber namanya tetap dipertahankan.
update public.service_orders o
set teknisi_id = null,
    teknisi_nama_histori = 'Deril',
    updated_at = now()
from teknisi_sumber_2026 s
where o.no_nota = s.no_nota
  and lower(trim(s.teknisi_nama)) = 'deril';

do $$
declare belum_ada integer;
declare belum_terpetakan integer;
begin
  select count(*) into belum_ada
  from teknisi_sumber_2026 s
  where not exists (select 1 from public.service_orders o where o.no_nota = s.no_nota);
  select count(*) into belum_terpetakan
  from teknisi_sumber_2026 s
  where lower(trim(s.teknisi_nama)) in ('admin', 'agus', 'aris', 'budi', 'irwan', 'reza')
    and not exists (
      select 1 from public.service_orders o
      join public.profiles p on p.id = o.teknisi_id
      where o.no_nota = s.no_nota and lower(trim(p.nama)) = lower(trim(s.teknisi_nama))
    );
  if belum_ada <> 0 or belum_terpetakan <> 0 then
    raise exception 'Dibatalkan: nota sumber hilang %, teknisi pasti belum terpeta %.', belum_ada, belum_terpetakan;
  end if;
end $$;

commit;
""", encoding="utf-8")
print(f"Wrote {{output}}: {{len(rows)}} notes; {{dict(counts)}}")
