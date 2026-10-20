#!/usr/bin/env python3
"""Which models the game can draw without a baked asset (the grey placeholder) or with a borrowed one.

Reads only versioned files: data/catalog (BuildingType components, SpellType structures, CreatureType/WizardType models),
the maps of assets/original/maps (widgets.json, ntts.json),
scenes/map/props/manafount.tscn, the model constants of scenes/, assets/original/models/sizes.json, assets/original/props,
assets/original/textures/index.json and scenes/bodies/models. With SAC_INSTALL set it also names the WAD each missing
model comes from, and lists the spell models of models.wad that nothing in the game references.

  python3 tools/audit/audit_models.py          # the rows that are not "ok", then a count per kind and status
  python3 tools/audit/audit_models.py --all    # every row

Status: ok (own baked model), placeholder (no BodySize or no .glb: MapBuilding draws the capsule), untextured (a .glb
without an entry in textures/index.json), borrowed (drawn with another land's model on purpose), not planted (the model is
imported but the map's layout plants nothing for that widget). Exit 1 when any row is a placeholder or untextured.
"""

import json
import os
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ALL = "--all" in sys.argv

sizes = json.loads((ROOT / "assets/original/models/sizes.json").read_text())
SIZED = set(sizes["props"]) | set(sizes["bodies"])
GLB = {p.stem for p in (ROOT / "assets/original/props").glob("*.glb")}
SKELETAL = {p.stem for p in (ROOT / "scenes/bodies/models").glob("*.tscn")}
TEXTURED = set(json.loads((ROOT / "assets/original/textures/index.json").read_text())["models"])


def field(text: str, name: str) -> str:
    m = re.search(r'^%s = "([^"]*)"' % name, text, re.M)
    return m.group(1) if m else ""


def status(model: str) -> str:
    if model in SKELETAL:
        return "ok"
    if model not in SIZED or model not in GLB:
        return "placeholder"
    return "ok" if model.lower() in TEXTURED else "untextured"


rows = []      # (tag, kind, status, used by)

# Buildings and the god structures (the buildings a spell builds: manaliths, shrines).
structure_tags = set()
for f in sorted((ROOT / "data/catalog/spells").glob("*.tres")):
    m = re.search(r"^structures = PackedStringArray\(([^)]*)\)", f.read_text(), re.M)
    if m:
        structure_tags |= set(re.findall(r'"(\w+)"', m.group(1)))
components = {}
for f in sorted((ROOT / "data/catalog/buildings").glob("*.tres")):
    text = f.read_text()
    tag = field(text, "tag")
    for model in re.findall(r'"(?:tag|destroyed)": "(\w+)"', text):
        components.setdefault(model, set()).add(tag)
for model, users in sorted(components.items()):
    kind = "structure" if users & structure_tags else "building"
    rows.append((model, kind, status(model), " ".join(sorted(users))))

# Creatures and wizards.
for kind in ("creatures", "wizards"):
    for f in sorted((ROOT / "data/catalog" / kind).glob("*.tres")):
        text = f.read_text()
        model = field(text, "model")
        if model:
            rows.append((model, kind[:-1], status(model), field(text, "tag")))

# Models named in code (spells, abilities, props).
for path in sorted((ROOT / "scenes").rglob("*.gd")):
    for model in re.findall(r'(?:MODEL|_model) := "(\w{4})"', path.read_text()):
        rows.append((model, "spell/prop", status(model), str(path.relative_to(ROOT))))

# Plants: the widgets of every imported map. The Flora layer (RFC-054, original_plants.tres: MAP_TAGS) draws each tag with
# the prop of its own name.
for widgets in sorted((ROOT / "assets/original/maps").glob("*/widgets.json")):
    land_map = widgets.parent.name
    for widget in sorted(json.loads(widgets.read_text())):
        rows.append((widget, "plant", status(widget), land_map))

# Manafounts: one scene for every map; each land's own fount model is a BuildingType component (see the buildings above).
fount = field((ROOT / "scenes/map/props/manafount.tscn").read_text(), "model")
for ntts in sorted((ROOT / "assets/original/maps").glob("*/ntts.json")):
    tags = sorted({s["tag"] for s in json.loads(ntts.read_text())["structures"]
                   if s["tag"] in ("jfnt", "cafn", "pfon", "stmf", "font")})
    for tag in tags:
        rows.append((tag, "fount", "ok" if tag == fount else "borrowed " + fount, ntts.parent.name))

sources = {}
unused_spell_models = []
if os.environ.get("SAC_INSTALL"):
    sys.path.insert(0, str(ROOT / "tools/import"))
    from sac_formats import wad  # noqa: E402
    from sac_formats.install import INSTALL  # noqa: E402
    for w in sorted(INSTALL.glob("*.wad")):
        try:
            files, _ = wad.index_wad(w)
        except Exception:     # noqa: BLE001
            continue
        for (name, ext) in files:
            if ext in ("MRMM", "WIDG"):
                sources.setdefault(name, w.name)
    referenced = {r[0] for r in rows}
    for folder in wad.index_folders(INSTALL / "models.wad"):
        m = re.match(r"MODL\.WAD!/(\w+)\.MRMC$", folder)
        if m and m.group(1) not in referenced:
            unused_spell_models.append(m.group(1))

seen = set()
print("%-6s %-10s %-24s %-14s %s" % ("tag", "kind", "status", "source", "used by"))
for tag, kind, state, users in rows:
    if (tag, kind, state, users) in seen or (state == "ok" and not ALL):
        continue
    seen.add((tag, kind, state, users))
    print("%-6s %-10s %-24s %-14s %s" % (tag, kind, state, sources.get(tag, "-"), users[:90]))
counts = Counter((kind, "borrowed" if state.startswith("borrowed") else state) for tag, kind, state, _u in {(r[0], r[1], r[2], "") for r in rows})
print("summary: " + ", ".join("%s %s %d" % (k, s, n) for (k, s), n in sorted(counts.items())))
if unused_spell_models:
    print("models.wad spell models nothing references (not imported): " + " ".join(sorted(unused_spell_models)))
bad = [r for r in rows if r[2] in ("placeholder", "untextured")]
print("MODELS AUDIT %s (%d placeholder or untextured)" % ("PASS" if not bad else "FAIL", len({(r[0], r[1]) for r in bad})))
sys.exit(1 if bad else 0)
