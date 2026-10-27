"""Requiere el juego original instalado (SAC_INSTALL). Ver tools/import/local.cfg.example.

Bakes the ground role sheets of a god: assets/original/themes/<god>/roles/<role>.png and <role>_detail.png.

A role sheet is what one ground role (open, earth, rock, path) of the god looks like: the base tiles of the land's MAPG groups that
play that role (tools/import/ground_roles_table.json, verified rows only; a land with no group for a role names the groups its
sheet borrows in `sheet_borrow`), laid out as a 4x4 grid of 64x64 tiles (256x256 px,
64 px = one 10 m cell). A group with fewer than 16 tiles repeats them in order, so a tile used twice weighs twice; a role with
more than 16 gives each tile its share of the cells its land's maps paint with it (fit_cells). The ground
shader (scenes/look/ground/ground.gdshader) picks one of the 16 cells per 10 m map cell. The detail sheet is the grey grain
layer (DTnn) the group lays over its tiles in the original, 256x256, stretched over one cell.

  SAC_INSTALL=/path/to/Sacrifice/data python3 -I tools/import/bake_role_sheets.py [--god=persephone] [--check] [--measure]

--check writes nothing and prints what it would write. Prints, per role, the groups, the tiles and the mean RGB of the sheet.
--measure writes nothing: for every imported map of the god's own land, the mean colour of the saved sheets weighted by the map's
ground_roles.png against the mean of the tiles the original paints there (its own ids on its own land; id 0, the void, skipped),
PASS or FAIL per criterion of plan 062 (saturation and value within 0.03, hue within 4 degrees); exit 1 on a FAIL.
Ref: sacmap.d:196-206 (DT layer per MAPG group), maps.d:65 loadDTIndex (byte 55 = DT layer).
"""

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import land_themes as lands  # noqa: E402  (exits with a message when the original is not installed)
import measure_ground  # noqa: E402
from sac_formats.txtr import folder_texture  # noqa: E402

ROLES = ("open", "earth", "rock", "path")
TABLE = Path(__file__).resolve().parent / "ground_roles_table.json"
THEMES = Path(__file__).resolve().parents[2] / "assets" / "original" / "themes"
MAP_SCENES = Path(__file__).resolve().parents[2] / "scenes" / "map" / "maps"
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
    for role, borrow in entry.get("sheet_borrow", {}).items():
        if not out[role]:
            out[role] = list(borrow["groups"])
    return out


def tile_rgb(folder: dict, palt: bytes, index: int) -> np.ndarray:
    data = np.frombuffer(folder[(f"{index:04d}", "MAPT")][:TILE_PX * TILE_PX], dtype=np.uint8)
    colors = np.frombuffer(palt, dtype=np.uint8)[:768].reshape(256, 3)
    return colors[data].reshape(TILE_PX, TILE_PX, 3)


def land_use(god: str) -> np.ndarray:
    """How many cells each tile id paints on the imported maps made of the god's land (id 0, the filler under the void, never counts)."""
    use = np.zeros(256)
    for scp in lands.imported_maps() + [lands.MAP]:
        if lands.map_god(scp) == god:
            use += np.bincount(np.frombuffer(lands.native_tiles(scp), dtype=np.uint8), minlength=256)
    use[0] = 0.0
    return use


def fit_cells(tiles: list, use: np.ndarray) -> list:
    """The tiles of a role with more tiles than cells: each used tile gets as many of the 16 cells as its share of the use on
    the land's maps (largest remainder), so the sheet shows the ground the maps paint most. Unused land: the first 16."""
    cells = GRID * GRID
    if len(tiles) <= cells or use[tiles].sum() <= 0.0:
        return tiles
    unique = sorted(set(tiles))
    share = use[unique] / use[unique].sum() * cells
    count = np.floor(share).astype(int)
    for i in np.argsort(-(share - count), kind="stable")[: cells - int(count.sum())]:
        count[i] += 1
    return [t for t, n in zip(unique, count) for _ in range(n)]


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


def measure(god: str, folder: dict, palt: bytes) -> int:
    """Sheets on each own-land map against what the original paints there (see --measure)."""
    colors = np.frombuffer(palt, dtype=np.uint8)[:768].reshape(256, 3).astype(np.float64)
    failed = 0
    for ntts in sorted((THEMES.parent / "maps").glob("*/ntts.json")):
        scp = next((c for c in (lands.MAPS / json.loads(ntts.read_text())["map"], lands.MAPS / "Tutorial" / json.loads(ntts.read_text())["map"]) if c.exists()), None)
        if scp is None or lands.map_god(scp) != god:
            continue
        tmap = np.frombuffer(lands.native_tiles(scp), dtype=np.uint8)
        counts = np.bincount(tmap, minlength=256).astype(np.float64)
        counts[0] = 0.0
        painted = [(colors[np.frombuffer(folder[("%04d" % t, "MAPT")][:4096], dtype=np.uint8)].mean(0), counts[t])
                   for t in np.nonzero(counts)[0] if ("%04d" % t, "MAPT") in folder]
        original = measure_ground.hsv_of(sum(m * n for m, n in painted) / sum(n for _, n in painted))
        weights = np.asarray(Image.open(MAP_SCENES / ntts.parent.name / "ground_roles.png").convert("RGBA"), dtype=np.float64)
        weights = weights.reshape(-1, 4)[tmap != 0].sum(0)
        means = [np.asarray(Image.open(THEMES / god / "roles" / ("%s.png" % r)).convert("RGB"), dtype=np.float64).reshape(-1, 3).mean(0) for r in ROLES]
        roles = measure_ground.hsv_of(sum(m * w for m, w in zip(means, weights)) / weights.sum())
        print("%s: roles %s original %s" % (ntts.parent.name, roles["rgb"], original["rgb"]))
        failed |= measure_ground.compare_roles(roles, original, "original")
    return failed


def main() -> int:
    god = str(ARGS.get("--god", "persephone"))
    wad_name, land, _ = lands.GODS[god]
    folder = lands.land_folder(lands.DATA / wad_name, land)
    palt = folder[("LAND", "PALT")][8:]
    groups = lands.tile_groups(folder)
    present = {int(name) for (name, ext) in folder if ext == "MAPT" and name.isdigit()}
    if "--measure" in ARGS:
        return measure(god, folder, palt)
    out_dir = THEMES / god / "roles"
    use = land_use(god)
    for role, numbers in role_groups(god).items():
        tiles = fit_cells([t for n in numbers if "band" in groups.get(n, {}) for t in groups[n]["tiles"] if t in present], use)
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
