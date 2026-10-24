#!/usr/bin/env python3
"""No necesita el juego original: usa los assets ya importados en assets/original (versionados).

The Godot side of an imported map (RFC-050): the files a map needs besides its assets.

  python3 tools/import/scaffold_map.py --map=Peaks            # write what is missing, list what it wrote
  python3 tools/import/scaffold_map.py --map=Peaks --force    # overwrite map.tscn and the definition (they are hand-edited afterwards)

Run tools/import/import_map.py first (it writes ntts.json, tiles.png, ...). For `<tag>` it writes:
  assets/original/maps/<tag>/terrain.glb.import    the post-import of the ground (tools/terrain_import.gd), so Godot reads the glb as a terrain
  scenes/map/maps/<tag>/<tag>.tres                 MapDefinition (typed: scene, terrain, tiles, light, navmesh); MapCatalog finds it by scanning the folder
  scenes/map/maps/<tag>/nav.res                    an empty navmesh, so the definition loads until the first bake
  scenes/map/maps/<tag>/map.tscn                   MapRoot: sky, look, terrain, one PlayerStart (with its WizardSpot) per seat and the manafounts, empty Buildings and Npcs, navmesh, minimap
The PlayerStart and the manafounts are the altar and manafount rows of the NTTS, placed on the ground height the game would give
them (sac_formats.terrain.ground_height_fn); the WizardSpot of seat k is 30 m toward the closest manafount, looking at it, as sacengine puts the wizard.
The buildings and the creatures are dragged into Buildings and Npcs in the editor; the navmesh is baked with the «Hornear navmesh» button of the NavRegion.
Nothing here is read at runtime. Idempotent: an existing file is kept unless --force.
"""

import base64
import json
import math
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import import_map  # noqa: E402
from sac_formats import terrain  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
ARGS = import_map.ARGS
SCP = import_map.SCP
TAG = import_map.TAG
ASSETS = ROOT / "assets" / "original" / "maps" / TAG
SCENES = ROOT / "scenes" / "map" / "maps" / TAG
FORCE = "--force" in ARGS

# The altar and the manafount of each land (flags 0x80001407 and 0x80002810 in data/buildings/). Same lists as
# tools/bake/plant_clears.py: those rows are PlayerStart and Manafount nodes of the map scene, not buildings.
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
[ext_resource type="Resource" path="res://assets/original/maps/{tag}/terrain.res" id="3_terrain"]
[ext_resource type="Image" path="res://assets/original/maps/{tag}/tiles.png" id="4_tiles"]
[ext_resource type="Texture2D" path="res://assets/original/maps/{tag}/light.png" id="5_light"]
[ext_resource type="NavigationMesh" path="res://scenes/map/maps/{tag}/nav.res" id="6_nav"]

[resource]
script = ExtResource("1_def")
tag = &"{tag}"
display_name = "{name}"
map_scene = ExtResource("2_scene")
terrain = ExtResource("3_terrain")
tiles = ExtResource("4_tiles")
light = ExtResource("5_light")
nav = ExtResource("6_nav")
player_starts = {seats}
""".format(tag=TAG, name=import_map.display_name(SCP), seats=seats)


# An empty NavigationMesh saved by Godot as a binary .res (ResourceSaver.save(NavigationMesh.new(), "x.res")), base64.
NAV_PLACEHOLDER_B64 = "UlNSQwAAAAAAAAAABAAAAAcAAAAGAAAADwAAAE5hdmlnYXRpb25NZXNoAAAAAAAAAAAAAwAAAP//////////AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAcAAAAGAAAAHJlc291cmNlX2xvY2FsX3RvX3NjZW5lAA4AAAByZXNvdXJjZV9uYW1lAAkAAAB2ZXJ0aWNlcwAJAAAAcG9seWdvbnMAFgAAAHNhbXBsZV9wYXJ0aXRpb25fdHlwZQAeAAAAZ2VvbWV0cnlfcGFyc2VkX2dlb21ldHJ5X3R5cGUAGAAAAGdlb21ldHJ5X2NvbGxpc2lvbl9tYXNrAB4AAABnZW9tZXRyeV9zb3VyY2VfZ2VvbWV0cnlfbW9kZQAKAAAAY2VsbF9zaXplAAwAAABjZWxsX2hlaWdodAAMAAAAYm9yZGVyX3NpemUADQAAAGFnZW50X2hlaWdodAANAAAAYWdlbnRfcmFkaXVzABAAAABhZ2VudF9tYXhfY2xpbWIAEAAAAGFnZW50X21heF9zbG9wZQAQAAAAcmVnaW9uX21pbl9zaXplABIAAAByZWdpb25fbWVyZ2Vfc2l6ZQAQAAAAZWRnZV9tYXhfbGVuZ3RoAA8AAABlZGdlX21heF9lcnJvcgAVAAAAdmVydGljZXNfcGVyX3BvbHlnb24AFwAAAGRldGFpbF9zYW1wbGVfZGlzdGFuY2UAGAAAAGRldGFpbF9zYW1wbGVfbWF4X2Vycm9yAB0AAABmaWx0ZXJfbG93X2hhbmdpbmdfb2JzdGFjbGVzABMAAABmaWx0ZXJfbGVkZ2Vfc3BhbnMAIQAAAGZpbHRlcl93YWxrYWJsZV9sb3dfaGVpZ2h0X3NwYW5zABMAAABmaWx0ZXJfYmFraW5nX2FhYmIAGgAAAGZpbHRlcl9iYWtpbmdfYWFiYl9vZmZzZXQABwAAAHNjcmlwdAAAAAAAAQAAAB0AAABsb2NhbDovL05hdmlnYXRpb25NZXNoXzhmMG8wABgDAAAAAAAADwAAAE5hdmlnYXRpb25NZXNoAAEAAAAbAAAAAQAAAFJTUkM="


GLB_IMPORT = """[remap]

