#!/usr/bin/env python3
"""055d-d2 (one-off): each PlayerStart gets a saved `WizardSpot` where `wizard_distance` + `faces` put the wizard,
and loses `faces`. Reads the map scenes (starts and founts have no turn), writes the WizardSpot override after each start.

Run from game/: python3 tools/migrate/d2_starts.py
"""
import math
import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAPS = ROOT / "scenes/map/maps"
DISTANCE = 30.0


def f32(value: float) -> float:
    return struct.unpack("f", struct.pack("f", value))[0]


def num(value: float) -> str:
    value = f32(value)
    text = "%.7g" % value
    if abs(float(text) - value) > 0:
        text = "%.9g" % value
    return text


def origin(block: list[str]) -> tuple[float, float, float]:
    line = next(l for l in block if l.startswith("transform"))
    nums = [float(v) for v in re.search(r"Transform3D\(([^)]*)\)", line).group(1).split(",")]
    assert nums[:9] == [1, 0, 0, 0, 1, 0, 0, 0, 1], line
    return nums[9], nums[10], nums[11]


def spot_for(start: tuple, faces: tuple, distance: float) -> tuple[list[float], tuple]:
    dx, dz = faces[0] - start[0], faces[2] - start[2]
    length = math.hypot(dx, dz)
    ahead = (dx / length, dz / length)
    sx, sz = start[0] + ahead[0] * distance, start[2] + ahead[1] * distance
    fx, fz = faces[0] - sx, faces[2] - sz
    angle = math.atan2(fx, fz)
    c, s = math.cos(angle), math.sin(angle)
    # Basis(UP, angle): columns x = (c, 0, -s), y = up, z = (s, 0, c)
    basis = [c, 0.0, s, 0.0, 1.0, 0.0, -s, 0.0, c]
    return basis, (sx - start[0], 0.0, sz - start[2])


def migrate(path: Path) -> int:
    text = path.read_text()
    chunks = re.split(r"(?m)^(?=\[node )", text)
    blocks = {}
    for chunk in chunks[1:]:
        head = chunk.split("\n", 1)[0]
        name = re.search(r'name="([^"]+)"', head).group(1)
        parent = re.search(r'parent="([^"]+)"', head)
        full = (parent.group(1) + "/" + name) if parent else name
        blocks[full] = chunk.split("\n")
    out = [chunks[0]]
    count = 0
    for chunk in chunks[1:]:
        head = chunk.split("\n", 1)[0]
        parent = re.search(r'parent="([^"]+)"', head)
        if parent is None or not parent.group(1).endswith("MapProps/Starts") or "player_start" not in "".join(l for l in text.split("\n") if l.startswith("[ext_resource") and re.search(r'id="%s"' % re.search(r'instance=ExtResource\("([^"]+)"\)', head).group(1), l)):
            out.append(chunk)
            continue
        name = re.search(r'name="([^"]+)"', head).group(1)
        lines = chunk.split("\n")
        faces_line = next(l for l in lines if l.startswith("faces = NodePath("))
        faces_rel = re.search(r'NodePath\("([^"]+)"\)', faces_line).group(1)
        # "../../Founts/X" from MapProps/Starts/StartN -> MapProps/Founts/X
        faces_full = "/".join((parent.group(1) + "/" + name).split("/")[:-1][:-1] + faces_rel.split("/")[2:])
        faces_pos = origin(blocks[faces_full])
        start_pos = origin(lines)
        basis, local = spot_for(start_pos, faces_pos, DISTANCE)
        new_lines = [l for l in lines if not l.startswith("faces = ")]
        head_new = new_lines[0].replace(' node_paths=PackedStringArray("faces")', "")
        new_lines[0] = head_new
        spot = '[node name="WizardSpot" parent="%s/%s" index="1"]\ntransform = Transform3D(%s, %s)\n' % (
            parent.group(1), name, ", ".join(num(v) for v in basis), ", ".join(num(v) for v in local))
        body = "\n".join(new_lines).rstrip("\n") + "\n\n" + spot + "\n"
        out.append(body)
        count += 1
    path.write_text("".join(out))
    return count


for tag in ["high_noon", "peaks", "peasantville", "roads", "winter_wonder", "test_flat", "test_flat4"]:
    print(tag, migrate(MAPS / tag / "map.tscn"), "starts")
