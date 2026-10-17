#!/usr/bin/env python3
"""Import High Noon's map files to assets/original/maps/high_noon/.

RFC-033 (033f, from the .scp in 033h). Writes only assets/original/maps/high_noon/. Deterministic and idempotent: a second run
writes nothing, and an existing .png.import is never touched (it carries the UID).

  python3 tools/import_map.py                    # tiles.png, light.png, ntts.json, widgets.json
  python3 tools/import_map.py --check            # report what would change, write nothing
  python3 tools/import_map.py --out=DIR          # write there instead (to compare with the versioned ones)
  python3 tools/import_map.py --terrain-bin=F    # also write the HNTR mesh bin to F (see below)

Source: "(2) High Noon.scp" of the installation, read with tools/sac_formats:
  TMAP   the map's tile index, 256x256, tile id in the R channel   -> tiles.png
  LMAP   the baked light of the ground                              -> light.png
  NTTS   creatures, structures and widgets, SIDS the sides          -> ntts.json, widgets.json
  HMAP   the height map and cliff walls                             -> HNTR bin -> terrain.res
terrain.res is made in two steps because only Godot writes a Resource: this script builds the HNTR v1 bin (vertices, normals,
indices) at --terrain-bin (a temporary file, not in the repo) and then
  "$GODOT" --headless --path game --script res://tools/import_terrain.gd -- --bin=F
turns it into a MapTerrainData. Run both once; the result is versioned.

tiles.png and light.png are imported as Image (importer="image": exact pixels, no sRGB, no mipmaps, no compression):
tiles.png is an index and must not go through mipmaps or compression; the game reads both on the CPU.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from import_themes import IMAGE_TEMPLATE  # noqa: E402
from sac_formats import png, terrain  # noqa: E402
from sac_formats.install import MAPS  # noqa: E402
from sac_formats.ntts import ntts_json, widgets_json  # noqa: E402
from sac_formats.wad import extract  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
ARGS = {a.split("=", 1)[0]: (a.split("=", 1)[1] if "=" in a else True) for a in sys.argv[1:]}
OUT = Path(ARGS.get("--out", ROOT / "assets" / "original" / "maps" / "high_noon"))
SCP = MAPS / "(2) High Noon.scp"


def files() -> dict:
    """destination -> (bytes, import kind or None)."""
    tmap = extract(SCP, "", "TMAP")
    lmap = extract(SCP, "", "LMAP")
    tiles = bytearray(256 * 256 * 3)
    light = bytearray(256 * 256 * 3)
    for i, tile in enumerate(tmap[512: 512 + 256 * 256]):
        tiles[i * 3: i * 3 + 3] = bytes((tile, tile, tile))
    for i in range(256 * 256):
        light[i * 3: i * 3 + 3] = lmap[i * 4: i * 4 + 3]
    return {
        "tiles.png": (png.encode(256, 256, bytes(tiles), 3, 9), "image"),
        "light.png": (png.encode(256, 256, bytes(light), 3, 9), "image"),
        "ntts.json": (ntts_json(SCP).encode(), None),
        "widgets.json": (widgets_json(SCP).encode(), None),
    }


def main() -> None:
    check = "--check" in ARGS
    written = kept = 0
    for name, (data, kind) in files().items():
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
    if "--terrain-bin" in ARGS:
        Path(ARGS["--terrain-bin"]).write_bytes(terrain.hntr(SCP))
        print("terrain bin written to", ARGS["--terrain-bin"], "(next: import_terrain.gd -- --bin=...)")
    print("map: %d written, %d unchanged%s" % (written, kept, " [check]" if check else ""))


if __name__ == "__main__":
    main()
