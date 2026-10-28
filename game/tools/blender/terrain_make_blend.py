"""No necesita el juego original: lee las imágenes del mapa.

Makes <map>/terrain_work/terrain.blend from a map's images, the Blender half of the round trip (plan 063D S4):
- «Terrain»: one welded plane of SIDE x SIDE vertices CELL_M apart (vertex id = row * SIDE + column, the axes of
  terrain_common), every cell cut into two triangles along the get_faces diagonal; Z = heights.png x M_PER_UNIT;
- the vertex group «void» (weight 1 where void.png is white);
- the colour attribute «roles» (one vertex = one pixel of ground_roles.png), only when the map has that image;
- the «VoidPreview» Geometry Nodes modifier, viewport only: it hides the void vertices' faces and changes no data;
- the text block «README» with the editing rules;
- terrain_work/manifest.json with the hash of the images it was made from (terrain_export_images.py checks it).
Not: writing any image (terrain_export_images.py does). It overwrites a terrain.blend of an earlier run.

Run (from game/; BLENDER_BIN is blender in the PATH or your install, e.g. /Applications/Blender.app/Contents/MacOS/Blender):
  "$BLENDER_BIN" --background --python tools/blender/terrain_make_blend.py -- --map=scenes/map/maps/<tag>
  "$BLENDER_BIN" --background --python tools/blender/terrain_make_blend.py -- --map=<dir> --flat=<m>   (a flat ground at <m> metres, no voids; roles kept)
"""

import sys
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
import terrain_common as tc  # noqa: E402

README = """Terrain (plan 063D S4). Rules, or «Traer de Blender» / terrain_export_images.py refuses the file:
- Move vertices only in Z (G Z, sculpt with Z locked, proportional editing in Z). Heights from 0 to 6553.5 m.
- Do not add, delete, merge or reorder vertices: 256 x 256 = 65536, one per pixel of heights.png.
- Do not move, rotate or scale the object «Terrain» (its transform must stay at the origin, unscaled).
- Cut a hole: paint the vertex group «void» (weight 1 = void, 0 = land) in Weight Paint. The height under a void is kept.
- The modifier «VoidPreview» only hides the void faces in the viewport. Turn it off to paint a void back to land.
- «roles» (if present) is ground_roles.png, one vertex = one pixel: paint it in Vertex Paint.
Then, from game/: "$BLENDER_BIN" --background <map>/terrain_work/terrain.blend --python tools/blender/terrain_export_images.py -- --out=<map>
"""


def fail(message):
    print("ERROR: " + message)
    sys.exit(1)


def load_sources(map_dir, flat_m):
    """(units, voids, roles or None) from the map's images; with flat_m, a flat ground without voids (roles still read)."""
    try:
        roles_path = map_dir / tc.ROLES_PNG
        roles = tc.read_roles(roles_path) if roles_path.is_file() else None
        if flat_m is not None:
            unit = tc.height_to_unit(flat_m)
            if unit is None:
                fail(f"--flat={flat_m} is outside 0..{tc.MAX_HEIGHT_M} m")
            return [unit] * tc.COUNT, [False] * tc.COUNT, roles
        heights = map_dir / tc.HEIGHTS_PNG
        if not heights.is_file():
            fail(f"{heights} does not exist (pass --flat=<m> for a new flat ground)")
        units = tc.read_heights(heights)
        void_path = map_dir / tc.VOID_PNG
        voids = tc.read_void(void_path) if void_path.is_file() else [False] * tc.COUNT
    except tc.PngError as error:
        fail(str(error))
    return units, voids, roles


def build_mesh(units):
    mesh = bpy.data.meshes.new("Terrain")
    vertices = []
    for vertex_id in range(tc.COUNT):
        x, y = tc.vertex_xy(vertex_id)
        vertices.append((x, y, units[vertex_id] * tc.M_PER_UNIT))
    faces = []
    for row in range(tc.SIDE - 1):
        for column in range(tc.SIDE - 1):
            faces.extend(tc.cell_triangles(column, row))
    mesh.from_pydata(vertices, [], faces)
    mesh.validate()
    mesh.update()
    return mesh


def add_roles(mesh, roles):
    attribute = mesh.color_attributes.new("roles", "FLOAT_COLOR", "POINT")
    flat = []
    for r, g, b, a in roles:
        flat += (tc.srgb_to_linear(r), tc.srgb_to_linear(g), tc.srgb_to_linear(b), a / 255.0)
    attribute.data.foreach_set("color", flat)
    mesh.color_attributes.active_color = attribute


def void_preview_group():
    """Named attribute «void» > 0.5 -> Delete Geometry (points): every face with a void corner goes, as in the game."""
    group = bpy.data.node_groups.new("VoidPreview", "GeometryNodeTree")
    group.interface.new_socket("Geometry", in_out="INPUT", socket_type="NodeSocketGeometry")
    group.interface.new_socket("Geometry", in_out="OUTPUT", socket_type="NodeSocketGeometry")
    nodes, links = group.nodes, group.links
    source = nodes.new("NodeGroupInput")
    sink = nodes.new("NodeGroupOutput")
    attribute = nodes.new("GeometryNodeInputNamedAttribute")
    attribute.data_type = "FLOAT"
    attribute.inputs["Name"].default_value = "void"
    compare = nodes.new("FunctionNodeCompare")
    compare.data_type = "FLOAT"
    compare.operation = "GREATER_THAN"
    compare.inputs[1].default_value = 0.5
    delete = nodes.new("GeometryNodeDeleteGeometry")
    delete.domain = "POINT"
    links.new(attribute.outputs["Attribute"], compare.inputs[0])
    links.new(source.outputs[0], delete.inputs["Geometry"])
    links.new(compare.outputs["Result"], delete.inputs["Selection"])
    links.new(delete.outputs["Geometry"], sink.inputs[0])
    return group


def main():
    args = tc.user_args()
    if "map" not in args or args["map"] is True:
        fail("pass -- --map=<map dir> (and optionally --flat=<m>)")
    map_dir = Path(args["map"]).resolve()
    flat_m = None
    if "flat" in args:
        try:
            flat_m = float(args["flat"])
        except ValueError:
            fail(f"--flat={args['flat']} is not a number of metres")
    units, voids, roles = load_sources(map_dir, flat_m)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    mesh = build_mesh(units)
    terrain = bpy.data.objects.new("Terrain", mesh)
    bpy.context.scene.collection.objects.link(terrain)
    group = terrain.vertex_groups.new(name="void")
    void_ids = [i for i, v in enumerate(voids) if v]
    if void_ids:
        group.add(void_ids, 1.0, "REPLACE")
    if roles is not None:
        add_roles(mesh, roles)
    modifier = terrain.modifiers.new("VoidPreview", "NODES")
    modifier.node_group = void_preview_group()
    modifier.show_render = False
    modifier.show_in_editmode = False
    text = bpy.data.texts.new("README")
    text.write(README)
    source_hash = tc.sources_hash(map_dir)

    blend = tc.work_dir(map_dir) / tc.BLEND_NAME
    bpy.ops.wm.save_as_mainfile(filepath=str(blend), check_existing=False)
    tc.write_manifest(map_dir, {
        "made_from": "flat %s m" % flat_m if flat_m is not None else "images",
        "source_sha256": source_hash,
        "vertex_count": len(mesh.vertices),
        "voids": len(void_ids),
        "roles": roles is not None,
    })
    print(f"TERRAIN BLEND {blend} ({len(mesh.vertices)} vertices, {len(void_ids)} voids, roles={roles is not None})")


main()
