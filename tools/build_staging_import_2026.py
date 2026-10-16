"""Build auditable SQL staging rows from the 2026 source CSV files.

This script only writes an SQL import package. It never connects to Supabase.
"""

from __future__ import annotations

import csv
import io
import json
import re
from datetime import date
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATASET = ROOT / "DATASET"
OUTPUT = ROOT / "supabase" / "manual" / "2026_01_09_staging_data.sql"
START = date(2026, 1, 1)
END = date(2026, 9, 30)


def read_text(path: Path) -> str:
    raw = path.read_bytes()
    for encoding in ("utf-8-sig", "utf-8", "cp1252", "latin1"):
        try:
            return raw.decode(encoding)
        except UnicodeDecodeError:
            pass
    raise ValueError(f"Tidak dapat membaca {path}")


def read_rows(path: Path) -> list[list[str]]:
    text = read_text(path)
    delimiter = ";" if text[:8000].count(";") > text[:8000].count(",") else ","
    return [
        row
        for row in csv.reader(io.StringIO(text, newline=""), delimiter=delimiter)
        if any(cell.strip() for cell in row)
    ]


def parse_date(value: str) -> date | None:
    match = re.fullmatch(r"\s*(\d{1,2})/(\d{1,2})/(\d{2,4})\s*", value or "")
    if not match:
        return None
    day, month, year = map(int, match.groups())
    if year < 100:
        year += 2000
    try:
        return date(year, month, day)
    except ValueError:
        return None


def in_scope(value: date | None) -> bool:
    return value is not None and START <= value <= END


def infer_note_date(note: str) -> date | None:
    match = re.search(r"(?:SVR|SRV)-(\d{2})(\d{2})(\d{2})\d+$", note, re.I)
    if not match:
        return None
    day, month, year = map(int, match.groups())
    try:
        return date(2000 + year, month, day)
    except ValueError:
        return None


def parse_money(value: str) -> int:
    digits = re.sub(r"[^0-9]", "", value or "")
    return int(digits) if digits else 0


def value(row: list[str], index: int) -> str:
    return row[index].strip() if index < len(row) else ""


def sql_literal(value: object) -> str:
    if value is None:
        return "null"
    if isinstance(value, date):
        return f"date '{value.isoformat()}'"
    if isinstance(value, (int, float)):
        return str(value)
    return "'" + str(value).replace("'", "''") + "'"


def insert(table: str, columns: list[str], rows: list[dict[str, object]]) -> list[str]:
    statements: list[str] = []
    for row in rows:
        values = ", ".join(sql_literal(row[column]) for column in columns)
        statements.append(f"insert into import_staging.{table} ({', '.join(columns)}) values ({values});")
    return statements


def build_services() -> list[dict[str, object]]:
    source = DATASET / "DATA SERVIS" / "Cellcom Palangka Raya  - Penerimaan Service.csv"
    rows: list[dict[str, object]] = []
    for source_row, row in enumerate(read_rows(source)[1:], start=2):
        note = value(row, 0)
        received = infer_note_date(note)
        if not in_scope(received):
            continue
        raw = {
            "no_nota": note, "nama": value(row, 1), "telp": value(row, 2),
            "barang": value(row, 3), "kerusakan": value(row, 4), "teknisi": value(row, 5),
            "tgl_selesai": value(row, 6), "biaya": value(row, 7),
            "keterangan": value(row, 10), "status": value(row, 11),
        }
        rows.append({
            "source_file": str(source.relative_to(ROOT)).replace("\\", "/"),
            "source_row": source_row, "no_nota_raw": note, "tanggal_masuk_inferred": received,
            "customer_nama": raw["nama"], "customer_telp": raw["telp"], "barang_nama": raw["barang"],
            "keluhan": raw["kerusakan"], "teknisi_nama": raw["teknisi"],
            "tanggal_selesai_raw": raw["tgl_selesai"], "biaya_raw": raw["biaya"],
            "status_raw": raw["status"], "raw_data": json.dumps(raw, ensure_ascii=False),
        })
    return rows


def build_settlements() -> list[dict[str, object]]:
    source = DATASET / "DATA SERVIS" / "Cellcom Palangka Raya  - Pelunasan Service.csv"
    current_date: date | None = None
    rows: list[dict[str, object]] = []
    for source_row, row in enumerate(read_rows(source)[1:], start=2):
        explicit_date = parse_date(value(row, 0))
        if explicit_date:
            current_date = explicit_date
        note = value(row, 1)
        if not in_scope(current_date) or not note:
            continue
        raw = {"tanggal_display": value(row, 0), "no_nota": note, "nama": value(row, 2),
               "barang": value(row, 3), "kerusakan": value(row, 4), "perbaikan": value(row, 5),
               "teknisi": value(row, 6), "biaya": value(row, 7)}
        rows.append({
            "source_file": str(source.relative_to(ROOT)).replace("\\", "/"),
            "source_row": source_row, "tanggal_lunas": current_date, "no_nota_raw": note,
            "customer_nama": raw["nama"], "barang_nama": raw["barang"], "keluhan": raw["kerusakan"],
            "perbaikan": raw["perbaikan"], "teknisi_nama": raw["teknisi"], "biaya": parse_money(raw["biaya"]),
            "raw_data": json.dumps(raw, ensure_ascii=False),
        })
    return rows


