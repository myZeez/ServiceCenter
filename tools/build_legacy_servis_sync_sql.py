#!/usr/bin/env python3
"""Build a repeatable, conservative SQL reconciliation from a legacy servis dump.

The legacy daily backup is authoritative for notes which have not been migrated and
for technician assignment. It is not authoritative for historical settlements: its payment column is a default
``CASH`` and its settlement date is blank.  Consequently the generated migration
preserves settlement/guarantee fields on existing notes, and applies them only to
notes which do not yet exist in the new database.
"""

from __future__ import annotations

import json
import sys
from datetime import date
from pathlib import Path


def sql_text(value: object | None) -> str:
    if value is None:
        return "null"
    return "'" + str(value).replace("'", "''") + "'"


def clean(value: object | None) -> str | None:
    text = str(value or "").strip()
    return text or None


def technician(value: object | None) -> str | None:
    name = clean(value)
    if not name:
        return None
    # Typo in the 12 October legacy backup.  September's current technician list
    # uses Aris, and there is no technician named "Airs".
    return "Aris" if name.upper() == "AIRS" else name.title()


def complaint(row: dict[str, object]) -> str | None:
    parts = [clean(row.get(key)) for key in ("kerusakan", "kerusakan2", "kerusakan3")]
    return " & ".join(part for part in parts if part) or None


def amount(value: object | None) -> str:
    try:
        return str(int(float(str(value or "0").replace(",", ""))))
    except ValueError as error:
        raise ValueError(f"Nominal tidak valid: {value!r}") from error


