#!/usr/bin/env python3
"""No necesita el juego original: usa los assets ya importados en assets/original (versionados).

The Godot side of an imported map (RFC-050): the files a map needs besides its assets.

  python3 tools/import/scaffold_map.py --map=Peaks            # write what is missing, list what it wrote
  python3 tools/import/scaffold_map.py --map=Peaks --force    # overwrite map.tscn and the definition (they are hand-edited afterwards)
  python3 tools/import/scaffold_map.py --scp="Tutorial/(tu02).scp" --tag=tutorial_valley --not-playable --no-npcs   # a map to look at, without inhabitants
  python3 tools/import/scaffold_map.py --map=Peaks --wire-flora   # the plants of widgets.json as FloraLayer nodes (a density PNG per species) in the existing map.tscn; then import once

Run tools/import/import_map.py first (it writes ntts.json, light.png, ...) and tools/import/bake_ground_roles.py (the map's
ground_roles.png). For `<tag>` it writes:
  scenes/map/maps/<tag>/heights.png                a flat ground (16-bit grey, all 0, no void.png), only when there is none, so the scene
                                                   loads; tools/terrain/heights_from_original.gd -- --map=<tag> writes the original's ground
  scenes/map/maps/<tag>/<tag>.tres                 MapDefinition (typed: scene, light, navmesh); MapCatalog finds it by scanning the folder
  scenes/map/maps/<tag>/nav.res                    an empty navmesh, so the definition loads until the first bake
  scenes/map/maps/<tag>/map.tscn                   MapRoot: sky, look, terrain (an instance of scenes/map/terrain/terrain.tscn), one PlayerStart (with its WizardSpot) per seat, the manafounts, Buildings, Npcs, navmesh, minimap
The PlayerStart and the manafounts are the altar and manafount rows of the NTTS, placed on the ground height the game would give
them (sac_formats.terrain.ground_height_fn); the WizardSpot of seat k is 30 m toward the closest manafount, looking at it, as sacengine puts the wizard.
Buildings: every other structure row that has a BuildingType in data/buildings/ becomes an instance of its scene
(scenes/structures/buildings/<name>.tscn) at the ground height, turned by its facing; Npcs: every creature row becomes an NpcSpawn
(the creature type of data/catalog/creatures/, its side) 0.2 m above the ground. Rows off the land, rows with no type and the sky dome
`pcsb` (a 1 140 m model, not a prop) are left out and listed. The plants are --wire-flora's: one FloraLayer per species under a `Vegetation` node.
The navmesh is baked with the «Hornear navmesh» button of the NavRegion. Nothing here is read at runtime. Idempotent: an existing file
is kept unless --force.
"""

import base64
import json
import math
import re
import struct
import sys
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "blender"))
import import_map  # noqa: E402
import terrain_common  # noqa: E402  (tools/blender/terrain_common.py: the one Python copy of the map images)
from sac_formats import terrain  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
ARGS = import_map.ARGS
SCP = import_map.SCP
TAG = import_map.TAG
ASSETS = ROOT / "assets" / "original" / "maps" / TAG
SCENES = ROOT / "scenes" / "map" / "maps" / TAG
FORCE = "--force" in ARGS

# The altar and the manafount of each land (flags 0x80001407 and 0x80002810 in data/buildings/). Same lists as
# the plant clearings of --wire-flora: those rows are PlayerStart and Manafount nodes of the map scene, not buildings.
ALTAR_TAGS = ("jaal", "ca_a", "pyal", "stal", "alt1")
FOUNT_TAGS = ("jfnt", "cafn", "pfon", "stmf", "font")
NEUTRAL_SIDE = 31


def pascal(tag: str) -> str:
    return "".join(part.capitalize() for part in tag.split("_"))


def fmt(value: float) -> str:
    text = ("%.4f" % value).rstrip("0").rstrip(".")
    return text if text not in ("", "-0") else "0"


def write(path: Path, text: "str | bytes", wrote: list) -> None:
    if path.exists() and not FORCE:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(text if isinstance(text, bytes) else text.encode())
    wrote.append(str(path.relative_to(ROOT)))


def seats_of(sides: list) -> list:
    """Side ids a player takes (assignment != 0), in order: seat k (slot k + 1) is the k-th."""
    return sorted(s["id"] for s in sides if s["id"] != NEUTRAL_SIDE and s["assignment"] != 0)