importer="scene"
importer_version=1
type="PackedScene"

[deps]

source_file="res://assets/original/maps/{tag}/terrain.glb"

[params]

nodes/root_type=""
nodes/root_name=""
nodes/root_script=null
mesh_library/use_node_names_as_mesh_names=false
array_mesh/deduplicate_surfaces=true
nodes/apply_root_scale=true
nodes/root_scale=1.0
nodes/import_as_skeleton_bones=false
nodes/use_name_suffixes=true
nodes/use_node_type_suffixes=true
meshes/ensure_tangents=false
meshes/generate_lods=false
meshes/create_shadow_meshes=false
meshes/light_baking=0
meshes/lightmap_texel_size=0.2
meshes/force_disable_compression=true
skins/use_named_skins=true
animation/import=false
animation/fps=30
animation/trimming=false
animation/remove_immutable_tracks=true
animation/import_rest_as_RESET=false
import_script/path="res://tools/terrain_import.gd"
materials/extract=0
materials/extract_format=0
materials/extract_path=""
_subresources={{}}
gltf/naming_version=2
gltf/embedded_image_handling=1
gltf/texture_map_mode=0
"""

MAP_HEAD = """[gd_scene format=3]

[ext_resource type="Script" path="res://scenes/map/map_root.gd" id="1_root"]
[ext_resource type="Script" path="res://scenes/map/terrain/terrain.gd" id="2_terrain"]
[ext_resource type="Script" path="res://scenes/map/props/map_props.gd" id="3_props"]
[ext_resource type="PackedScene" path="res://scenes/map/props/player_start.tscn" id="4_start"]
[ext_resource type="PackedScene" path="res://scenes/map/props/manafount.tscn" id="5_fount"]
[ext_resource type="PackedScene" path="res://scenes/look/look_rig.tscn" id="8_look"]
[ext_resource type="Resource" path="res://data/look/ground/high_noon_tiles.tres" id="9_tiles"]
[ext_resource type="Resource" path="res://assets/original/maps/{tag}/terrain.res" id="10_data"]
[ext_resource type="Material" path="res://assets/original/themes/james/ground_classic.tres" id="11_ground"]
[ext_resource type="PackedScene" path="res://assets/original/maps/{tag}/terrain.glb" id="12_glb"]
[ext_resource type="Resource" path="res://data/nav/nav_bake.tres" id="14_bake"]
[ext_resource type="NavigationMesh" path="res://scenes/map/maps/{tag}/nav.res" id="15_navmesh"]
[ext_resource type="Script" path="res://scenes/map/nav/map_nav_region.gd" id="16_nav_region"]
[ext_resource type="PackedScene" path="res://scenes/ui/minimap/minimap_terrain_bake.tscn" id="17_minimap"]

[node name="Map" type="Node3D" node_paths=PackedStringArray("terrain", "nav_region", "starts", "look", "minimap_bake", "buildings", "npcs")]
script = ExtResource("1_root")
terrain = NodePath("Terrain")
nav_region = NodePath("NavRegion")
starts = NodePath("MapProps/Starts")
look = NodePath("Look")
minimap_bake = NodePath("MinimapBake")
buildings = NodePath("Buildings")
npcs = NodePath("Npcs")

[node name="Look" parent="." node_paths=PackedStringArray("terrain") instance=ExtResource("8_look")]
unique_name_in_owner = true
terrain = NodePath("../Terrain")
tile_map = ExtResource("9_tiles")

[node name="Terrain" parent="." groups=["nav_source"] instance=ExtResource("12_glb")]
unique_name_in_owner = true
material_override = ExtResource("11_ground")
script = ExtResource("2_terrain")
data = ExtResource("10_data")

