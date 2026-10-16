"""Export one month of legacy MySQL `servis` rows from the newest daily dump."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


def split_values(text: str) -> list[list[str]]:
    rows: list[list[str]] = []
    row: list[str] | None = None
    field: list[str] = []
    quoted = escaped = False
    depth = 0
    for char in text:
        if escaped:
            field.append(char)
            escaped = False
        elif quoted and char == "\\":
            escaped = True
        elif char == '"':
            quoted = not quoted
        elif quoted:
            field.append(char)
        elif char == "(":
            if depth == 0:
                row, field = [], []
            else:
                field.append(char)
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0 and row is not None:
                row.append("".join(field).strip())
                rows.append(row)
                row, field = None, []
            else:
                field.append(char)
        elif char == "," and depth == 1 and row is not None:
            row.append("".join(field).strip())
            field = []
        elif depth:
            field.append(char)
    return rows


def read_servis(path: Path) -> tuple[list[str], list[list[str]]]:
    text = path.read_text(encoding="utf-8", errors="replace")
    create = re.search(r"CREATE TABLE `servis` \((.*?)\);", text, re.S)
    starts = [m.start() for m in re.finditer(r"INSERT INTO servis VALUES ", text)]
    if not create or not starts:
        raise SystemExit(f"Tabel servis tidak ditemukan: {path}")
    columns = re.findall(r"^`([^`]+)`", create.group(1), re.M)
    rows: list[list[str]] = []
    for start in starts:
        end = text.find(";", start)
        if end < 0:
            raise SystemExit(f"INSERT servis tidak lengkap: {path}")
        values = text[text.find("VALUES", start) + len("VALUES") : end]
        rows.extend(split_values(values))
    return columns, rows


root = Path(sys.argv[1])
month = sys.argv[2]  # YYYY-MM
output = Path(sys.argv[3])
suffix = month[5:7]
snapshots = sorted(root.glob(f"*-{suffix}-{month[:4]}_SP4.SQL"))
if not snapshots:
    raise SystemExit(f"Backup {month} tidak ditemukan di {root}")

snapshot = snapshots[-1]
columns, raw_rows = read_servis(snapshot)
date_index = columns.index("tanggal")
selected = {
    row[0]: dict(zip(columns, row))
    for row in raw_rows
    if row and row[0].startswith("SVR-") and len(row) > date_index and row[date_index].startswith(month)
}
output.write_text(json.dumps({"columns": columns, "rows": selected}, ensure_ascii=False), encoding="utf-8")
tech_index = columns.index("teknisi")
print(f"SNAPSHOT {snapshot.name}")
print(f"NOTA {len(selected)}")
print(f"TEKNISI_KOSONG {sum(not record['teknisi'].strip() for record in selected.values())}")