def definition_tres(seats: int) -> str:
    return """[gd_resource type="Resource" script_class="MapDefinition" format=3]

[ext_resource type="Script" path="res://scenes/map/map_definition.gd" id="1_def"]
[ext_resource type="PackedScene" path="res://scenes/map/maps/{tag}/map.tscn" id="2_scene"]
[ext_resource type="Texture2D" path="res://assets/original/maps/{tag}/light.png" id="5_light"]
[ext_resource type="NavigationMesh" path="res://scenes/map/maps/{tag}/nav.res" id="6_nav"]

[resource]
script = ExtResource("1_def")
tag = &"{tag}"
display_name = "{name}"
map_scene = ExtResource("2_scene")
light = ExtResource("5_light")
nav = ExtResource("6_nav")
player_starts = {seats}
{playable}""".format(
        tag=TAG, name=import_map.display_name(SCP), seats=seats,
        playable="playable = false\n" if "--not-playable" in ARGS else "")


# An empty NavigationMesh saved by Godot as a binary .res (ResourceSaver.save(NavigationMesh.new(), "x.res")), base64.
NAV_PLACEHOLDER_B64 = "UlNSQwAAAAAAAAAABAAAAAcAAAAGAAAADwAAAE5hdmlnYXRpb25NZXNoAAAAAAAAAAAAAwAAAP//////////AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAcAAAAGAAAAHJlc291cmNlX2xvY2FsX3RvX3NjZW5lAA4AAAByZXNvdXJjZV9uYW1lAAkAAAB2ZXJ0aWNlcwAJAAAAcG9seWdvbnMAFgAAAHNhbXBsZV9wYXJ0aXRpb25fdHlwZQAeAAAAZ2VvbWV0cnlfcGFyc2VkX2dlb21ldHJ5X3R5cGUAGAAAAGdlb21ldHJ5X2NvbGxpc2lvbl9tYXNrAB4AAABnZW9tZXRyeV9zb3VyY2VfZ2VvbWV0cnlfbW9kZQAKAAAAY2VsbF9zaXplAAwAAABjZWxsX2hlaWdodAAMAAAAYm9yZGVyX3NpemUADQAAAGFnZW50X2hlaWdodAANAAAAYWdlbnRfcmFkaXVzABAAAABhZ2VudF9tYXhfY2xpbWIAEAAAAGFnZW50X21heF9zbG9wZQAQAAAAcmVnaW9uX21pbl9zaXplABIAAAByZWdpb25fbWVyZ2Vfc2l6ZQAQAAAAZWRnZV9tYXhfbGVuZ3RoAA8AAABlZGdlX21heF9lcnJvcgAVAAAAdmVydGljZXNfcGVyX3BvbHlnb24AFwAAAGRldGFpbF9zYW1wbGVfZGlzdGFuY2UAGAAAAGRldGFpbF9zYW1wbGVfbWF4X2Vycm9yAB0AAABmaWx0ZXJfbG93X2hhbmdpbmdfb2JzdGFjbGVzABMAAABmaWx0ZXJfbGVkZ2Vfc3BhbnMAIQAAAGZpbHRlcl93YWxrYWJsZV9sb3dfaGVpZ2h0X3NwYW5zABMAAABmaWx0ZXJfYmFraW5nX2FhYmIAGgAAAGZpbHRlcl9iYWtpbmdfYWFiYl9vZmZzZXQABwAAAHNjcmlwdAAAAAAAAQAAAB0AAABsb2NhbDovL05hdmlnYXRpb25NZXNoXzhmMG8wABgDAAAAAAAADwAAAE5hdmlnYXRpb25NZXNoAAEAAAAbAAAAAQAAAFJTUkM="


