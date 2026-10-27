#!/usr/bin/env python3
"""055x: rewrite FX named by text in .tscn / .tres files into typed ExtResource references.

    campo = "nombre"   ->   campo = ExtResource("fx_nombre")   (+ the [ext_resource] line and load_steps)

A value is rewritten only when the property name looks like an FX field (default: a name containing fx, burst, puff, effect, dust, spark
or look) AND the text names a file that exists: data/fx/<value>.tres (a burst), data/fx/beams/<value>.tres (a beam, with --beams) or, for a
value that starts with res:// and ends in .tscn, that scene (with --scenes). Anything else is reported and left alone.

Each sub-cut (x2..x5) runs it on its own folders (--dirs), so two cuts never touch the same file (R7). The GDScript side (`@export var
x_fx := "name"` defaults, `FxBus.broadcast("name", ...)`) is the developer's: this tool only moves the data.

Usage (from game/):
    python3 tools/migrate/fx_refs_055x.py --dry-run --dirs scenes/spells/actions scenes/spells/wards
    python3 tools/migrate/fx_refs_055x.py --dirs scenes/units --fields look_fx,fire_fx
"""
import argparse
import os
import re
import sys

GAME = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DEFAULT_NAME = re.compile(r"(fx|burst|puff|effect|dust|spark|look)", re.I)
LINE = re.compile(r'^(?P<field>[A-Za-z_][A-Za-z0-9_]*) = &?"(?P<value>[^"\n]*)"\s*$')
EXT = re.compile(r'^\[ext_resource [^\]]*path="(?P<path>[^"]+)"[^\]]*id="(?P<id>[^"]+)"')
STEPS = re.compile(r"(\[gd_(?:scene|resource)[^\]]*load_steps=)(\d+)")


def target_of(value, beams, scenes):
    """The res:// path the text names, or None."""
    if not value:
        return None
    if value.startswith("res://"):
        ok = scenes and value.endswith(".tscn") and os.path.exists(os.path.join(GAME, value[6:]))
        return value if ok else None
    path = os.path.join(GAME, "data", "fx", value + ".tres")
    if os.path.exists(path):
        return "res://data/fx/" + value + ".tres"
    if beams and os.path.exists(os.path.join(GAME, "data", "fx", "beams", value + ".tres")):
        return "res://data/fx/beams/" + value + ".tres"
    return None


def id_for(path):
    return "fx_" + re.sub(r"[^a-z0-9]+", "_", os.path.basename(path).rsplit(".", 1)[0].lower())


def rewrite(text, fields, beams, scenes):
    """Returns (new_text, [(field, value, path)], [(field, value)] left alone)."""
    lines = text.split("\n")
    known = {}
    last_ext = -1
    for i, line in enumerate(lines):
        match = EXT.match(line)
        if match:
            known[match.group("path")] = match.group("id")
            last_ext = i
    done, skipped, added = [], [], []
    for i, line in enumerate(lines):
        match = LINE.match(line)
        if not match:
            continue
        field, value = match.group("field"), match.group("value")
        wanted = field in fields if fields else bool(DEFAULT_NAME.search(field))
        if not wanted:
            continue
        path = target_of(value, beams, scenes)
        if path is None:
            if value:
                skipped.append((field, value))
            continue
        ident = known.get(path)
        if ident is None:
            ident = id_for(path)
            kind = "PackedScene" if path.endswith(".tscn") else "Resource"
            added.append('[ext_resource type="%s" path="%s" id="%s"]' % (kind, path, ident))
            known[path] = ident
        lines[i] = '%s = ExtResource("%s")' % (field, ident)
        done.append((field, value, path))
    if added:
        at = last_ext + 1 if last_ext >= 0 else 1
        lines[at:at] = added if last_ext >= 0 else added + [""]
    out = "\n".join(lines)
    if added:
        out = STEPS.sub(lambda m: m.group(1) + str(int(m.group(2)) + len(added)), out, count=1)
    return out, done, skipped


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dirs", nargs="+", default=["scenes"], help="folders under game/ to scan (default: scenes)")
    parser.add_argument("--fields", default="", help="comma list of property names; default: any name with fx/burst/puff/effect/dust/spark/look")
    parser.add_argument("--beams", action="store_true", help="also resolve data/fx/beams/<name>.tres")
    parser.add_argument("--scenes", action="store_true", help="also resolve res://....tscn values")
    parser.add_argument("--dry-run", action="store_true", help="print what would change and write nothing")
    args = parser.parse_args()
    fields = {f for f in args.fields.split(",") if f}
    changed = 0
    left = 0
    for folder in args.dirs:
        for root, _dirs, files in os.walk(os.path.join(GAME, folder)):
            for name in sorted(files):
                if not name.endswith((".tscn", ".tres")):
                    continue
                path = os.path.join(root, name)
                with open(path, encoding="utf-8") as handle:
                    text = handle.read()
                out, done, skipped = rewrite(text, fields, args.beams, args.scenes)
                rel = os.path.relpath(path, GAME)
                for field, value in skipped:
                    left += 1
                    print("LEFT  %s: %s = \"%s\" (no file with that name)" % (rel, field, value))
                if not done:
                    continue
                changed += 1
                for field, value, target in done:
                    print("%s %s: %s = \"%s\" -> %s" % ("WOULD" if args.dry_run else "DONE ", rel, field, value, target))
                if not args.dry_run:
                    with open(path, "w", encoding="utf-8") as handle:
                        handle.write(out)
    print("%s %d file(s), %d value(s) left as text" % ("would change" if args.dry_run else "changed", changed, left))
    return 0


if __name__ == "__main__":
    sys.exit(main())
