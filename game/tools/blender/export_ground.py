"""No necesita el juego original.

RFC-063: exports the ground of a map from Blender to a .glb with the options Godot's ground import (tools/ground_import.gd) expects.
The ground is every object in the collection «Ground» (an object whose name starts with «_» or is «SizeGuide» is left out).
Only the shape matters: location, rotation and scale are applied on export, Y is up in the file, and the normals are written.

Run (from game/; BLENDER is blender in the PATH or $BLENDER; no personal paths):
  "$BLENDER" --background ground.blend --python tools/blender/export_ground.py -- --out=scenes/map/maps/<tag>/ground.glb
Or from another Blender script: `import export_ground; export_ground.export("path/ground.glb")`.
"""
import os
import sys

import bpy

COLLECTION = "Ground"
LEFT_OUT = ("SizeGuide",)


def ground_objects() -> list:
    """The objects that make the ground: the meshes of the collection «Ground»."""
    collection = bpy.data.collections.get(COLLECTION)
    if collection is None:
        raise SystemExit("export_ground: the file has no collection «%s» (open ground_template.blend and model in it)." % COLLECTION)
    return [o for o in collection.all_objects if o.type == "MESH" and not o.name.startswith("_") and o.name not in LEFT_OUT]


def export(path: str) -> int:
    """Writes the ground to `path` (a .glb); returns how many objects went in."""
    objects = ground_objects()
    if not objects:
        raise SystemExit("export_ground: the collection «%s» has no mesh." % COLLECTION)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_yup=True, export_apply=True,
        export_normals=True, export_texcoords=True, export_materials="EXPORT",
        export_cameras=False, export_lights=False, export_animations=False, export_extras=False)
    return len(objects)


def _option(name: str, default: str = "") -> str:
    prefix = "--%s=" % name
    for arg in sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []:
        if arg.startswith(prefix):
            return arg[len(prefix):]
    return default


if __name__ == "__main__":
    target = _option("out")
    if not target:
        raise SystemExit("export_ground: pass --out=<path>.glb")
    print("export_ground: %d objects -> %s" % (export(target), target))