MAP_HEAD = """[gd_scene format=3]

[ext_resource type="Script" path="res://scenes/map/map_root.gd" id="1_root"]
[ext_resource type="PackedScene" path="res://scenes/map/terrain/terrain.tscn" id="2_terrain"]
[ext_resource type="Resource" path="res://scenes/map/maps/{tag}/heights.png" id="2_heights"]
[ext_resource type="Texture2D" path="res://assets/original/maps/{tag}/light.png" id="2_light"]{roles_res}
[ext_resource type="Script" path="res://scenes/map/props/map_props.gd" id="3_props"]
[ext_resource type="PackedScene" path="res://scenes/map/props/player_start.tscn" id="4_start"]
[ext_resource type="PackedScene" path="res://scenes/map/props/manafount.tscn" id="5_fount"]
[ext_resource type="PackedScene" path="res://scenes/look/look_rig.tscn" id="8_look"]
[ext_resource type="Resource" path="res://data/nav/nav_bake.tres" id="14_bake"]
[ext_resource type="NavigationMesh" path="res://scenes/map/maps/{tag}/nav.res" id="15_navmesh"]
[ext_resource type="Script" path="res://scenes/map/nav/map_nav_region.gd" id="16_nav_region"]
[ext_resource type="PackedScene" path="res://scenes/ui/minimap/minimap_terrain_bake.tscn" id="17_minimap"]

[node name="Map" type="Node3D" node_paths=PackedStringArray("terrain", "nav_region", "starts", "look", "minimap_bake", "buildings", "npcs", "props")]
script = ExtResource("1_root")
terrain = NodePath("Terrain")
nav_region = NodePath("NavRegion")
starts = NodePath("MapProps/Starts")
look = NodePath("Look")
minimap_bake = NodePath("MinimapBake")
buildings = NodePath("Buildings")
npcs = NodePath("Npcs")
props = NodePath("Props")

[node name="Look" parent="." node_paths=PackedStringArray("terrain") instance=ExtResource("8_look")]
unique_name_in_owner = true
terrain = NodePath("../Terrain")

[node name="Terrain" parent="." instance=ExtResource("2_terrain")]
unique_name_in_owner = true
heights = ExtResource("2_heights")
light_map = ExtResource("2_light"){roles_line}

[node name="MapProps" type="Node3D" parent="."]
script = ExtResource("3_props")

[node name="Starts" type="Node3D" parent="MapProps"]
"""

MAP_TAIL = """
[node name="NavRegion" type="NavigationRegion3D" parent="."]
unique_name_in_owner = true
navigation_mesh = ExtResource("15_navmesh")
script = ExtResource("16_nav_region")
bake_settings = ExtResource("14_bake")

[node name="MinimapBake" parent="." node_paths=PackedStringArray("terrain") instance=ExtResource("17_minimap")]
unique_name_in_owner = true
terrain = NodePath("../Terrain")
"""

# Structure rows that are not props of the Buildings folder: the altar and the manafount are PlayerStart and Manafount nodes,
# and `pcsb` is a 1 140 m model (a sky dome), not something to stand on the ground.
NOT_BUILDINGS = ("pcsb",)
SPAWN_LIFT = 0.2


def pascal_stem(stem: str) -> str:
    return "".join(part.capitalize() for part in stem.strip("_").split("_"))


def turn(facing: float) -> str:
    """The Transform3D basis of a turn about Y of -facing degrees (rotation.y = -deg_to_rad(facing)), row major."""
    angle = -math.radians(facing)
    c, s = math.cos(angle), math.sin(angle)
    return ", ".join(fmt(v) for v in (c, 0, s, 0, 1, 0, -s, 0, c))


def building_files() -> dict:
    """BuildingType tag -> file stem of data/buildings/ (the building scene has the same stem)."""
    files = {}
    for f in (ROOT / "data/buildings").glob("*.tres"):
        m = re.search(r'^tag = "(\w+)"', f.read_text(), re.M)
        if m:
            files[m.group(1)] = f.stem
    return files


def creature_files() -> dict:
    """Creature tag -> (file stem of data/catalog/creatures/, display name)."""
    files = {}
    for f in (ROOT / "data/catalog/creatures").glob("*.tres"):
        text = f.read_text()
        m = re.search(r'^display_name = "([^"]*)"', text, re.M)
        tag = re.search(r'^tag = "([^"]*)"', text, re.M)
        # The file carries a human name (trogg.tres); the original's tag is a field inside (ycro). A custom creature may have no tag: its id is the file name.
        files[tag.group(1) if tag and tag.group(1) else f.stem] = (f.stem, m.group(1) if m else f.stem)
    return files


