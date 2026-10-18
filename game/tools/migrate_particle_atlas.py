#!/usr/bin/env python3
"""One-time migration (RFC-036 036i, A11): ParticleType .tres files swap `atlas_key = "<fx.json key>"` for a
`atlas` Texture2D ext_resource (the `png` of that fx.json entry). fx.json stays a tool-side catalog only.
Run from game/: python3 tools/migrate_particle_atlas.py"""
import json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
catalog = json.loads((ROOT / "assets/original/fx/fx.json").read_text())


def uid_of(png: str) -> str:
    imp = ROOT / (png.replace("res://", "") + ".import")
    m = re.search(r'^uid="(uid://[^"]+)"', imp.read_text(), re.M) if imp.exists() else None
    return m.group(1) if m else ""


done = 0
for tres in sorted((ROOT / "data").rglob("*.tres")) + sorted((ROOT / "scenes").rglob("*.tres")) + sorted((ROOT / "debug").rglob("*.tres")):
    text = tres.read_text()
    m = re.search(r'^atlas_key = "([^"]*)"\n', text, re.M)
    if not m or "particle_type.gd" not in text:
        continue
    png = catalog[m.group(1)]["png"]
    uid = uid_of(png)
    ext_id = "atlas_png"
    uid_part = f' uid="{uid}"' if uid else ""
    ext = f'[ext_resource type="Texture2D"{uid_part} path="{png}" id="{ext_id}"]\n'
    text = text.replace(m.group(0), f'atlas = ExtResource("{ext_id}")\n')
    # insert after the last ext_resource line
    last = list(re.finditer(r'^\[ext_resource [^\n]*\n', text, re.M))[-1]
    text = text[:last.end()] + ext + text[last.end():]
    steps = re.search(r'load_steps=(\d+)', text)
    if steps:
        text = text.replace(steps.group(0), f"load_steps={int(steps.group(1)) + 1}", 1)
    tres.write_text(text)
    done += 1
print("migrated", done)
