"""Read legacy MySQL `servis` snapshots without importing them."""

from __future__ import annotations

import re
import sys
from collections import Counter
from pathlib import Path


def split_values(text: str) -> list[list[str]]:
    rows: list[list[str]] = []
    row: list[str] | None = None
    field: list[str] = []
    quoted = False
    escaped = False
    depth = 0
    for char in text:
        if escaped:
            field.append(char)
            escaped = False
            continue
        if quoted and char == "\\":
            escaped = True
            continue
        if char == '"':
            quoted = not quoted
            continue
        if quoted:
            field.append(char)
            continue
        if char == "(":
            if depth == 0:
                row, field = [], []
            else:
                field.append(char)
            depth += 1
            continue
        if char == ")":
            depth -= 1
            if depth == 0 and row is not None:
                row.append("".join(field).strip())
                rows.append(row)
                row, field = None, []
            else:
                field.append(char)
            continue
        if char == "," and depth == 1 and row is not None:
            row.append("".join(field).strip())
            field = []
            continue
        if depth:
            field.append(char)
    return rows


def read_snapshot(path: Path) -> tuple[list[str], list[list[str]]]:
    text = path.read_text(encoding="utf-8", errors="replace")
    create = re.search(r"CREATE TABLE `servis` \((.*?)\);", text, re.S)
    insert_starts = [match.start() for match in re.finditer(r"INSERT INTO servis VALUES ", text)]
    if not create or not insert_starts:
        raise ValueError(f"servis table not found: {path.name}")
    columns = re.findall(r"^`([^`]+)`", create.group(1), re.M)
    rows: list[list[str]] = []
    for insert_start in insert_starts:
        end = text.find(";", insert_start)
        if end < 0:
            raise ValueError(f"servis INSERT end not found: {path.name}")
        values = text[text.find("VALUES", insert_start) + len("VALUES"):end]
        rows.extend(split_values(values))
    return columns, rows


root = Path(sys.argv[1])
# September backup is incomplete as a daily series, so use its newest available
# snapshot as the source of truth instead of requiring all 31 calendar days.
available_snapshots = sorted(root.glob("*-09-2026_SP4.SQL"))
if not available_snapshots:
    raise SystemExit("No September snapshot found")
snapshots = [available_snapshots[-1]]

previous: dict[str, tuple[str, ...]] = {}
all_days = []
schema: list[str] | None = None
for snapshot in snapshots:
    columns, rows = read_snapshot(snapshot)
    if schema is None:
        schema = columns
    elif columns != schema:
        raise SystemExit(f"Schema differs: {snapshot.name}")
    current = {row[0]: tuple(row) for row in rows if row and row[0].startswith("SVR-")}
    added = set(current) - set(previous)
    changed = {note for note in set(current) & set(previous) if current[note] != previous[note]}
    all_days.append((snapshot.name[:2], len(current), len(added), len(changed)))
    previous = current

print("COLUMNS", len(schema or []), "|", ", ".join(schema or []))
for day, total, added, changed in all_days:
    print(f"{day}: total={total} baru={added} berubah={changed}")
print("FINAL", len(previous))
if schema:
    tech_index = schema.index("teknisi") if "teknisi" in schema else -1
    if tech_index >= 0:
        print("TEKNISI FINAL", Counter(row[tech_index] for row in previous.values()))

# Optional export: final 2026 rows from the last August snapshot.
if len(sys.argv) > 2 and schema:
    import json
    idx = schema.index('tanggal')
    selected = {
        note: dict(zip(schema, row))
        for note, row in previous.items()
        if len(row) > idx and row[idx].startswith('2026-')
    }
    Path(sys.argv[2]).write_text(json.dumps({'columns': schema, 'rows': selected}, ensure_ascii=False), encoding='utf-8')
    print('EXPORTED_2026', len(selected))
