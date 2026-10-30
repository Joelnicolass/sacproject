"""Needs the original game installed (SAC_INSTALL). See tools/import/local.cfg.example.

WARNING: re-baking OVERWRITES the ground roles painted by hand in the editor (the roles brush of addons/terrain_tools):
once a map's ground_roles.png was painted, run it with --check first and leave that map alone.

Bakes scenes/map/maps/<map>/ground_roles.png for the maps of assets/original/maps (and test_flat*, all open ground).

Each map is read in its OWN land (the one its LEVL names): the TMAP tile ids index that land's MAPTs, so no translation to
another god is involved. A tile is made of 4 corners, each showing a base group of the land (MAPG); the table
tools/import/ground_roles_table.json says which role (open, earth, rock, path) each base group plays. A cell weighs each role by
its corners (a transition tile is 50/50). Cells with no role (no tile in the land, or only groups with no role) take the
majority role of the cells around them, and lone cells (a role none of their 4 neighbours has) are absorbed the same way.

  python3 -I tools/import/bake_ground_roles.py            # write the PNGs and tools/import/ground_roles_report.json
  python3 -I tools/import/bake_ground_roles.py --infer    # print the table of the lands that are not decided by hand
  python3 -I tools/import/bake_ground_roles.py --check    # bake in memory, say what would change, write nothing
"""

import json
import sys
from collections import Counter
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ground_roles_common as common  # noqa: E402
import land_themes as lands  # noqa: E402

TABLE = Path(__file__).resolve().parent / "ground_roles_table.json"
NO_ROLE = "neighbours"
SHIFTS = [(dy, dx) for dy in (-1, 0, 1) for dx in (-1, 0, 1) if (dy, dx) != (0, 0)]


def load_table() -> dict:
    return json.loads(TABLE.read_text())["lands"]


def role_of_groups(god: str) -> dict:
    """Base group number -> role index, or None for the groups that take the role of their surroundings."""
    entry = load_table().get(god)
    if entry is None:
        sys.exit("bake_ground_roles: ground_roles_table.json has no land '%s' (run --infer)" % god)
    out = {}
    for number, info in entry["groups"].items():
        out[int(number)] = None if info["role"] == NO_ROLE else common.ROLES.index(info["role"])
    return out


