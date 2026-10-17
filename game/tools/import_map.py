#!/usr/bin/env python3
"""Import High Noon's map files to assets/original/maps/high_noon/.

RFC-033 (033f). Writes only assets/original/maps/high_noon/. Deterministic and idempotent: a second run writes nothing,
and an existing .png.import is never touched (it carries the UID).

  python3 tools/import_map.py            # write
  python3 tools/import_map.py --check    # report what would change, write nothing

Source: what the old exporters leave in cache/ (copied byte for byte, so the data are the ones the game read before):
  look/tiles.png   the map's tile index, 256x256, tile id in the R channel   (export_high_noon_look.py)
  look/light.png   the baked light of the ground                              (export_high_noon_look.py)
  high_noon_ntts.json      creatures, structures and sides                    (export_high_noon_ntts.py)
  high_noon_widgets.json   the 720 widgets (plants)                           (export_high_noon_widgets.py)
terrain.res is not made here: tools/import_terrain.gd turns cache/high_noon_terrain.bin into a MapTerrainData
("$GODOT" --headless --path game --script res://tools/import_terrain.gd). Run both once; the result is versioned.

tiles.png and light.png are imported as Image (importer="image": exact pixels, no sRGB, no mipmaps, no compression):
tiles.png is an index and must not go through mipmaps or compression; the game reads both on the CPU.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from import_themes import IMAGE_TEMPLATE  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / "cache"
OUT = ROOT / "assets" / "original" / "maps" / "high_noon"
# destination -> (source, import kind or None)
FILES = {
    "tiles.png": (CACHE / "look" / "tiles.png", "image"),
    "light.png": (CACHE / "look" / "light.png", "image"),
    "ntts.json": (CACHE / "high_noon_ntts.json", None),
    "widgets.json": (CACHE / "high_noon_widgets.json", None),
}


def main() -> None:
    check = "--check" in sys.argv
    written = kept = 0
    for name, (src, kind) in FILES.items():
        data = src.read_bytes()
        path = OUT / name
        if path.exists() and path.read_bytes() == data:
            kept += 1
        else:
            written += 1
            if not check:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
        if kind == "image":
            imp = path.with_name(path.name + ".import")
            if not imp.exists() and not check:
                imp.write_text(IMAGE_TEMPLATE.format(rel=path.relative_to(OUT.parents[1]).as_posix()))
    print("map: %d written, %d unchanged%s" % (written, kept, " [check]" if check else ""))


if __name__ == "__main__":
    main()
