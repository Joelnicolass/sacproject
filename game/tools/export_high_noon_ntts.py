#!/usr/bin/env python3
"""Export the creatures, structures and sides of High Noon to game/cache/high_noon_ntts.json.

RFC-024 addendum 1, cut 024b2. NTTS layout and sides follow sacengine `ntts.d` and `sids.d`:
  Structure (48 bytes) type=2: x y z facing(deg) tag[4] flags side unknown id base
  Creature  (48 bytes) type=64: x y z facing(rad) tag[4] flags side unknown id unknown
  SIDS: u32 count, then 20 bytes per side: id allies enemies assignment color
Sac axes (x, y, z up) become Godot (x, z = y); the height of the land is chosen by the game.

Tags: a creature keeps the raw tag (zepe, raeb), the key of cache/data/creatures.json. A structure
keeps the name the WAD index uses (jhut, jwg1, jfnt), which is the reverse of the NTTS bytes (tuhj),
the key of cache/data/buildings.json. Both are written as `tag`; `raw` has the bytes as stored.
The "side" of a structure out of range (>= 32) is the neutral side 31 (sacengine placeStructure).

Reads the local install; the cache is gitignored. Run: python3 tools/export_high_noon_ntts.py
"""

import json
import struct
import sys
from pathlib import Path

from export_high_noon_look import extract

DEFAULT_SCP = "/Users/joelsartori/Downloads/sacgame/Sacrifice/maps/(2) High Noon.scp"
ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUT = ROOT / "cache" / "high_noon_ntts.json"
STRUCTURE = 2
CREATURE = 64
NEUTRAL_SIDE = 31
## BldgFlags.shelter (bldg.d:11); the BLDG flags themselves come from export_stats.py (buildings.json).
SIDS_RECORD = 20


def raw_tag(blob: bytes, offset: int) -> str:
    return blob[offset : offset + 4].decode("latin1").rstrip("\x00")


def read_entities(ntts: bytes) -> tuple[list, list]:
    structures, creatures = [], []
    offset = 4
    while offset < len(ntts):
        kind, size = struct.unpack_from("<II", ntts, offset)
        if kind in (STRUCTURE, CREATURE):
            x, y, z, facing = struct.unpack_from("<ffff", ntts, offset + 8)
            raw = raw_tag(ntts, offset + 24)
            flags, side, _unknown, ident = struct.unpack_from("<IIII", ntts, offset + 28)
            if side >= 32:
                side = NEUTRAL_SIDE
            row = {
                "tag": raw if kind == CREATURE else raw[::-1],
                "raw": raw,
                "x": round(x, 3),
                "z": round(y, 3),
                "facing": round(facing, 5),
                "flags": flags,
                "side": side,
                "id": ident,
            }
            (creatures if kind == CREATURE else structures).append(row)
        offset += size
    return structures, creatures


def read_sides(sids: bytes) -> list:
    count = struct.unpack_from("<I", sids, 0)[0]
    sides = []
    for k in range(count):
        ident, allies, enemies, assignment, color = struct.unpack_from("<IIIII", sids, 4 + SIDS_RECORD * k)
        sides.append({
            "id": ident,
            "allies": allies,
            "enemies": enemies,
            "assignment": assignment,
            "color": color,
        })
    return sides


def main() -> int:
    scp = Path(sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SCP)
    out = Path(sys.argv[2] if len(sys.argv) > 2 else DEFAULT_OUT)
    structures, creatures = read_entities(extract(scp, "", "NTTS"))
    sides = read_sides(extract(scp, "", "SIDS"))
    payload = {
        "map": scp.name,
        "neutral_side": NEUTRAL_SIDE,
        "sides": sides,
        "creatures": creatures,
        "structures": structures,
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, separators=(",", ":")))
    by_tag: dict = {}
    for row in structures:
        key = (row["tag"], row["side"])
        by_tag[key] = by_tag.get(key, 0) + 1
    creature_count: dict = {}
    for row in creatures:
        key = (row["tag"], row["side"])
        creature_count[key] = creature_count.get(key, 0) + 1
    print("creatures", creature_count)
    print("structures", sorted(by_tag.items()))
    print("sides", [(s["id"], hex(s["allies"]), hex(s["enemies"]), s["assignment"]) for s in sides])
    print(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
