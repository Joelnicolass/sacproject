"""Blender CLI: builds the two meshes of the walls of 061g and exports them as OBJ under assets/custom/walls/.

  /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/bake/make_wall_meshes.py

wall_strip.obj  The strip a Firewall / Wailing Wall is drawn with: a gable roof (two sheets from (+-0.5, 0) through (+-0.2, 0.4) to (0, 1),
                x across the section, y up) repeated over SECTIONS + 1 sections along the wall, x from -0.5 to 0.5 (1 m long in all). UV
                v runs from the base (1) through the break (0.6) to the ridge (0), u along the wall. The wall shader stretches it to the
                wall's length, thickness and height, bends it over the land and slopes its ends (wall.gdshaderinc).
vine_tube.obj   A vine without bones: a tube of 24 sides and 19 segments along +Y, 1 m long, radius 0.1 m at the root and 0 at the tip,
                UV u around and v along (v = 0 at the root). The Vinewall shader bends it (wall_vine.gdshader).

Both are in Godot's frame (Y up). Needs no original game file.
"""
import math
import sys
from pathlib import Path

import bpy

SECTIONS = 128
PROFILE = [(-0.5, 0.0), (-0.2, 0.4), (0.0, 1.0), (0.2, 0.4), (0.5, 0.0)]
SIDES, SEGMENTS, ROOT_RADIUS = 24, 19, 0.1
OUT = Path(__file__).resolve().parents[2] / "assets" / "custom" / "walls"


def blender_of(gx, gy, gz):
    """Godot (x, y up, z) to Blender (x, y, z up) so the OBJ exporter (-Z forward, Y up) writes it back as it is."""
    return (gx, -gz, gy)


def make(name, verts, faces, uvs):
    """An object from Godot-frame vertices, quads (indices) and per-corner UVs (one (u, v) per index of each face)."""
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([blender_of(*v) for v in verts], [], faces)
    layer = mesh.uv_layers.new(name="UVMap")
    for polygon in mesh.polygons:
        for corner, loop in enumerate(polygon.loop_indices):
            layer.data[loop].uv = uvs[polygon.index][corner]
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def export(obj, file):
    for other in bpy.context.scene.objects:
        other.select_set(other == obj)
    bpy.context.view_layer.objects.active = obj
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.obj_export(filepath=str(OUT / file), export_selected_objects=True, export_materials=False, export_normals=False,
                          export_uv=True, forward_axis="NEGATIVE_Z", up_axis="Y")
    print(file, "written:", OUT / file, file=sys.stderr)


bpy.ops.wm.read_factory_settings(use_empty=True)

# The wall strip.
verts, faces, uvs = [], [], []
for i in range(SECTIONS + 1):
    x = -0.5 + i / SECTIONS
    for z, y in PROFILE:
        verts.append((x, y, z))
width = len(PROFILE)
for i in range(SECTIONS):
    for k in range(width - 1):
        a, b = i * width + k, i * width + k + 1
        c, d = (i + 1) * width + k + 1, (i + 1) * width + k
        faces.append((a, b, c, d))
        u0, u1 = i / SECTIONS, (i + 1) / SECTIONS
        v0, v1 = 1.0 - PROFILE[k][1], 1.0 - PROFILE[k + 1][1]
        uvs.append(((u0, v0), (u0, v1), (u1, v1), (u1, v0)))
export(make("WallStrip", verts, faces, uvs), "wall_strip.obj")

# The vine tube.
verts, faces, uvs = [], [], []
for i in range(SEGMENTS + 1):
    t = i / SEGMENTS
    radius = ROOT_RADIUS * (1.0 - t)
    for k in range(SIDES):
        angle = math.tau * k / SIDES
        verts.append((math.cos(angle) * radius, t, math.sin(angle) * radius))
for i in range(SEGMENTS):
    for k in range(SIDES):
        k2 = (k + 1) % SIDES
        faces.append((i * SIDES + k, i * SIDES + k2, (i + 1) * SIDES + k2, (i + 1) * SIDES + k))
        uvs.append(((k / SIDES, i / SEGMENTS), ((k + 1) / SIDES, i / SEGMENTS), ((k + 1) / SIDES, (i + 1) / SEGMENTS), (k / SIDES, (i + 1) / SEGMENTS)))
export(make("VineTube", verts, faces, uvs), "vine_tube.obj")
