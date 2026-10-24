#!/usr/bin/env python3
"""Requiere el juego original instalado (SAC_INSTALL). Ver tools/import/local.cfg.example.

Import one multiplayer map of the installation to assets/original/maps/<tag>/ (High Noon without arguments).

RFC-033 (033f, from the .scp in 033h); RFC-050 made the map a parameter. Writes only assets/original/maps/<tag>/. Deterministic and
idempotent: a second run writes nothing, and an existing .png.import is never touched (it carries the UID).

  python3 tools/import/import_map.py                    # High Noon: tiles.png, light.png, ntts.json, widgets.json
  python3 tools/import/import_map.py --map=Peaks        # another map: the name of "(2) Peaks.scp"; the tag is "peaks"
  python3 tools/import/import_map.py --map=WinterWonder # tag "winter_wonder" (camel case is split); --tag=X overrides it
  python3 tools/import/import_map.py --scp="Tutorial/(tu02).scp" --tag=tutorial_valley --native-tiles   # a .scp by path (relative to the maps folder, or absolute)
  python3 tools/import/import_map.py --list             # every .scp of the installation with its player seats, size and content
  python3 tools/import/import_map.py --check            # report what would change, write nothing
  python3 tools/import/import_map.py --out=DIR          # write there instead (to compare with the versioned ones)
  python3 tools/import/import_map.py --terrain-bin=F    # also write the HNTR mesh bin to F (see below)
  python3 tools/import/import_map.py --native-tiles     # also tiles_native.png and atlas_native.png: the map's own tile ids and the tiles it paints (RFC-059b)

The Godot side of a new map (MapDefinition, map.tscn, catalog entry) is tools/import/scaffold_map.py; the whole sequence is in
rfcs/RFC-050-original-maps.md.

Source: "(N) <name>.scp" of the installation, read with tools/import/sac_formats:
  TMAP   the map's tile index, 256x256, tile id in the R channel   -> tiles.png (in James's tile ids: land_themes.map_tiles)
                                                                      -> tiles_native.png (--native-tiles: the ids as stored, of the map's own land)
                                                                      -> atlas_native.png (--native-tiles: the land's MAPTs the map paints, each at its id)
  LMAP   the baked light of the ground                              -> light.png
  NTTS   creatures, structures and widgets, SIDS the sides          -> ntts.json, widgets.json
  HMAP   the height map and cliff walls                             -> HNTR bin -> terrain.res
terrain.res is made in two steps because only Godot writes a Resource: this script builds the HNTR v1 bin (vertices, normals,
indices) at --terrain-bin (a temporary file, not in the repo) and then
  "$GODOT" --headless --path game --script res://tools/bake/import_terrain.gd -- [--map=<tag>] --bin=F
turns it into a MapTerrainData. Run both once; the result is versioned.

tiles.png and light.png are imported as Image (importer="image": exact pixels, no sRGB, no mipmaps, no compression):
tiles.png is an index and must not go through mipmaps or compression; the game reads both on the CPU.
"""

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import land_themes  # noqa: E402
from import_themes import IMAGE_TEMPLATE  # noqa: E402
from import_ui import IMPORT_TEMPLATE  # noqa: E402
from sac_formats import png, terrain, txtr  # noqa: E402
from sac_formats.install import MAPS  # noqa: E402
from sac_formats.ntts import ntts_json, read_entities, read_sides, widgets_json  # noqa: E402
from sac_formats.wad import extract  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
ARGS = {a.split("=", 1)[0]: (a.split("=", 1)[1] if "=" in a else True) for a in sys.argv[1:]}


def find_scp(name: str) -> Path:
    """"High Noon", "(2) High Noon" or "high_noon" -> the .scp of the installation (case and separators ignored)."""
    def key(text: str) -> str:
        return re.sub(r"[^a-z0-9]", "", re.sub(r"^\(\d\)\s*", "", text).lower())
    wanted = key(name)
    found = [p for p in sorted(MAPS.glob("*.scp")) if key(p.stem) == wanted]
    if len(found) != 1:
        sys.exit("import_map: '%s' matches %d maps of %s" % (name, len(found), MAPS))
    return found[0]