def map_tscn(ntts: dict, seats: list) -> str:
    height_at = terrain.ground_height_fn(SCP)
    founts = [s for s in ntts["structures"] if s["tag"] in FOUNT_TAGS]
    altars = [s for s in ntts["structures"] if s["tag"] in ALTAR_TAGS and s["side"] in seats]
    if not founts or len(altars) < len(seats):
        sys.exit("scaffold_map: %s has %d manafounts and %d altars for %d seats" % (TAG, len(founts), len(altars), len(seats)))
    width = max(2, len(str(len(founts))))
    names = ["Fount%0*d" % (width, k + 1) for k in range(len(founts))]

    def y_of(row: dict) -> float:
        y = height_at(row["x"], row["z"])
        if y is None:
            sys.exit("scaffold_map: %s (%s, %s) is over a hole" % (row["tag"], row["x"], row["z"]))
        return y

    # data/buildings/<name>.tres: the file is named for humans, the tag is a field inside.
    bldg_files = {}
    for f in (ROOT / "data/buildings").glob("*.tres"):
        m = re.search(r'^tag = "(\w+)"', f.read_text(), re.M)
        if m:
            bldg_files[m.group(1)] = f.name
    ext = []   # (type, path, id) in order
    ext_ids = {}

    def resource(kind: str, path: str, key: str) -> str:
        if key not in ext_ids:
            ext_ids[key] = key
            ext.append('[ext_resource type="%s" path="%s" id="%s"]' % (kind, path, key))
        return key

    # The BLDG each fount row names (its first part is the model ManafountBody draws).
    for t in sorted({row["tag"] for row in founts}):
        resource("Resource", "res://data/buildings/%s" % bldg_files[t], "fbldg_%s" % t)
    starts = []
    for altar in sorted(altars, key=lambda a: seats.index(a["side"])):
        slot = seats.index(altar["side"]) + 1
        near = min(range(len(founts)), key=lambda k: (founts[k]["x"] - altar["x"]) ** 2 + (founts[k]["z"] - altar["z"]) ** 2)
        starts.append((slot, altar, near))
    body = [""]
    for slot, altar, near in starts:
        spot, local = wizard_spot(altar, founts[near])
        body.append("""
[node name="Start{slot}" parent="MapProps/Starts" instance=ExtResource("4_start")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, {y}, {z})
{slot_line}
[node name="WizardSpot" parent="MapProps/Starts/Start{slot}" index="1"]
transform = Transform3D({basis}, {x_off}, 0, {z_off})
""".format(slot=slot, x=fmt(altar["x"]), y=fmt(y_of(altar)), z=fmt(altar["z"]),
           slot_line="" if slot == 1 else "slot = %d\n" % slot, basis=", ".join(fmt(v) for v in spot),
           x_off=fmt(local[0]), z_off=fmt(local[1])))
    body.append('\n[node name="Founts" type="Node3D" parent="MapProps"]\n')
    for name, row in zip(names, founts):
        body.append("""
[node name="{name}" parent="MapProps/Founts" instance=ExtResource("5_fount")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, {y}, {z})
building = ExtResource("fbldg_{bldg}")
""".format(name=name, x=fmt(row["x"]), y=fmt(y_of(row)), z=fmt(row["z"]), bldg=row["tag"]))

    # Slot of each side, as SideRelations gives it: seats first, then the sides of the Npcs in the order they appear.
    creatures = [] if "--no-npcs" in ARGS else ntts["creatures"]
    npc_sides = []
    for row in creatures:
        if row["side"] not in seats and row["side"] not in npc_sides:
            npc_sides.append(row["side"])

    def slot_of(side: int) -> int:
        if side in seats:
            return seats.index(side) + 1
        if side in npc_sides:
            return len(seats) + npc_sides.index(side) + 1
        return 0

    left_out = {}
    counters = {}
    body.append('\n[node name="Props" type="Node3D" parent="."]\n')
    body.append('\n[node name="Buildings" type="Node3D" parent="."]\n')
    by_tag = building_files()
    for row in ntts["structures"]:
        tag = row["tag"]
        if tag in ALTAR_TAGS or tag in FOUNT_TAGS:
            continue
        if tag in NOT_BUILDINGS or tag not in by_tag:
            left_out.setdefault(tag + (" (not a prop)" if tag in NOT_BUILDINGS else " (no BuildingType)"), 0)
            left_out[tag + (" (not a prop)" if tag in NOT_BUILDINGS else " (no BuildingType)")] += 1
            continue
        y = height_at(row["x"], row["z"])
        if y is None:
            left_out.setdefault(tag + " (off the land)", 0)
            left_out[tag + " (off the land)"] += 1
            continue
        stem = by_tag[tag]
        counters[stem] = counters.get(stem, 0) + 1
        key = resource("PackedScene", "res://scenes/structures/buildings/%s.tscn" % stem, "d2_%s" % stem)
        owner = slot_of(row.get("side", NEUTRAL_SIDE))
        body.append("""
[node name="{name}_{n:02d}" parent="Buildings" instance=ExtResource("{key}")]
transform = Transform3D({basis}, {x}, {y}, {z})
{owner}""".format(name=pascal_stem(stem), n=counters[stem], key=key, basis=turn(float(row.get("facing", 0.0))),
                  x=fmt(row["x"]), y=fmt(y), z=fmt(row["z"]), owner="owner_slot = %d\n" % owner if owner else ""))
    body.append('\n[node name="Npcs" type="Node3D" parent="."]\n')
    types = creature_files()
    for row in creatures:
        if row["tag"] not in types:
            left_out[row["tag"] + " (no CreatureType)"] = left_out.get(row["tag"] + " (no CreatureType)", 0) + 1
            continue
        stem, display = types[row["tag"]]
        y = height_at(row["x"], row["z"])
        label = display.replace(" ", "")
        counters[label] = counters.get(label, 0) + 1
        npc = resource("PackedScene", "res://scenes/map/npc_spawn.tscn", "d2_npc_spawn")
        creature = resource("Resource", "res://data/catalog/creatures/%s.tres" % stem, "d2_%s" % stem)
        body.append("""
[node name="{name}_{n:02d}" parent="Npcs" instance=ExtResource("{npc}")]
transform = Transform3D({basis}, {x}, {y}, {z})
creature = ExtResource("{creature}")
side = {side}
""".format(name=label, n=counters[label], npc=npc, basis=turn(float(row.get("facing", 0.0))), x=fmt(row["x"]),
           y=fmt((0.0 if y is None else y) + SPAWN_LIFT), z=fmt(row["z"]), creature=creature, side=row["side"]))
    body.append(MAP_TAIL)
    if left_out:
        print("scaffold_map: left out: %s" % ", ".join("%s x%d" % kv for kv in sorted(left_out.items())))
    has_roles = (SCENES / "ground_roles.png").exists()  # tools/import/bake_ground_roles.py writes it
    head = MAP_HEAD.format(tag=TAG,
                           roles_res='\n[ext_resource type="Texture2D" path="res://scenes/map/maps/%s/ground_roles.png" id="2_roles"]' % TAG if has_roles else "",
                           roles_line='\nground_roles = ExtResource("2_roles")' if has_roles else "")
    cut = head.index("\n\n[node ")
    head = head[:cut] + "".join("\n" + line for line in ext) + head[cut:]
    return head + "".join(body)


