"""Parse laporan SVS manual 1--23 September 2026 into audit-friendly JSON.

The report contains two tables per date: outgoing notes first, then incoming
notes. This parser deliberately keeps raw source fields; it makes no technician
assumptions.
"""

from __future__ import annotations

import json
import re
import sys
from collections import Counter
from pathlib import Path


REPORT = Path(sys.argv[1])
OUT = Path(sys.argv[2])
DATE_RE = re.compile(r"LAPORAN PERHARI TGL\s+(\d{2}/09/2026)", re.I)
NOTE_RE = re.compile(r"^\d{5}$")


def clean(value: str) -> str:
    return re.sub(r"\s+", " ", value.replace("\xa0", " ")).strip()


def money(value: str) -> int:
    digits = re.sub(r"\D", "", value)
    return int(digits) if digits else 0


rows: list[dict[str, object]] = []
mode: str | None = None
report_date: str | None = None

for number, source_line in enumerate(REPORT.read_text(encoding="utf-8-sig").splitlines(), start=1):
    line = source_line.replace("\r", "")
    heading = DATE_RE.search(line)
    if heading:
        report_date = heading.group(1)
        mode = None
        continue

    cells = [clean(cell) for cell in line.split("\t")]
    joined = " ".join(cells).upper()
    if "NO NOTA" in joined and "NO HP" in joined:
        mode = "masuk"
        continue
    if "NO NOTA" in joined and "JENIS BARANG" in joined and "PERBAIKAN" in joined:
        mode = "keluar"
        continue
    if not report_date or not mode or not any(cells):
        continue

    cells += [""] * (7 - len(cells))
    if not NOTE_RE.fullmatch(cells[1]):
        continue

    if mode == "masuk":
        if not cells[0] or not cells[3]:
            continue
        rows.append({
            "jenis": "masuk", "tanggal_laporan": report_date, "baris": number,
            "no_nota": cells[1], "customer_nama": cells[0], "customer_telp": cells[2],
            "barang_nama": cells[3], "keluhan": cells[4], "pelunasan_tertulis": cells[5],
        })
    else:
        if not cells[0] or not cells[2] or not cells[3]:
            continue
        rows.append({
            "jenis": "keluar", "tanggal_laporan": report_date, "baris": number,
            "no_nota": cells[1], "customer_nama": cells[0], "barang_nama": cells[2],
            "perbaikan": cells[3], "biaya": money(cells[4]), "tanggal_masuk_tertulis": cells[5],
            "keterangan": cells[6],
        })

counts = Counter(row["jenis"] for row in rows)
duplicates = {
    kind: sorted(note for note, count in Counter(
        row["no_nota"] for row in rows if row["jenis"] == kind
    ).items() if count > 1)
    for kind in ("masuk", "keluar")
}

OUT.write_text(json.dumps({"rows": rows, "counts": counts, "duplicates": duplicates}, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps({"counts": counts, "duplicates": duplicates}, ensure_ascii=False))
