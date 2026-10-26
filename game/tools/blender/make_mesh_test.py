"""No necesita el juego original (genera su propia isla).

RFC-063: the test island of the free-mesh ground, 1200 x 800 m, deterministic (same file every run):
  - a flat island at 10 m with a 20 m lattice, its rim a steep skirt down to -40 m (a wall: it collides, it gives no height);
  - a hill (28 m) at (600, 240), a cliff plateau (+30 m) at x 900..1100, z 500..700, a pit (-28 m, radius 50) at (300, 600);
  - an arch at (600, 600): two pillars and a lintel whose roof is at 28 m, 14 m over the ground it spans.
Positions are in Godot metres (x, z); Blender's y is -z. Also writes the numbers the checks read (mesh_test_spec.json).

Run (from game/; BLENDER is blender in the PATH or $BLENDER):
  "$BLENDER" --background --python tools/blender/make_mesh_test.py -- --out=scenes/map/maps/mesh_test/ground.glb [--spec=debug/map/mesh_test_spec.json]
"""
import json
import math
import os
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import export_ground  # noqa: E402

WIDTH, DEPTH, STEP = 1200, 800, 20
BASE_Y, RIM_Y = 10.0, -40.0
HILL = {"x": 600, "z": 240, "radius": 170.0, "height": 28.0}
PLATEAU = {"x": (900, 1100), "z": (500, 700), "rise": 30.0}
PIT = {"x": 300, "z": 600, "radius": 50.0, "drop": 28.0}
ARCH = {"x": (570, 630), "z": (590, 610), "pillar": 10, "floor_y": BASE_Y, "lintel_bottom": 24.0, "roof_y": 28.0}
STARTS = {"start1": (150, 250), "start2": (1050, 250), "fount1": (300, 250), "fount2": (900, 250)}


def height(x: float, z: float) -> float:
    """The island's height at a lattice node, in Godot (x, z)."""
    if x <= 0 or z <= 0 or x >= WIDTH or z >= DEPTH:
        return RIM_Y
    y = BASE_Y
    d = math.hypot(x - HILL["x"], z - HILL["z"])
    if d < HILL["radius"]:
        t = 1.0 - d / HILL["radius"]
        y += HILL["height"] * t * t * (3.0 - 2.0 * t)
    if PLATEAU["x"][0] <= x <= PLATEAU["x"][1] and PLATEAU["z"][0] <= z <= PLATEAU["z"][1]:
        y += PLATEAU["rise"]
    if math.hypot(x - PIT["x"], z - PIT["z"]) <= PIT["radius"]:
        y -= PIT["drop"]
    return y


def material(name: str, color: tuple):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = color
    return mat


def island() -> bpy.types.Object:
    """The heightfield: one quad per lattice cell, cut in two triangles along an alternating diagonal, facing up."""
    nx, nz = WIDTH // STEP, DEPTH // STEP
    verts = [(i * STEP, -k * STEP, height(i * STEP, k * STEP)) for k in range(nz + 1) for i in range(nx + 1)]
    faces = []
    for k in range(nz):
        for i in range(nx):
            a, b = k * (nx + 1) + i, k * (nx + 1) + i + 1
            d, c = (k + 1) * (nx + 1) + i, (k + 1) * (nx + 1) + i + 1
            # Blender looks from +Z with +y up on screen; z grows toward -y, so counter-clockwise runs a, d, c, b.
            faces += [(a, d, c), (a, c, b)] if (i + k) % 2 == 0 else [(a, d, b), (d, c, b)]
    mesh = bpy.data.meshes.new("Island")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    mesh.materials.append(material("grass", (0.25, 0.45, 0.2, 1.0)))
    return bpy.data.objects.new("Island", mesh)


def box(low: tuple, high: tuple) -> bmesh.types.BMesh:
    """A closed box from `low` to `high`, both (x, y_up, z) in Godot metres."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(high[0] - low[0], high[2] - low[2], high[1] - low[1]), verts=bm.verts)
    bmesh.ops.translate(bm, vec=((low[0] + high[0]) / 2, -(low[2] + high[2]) / 2, (low[1] + high[1]) / 2), verts=bm.verts)
    return bm


def arch() -> bpy.types.Object:
    x0, x1 = ARCH["x"]
    z0, z1 = ARCH["z"]
    pillar = ARCH["pillar"]
    bm = bmesh.new()
    parts = [
        ((x0, ARCH["floor_y"] - 1.0, z0), (x0 + pillar, ARCH["lintel_bottom"], z1)),
        ((x1 - pillar, ARCH["floor_y"] - 1.0, z0), (x1, ARCH["lintel_bottom"], z1)),
        ((x0, ARCH["lintel_bottom"], z0), (x1, ARCH["roof_y"], z1)),
    ]
    for low, high in parts:
        part = box(low, high)
        mesh = bpy.data.meshes.new("part")
        part.to_mesh(mesh)
        part.free()
        bm.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new("Arch")
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(material("stone", (0.5, 0.5, 0.5, 1.0)))
    return bpy.data.objects.new("Arch", mesh)


def option(name: str, default: str = "") -> str:
    prefix = "--%s=" % name
    for arg in sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []:
        if arg.startswith(prefix):
            return arg[len(prefix):]
    return default


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    collection = bpy.data.collections.new(export_ground.COLLECTION)
    bpy.context.scene.collection.children.link(collection)
    for obj in (island(), arch()):
        collection.objects.link(obj)
    for obj in collection.objects:  # an open heightfield has no inside: make every face look the way it was built
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        if obj.name == "Arch":
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(obj.data)
        bm.free()
    print("make_mesh_test: %d objects -> %s" % (export_ground.export(option("out", "ground.glb")), option("out", "ground.glb")))
    spec = option("spec")
    if spec:
        data = {"size_m": [WIDTH, DEPTH], "step_m": STEP, "base_y": BASE_Y, "rim_y": RIM_Y, "hill": HILL, "plateau": PLATEAU, "pit": PIT,
                "arch": ARCH, "starts": STARTS, "hill_top_y": BASE_Y + HILL["height"], "plateau_y": BASE_Y + PLATEAU["rise"],
                "pit_floor_y": BASE_Y - PIT["drop"]}
        os.makedirs(os.path.dirname(os.path.abspath(spec)), exist_ok=True)
        with open(spec, "w") as handle:
            json.dump(data, handle, indent=1, sort_keys=True)
            handle.write("\n")


if __name__ == "__main__":
    main()
