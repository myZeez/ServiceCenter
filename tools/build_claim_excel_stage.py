"""Build a temporary SQL staging table from the 2026 claim-master workbook."""

from __future__ import annotations

import sys
from datetime import date, datetime
from pathlib import Path

import openpyxl


def text(value: object) -> str:
    if value is None:
        return ""
    if isinstance(value, float) and value.is_integer():
        return str(int(value))
    return str(value).strip()


def quote(value: object) -> str:
    return "'" + text(value).replace("'", "''") + "'"


book = openpyxl.load_workbook(Path(sys.argv[1]), data_only=True, read_only=False)
records: list[tuple[str, str, str, str, str, str, str, str, str, str]] = []

for sheet in book.worksheets:
    headers = [text(cell.value).lower() for cell in sheet[1]]
    if "nama" not in headers or "sn" not in headers:
        continue
    index = {header: headers.index(header) for header in headers if header}
    for row in range(2, sheet.max_row + 1):
        values = [cell.value for cell in sheet[row]]
        tanggal = values[0] if values else None
        if not isinstance(tanggal, (datetime, date)) or tanggal.year != 2026:
            continue
        def get(header: str) -> object:
            position = index.get(header)
            return values[position] if position is not None and position < len(values) else None
        nama, sn = get("nama"), get("sn")
        if not text(nama) or not text(sn):
            continue
        records.append((
            sheet.title, tanggal.date().isoformat(), text(nama), text(get("telp")),
            text(sn), text(get("teknisi")), text(get("keluhan")),
            text(get("no perbaikan")), text(get("status")), text(get("catatan")),
        ))

if len(records) != 573:
    raise SystemExit(f"Expected 573 valid 2026 claims, got {len(records)}")

values_sql = ",\n".join(
    "(" + ",".join(quote(value) for value in record) + ")" for record in records
)
sql = """create temp table claim_excel_2026 (
  brand text, tanggal date, nama text, telp text, sn text, teknisi text,
  keluhan text, no_perbaikan text, status_excel text, catatan text
) on commit drop;
insert into claim_excel_2026 values
""" + values_sql + ";\n"
Path(sys.argv[2]).write_text(sql, encoding="utf-8")
print(len(records))
