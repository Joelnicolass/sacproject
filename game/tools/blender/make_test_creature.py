"""RFC-051: a throwaway creature to prove the custom creature pipeline (assets/custom/models/testmonster.glb).

Also the smallest example of what a model for `tools/bake/new_creature.gd` looks like: one armature, one skinned mesh and
one ACTION per role, named after the role (idle, run, attack, death). `attack_at45` puts the impact at 45 % of the clip (`attack_f18`: at frame 18).

Run (from game/):
  /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/blender/make_test_creature.py -- assets/custom/models/testmonster.glb

The creature faces -Y in Blender (the glTF exporter turns that into +Z, the way the game faces).
"""
import math
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector

FPS = 30
out_path = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "testmonster.glb"

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = FPS

# --- armature: hips (root) > spine > head, two arms, two legs ---------------------------------------------------------
arm_data = bpy.data.armatures.new("Armature")
arm_obj = bpy.data.objects.new("Armature", arm_data)
scene.collection.objects.link(arm_obj)
bpy.context.view_layer.objects.active = arm_obj
bpy.ops.object.mode_set(mode="EDIT")
BONES = {
    # name: (head, tail, parent)
    "hips": ((0, 0, 0.9), (0, 0, 1.1), None),
    "spine": ((0, 0, 1.1), (0, 0, 1.6), "hips"),
    "head": ((0, 0, 1.6), (0, 0, 2.0), "spine"),
    "arm.L": ((0.35, 0, 1.5), (0.35, -0.5, 1.5), "spine"),
    "arm.R": ((-0.35, 0, 1.5), (-0.35, -0.5, 1.5), "spine"),
    "leg.L": ((0.2, 0, 0.9), (0.2, 0, 0.0), "hips"),
    "leg.R": ((-0.2, 0, 0.9), (-0.2, 0, 0.0), "hips"),
}
for name, (head, tail, parent) in BONES.items():
    bone = arm_data.edit_bones.new(name)
    bone.head, bone.tail = Vector(head), Vector(tail)
    if parent:
        bone.parent = arm_data.edit_bones[parent]
bpy.ops.object.mode_set(mode="OBJECT")

# --- mesh: one box per bone, each fully weighted to its bone ----------------------------------------------------------
BOXES = {
    # bone: (center, size)
    "hips": ((0, 0, 1.0), (0.6, 0.4, 0.3)),
    "spine": ((0, 0, 1.35), (0.7, 0.45, 0.6)),
    "head": ((0, -0.1, 1.8), (0.4, 0.4, 0.4)),
    "arm.L": ((0.4, -0.25, 1.5), (0.15, 0.55, 0.15)),
    "arm.R": ((-0.4, -0.25, 1.5), (0.15, 0.55, 0.15)),
    "leg.L": ((0.2, 0, 0.45), (0.2, 0.2, 0.9)),
    "leg.R": ((-0.2, 0, 0.45), (0.2, 0.2, 0.9)),
}
mesh = bpy.data.meshes.new("MonsterMesh")
mesh_obj = bpy.data.objects.new("Monster", mesh)
scene.collection.objects.link(mesh_obj)
bm = bmesh.new()
owner = []  # vertex index -> bone name
for bone, (center, size) in BOXES.items():
    before = len(bm.verts)
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.LocRotScale(Vector(center), None, Vector(size)))
    bm.verts.ensure_lookup_table()
    owner.extend([bone] * (len(bm.verts) - before))
bm.to_mesh(mesh)
bm.free()
groups = {name: mesh_obj.vertex_groups.new(name=name) for name in BONES}
for index, bone in enumerate(owner):
    groups[bone].add([index], 1.0, "REPLACE")
material = bpy.data.materials.new("MonsterGreen")
material.diffuse_color = (0.25, 0.6, 0.25, 1.0)
material.use_nodes = True
material.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.25, 0.6, 0.25, 1.0)
mesh.materials.append(material)
mesh_obj.parent = arm_obj
modifier = mesh_obj.modifiers.new("Armature", "ARMATURE")
modifier.object = arm_obj

# --- actions ----------------------------------------------------------------------------------------------------------
bpy.context.view_layer.objects.active = arm_obj
bpy.ops.object.mode_set(mode="POSE")
pose = arm_obj.pose.bones
for bone in pose:
    bone.rotation_mode = "XYZ"
arm_obj.animation_data_create()


def make_action(name, length, keys):
    """keys: {bone: [(frame, (rx, ry, rz) degrees, (x, y, z) location)]}; frame 0 and `length` should match for a loop."""
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    arm_obj.animation_data.action = action
    for bone in pose:
        bone.rotation_euler = (0, 0, 0)
        bone.location = (0, 0, 0)
    for bone_name, frames in keys.items():
        for frame, rot, loc in frames:
            pose[bone_name].rotation_euler = tuple(math.radians(a) for a in rot)
            pose[bone_name].location = loc
            pose[bone_name].keyframe_insert("rotation_euler", frame=frame)
            pose[bone_name].keyframe_insert("location", frame=frame)
    action.frame_start, action.frame_end = 0, length
    action.use_frame_range = True


Z = (0, 0, 0)
make_action("idle", 60, {
    "hips": [(0, Z, (0, 0, 0)), (30, Z, (0, 0, -0.05)), (60, Z, (0, 0, 0))],
    "head": [(0, Z, Z), (30, (8, 0, 0), Z), (60, Z, Z)],
})
make_action("run", 24, {
    "leg.L": [(0, (35, 0, 0), Z), (12, (-35, 0, 0), Z), (24, (35, 0, 0), Z)],
    "leg.R": [(0, (-35, 0, 0), Z), (12, (35, 0, 0), Z), (24, (-35, 0, 0), Z)],
    "arm.L": [(0, (-25, 0, 0), Z), (12, (25, 0, 0), Z), (24, (-25, 0, 0), Z)],
    "arm.R": [(0, (25, 0, 0), Z), (12, (-25, 0, 0), Z), (24, (25, 0, 0), Z)],
    "hips": [(0, Z, (0, 0, 0)), (6, Z, (0, 0, 0.06)), (12, Z, (0, 0, 0)), (18, Z, (0, 0, 0.06)), (24, Z, (0, 0, 0))],
})
# The impact sits at 45 % of the clip: the name carries it (`_at45`), the tool reads it.
make_action("attack_at45", 40, {
    "spine": [(0, Z, Z), (12, (-25, 0, 0), Z), (18, (35, 0, 0), Z), (40, Z, Z)],
    "arm.L": [(0, Z, Z), (12, (80, 0, 0), Z), (18, (-70, 0, 0), Z), (40, Z, Z)],
    "arm.R": [(0, Z, Z), (12, (80, 0, 0), Z), (18, (-70, 0, 0), Z), (40, Z, Z)],
})
make_action("death", 36, {
    "hips": [(0, Z, (0, 0, 0)), (36, (-90, 0, 0), (0, 0.6, -0.6))],
    "head": [(0, Z, Z), (36, (20, 0, 0), Z)],
})
arm_obj.animation_data.action = None
bpy.ops.object.mode_set(mode="OBJECT")

# --- export -----------------------------------------------------------------------------------------------------------
bpy.ops.export_scene.gltf(
    filepath=out_path,
    export_format="GLB",
    export_animations=True,
    export_animation_mode="ACTIONS",
    export_apply=False,
    export_yup=True,
)
print("MAKE_TEST_CREATURE wrote", out_path, [a.name for a in bpy.data.actions])
