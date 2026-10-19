#!/usr/bin/env python3
"""No necesita el juego original: usa los assets ya importados en assets/original (versionados).

The Godot side of an imported map (RFC-050): the files a map needs besides its assets.

  python3 tools/import/scaffold_map.py --map=Peaks            # write what is missing, list what it wrote
  python3 tools/import/scaffold_map.py --map=Peaks --force    # overwrite map.tscn and the definition (they are hand-edited afterwards)

Run tools/import/import_map.py first (it writes ntts.json, tiles.png, ...). For `<tag>` it writes:
  assets/original/maps/<tag>/sides.tres            MapSides, from the SIDS of the .scp (bake_map_layout rewrites it the same)
  assets/original/maps/<tag>/terrain.glb.import    the post-import of the ground (tools/terrain_import.gd), so Godot reads the glb as a terrain
  scenes/map/maps/<tag>/<tag>.tres                 MapDefinition
  scenes/map/maps/<tag>/map.tscn                   MapRoot: sky, look, terrain, one PlayerStart per seat and the manafounts, layout, navmesh, minimap
  data/maps/map_catalog.tres                       the definition is added to the list (nothing is removed)
The PlayerStart and the manafounts are the altar and manafount rows of the NTTS, placed on the ground height the game would give
them (sac_formats.terrain.ground_height_fn); the start of seat k faces the closest manafount, as sacengine puts the wizard.
The layout (buildings, plants, NPCs) and the navmesh are baked by Godot afterwards: tools/bake/bake_map_layout.gd and bake_nav.gd.
Nothing here is read at runtime. Idempotent: an existing file is kept unless --force.
"""

import json
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
CATALOG = ROOT / "data" / "maps" / "map_catalog.tres"
FORCE = "--force" in ARGS

# The altar and the manafount of each land (flags 0x80001407 and 0x80002810 in data/catalog/buildings/). Same lists as
# tools/bake/bake_map_layout.gd: those rows are PlayerStart and Manafount nodes of the map scene, not buildings of the layout.
ALTAR_TAGS = ("jaal", "ca_a", "pyal", "stal", "alt1")
FOUNT_TAGS = ("jfnt", "cafn", "pfon", "stmf", "font")
NEUTRAL_SIDE = 31


def pascal(tag: str) -> str:
    return "".join(part.capitalize() for part in tag.split("_"))


def fmt(value: float) -> str:
    text = ("%.4f" % value).rstrip("0").rstrip(".")
    return text if text not in ("", "-0") else "0"


def write(path: Path, text: str, wrote: list) -> None:
    if path.exists() and not FORCE:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    wrote.append(str(path.relative_to(ROOT)))


def seats_of(sides: list) -> list:
    """Side ids a player takes (assignment != 0), in order: seat k (slot k + 1) is the k-th."""
    return sorted(s["id"] for s in sides if s["id"] != NEUTRAL_SIDE and s["assignment"] != 0)


def sides_tres(sides: list) -> str:
    def arr(key: str) -> str:
        return "PackedInt64Array(%s)" % ", ".join(str(s[key]) for s in sides)

    return """[gd_resource type="Resource" script_class="MapSides" format=3]

[ext_resource type="Script" path="res://scenes/map/map_sides.gd" id="1_sides"]

[resource]
script = ExtResource("1_sides")
ids = %s
allies = %s
enemies = %s
assignment = %s
colors = %s
""" % (arr("id"), arr("allies"), arr("enemies"), arr("assignment"), arr("color"))


