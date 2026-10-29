"""High Noon's NTTS (creatures, structures, widgets) and SIDS (sides).

NTTS layout and sides follow sacengine `ntts.d` and `sids.d`:
  Structure (48 bytes) type=2: x y z facing(deg) tag[4] flags side unknown id base
  Creature  (48 bytes) type=64: x y z facing(rad) tag[4] flags side unknown id unknown
  Widgets   (type 8192): tag[4], count, then x y facing per widget
  SIDS: u32 count, then 20 bytes per side: id allies enemies assignment color
Sac axes (x, y, z up) become Godot (x, z = y); the height of the land is chosen by the game.

Tags: a creature keeps the raw tag (zepe, raeb), the key of data/creatures.json. A structure keeps the name the WAD index uses
(jhut, jwg1, jfnt), which is the reverse of the NTTS bytes (tuhj), the key of data/buildings.json. Both are written as `tag`;
`raw` has the bytes as stored. The "side" of a structure out of range (>= 32) is the neutral side 31 (sacengine placeStructure).
"""

import json
import struct
from pathlib import Path

from .wad import extract

WIDGETS_TYPE = 8192
STRUCTURE = 2
CREATURE = 64
NEUTRAL_SIDE = 31
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


def read_widgets(ntts: bytes) -> dict:
    widgets = {}
    offset = 4
    while offset < len(ntts):
        kind, size = struct.unpack_from("<II", ntts, offset)
        if kind == WIDGETS_TYPE:
            tag = ntts[offset + 8: offset + 12][::-1].decode("latin1")
            count = struct.unpack_from("<I", ntts, offset + 12)[0]
            rows = widgets.setdefault(tag, [])
            for k in range(count):
                x, y, facing = struct.unpack_from("<fff", ntts, offset + 16 + 12 * k)
                rows.append([round(x, 3), round(y, 3), round(facing, 4)])
        offset += size
    return widgets


def ntts_json(scp: Path) -> str:
    """high_noon_ntts.json: sides, creatures and structures."""
    structures, creatures = read_entities(extract(scp, "", "NTTS"))
    sides = read_sides(extract(scp, "", "SIDS"))
    payload = {
        "map": scp.name,
        "neutral_side": NEUTRAL_SIDE,
        "sides": sides,
        "creatures": creatures,
        "structures": structures,
    }
    return json.dumps(payload, separators=(",", ":"))


def widgets_json(scp: Path) -> str:
    return json.dumps(read_widgets(extract(scp, "", "NTTS")), separators=(",", ":"))
