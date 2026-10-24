"""Runs INSIDE Blender (`blender --background --python blender_dfir.py -- data.json out.glb`), started by import_dragonfire.py.

Builds the dragon of Dragonfire: frame 0 is the mesh, frames 1..4 are shape keys (f1..f4), two materials named after the texture labels.
Positions in the json are in Godot's axes (x right, y up, z forward); Blender is Z-up and its glTF exporter maps (x, y, z) to
(x, z, -y), so a vertex goes in as (x, -z, y) and comes out unchanged.
"""

import json
import sys

import bpy

args = sys.argv[sys.argv.index("--") + 1:]
data = json.load(open(args[0]))
out_path = args[1]

frames, uvs, faces, labels = data["frames"], data["uvs"], data["faces"], data["labels"]


def blender_axes(p):
    return (p[0], -p[2], p[1])


bpy.ops.wm.read_factory_settings(use_empty=True)
mesh = bpy.data.meshes.new("Dragon")
mesh.from_pydata([blender_axes(p) for p in frames[0]], [], [(f[0], f[1], f[2]) for f in faces])
mesh.update()
for label in labels:
    material = bpy.data.materials.new(label)
    mesh.materials.append(material)
for polygon, face in zip(mesh.polygons, faces):
    polygon.material_index = labels.index(face[3])
    polygon.use_smooth = True
layer = mesh.uv_layers.new(name="UVMap")
for loop in mesh.loops:
    layer.data[loop.index].uv = uvs[loop.vertex_index]
obj = bpy.data.objects.new("Dragon", mesh)
bpy.context.scene.collection.objects.link(obj)
bpy.context.view_layer.objects.active = obj
obj.shape_key_add(name="Basis")
for k in range(1, len(frames)):
    key = obj.shape_key_add(name="f%d" % k, from_mix=False)
    for i, p in enumerate(frames[k]):
        key.data[i].co = blender_axes(p)
bpy.ops.export_scene.gltf(
    filepath=out_path,
    export_format="GLB",
    use_selection=False,
    export_apply=False,
    export_morph=True,
    export_morph_normal=False,
    export_morph_tangent=False,
    export_image_format="NONE",
    export_materials="EXPORT",
    export_yup=True,
    export_animations=False,
    export_cameras=False,
    export_lights=False,
)