[node name="Missing" type="Label3D" parent="Terrain"]
visible = false
text = "UI_MAP_MISSING"
font_size = 48

[node name="MapProps" type="Node3D" parent="."]
script = ExtResource("3_props")

[node name="Starts" type="Node3D" parent="MapProps"]
"""

MAP_TAIL = """
[node name="Buildings" type="Node3D" parent="."]

[node name="Npcs" type="Node3D" parent="."]

[node name="NavRegion" type="NavigationRegion3D" parent="."]
unique_name_in_owner = true
navigation_mesh = ExtResource("15_navmesh")
script = ExtResource("16_nav_region")
bake_settings = ExtResource("14_bake")

[node name="MinimapBake" parent="." node_paths=PackedStringArray("terrain") instance=ExtResource("17_minimap")]
unique_name_in_owner = true
terrain = NodePath("../Terrain")
"""


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

    out = [MAP_HEAD.format(tag=TAG)]
    # data/buildings/<name>.tres: the file is named for humans, the tag is a field inside.
    bldg_files = {}
    for f in (ROOT / "data/buildings").glob("*.tres"):
        m = re.search(r'^tag = "(\w+)"', f.read_text(), re.M)
        if m:
            bldg_files[m.group(1)] = f.name
    # The BLDG each fount row names (its first part is the model ManafountBody draws), right after the head's resources.
    fount_bldgs = sorted({row["tag"] for row in founts})
    cut = out[0].index("\n\n[node ")
    out[0] = out[0][:cut] + "".join(
        '\n[ext_resource type="Resource" path="res://data/buildings/%s" id="fbldg_%s"]' % (bldg_files[t], t)
        for t in fount_bldgs) + out[0][cut:]
    starts = []
    for altar in sorted(altars, key=lambda a: seats.index(a["side"])):
        slot = seats.index(altar["side"]) + 1
        near = min(range(len(founts)), key=lambda k: (founts[k]["x"] - altar["x"]) ** 2 + (founts[k]["z"] - altar["z"]) ** 2)
        starts.append((slot, altar, near))
    for slot, altar, near in starts:
        spot, local = wizard_spot(altar, founts[near])
        out.append("""
[node name="Start{slot}" parent="MapProps/Starts" instance=ExtResource("4_start")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, {y}, {z})
{slot_line}
[node name="WizardSpot" parent="MapProps/Starts/Start{slot}" index="1"]
transform = Transform3D({basis}, {x_off}, 0, {z_off})
""".format(slot=slot, x=fmt(altar["x"]), y=fmt(y_of(altar)), z=fmt(altar["z"]),
           slot_line="" if slot == 1 else "slot = %d\n" % slot, basis=", ".join(fmt(v) for v in spot),
           x_off=fmt(local[0]), z_off=fmt(local[1])))
    out.append('\n[node name="Founts" type="Node3D" parent="MapProps"]\n')
    for name, row in zip(names, founts):
        out.append("""
[node name="{name}" parent="MapProps/Founts" instance=ExtResource("5_fount")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, {y}, {z})
building = ExtResource("fbldg_{bldg}")
""".format(name=name, x=fmt(row["x"]), y=fmt(y_of(row)), z=fmt(row["z"]), bldg=row["tag"]))
    out.append(MAP_TAIL)
    return "".join(out)


def wizard_spot(altar: dict, fount: dict, distance: float = 30.0) -> tuple:
    """The wizard stands `distance` m from the altar toward the fount, looking at it (state.d:2357-2388): the basis (row
    major, a turn about Y) and the offset (x, z) from the altar."""
    dx, dz = fount["x"] - altar["x"], fount["z"] - altar["z"]
    length = math.hypot(dx, dz)
    off = (dx / length * distance, dz / length * distance)
    angle = math.atan2(dx - off[0], dz - off[1])
    c, s = math.cos(angle), math.sin(angle)
    return [c, 0, s, 0, 1, 0, -s, 0, c], off


def main() -> None:
    ntts_path = ASSETS / "ntts.json"
    if not ntts_path.exists():
        sys.exit("scaffold_map: run tools/import/import_map.py --map=%s first (%s is missing)" % (ARGS.get("--map"), ntts_path))
    ntts = json.loads(ntts_path.read_text())
    seats = seats_of(ntts["sides"])
    wrote = []
    write(ASSETS / "terrain.glb.import", GLB_IMPORT.format(tag=TAG), wrote)
    write(SCENES / (TAG + ".tres"), definition_tres(len(seats)), wrote)
    write(SCENES / "nav.res", base64.b64decode(NAV_PLACEHOLDER_B64), wrote)
    write(SCENES / "map.tscn", map_tscn(ntts, seats), wrote)
    print("scaffold_map: %s (%d seats): %s" % (TAG, len(seats), ", ".join(wrote) if wrote else "nothing new"))


if __name__ == "__main__":
    main()
