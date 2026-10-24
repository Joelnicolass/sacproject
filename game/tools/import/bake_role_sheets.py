"""Requiere el juego original instalado (SAC_INSTALL). Ver tools/import/local.cfg.example.

Bakes the ground role sheets of a god: assets/original/themes/<god>/roles/<role>.png and <role>_detail.png.

A role sheet is what one ground role (open, earth, rock, path) of the god looks like: the base tiles of the land's MAPG groups that
play that role (tools/import/ground_roles_table.json, verified rows only), laid out as a 4x4 grid of 64x64 tiles (256x256 px,
64 px = one 10 m cell). A group with fewer than 16 tiles repeats them in order, so a tile used twice weighs twice. The ground
shader (scenes/look/ground/ground.gdshader) picks one of the 16 cells per 10 m map cell. The detail sheet is the grey grain
layer (DTnn) the group lays over its tiles in the original, 256x256, stretched over one cell.

  SAC_INSTALL=/path/to/Sacrifice/data python3 -I tools/import/bake_role_sheets.py [--god=persephone] [--check]

--check writes nothing and prints what it would write. Prints, per role, the groups, the tiles and the mean RGB of the sheet.
Ref: sacmap.d:196-206 (DT layer per MAPG group), maps.d:65 loadDTIndex (byte 55 = DT layer).
"""

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import land_themes as lands  # noqa: E402  (exits with a message when the original is not installed)
from sac_formats.txtr import folder_texture  # noqa: E402

ROLES = ("open", "earth", "rock", "path")
TABLE = Path(__file__).resolve().parent / "ground_roles_table.json"
THEMES = Path(__file__).resolve().parents[2] / "assets" / "original" / "themes"
TILE_PX = 64
GRID = 4
ARGS = {a.split("=", 1)[0]: (a.split("=", 1)[1] if "=" in a else True) for a in sys.argv[1:]}


def role_groups(god: str) -> dict:
    """role -> [MAPG group numbers] from the table, verified rows only, in group order."""
    entry = json.loads(TABLE.read_text())["lands"].get(god)
    if entry is None:
        sys.exit("bake_role_sheets: ground_roles_table.json has no land '%s'" % god)
    out = {role: [] for role in ROLES}
    for number, info in sorted(entry["groups"].items(), key=lambda kv: int(kv[0])):
        if info["role"] in out and info.get("verified", False):
            out[info["role"]].append(int(number))
    return out


def tile_rgb(folder: dict, palt: bytes, index: int) -> np.ndarray:
    data = np.frombuffer(folder[(f"{index:04d}", "MAPT")][:TILE_PX * TILE_PX], dtype=np.uint8)
    colors = np.frombuffer(palt, dtype=np.uint8)[:768].reshape(256, 3)
    return colors[data].reshape(TILE_PX, TILE_PX, 3)


def sheet(folder: dict, palt: bytes, tiles: list) -> np.ndarray:
    out = np.zeros((GRID * TILE_PX, GRID * TILE_PX, 3), dtype=np.uint8)
    for cell in range(GRID * GRID):
        y, x = divmod(cell, GRID)
        out[y * TILE_PX:(y + 1) * TILE_PX, x * TILE_PX:(x + 1) * TILE_PX] = tile_rgb(folder, palt, tiles[cell % len(tiles)])
    return out


def detail(folder: dict, layer: int) -> np.ndarray:
    found = folder_texture(folder, "DT%02d" % layer)
    if found is None:
        sys.exit("bake_role_sheets: the land has no DT%02d" % layer)
    width, height, rgba = found
    return np.frombuffer(rgba, dtype=np.uint8).reshape(height, width, 4)[..., 0].copy()


def main() -> int:
    god = str(ARGS.get("--god", "persephone"))
    wad_name, land, _ = lands.GODS[god]
    folder = lands.land_folder(lands.DATA / wad_name, land)
    palt = folder[("LAND", "PALT")][8:]
    groups = lands.tile_groups(folder)
    present = {int(name) for (name, ext) in folder if ext == "MAPT" and name.isdigit()}
    out_dir = THEMES / god / "roles"
    for role, numbers in role_groups(god).items():
        tiles = [t for n in numbers if "band" in groups.get(n, {}) for t in groups[n]["tiles"] if t in present]
        if not tiles:
            sys.exit("bake_role_sheets: %s has no verified base tile for the role '%s'" % (god, role))
        albedo = sheet(folder, palt, tiles)
        grain = detail(folder, groups[numbers[0]]["detail"])
        print("%-6s groups %s  tiles %d %s  DT%02d  mean RGB %s" % (role, numbers, len(tiles), tiles, groups[numbers[0]]["detail"],
              [round(float(c), 1) for c in albedo.reshape(-1, 3).mean(0)]))
        if "--check" in ARGS:
            continue
        out_dir.mkdir(parents=True, exist_ok=True)
        Image.fromarray(albedo, "RGB").save(out_dir / ("%s.png" % role))
        Image.fromarray(grain, "L").save(out_dir / ("%s_detail.png" % role))
    return 0


if __name__ == "__main__":
    sys.exit(main())