def split(counts: list) -> list:
    """255 shared by the corner counts (4 corners), the remainder to the largest."""
    total = sum(counts)
    out = [255 * c // total for c in counts]
    out[counts.index(max(counts))] += 255 - sum(out)
    return out


def tile_weights(god: str) -> dict:
    """Tile id -> (4 weights, role-less corner count) for the tiles of the land; absent = the land has no such tile."""
    roles = role_of_groups(god)
    out = {}
    for tile, (_, _, corners) in lands.god_land(god)["signatures"].items():
        counts = [0] * 4
        for corner in corners:
            if roles.get(corner) is not None:
                counts[roles[corner]] += 1
        if sum(counts):
            out[tile] = split(counts)
    return out


def fill_unknown(weights: np.ndarray, known: np.ndarray) -> None:
    """Ring by ring, an unknown cell next to known ones takes the majority role of those (ties: the first role)."""
    known = known.copy()
    while not known.all():
        votes = np.zeros(weights.shape, dtype=np.int32)
        onehot = np.eye(4, dtype=np.int32)[weights.argmax(-1)] * known[..., None]
        for dy, dx in SHIFTS:
            votes += common.shift(onehot, dy, dx)
        take = ~known & (votes.sum(-1) > 0)
        if not take.any():
            weights[~known] = (255, 0, 0, 0)
            return
        weights[take] = np.eye(4, dtype=np.int32)[votes.argmax(-1)][take] * 255
        known |= take


def absorb_loose(weights: np.ndarray) -> int:
    """Turns every lone cell into the majority role of its 4 neighbours; returns the cells changed."""
    changed = 0
    for _ in range(16):
        mask = common.loose_mask(weights)
        if not mask.any():
            break
        strongest = weights.argmax(-1)
        votes = np.zeros(weights.shape, dtype=np.int32)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            votes += common.shift(np.eye(4, dtype=np.int32)[strongest], dy, dx)
        weights[mask] = np.eye(4, dtype=np.int32)[votes.argmax(-1)][mask] * 255
        changed += int(mask.sum())
    return changed


def bake_map(scp: Path) -> tuple:
    """((256, 256, 4) weights, report dict) of a map read in its own land."""
    god = lands.map_god(scp)
    table = tile_weights(god)
    tmap = np.frombuffer(lands.native_tiles(scp), dtype=np.uint8).reshape(256, 256)
    weights = np.zeros((256, 256, 4), dtype=np.int32)
    known = np.zeros((256, 256), dtype=bool)
    no_tile = no_role = 0
    present = lands.god_land(god)["signatures"]
    for tile in np.unique(tmap):
        cells = tmap == tile
        if int(tile) in table:
            weights[cells] = table[int(tile)]
            known |= cells
        elif int(tile) in present:
            no_role += int(cells.sum())
        else:
            no_tile += int(cells.sum())
    fill_unknown(weights, known)
    before = common.loose_by_role(weights)
    absorbed = absorb_loose(weights)
    return weights, {"god": god, "cells_without_tile": no_tile, "cells_without_role": no_role,
                     "loose_cells_before": before, "loose_cells_absorbed": absorbed}


def infer(god: str) -> dict:
    """Role per base group, decided by the script (NO VERIFICADO): open = the banded group most used by the imported maps of
    the land; rock = the highest height band; path = the lowest one; the banded groups in between = earth; the groups with
    no height band take the role of their surroundings."""
    land = lands.god_land(god)
    usage = Counter()
    for scp in lands.imported_maps() + [lands.MAP]:
        if lands.map_god(scp) == god:
            for tile in lands.native_tiles(scp):
                for corner in land["signatures"].get(tile, (0, 0, ()))[2]:
                    usage[corner] += 1
    centers = {n: c for n, g in land["groups"].items() if (c := lands.band_center(g)) is not None}
    open_ = max(centers, key=lambda n: (usage[n], -n))
    rest = {n: c for n, c in centers.items() if n != open_}
    rock = max(rest, key=lambda n: (rest[n], n)) if rest else None
    path = min((n for n in rest if n != rock), key=lambda n: (rest[n], n), default=None)
    out = {}
    for number, group in sorted(land["groups"].items()):
        if "band" not in group:
            continue
        role = NO_ROLE if number not in centers else "open" if number == open_ else "rock" if number == rock else "path" if number == path else "earth"
        out[str(number)] = {"role": role, "verified": False}
    return out


def maps_to_bake() -> dict:
    """tag -> .scp for the maps with an assets/original/maps/<tag>/ntts.json."""
    found = {}
    for ntts in sorted((Path(__file__).resolve().parents[2] / "assets" / "original" / "maps").glob("*/ntts.json")):
        name = json.loads(ntts.read_text())["map"]
        found[ntts.parent.name] = next((c for c in (lands.MAPS / name, lands.MAPS / "Tutorial" / name) if c.exists()), lands.MAPS / name)
    return found


def main() -> int:
    if "--infer" in sys.argv:
        print(json.dumps({god: {"groups": infer(god)} for god in ("pyro", "stratos")}, indent=2))
        return 0
    report, check = {}, "--check" in sys.argv
    for tag, scp in maps_to_bake().items():
        weights, report[tag] = bake_map(scp)
        print(tag, report[tag])
        if not check:
            Image.fromarray(weights.astype(np.uint8), "RGBA").save(common.png_path(tag))
    flat = np.zeros((256, 256, 4), dtype=np.uint8)
    flat[..., 0] = 255
    for tag in common.FLAT_MAPS:
        report[tag] = {"god": None, "all": "open"}
        if not check:
            Image.fromarray(flat, "RGBA").save(common.png_path(tag))
    if not check:
        common.REPORT.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
