#!/usr/bin/env python3
"""055d-d2 (one-off): the 196 building scenes become the thing you drag into a map.

Before: scenes/structures/buildings/<name>.tscn = a Node3D with the parts and a `Footprint` (hit_box AABB), instanced by
MapBuilding under `Visuals` as an unsaved child; data/buildings/<name>.tres pointed at it with `scene`.
After:  the scene root is an inheritance of scenes/map/map_building.tscn with `type = <name>.tres`, the parts are saved
children of `Visuals`, and the Footprint box is a saved BoxShape3D on the inherited `Collision` node (the box of the parts,
the old hit_box; MapBuilding shrinks it by `inset_m` for the body at runtime, as the footprint did). Ruin scenes (`*_ruin.tscn`)
stay. It also drops `scene` from every BuildingType .tres. It reads the old files from git HEAD, so it can run again.

Run from game/: python3 tools/migrate/d2_buildings.py
"""
import re
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BUILDINGS = ROOT / "scenes/structures/buildings"
TYPES = ROOT / "data/buildings"
INSET = 0.5

AABB_RE = re.compile(r"AABB\(([^)]*)\)")


def f32(value: float) -> float:
    return struct.unpack("f", struct.pack("f", value))[0]


def fmt(value: float) -> str:
    """The shortest text that reads back as the same float32 (what Godot writes)."""
    value = f32(value)
    for digits in range(1, 10):
        text = "%.*g" % (digits, value)
        if f32(float(text)) == value:
            return text
    return repr(value)


def old(path: Path) -> str:
    return subprocess.check_output(["git", "show", "HEAD:./" + str(path.relative_to(ROOT))], cwd=ROOT, text=True)


def split_blocks(text: str) -> list[list[str]]:
    blocks: list[list[str]] = []
    for line in text.split("\n"):
        if line.startswith("["):
            blocks.append([line])
        elif blocks:
            blocks[-1].append(line)
    return blocks


def pascal(stem: str) -> str:
    return "".join(part.capitalize() for part in stem.strip("_").split("_"))


def convert(path: Path, type_path: str) -> str:
    blocks = split_blocks(old(path))
    ext_scripts = []
    nodes = []
    for block in blocks:
        head = block[0]
        if head.startswith("[ext_resource"):
            if "building_footprint.gd" not in head:
                ext_scripts.append(head)
        elif head.startswith("[node"):
            nodes.append(block)
    root_name = re.search(r'name="([^"]*)"', nodes[0][0]).group(1)
    footprint = None
    parts = []
    for block in nodes[1:]:
        name = re.search(r'name="([^"]*)"', block[0]).group(1)
        parent = re.search(r'parent="([^"]*)"', block[0]).group(1)
        if name == "Footprint" and parent == ".":
            footprint = block
            continue
        new_parent = "Visuals" if parent == "." else "Visuals/" + parent
        head = re.sub(r'parent="[^"]*"', 'parent="%s"' % new_parent, block[0])
        parts.append([head] + block[1:])
    assert footprint is not None, path
    box_line = next(line for line in footprint if line.startswith("hit_box"))
    raw = [f32(float(v.strip())) for v in AABB_RE.search(box_line).group(1).split(",")]
    px, py, pz, sx, sy, sz = raw
    inset_line = next((line for line in footprint if line.startswith("inset")), "inset = 0.5")
    assert float(inset_line.split("=")[1]) == INSET, path
    body = (sx, sy, sz)
    # AABB::get_center() in float32: position + size * 0.5, rounded once per axis.
    center = (f32(px + f32(sx * 0.5)), f32(py + f32(sy * 0.5)), f32(pz + f32(sz * 0.5)))
    out = ['[gd_scene format=3]', '',
           '[ext_resource type="PackedScene" path="res://scenes/map/map_building.tscn" id="1_building"]',
           '[ext_resource type="Resource" path="%s" id="2_type"]' % type_path]
    out += ext_scripts
    out += ['', '[sub_resource type="BoxShape3D" id="BoxShape3D_body"]',
            "size = Vector3(%s, %s, %s)" % tuple(fmt(v) for v in body), '',
            '[node name="%s" instance=ExtResource("1_building")]' % root_name,
            'type = ExtResource("2_type")', '']
    for block in parts:
        out += [line for line in block]
        if out[-1] != "":
            out.append("")
    out += ['[node name="Collision" parent="." index="1"]',
            "position = Vector3(%s, %s, %s)" % tuple(fmt(v) for v in center),
            'shape = SubResource("BoxShape3D_body")', '']
    text = "\n".join(out)
    return re.sub(r"\n{3,}", "\n\n", text).rstrip("\n") + "\n"


def main() -> None:
    changed = 0
    for tres in sorted(TYPES.glob("*.tres")):
        text = old(tres)
        match = re.search(r'^scene = ExtResource\("([^"]+)"\)\n', text, re.M)
        if match is None:
            print("no scene in", tres.name)
            continue
        scene_id = match.group(1)
        ext = re.search(r'\[ext_resource type="PackedScene" path="([^"]+)" id="%s"\]\n' % re.escape(scene_id), text)
        scene_path = ext.group(1)
        scene_file = ROOT / scene_path.replace("res://", "")
        res_path = "res://data/buildings/%s" % tres.name
        scene_file.write_text(convert(scene_file, res_path))
        text = text.replace(match.group(0), "").replace(ext.group(0), "")
        tres.write_text(text)
        changed += 1
    print("converted", changed)


if __name__ == "__main__":
    sys.exit(main())