def sequence(no_nota: str) -> int:
    return int(no_nota[-5:])


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("pakai: build_legacy_servis_sync_sql.py sumber.json hasil.sql")

    source, destination = map(Path, sys.argv[1:])
    raw = json.loads(source.read_text(encoding="utf-8"))
    rows = list(raw["rows"].values())
    rows.sort(key=lambda row: sequence(str(row["kode"])))

    if not rows:
        raise SystemExit("Tidak ada nota pada sumber.")
    if len({sequence(str(row["kode"])) for row in rows}) != len(rows):
        raise SystemExit("Nomor urut ganda ditemukan pada sumber; dibatalkan.")

    normalized = []
    for row in rows:
        no_nota = clean(row.get("kode"))
        incoming = clean(row.get("tanggal"))
        if not no_nota or not incoming:
            raise SystemExit(f"Nota/tanggal kosong: {row!r}")
        date.fromisoformat(incoming)
        picked_date = clean(row.get("tanggal_kembali"))
        if picked_date == "1899-12-30":
            picked_date = None
        if picked_date:
            date.fromisoformat(picked_date)
        is_picked = str(row.get("sudahdiambil", "")).lower() == "true"
        normalized.append({
            "no_nota": no_nota,
            "urut": sequence(no_nota),
            "tanggal_masuk": incoming,
            "nama": clean(row.get("nama_pelanggan")),
            "telp": clean(row.get("telp_pelanggan")),
            "barang": clean(row.get("barang")),
            "type": clean(row.get("type")),
            "sn": clean(row.get("no_imei")),
            "keluhan": complaint(row),
            "kelengkapan": clean(row.get("kelengkapan")),
            "teknisi": technician(row.get("teknisi")),
            "status": "diambil" if is_picked else "masuk",
            "biaya": amount(row.get("jumlah")),
            "tanggal_keluar": picked_date if is_picked else None,
            "waktu_keluar": clean(row.get("jamkembali")) if is_picked else None,
        })

    values = []
    for row in normalized:
        values.append(
            "  ("
            + ", ".join(
                [
                    sql_text(row["no_nota"]), str(row["urut"]), sql_text(row["tanggal_masuk"]),
                    sql_text(row["nama"]), sql_text(row["telp"]), sql_text(row["barang"]),
                    sql_text(row["type"]), sql_text(row["sn"]), sql_text(row["keluhan"]),
                    sql_text(row["kelengkapan"]), sql_text(row["teknisi"]), sql_text(row["status"]),
                    row["biaya"], sql_text(row["tanggal_keluar"]), sql_text(row["waktu_keluar"]),
                ]
            )
            + ")"
        )

    sql = f"""-- =====================================================================
-- SINKRONISASI BACKUP APLIKASI LAMA: OKTOBER 2026 s.d. 12 OKTOBER
-- Sumber: DATASET/October/12-10-2026_SP4.SQL (snapshot terakhir)
--
-- Memuat {len(normalized)} nota (urut {normalized[0]['urut']}--{normalized[-1]['urut']}).
-- Backup lama dipakai untuk nota yang belum ada dan penugasan teknisi.
-- Kolom pelunasan/garansi nota lama yang sudah ada TIDAK disentuh karena backup
-- menyimpan semua pembayaran sebagai CASH dan tanggal bayar kosong.
-- Nota yang belum ada (12 Oktober) dibuat dengan status dari snapshot.
-- Aman dijalankan ulang; akan berhenti bila nomor urut di database ambigu.
-- =====================================================================

do $validasi$
declare
  ambigu text;
  teknisi_hilang text;
begin
  with sumber(no_nota, urut, tanggal_masuk, nama, telp, barang, type_barang, sn,
              keluhan, kelengkapan, teknisi, status, biaya, tanggal_keluar, waktu_keluar) as (
    values
{',\n'.join(values)}
  )
  select string_agg(s.urut::text, ', ' order by s.urut) into ambigu
  from sumber s
  where (select count(*) from service_orders o where urut_no_nota(o.no_nota) = s.urut) > 1;

  if ambigu is not null then
    raise exception 'Sinkron Oktober dibatalkan: nomor urut ganda di database: %', ambigu;
  end if;

  with sumber(no_nota, urut, tanggal_masuk, nama, telp, barang, type_barang, sn,
              keluhan, kelengkapan, teknisi, status, biaya, tanggal_keluar, waktu_keluar) as (
    values
{',\n'.join(values)}
  )
  select string_agg(distinct s.teknisi, ', ' order by s.teknisi) into teknisi_hilang
  from sumber s
  where s.teknisi is not null
    and not exists (select 1 from profiles p where lower(p.nama) = lower(s.teknisi));

  if teknisi_hilang is not null then
    raise exception 'Sinkron Oktober dibatalkan: teknisi tidak ditemukan: %', teknisi_hilang;
  end if;
end
$validasi$;

with sumber(no_nota, urut, tanggal_masuk, nama, telp, barang, type_barang, sn,
            keluhan, kelengkapan, teknisi, status, biaya, tanggal_keluar, waktu_keluar) as (
  values
{',\n'.join(values)}
)
insert into service_orders (
  no_nota, tanggal_masuk, customer_nama, customer_telp, barang_nama, barang_type,
  barang_sn, keluhan, kelengkapan, teknisi_id, status, biaya, tanggal_selesai,
  tanggal_diambil, waktu_diambil, cara_bayar, tanggal_lunas, waktu_lunas, created_by
)
select s.no_nota,
       (s.tanggal_masuk || ' 00:00:00+07')::timestamptz,
       s.nama, s.telp, s.barang, s.type_barang, s.sn, s.keluhan, s.kelengkapan,
       (select p.id from profiles p where lower(p.nama) = lower(s.teknisi) limit 1),
       s.status::service_status,
       s.biaya,
       s.tanggal_keluar::date,
       s.tanggal_keluar::date,
       case when s.waktu_keluar is not null
            then (s.tanggal_keluar || ' ' || s.waktu_keluar || '+07')::timestamptz
            else null end,
       case when s.biaya > 0 then 'cash' else null end,
       case when s.biaya > 0 then s.tanggal_keluar::date else null end,
       case when s.biaya > 0 and s.waktu_keluar is not null
            then (s.tanggal_keluar || ' ' || s.waktu_keluar || '+07')::timestamptz
            else null end,
       (select p.id from profiles p where lower(p.nama) = 'admin' limit 1)
from sumber s
where not exists (
  select 1 from service_orders o where urut_no_nota(o.no_nota) = s.urut
);

do $tunggal$
declare tidak_tunggal text;
begin
  with sumber(no_nota, urut, tanggal_masuk, nama, telp, barang, type_barang, sn,
              keluhan, kelengkapan, teknisi, status, biaya, tanggal_keluar, waktu_keluar) as (
    values
{',\n'.join(values)}
  )
  select string_agg(s.urut::text, ', ' order by s.urut) into tidak_tunggal
  from sumber s
  where (select count(*) from service_orders o where urut_no_nota(o.no_nota) = s.urut) <> 1;

  if tidak_tunggal is not null then
    raise exception 'Sinkron Oktober dibatalkan: nota tidak tunggal setelah insert: %', tidak_tunggal;
  end if;
end
$tunggal$;

-- Laporan SVS 1--11 sudah merupakan sumber yang lebih lengkap untuk identitas,
-- status, biaya, pelunasan, dan garansi. Pada nota yang sudah ada, hanya
-- penugasan teknisi dari backup aplikasi lama yang disinkronkan.
with sumber(no_nota, urut, tanggal_masuk, nama, telp, barang, type_barang, sn,
            keluhan, kelengkapan, teknisi, status, biaya, tanggal_keluar, waktu_keluar) as (
  values
{',\n'.join(values)}
)
update service_orders o
set teknisi_id = (select p.id from profiles p where lower(p.nama) = lower(s.teknisi) limit 1)
from sumber s
where urut_no_nota(o.no_nota) = s.urut
  and o.teknisi_id is distinct from
      (select p.id from profiles p where lower(p.nama) = lower(s.teknisi) limit 1);
"""
    destination.write_text(sql, encoding="utf-8")
    print(f"{destination}: {len(normalized)} nota")


if __name__ == "__main__":
    main()
