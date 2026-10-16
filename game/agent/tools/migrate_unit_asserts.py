#!/usr/bin/env python3
"""RFC-025b: flows that read the old `%Unit` label of the HUD now read `%SelectionRoster`.

    python3 agent/tools/migrate_unit_asserts.py [flows_dir] [--dry-run]

Rewrites, in place and keeping each file's layout (one-line or pretty):
    visible false                 -> prop count, equals 0
    visible true                  -> prop count, gte 1
    text_equals "N unidades"      -> prop count, equals N
    text_equals "Trogg 960/960"   -> prop summary, equals "..."
    text_contains "Manahoar"      -> prop summary, contains "Manahoar"
    print prop text               -> print prop summary
    print prop visible            -> print prop count
`timeout` and any other key stay. `summary` is the roster's undrawn text («Trogg 960/960» for
one creature, «N unidades» otherwise). Running it twice changes nothing.
"""
import json
import re
import sys
from pathlib import Path

OBJECT = re.compile(r'\{[^{}]*"node"\s*:\s*"%Unit"[^{}]*\}')
ROSTER = "%SelectionRoster"


def convert(spec: dict) -> dict:
    out = {"node": ROSTER}
    for key, value in spec.items():
        if key == "node":
            continue
        if key == "visible":
            out["prop"] = "count"
            if value:
                out["gte"] = 1
            else:
                out["equals"] = 0
        elif key == "text_equals":
            found = re.fullmatch(r"(\d+) unidades", str(value))
            if found:
                out["prop"] = "count"
                out["equals"] = int(found.group(1))
            else:
                out["prop"] = "summary"
                out["equals"] = value
        elif key == "text_contains":
            out["prop"] = "summary"
            out["contains"] = value
        elif key == "prop":
            out["prop"] = {"text": "summary", "visible": "count"}.get(value, value)
        else:
            out[key] = value
    return out


def render(original: str, spec: dict) -> str:
    items = [f'"{key}": {json.dumps(value, ensure_ascii=False)}' for key, value in spec.items()]
    if "\n" not in original:
        return "{ " + ", ".join(items) + " }"
    key_indent = re.search(r'\n([ \t]*)"node"', original).group(1)
    close_indent = re.search(r'\n([ \t]*)\}$', original).group(1)
    body = ",\n".join(key_indent + item for item in items)
    return "{\n" + body + "\n" + close_indent + "}"


def migrate(path: Path, dry: bool) -> int:
    text = path.read_text(encoding="utf-8")
    hits = 0

    def swap(match: re.Match) -> str:
        nonlocal hits
        hits += 1
        return render(match.group(0), convert(json.loads(match.group(0))))

    new = OBJECT.sub(swap, text)
    if hits:
        json.loads(new)  # never leave a broken flow behind
        if not dry:
            path.write_text(new, encoding="utf-8")
    return hits


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    folder = Path(args[0]) if args else Path(__file__).resolve().parent.parent / "flows"
    dry = "--dry-run" in sys.argv
    files = changed = total = 0
    for path in sorted(folder.glob("*.json")):
        files += 1
        hits = migrate(path, dry)
        if hits:
            changed += 1
            total += hits
            print(f"{path.name}: {hits}")
    print(f"{files} flows, {changed} migrated, {total} asserts/prints rewritten" + (" (dry run)" if dry else ""))


if __name__ == "__main__":
    main()