def definition_tres(seats: int) -> str:
    return """[gd_resource type="Resource" script_class="MapDefinition" load_steps=3 format=3]

[ext_resource type="Script" path="res://scenes/map/map_definition.gd" id="1_def"]
[ext_resource type="Resource" path="res://assets/original/maps/{tag}/sides.tres" id="2_sides"]

[resource]
script = ExtResource("1_def")
tag = &"{tag}"
display_name = "{name}"
map_scene_path = "res://scenes/map/maps/{tag}/map.tscn"
sides = ExtResource("2_sides")
terrain_path = "res://assets/original/maps/{tag}/terrain.res"
tiles_path = "res://assets/original/maps/{tag}/tiles.png"
light_path = "res://assets/original/maps/{tag}/light.png"
nav_path = "res://scenes/map/maps/{tag}/nav.res"
player_starts = {seats}
layout_scene_path = "res://scenes/map/maps/{tag}/layout.tscn"
ntts_path = "res://assets/original/maps/{tag}/ntts.json"
widgets_path = "res://assets/original/maps/{tag}/widgets.json"
""".format(tag=TAG, name=import_map.display_name(SCP), seats=seats)


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
[ext_resource type="Environment" path="res://data/look/env_base.tres" id="6_env"]
[ext_resource type="PackedScene" path="res://scenes/look/sky/sky.tscn" id="7_sky"]
[ext_resource type="PackedScene" path="res://scenes/look/look_rig.tscn" id="8_look"]
[ext_resource type="Resource" path="res://data/look/ground/high_noon_tiles.tres" id="9_tiles"]
[ext_resource type="Resource" path="res://assets/original/maps/{tag}/terrain.res" id="10_data"]
[ext_resource type="Material" path="res://assets/original/themes/james/ground_classic.tres" id="11_ground"]
[ext_resource type="PackedScene" path="res://assets/original/maps/{tag}/terrain.glb" id="12_glb"]
[ext_resource type="PackedScene" path="res://scenes/map/maps/{tag}/layout.tscn" id="13_layout"]
[ext_resource type="Resource" path="res://data/nav/nav_bake.tres" id="14_bake"]
[ext_resource type="NavigationMesh" path="res://scenes/map/maps/{tag}/nav.res" id="15_navmesh"]
[ext_resource type="Script" path="res://scenes/map/nav/map_nav_region.gd" id="16_nav_region"]
[ext_resource type="PackedScene" path="res://scenes/ui/minimap/minimap_terrain_bake.tscn" id="17_minimap"]

[node name="Map" type="Node3D" node_paths=PackedStringArray("terrain", "nav_region", "starts", "look", "minimap_bake", "buildings_root", "npc_spawns_root")]
script = ExtResource("1_root")
terrain = NodePath("Terrain")
nav_region = NodePath("NavRegion")
starts = NodePath("MapProps/Starts")
look = NodePath("Look")
minimap_bake = NodePath("MinimapBake")
buildings_root = NodePath("{layout}/Buildings")
npc_spawns_root = NodePath("{layout}/NpcSpawns")

[node name="Sky" parent="." instance=ExtResource("7_sky")]
unique_name_in_owner = true
background_color = Color(2.8878452e-07, 0.92139935, 0.5927794, 1)
top_path = "res://assets/original/themes/persephone/skyt.png"
bottom_path = "res://assets/original/themes/persephone/skyb.png"
clouds_path = "res://assets/original/themes/persephone/sky.png"

[node name="Environment" type="WorldEnvironment" parent="."]
unique_name_in_owner = true
environment = ExtResource("6_env")

[node name="Look" parent="." node_paths=PackedStringArray("sun", "world_environment", "terrain", "legacy_sky") instance=ExtResource("8_look")]
unique_name_in_owner = true
sun = NodePath("../Sun")
world_environment = NodePath("../Environment")
terrain = NodePath("../Terrain")
legacy_sky = NodePath("../Sky")
tile_map = ExtResource("9_tiles")

[node name="Sun" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.921061, -0.27935162, 0.27131036, 0, 0.6967067, 0.7173561, -0.38941833, -0.6607287, 0.6417094, 0, 0, 0)
shadow_enabled = true

[node name="Terrain" parent="." groups=["nav_source"] instance=ExtResource("12_glb")]
unique_name_in_owner = true
material_override = ExtResource("11_ground")
script = ExtResource("2_terrain")
data = ExtResource("10_data")

[node name="Missing" type="Label3D" parent="Terrain"]
visible = false
text = "UI_MAP_MISSING"
font_size = 48

[node name="MapProps" type="Node3D" parent="." node_paths=PackedStringArray("plants_root")]
script = ExtResource("3_props")
plants_root = NodePath("../{layout}/Plants")