def wizard_spot(altar: dict, fount: dict, distance: float = 30.0) -> tuple:
    """The wizard stands `distance` m from the altar toward the fount, looking at it (state.d:2357-2388): the basis (row
    major, a turn about Y) and the offset (x, z) from the altar."""
    dx, dz = fount["x"] - altar["x"], fount["z"] - altar["z"]
    length = math.hypot(dx, dz)
    off = (dx / length * distance, dz / length * distance)
    angle = math.atan2(dx - off[0], dz - off[1])
    c, s = math.cos(angle), math.sin(angle)
    return [c, 0, s, 0, 1, 0, -s, 0, c], off


PLANT_CELL_M = 8.0
PLANT_CELLS = 320
ALTAR_CLEAR_M = 40.0
FOUNT_CLEAR_M = 6.0


def png_l8(size: int, data: bytes) -> bytes:
    """A grayscale (L8) PNG of size x size pixels."""
    def chunk(kind: bytes, body: bytes) -> bytes:
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)
    raw = b"".join(b"\x00" + data[row * size:(row + 1) * size] for row in range(size))
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 0, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")


def species_files() -> dict:
    """Original plant tag -> file stem of data/vegetation/species/."""
    found = {}
    for f in (ROOT / "data/vegetation/species").glob("*.tres"):
        m = re.search(r'^tag = "([^"]*)"', f.read_text(), re.M)
        if m:
            found[m.group(1)] = f.stem
    return found


