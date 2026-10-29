"""Blender CLI: builds the Grasping Vines tube and exports it as assets/custom/vine/vine.glb.

  /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/bake/make_vine.py

A tube of 24 sides and 19 segments along Blender's +Z (+Y in Godot), 1 m long, radius 0.1 m at the root and 0 at the tip (linear), UV u around and v along
(v = 0 at the root), skinned to a chain of 20 bones, one per ring of vertices (each ring follows its bone rigidly). Godot scales it
to the vine's size and moves the bones (VineLook). Needs no original game file.
"""
import math
import sys
from pathlib import Path

import bpy
import bmesh

SIDES, SEGMENTS, LENGTH, ROOT_RADIUS = 24, 19, 1.0, 0.1
OUT = Path(__file__).resolve().parents[2] / "assets" / "custom" / "vine" / "vine.glb"

bpy.ops.wm.read_factory_settings(use_empty=True)

mesh = bpy.data.meshes.new("VineMesh")
obj = bpy.data.objects.new("Vine", mesh)
bpy.context.scene.collection.objects.link(obj)
bm = bmesh.new()
uv = bm.loops.layers.uv.new("UVMap")
rings = []
for i in range(SEGMENTS + 1):
    t = i / SEGMENTS
    radius = ROOT_RADIUS * (1.0 - t)
    ring = []
    for k in range(SIDES):
        a = math.tau * k / SIDES
        ring.append(bm.verts.new((math.cos(a) * radius, math.sin(a) * radius, t * LENGTH)))
    rings.append(ring)
for i in range(SEGMENTS):
    for k in range(SIDES):
        k2 = (k + 1) % SIDES
        face = bm.faces.new((rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]))
        for loop, (u, v) in zip(face.loops, ((k, i), (k + 1, i), (k + 1, i + 1), (k, i + 1))):
            loop[uv].uv = (u / SIDES, v / SEGMENTS)
bm.normal_update()
bm.to_mesh(mesh)
bm.free()
for i in range(SEGMENTS + 1):
    group = obj.vertex_groups.new(name="b%02d" % i)
    group.add([i * SIDES + k for k in range(SIDES)], 1.0, "REPLACE")
for poly in mesh.polygons:
    poly.use_smooth = True

arm_data = bpy.data.armatures.new("Skeleton")
arm = bpy.data.objects.new("Skeleton", arm_data)
bpy.context.scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
step = LENGTH / SEGMENTS
for i in range(SEGMENTS + 1):
    bone = arm_data.edit_bones.new("b%02d" % i)
    bone.head = (0.0, 0.0, i * step)
    bone.tail = (0.0, 0.0, i * step + step * 0.5)
    if i:
        bone.parent = arm_data.edit_bones["b%02d" % (i - 1)]
bpy.ops.object.mode_set(mode="OBJECT")
obj.parent = arm
mod = obj.modifiers.new("Armature", "ARMATURE")
mod.object = arm

OUT.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", export_skins=True, export_yup=True, export_apply=False)
print("vine.glb written:", OUT, file=sys.stderr)
