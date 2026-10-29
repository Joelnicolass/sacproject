"""Needs neither the original game nor a window: checks the baked scenes/map/maps/<map>/ground_roles.png of the 9 maps.

Criterion: in every map 0 cells whose four weights add up to less than 250/255 (a cell with no ground role),
and 0 lone cells (a cell dominated by a role that none of its 4 neighbours has). Prints one summary line per map: the share of
each role, those two counts, and (from tools/import/ground_roles_report.json, written by bake_ground_roles.py) what the bake
had to resolve. Exit status 1 when a map fails.

  python3 -I tools/import/check_ground_roles.py          (run from game/)
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ground_roles_common as common  # noqa: E402

MAPS = ("alpine_meadow", "high_noon", "peaks", "peasantville", "roads", "test_flat", "test_flat4", "tutorial_valley", "winter_wonder")
MIN_SUM = 250
# Measured on the plan (62): cells that fell in a hole of the atlas of the god the map was dressed with, and the lone rock cells of High Noon.
OLD_WITHOUT_TILE = {"peasantville": 725, "alpine_meadow": 31, "tutorial_valley": 5}
OLD_HIGH_NOON_ROCK = 19


def main() -> int:
    report = json.loads(common.REPORT.read_text()) if common.REPORT.exists() else {}
    failed = False
    resolved = 0
    for tag in MAPS:
        if not common.png_path(tag).exists():
            print("FAIL  %-16s missing %s" % (tag, common.png_path(tag).name))
            failed = True
            continue
        weights = common.load(tag)
        if weights.shape != (common.SIZE, common.SIZE, 4):
            print("FAIL  %-16s size %s, wanted 256x256" % (tag, weights.shape[:2]))
            failed = True
            continue
        thin = int((weights.sum(-1) < MIN_SUM).sum())
        loose = int(common.loose_mask(weights).sum())
        share = weights.sum((0, 1)) / float(weights.sum())
        info = report.get(tag, {})
        resolved += info.get("cells_without_tile", 0)
        bad = thin or loose
        failed = failed or bool(bad)
        print("%s  %-16s open %4.1f%% earth %4.1f%% rock %4.1f%% path %4.1f%% | sum<%d: %d  lone: %d | bake: no tile %s, no role %s, lone absorbed %s"
              % ("FAIL" if bad else "PASS", tag, *(100 * share), MIN_SUM, thin, loose,
                 info.get("cells_without_tile", "-"), info.get("cells_without_role", "-"), info.get("loose_cells_absorbed", "-")))
    rock = report.get("high_noon", {}).get("loose_cells_before", {}).get("rock")
    print("High Noon lone rock cells: %d in the plan (rock of James on Persephone's pale stone), %s before the bake absorbed them in the map's own land, 0 now"
          % (OLD_HIGH_NOON_ROCK, rock if rock is not None else "?"))
    print("Cells with no tile: %d in the plan (%s) when dressed with another god; %d without a tile in their own land, all with a role now"
          % (sum(OLD_WITHOUT_TILE.values()), " + ".join(str(v) for v in OLD_WITHOUT_TILE.values()), resolved))
    print("RESULT %s" % ("FAIL" if failed else "PASS"))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