def build_claims() -> list[dict[str, object]]:
    result: list[dict[str, object]] = []
    for source in sorted(DATASET.glob("SERVICE CLAIM*.csv")):
        lenovo = "LENOVO" in source.name
        columns = {"sn": 4 if lenovo else 3, "teknisi": 5 if lenovo else 4,
                   "keluhan": 6 if lenovo else 5, "perbaikan": 7 if lenovo else 6,
                   "part": 8 if lenovo else 7, "status": 9 if lenovo else 8,
                   "catatan": 10 if lenovo else 9}
        brand = source.stem.split(" - ")[-1]
        for source_row, row in enumerate(read_rows(source)[1:], start=2):
            claim_date = parse_date(value(row, 0))
            if not in_scope(claim_date):
                continue
            raw = {"tanggal": value(row, 0), "nama": value(row, 1), "telp": value(row, 2),
                   "sn": value(row, columns["sn"]), "teknisi": value(row, columns["teknisi"]),
                   "keluhan": value(row, columns["keluhan"]), "no_perbaikan": value(row, columns["perbaikan"]),
                   "claim_part": value(row, columns["part"]), "status": value(row, columns["status"]),
                   "catatan": value(row, columns["catatan"])}
            result.append({
                "source_file": str(source.relative_to(ROOT)).replace("\\", "/"), "source_row": source_row,
                "brand": brand, "tanggal": claim_date, "customer_nama": raw["nama"],
                "customer_telp": raw["telp"], "serial_number": raw["sn"], "teknisi_nama": raw["teknisi"],
                "keluhan": raw["keluhan"], "no_perbaikan": raw["no_perbaikan"],
                "claim_part_raw": raw["claim_part"], "status_raw": raw["status"], "catatan": raw["catatan"],
                "raw_data": json.dumps(raw, ensure_ascii=False),
            })
    return result


def build_shipments() -> list[dict[str, object]]:
    source = DATASET / "DATA SERVIS" / "Cellcom Palangka Raya  - Kirim-Kirim.csv"
    result: list[dict[str, object]] = []
    for source_row, row in enumerate(read_rows(source)[1:], start=2):
        sent = parse_date(value(row, 0))
        if not in_scope(sent):
            continue
        raw = {"tanggal_kirim": value(row, 0), "dari": value(row, 1), "ke": value(row, 2),
               "nama": value(row, 3), "barang": value(row, 4), "sn": value(row, 5),
               "keluhan": value(row, 6), "kelengkapan": value(row, 7), "status": value(row, 8),
               "tanggal_kembali": value(row, 9), "keterangan": value(row, 10)}
        result.append({
            "source_file": str(source.relative_to(ROOT)).replace("\\", "/"), "source_row": source_row,
            "tanggal_kirim": sent, "dari_cabang": raw["dari"], "ke_cabang": raw["ke"],
            "user_nama": raw["nama"], "barang_nama": raw["barang"], "serial_number": raw["sn"],
            "keluhan": raw["keluhan"], "kelengkapan": raw["kelengkapan"], "status_raw": raw["status"],
            "tanggal_kembali": parse_date(raw["tanggal_kembali"]), "keterangan_raw": raw["keterangan"],
            "raw_data": json.dumps(raw, ensure_ascii=False),
        })
    return result


def main() -> None:
    services = build_services()
    settlements = build_settlements()
    claims = build_claims()
    shipments = build_shipments()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "-- Generated from DATASET. Do not edit manually.", "begin;",
        "delete from import_staging.shipment_rows_2026;",
        "delete from import_staging.claim_rows_2026;",
        "delete from import_staging.settlement_rows_2026;",
        "delete from import_staging.service_rows_2026;",
    ]
    lines += insert("service_rows_2026", [
        "source_file", "source_row", "no_nota_raw", "tanggal_masuk_inferred", "customer_nama", "customer_telp",
        "barang_nama", "keluhan", "teknisi_nama", "tanggal_selesai_raw", "biaya_raw", "status_raw", "raw_data"], services)
    lines += insert("settlement_rows_2026", [
        "source_file", "source_row", "tanggal_lunas", "no_nota_raw", "customer_nama", "barang_nama", "keluhan",
        "perbaikan", "teknisi_nama", "biaya", "raw_data"], settlements)
    lines += insert("claim_rows_2026", [
        "source_file", "source_row", "brand", "tanggal", "customer_nama", "customer_telp", "serial_number",
        "teknisi_nama", "keluhan", "no_perbaikan", "claim_part_raw", "status_raw", "catatan", "raw_data"], claims)
    lines += insert("shipment_rows_2026", [
        "source_file", "source_row", "tanggal_kirim", "dari_cabang", "ke_cabang", "user_nama", "barang_nama",
        "serial_number", "keluhan", "kelengkapan", "status_raw", "tanggal_kembali", "keterangan_raw", "raw_data"], shipments)
    lines += ["commit;", ""]
    OUTPUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"{OUTPUT}: services={len(services)}, settlements={len(settlements)}, claims={len(claims)}, shipments={len(shipments)}")


if __name__ == "__main__":
    main()