def plant_cells(rows: list, height_at, clears: list) -> list:
    """Plants per 8 m cell (row-major, 320 x 320, capped at 255): on the land, outside the altar's and the fount's clearing."""
    counts = [0] * (PLANT_CELLS * PLANT_CELLS)
    for x, z in ((row[0], row[1]) for row in rows):
        if height_at(x, z) is None or any(math.hypot(x - cx, z - cz) < radius for cx, cz, radius in clears):
            continue
        cx, cz = min(max(int(x // PLANT_CELL_M), 0), PLANT_CELLS - 1), min(max(int(z // PLANT_CELL_M), 0), PLANT_CELLS - 1)
        counts[cz * PLANT_CELLS + cx] = min(counts[cz * PLANT_CELLS + cx] + 1, 255)
    return counts


def wire_flora() -> None:
    """The plants of widgets.json as FloraLayer nodes of the existing map.tscn: per species a density PNG
    (scenes/map/maps/<tag>/flora/<species>.png, v = round(count x 255 / max), max_per_cell = max) and a node under `Vegetation`. A tag with
    no species file gets data/vegetation/species/<tag>.tres: rename it by hand. Import the project once afterwards."""
    path = SCENES / "map.tscn"
    text = path.read_text()
    if '[node name="Vegetation"' in text and not FORCE:
        print("scaffold_map: %s already has its Vegetation node" % TAG)
        return
    widgets = json.loads((ASSETS / "widgets.json").read_text())
    structures = json.loads((ASSETS / "ntts.json").read_text())["structures"]
    clears = [(s["x"], s["z"], ALTAR_CLEAR_M) for s in structures if s["tag"] in ALTAR_TAGS]
    clears += [(s["x"], s["z"], FOUNT_CLEAR_M) for s in structures if s["tag"] in FOUNT_TAGS]
    height_at = terrain.ground_height_fn(SCP)
    known = species_files()
    heads = ['[ext_resource type="Script" path="res://scenes/look/vegetation/flora_layer.gd" id="flora_layer_script"]']
    nodes = ['\n[node name="Vegetation" type="Node3D" parent="."]']
    for tag in sorted(widgets):
        counts = plant_cells(widgets[tag], height_at, clears)
        biggest = max(counts)
        if biggest == 0:
            continue
        if tag not in known:
            known[tag] = tag.lower()
            (ROOT / "data/vegetation/species").mkdir(parents=True, exist_ok=True)
            (ROOT / "data/vegetation/species" / (tag.lower() + ".tres")).write_text(
                '[gd_resource type="Resource" script_class="VegetationSpecies" load_steps=2 format=3]\n\n'
                '[ext_resource type="Script" path="res://scenes/look/vegetation/vegetation_species.gd" id="1_species"]\n\n'
                '[resource]\nscript = ExtResource("1_species")\ntag = "%s"\n' % tag)
        name = known[tag]
        png = SCENES / "flora" / (name + ".png")
        png.parent.mkdir(parents=True, exist_ok=True)
        png.write_bytes(png_l8(PLANT_CELLS, bytes(round(c * 255 / biggest) for c in counts)))
        heads.append('[ext_resource type="Resource" path="res://data/vegetation/species/%s.tres" id="sp_%s"]' % (name, name))
        heads.append('[ext_resource type="Texture2D" path="res://scenes/map/maps/%s/flora/%s.png" id="fd_%s"]' % (TAG, name, name))
        nodes.append('\n[node name="%s" type="Node3D" parent="Vegetation"]\nscript = ExtResource("flora_layer_script")\n'
                     'species = ExtResource("sp_%s")\ndensity = ExtResource("fd_%s")\nmax_per_cell = %d' % (pascal(name), name, name, biggest))
        print("scaffold_map: %s %s -> %s (max %d)" % (TAG, tag, name, biggest))
    last = max(m.end() for m in re.finditer(r"^\[ext_resource [^\n]*\n", text, re.M))
    text = text[:last] + "\n".join(heads) + "\n" + text[last:]
    path.write_text(text.rstrip("\n") + "\n" + "\n".join(nodes) + "\n")
    print("scaffold_map: %s: Vegetation wired; import the project once (Godot --import)" % TAG)


def main() -> None:
    if "--wire-flora" in ARGS:
        wire_flora()
        return
    ntts_path = ASSETS / "ntts.json"
    if not ntts_path.exists():
        sys.exit("scaffold_map: run tools/import/import_map.py (--map=<Name> or --scp=<path>) first (%s is missing)" % ntts_path)
    ntts = json.loads(ntts_path.read_text())
    seats = seats_of(ntts["sides"])
    wrote = []
    if not (SCENES / terrain_common.HEIGHTS_PNG).exists():  # never over a ground that is there, not even with --force
        write(SCENES / terrain_common.HEIGHTS_PNG, terrain_common.encode_heights([0] * terrain_common.COUNT), wrote)
    write(SCENES / (TAG + ".tres"), definition_tres(len(seats)), wrote)
    write(SCENES / "nav.res", base64.b64decode(NAV_PLACEHOLDER_B64), wrote)
    write(SCENES / "map.tscn", map_tscn(ntts, seats), wrote)
    print("scaffold_map: %s (%d seats): %s" % (TAG, len(seats), ", ".join(wrote) if wrote else "nothing new"))
    print("next: the original's ground with tools/terrain/heights_from_original.gd -- --map=%s, then Godot --import" % TAG)


if __name__ == "__main__":
    main()