def display_name(scp: Path) -> str:
    """"(2) High Noon" -> "High Noon"; "(4) WinterWonder" -> "Winter Wonder"."""
    name = re.sub(r"^\(\d\)\s*", "", scp.stem).replace("'", "")
    return re.sub(r"(?<=[a-z])(?=[A-Z])", " ", name)


def tag_of(scp: Path) -> str:
    return re.sub(r"[^a-z0-9]+", "_", display_name(scp).lower()).strip("_")


def scp_by_path(text: str) -> Path:
    """--scp=PATH: absolute, or relative to the maps folder of the installation (Tutorial/(tu02).scp)."""
    path = Path(text).expanduser()
    path = path if path.is_absolute() else MAPS / path
    if not path.is_file():
        sys.exit("import_map: --scp=%s: no such file" % path)
    return path


SCP = scp_by_path(str(ARGS["--scp"])) if "--scp" in ARGS else find_scp(str(ARGS.get("--map", "High Noon")))
TAG = str(ARGS.get("--tag", tag_of(SCP)))
OUT = Path(ARGS.get("--out", ROOT / "assets" / "original" / "maps" / TAG))


def listing() -> None:
    """Every map of the installation: seats (sides a player takes), land size and what it holds."""
    print("%-24s %-9s %5s %9s %6s %6s  %s" % ("map", "land", "seats", "land cells", "bldgs", "creat", "sides (assignment)"))
    for scp in sorted(MAPS.glob("*.scp")):
        grid = terrain.load_grid(scp)[0]
        cells = sum(1 for row in grid for void in row if not void)
        structures, creatures = read_entities(extract(scp, "", "NTTS"))
        sides = read_sides(extract(scp, "", "SIDS"))
        seats = [s for s in sides if s["assignment"] & 31]
        print("%-24s %-9s %5d %9d %6d %6d  %s" % (scp.stem, land_themes.map_god(scp), len(seats), cells, len(structures),
                                                   len(creatures), [s["assignment"] for s in sides]))


def files() -> dict:
    """destination -> (bytes, import kind or None)."""
    tmap, missed, _ = land_themes.map_tiles(SCP)
    if missed:
        print("import_map: %d cells have a tile with no James equivalent (kept as they are)" % missed, file=sys.stderr)
    lmap = extract(SCP, "", "LMAP")
    tiles = bytearray(256 * 256 * 3)
    light = bytearray(256 * 256 * 3)
    for i, tile in enumerate(tmap):
        tiles[i * 3: i * 3 + 3] = bytes((tile, tile, tile))
    for i in range(256 * 256):
        light[i * 3: i * 3 + 3] = lmap[i * 4: i * 4 + 3]
    out = {
        "tiles.png": (png.encode(256, 256, bytes(tiles), 3, 9), "image"),
        "light.png": (png.encode(256, 256, bytes(light), 3, 9), "lossless"),
        "ntts.json": (ntts_json(SCP).encode(), None),
        "widgets.json": (widgets_json(SCP).encode(), None),
    }
    if "--native-tiles" in ARGS:
        native = bytearray(256 * 256 * 3)
        for i, tile in enumerate(land_themes.native_tiles(SCP)):
            native[i * 3: i * 3 + 3] = bytes((tile, tile, tile))
        out["tiles_native.png"] = (png.encode(256, 256, bytes(native), 3, 9), "lossless")  # a texture: the ground shader reads it
        out["atlas_native.png"] = (txtr.png_bytes(*land_themes.native_atlas(land_themes.map_god(SCP), SCP)), "lossless")
    return out


def main() -> None:
    if "--list" in ARGS:
        listing()
        return
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
        elif kind == "lossless":
            imp = path.with_name(path.name + ".import")
            if not imp.exists() and not check:
                rel = path.relative_to(OUT.parents[1]).as_posix()
                imp.write_text(IMPORT_TEMPLATE.format(rel=rel, mips="false").replace("compress_to=1", "compress_to=0"))
    if "--terrain-bin" in ARGS:
        Path(ARGS["--terrain-bin"]).write_bytes(terrain.hntr(SCP))
        print("terrain bin written to", ARGS["--terrain-bin"], "(next: import_terrain.gd -- --bin=...)")
    print("map: %d written, %d unchanged%s" % (written, kept, " [check]" if check else ""))


if __name__ == "__main__":
    main()