[node name="Starts" type="Node3D" parent="MapProps"]
"""

MAP_TAIL = """
[node name="{layout}" parent="." instance=ExtResource("13_layout")]

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
    layout = pascal(TAG) + "Layout"
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

    out = [MAP_HEAD.format(tag=TAG, layout=layout)]
    # The BLDG each fount row names (its BASE component is the model ManafountBody draws), right after the head's resources.
    fount_bldgs = sorted({row["tag"] for row in founts})
    cut = out[0].index("\n\n[node ")
    out[0] = out[0][:cut] + "".join(
        '\n[ext_resource type="Resource" path="res://data/catalog/buildings/%s.tres" id="fbldg_%s"]' % (t, t)
        for t in fount_bldgs) + out[0][cut:]
    starts = []
    for altar in sorted(altars, key=lambda a: seats.index(a["side"])):
        slot = seats.index(altar["side"]) + 1
        near = min(range(len(founts)), key=lambda k: (founts[k]["x"] - altar["x"]) ** 2 + (founts[k]["z"] - altar["z"]) ** 2)
        starts.append((slot, altar, near))
    for slot, altar, near in starts:
        out.append("""
[node name="Start{slot}" parent="MapProps/Starts" node_paths=PackedStringArray("faces") instance=ExtResource("4_start")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, {y}, {z})
{slot_line}faces = NodePath("../../Founts/{fount}")
""".format(slot=slot, x=fmt(altar["x"]), y=fmt(y_of(altar)), z=fmt(altar["z"]),
           slot_line="" if slot == 1 else "slot = %d\n" % slot, fount=names[near]))
    out.append('\n[node name="Founts" type="Node3D" parent="MapProps"]\n')
    for name, row in zip(names, founts):
        out.append("""
[node name="{name}" parent="MapProps/Founts" instance=ExtResource("5_fount")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, {y}, {z})
building = ExtResource("fbldg_{bldg}")
""".format(name=name, x=fmt(row["x"]), y=fmt(y_of(row)), z=fmt(row["z"]), bldg=row["tag"]))
    out.append(MAP_TAIL.format(layout=layout))
    return "".join(out)


def add_to_catalog(wrote: list) -> None:
    text = CATALOG.read_text()
    path = "res://scenes/map/maps/%s/%s.tres" % (TAG, TAG)
    if path in text:
        return
    ids = [int(n) for n in re.findall(r'id="(\d+)_', text)]
    ext_id = "%d_%s" % (max(ids) + 1, TAG)
    cut = text.index("\n\n[resource]")
    text = text[:cut] + '\n[ext_resource type="Resource" path="%s" id="%s"]' % (path, ext_id) + text[cut:]
    text = re.sub(r'maps = Array\[ExtResource\("([^"]+)"\)\]\(\[(.*)\]\)',
                  lambda m: 'maps = Array[ExtResource("%s")]([%s, ExtResource("%s")])' % (m.group(1), m.group(2), ext_id), text)
    steps = int(re.search(r"load_steps=(\d+)", text).group(1)) + 1
    text = re.sub(r"load_steps=\d+", "load_steps=%d" % steps, text, count=1)
    CATALOG.write_text(text)
    wrote.append(str(CATALOG.relative_to(ROOT)))


def main() -> None:
    ntts_path = ASSETS / "ntts.json"
    if not ntts_path.exists():
        sys.exit("scaffold_map: run tools/import/import_map.py --map=%s first (%s is missing)" % (ARGS.get("--map"), ntts_path))
    ntts = json.loads(ntts_path.read_text())
    seats = seats_of(ntts["sides"])
    wrote = []
    write(ASSETS / "sides.tres", sides_tres(ntts["sides"]), wrote)
    write(ASSETS / "terrain.glb.import", GLB_IMPORT.format(tag=TAG), wrote)
    write(SCENES / (TAG + ".tres"), definition_tres(len(seats)), wrote)
    write(SCENES / "map.tscn", map_tscn(ntts, seats), wrote)
    add_to_catalog(wrote)
    print("scaffold_map: %s (%d seats): %s" % (TAG, len(seats), ", ".join(wrote) if wrote else "nothing new"))


if __name__ == "__main__":
    main()
