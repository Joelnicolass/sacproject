"""No necesita el juego original.

RFC-063: writes ground_template.blend, the starting point to model a map's ground: metres, collection «Ground» (model in it),
and a flat guide plane «SizeGuide» with the size of the map (it is not exported). Blender is Z up; the glTF export turns it into
Y up, so a point (x, y, z) here lands at Godot (x, z, -y): Godot's z grows toward -y. The import moves the map to x, z >= 0.

Run (from game/; BLENDER is blender in the PATH or $BLENDER):
  "$BLENDER" --background --python tools/blender/make_ground_template.py -- --out=ground_template.blend [--size=1200x800]
"""
import sys

import bpy

COLLECTION = "Ground"


def _option(name: str, default: str) -> str:
    prefix = "--%s=" % name
    for arg in sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []:
        if arg.startswith(prefix):
            return arg[len(prefix):]
    return default


def main() -> None:
    width, depth = (float(v) for v in _option("size", "1200x800").lower().split("x"))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    collection = bpy.data.collections.new(COLLECTION)
    scene.collection.children.link(collection)
    mesh = bpy.data.meshes.new("SizeGuide")
    mesh.from_pydata([(0, 0, 0), (width, 0, 0), (width, -depth, 0), (0, -depth, 0)], [], [(0, 1, 2, 3)])
    guide = bpy.data.objects.new("SizeGuide", mesh)
    guide.display_type = "WIRE"
    guide.hide_render = True
    collection.objects.link(guide)
    target = _option("out", "ground_template.blend")
    bpy.ops.wm.save_as_mainfile(filepath=target)
    print("make_ground_template: %.0f x %.0f m -> %s" % (width, depth, target))


if __name__ == "__main__":
    main()
