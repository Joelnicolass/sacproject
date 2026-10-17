#!/usr/bin/env python3
"""Import the original's model textures (bodies, buildings, plants) to assets/original/textures/ as PNG.

RFC-033 (033b). One PNG per unique texture, with the colour key of the model's limb records already applied to the alpha
channel. Writes only assets/original/textures/. Deterministic and idempotent: a second run changes nothing (an existing
.png.import is never touched: it carries the UID).

  python3 tools/import_textures.py            # write
  python3 tools/import_textures.py --check    # report what would change, write nothing

Layout:
  textures/<owner>/<file>.png     bodies: <file> = NNN (the TGA number); props: the OBJ material label (M000, plant)
  textures/index.json             model (lower case) -> label -> {owner, file, cutout}; the label is the OBJ material label
                                  (bodypart003, M000, plant). A texture used by several models is stored once, under the
                                  first one (sorted); every other model points to it.

Source: the files the exporters leave in cache/look (SAXS and TGA of cache/look/bodies from export_bodies.py;
OBJ and PNG of the props from export_persephone.py / export_stats.py). The raw WAD extraction stays in those exporters
until 033h; this step only converts. Run it once; the result is versioned.
"""

import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sac_formats import textures as tx  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
BODIES = ROOT / "cache" / "look" / "bodies"
CATALOG = ROOT / "cache" / "look" / "persephone" / "catalog.json"
OUT = ROOT / "assets" / "original" / "textures"

IMPORT_TEMPLATE = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://assets/original/textures/{rel}"

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""


def body_textures():
    """(model, label, file stem, pixels) for every TGA of every body, chroma applied."""
    for folder in sorted(p for p in BODIES.iterdir() if p.is_dir()):
        model = folder.name
        saxs = folder / (model + ".SAXS")
        keys = tx.chroma_keys(saxs.read_bytes()) if saxs.exists() else {}
        for tga in sorted(folder.glob("*.tga")):
            stem = tga.stem
            label = "bodypart" + stem
            pixels = tx.load_rgb_or_rgba(tga)
            if label in keys:
                pixels = tx.apply_chroma(pixels, keys[label])
            yield model, label, stem, pixels


def obj_labels(obj: Path) -> list:
    seen = []
    for label in re.findall(r"^usemtl (\S*)", obj.read_text(), re.M):
        if label not in seen:
            seen.append(label)
    return seen


def prop_textures():
    """(prop, label, label, pixels) for every building component and plant of the Persephone catalog."""
    catalog = json.loads(CATALOG.read_text())
    items = [(i, False) for i in catalog.get("structures", [])] + [(i, True) for i in catalog.get("plants", [])]
    for item, _plant in sorted(items, key=lambda x: x[0]["name"]):
        name = item["name"]
        obj = ROOT / item["mesh"].replace("res://", "")
        fallback = ROOT / item["texture"].replace("res://", "") if item.get("texture") else None
        for label in obj_labels(obj):
            beside = obj.parent / (label + ".png")
            src = beside if beside.exists() else fallback
            if src is None or not src.exists():
                print("  no texture for", name, label)
                continue
            yield name, label, label, tx.load_rgb_or_rgba(src)


def main() -> None:
    check = "--check" in sys.argv
    owners = {}     # digest -> (owner dir, file stem)
    files = {}      # (owner, stem) -> pixels
    index = {}
    taken = set()   # lower-case owner/stem, to catch two textures spelled alike
    for model, label, stem, pixels in list(body_textures()) + list(prop_textures()):
        key = tx.digest(pixels)
        if key not in owners:
            where = (model, stem)
            low = (model.lower(), stem.lower())
            assert low not in taken, "name clash %s/%s" % where
            taken.add(low)
            owners[key] = where
            files[where] = pixels
        owner, stem_owner = owners[key]
        entry = index.setdefault(model.lower(), {})
        assert label not in entry, (model, label)
        entry[label] = {"owner": owner, "file": stem_owner, "cutout": tx.is_cutout(pixels)}
    written = kept = 0
    for (owner, stem), pixels in sorted(files.items()):
        png = OUT / owner / (stem + ".png")
        data = tx.png_bytes(pixels)
        if png.exists() and png.read_bytes() == data:
            kept += 1
        else:
            written += 1
            if not check:
                png.parent.mkdir(parents=True, exist_ok=True)
                png.write_bytes(data)
        imp = png.with_name(png.name + ".import")
        if not imp.exists() and not check:
            imp.write_text(IMPORT_TEMPLATE.format(rel="%s/%s.png" % (owner, stem)))
    text = json.dumps({"models": index}, indent=1, sort_keys=True) + "\n"
    idx = OUT / "index.json"
    if not (idx.exists() and idx.read_text() == text) and not check:
        OUT.mkdir(parents=True, exist_ok=True)
        idx.write_text(text)
    cutouts = sum(1 for p in files.values() if tx.is_cutout(p))
    print("textures %d unique (%d written, %d unchanged), %d models, %d labels, %d with alpha%s" % (
        len(files), written, kept, len(index), sum(len(v) for v in index.values()), cutouts, " [check]" if check else ""))


if __name__ == "__main__":
    main()
