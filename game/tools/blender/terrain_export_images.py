"""Does not need the original game: it reads the terrain.blend that terrain_make_blend.py made.

Writes a map's images back from the open terrain.blend, the second half of the Blender round trip:
heights.png (Z / M_PER_UNIT), void.png (vertex group «void», weight >= 0.5) and ground_roles.png (colour attribute
«roles», when the .blend has it), then updates terrain_work/manifest.json (the new hash and the vertex count).
It validates everything first and, on any failure, prints each reason, exits 1 and writes nothing:
- there is no mesh object «Terrain», or it does not have SIDE x SIDE vertices;
- the object has a transform (location, rotation, scale, delta or parent) that is not the identity;
- a vertex moved in X or Y by more than XY_TOLERANCE_M from its lattice point;
- a height is below 0 or above MAX_HEIGHT_M;
- the map's images changed since the .blend was made (the manifest's hash), or there is no manifest; --force skips this.
Not: deleting anything. void.png is written when there is a void or the map already has one (then all land is black);
ground_roles.png only when «roles» exists. Each file is written to a temporary name and renamed over the old one.

Run (from game/; BLENDER_BIN is blender in the PATH or your install, e.g. /Applications/Blender.app/Contents/MacOS/Blender):
  "$BLENDER_BIN" --background scenes/map/maps/<tag>/terrain_work/terrain.blend --python tools/blender/terrain_export_images.py -- --out=scenes/map/maps/<tag> [--force]
"""

import os
import sys
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
import terrain_common as tc  # noqa: E402

XY_TOLERANCE_M = 1e-3
VOID_WEIGHT = 0.5
MAX_LISTED = 5


def refuse(reasons):
    for reason in reasons:
        print("ERROR: " + reason)
    print(f"TERRAIN EXPORT REFUSED: {len(reasons)} reason(s), nothing written")
    sys.exit(1)


def transform_reasons(terrain):
    out = []
    if terrain.parent is not None:
        out.append(f"«Terrain» has a parent ({terrain.parent.name}): clear it (Alt P, keep transform) and apply")
    for name in ("location", "delta_location", "rotation_euler", "delta_rotation_euler"):
        if any(abs(v) > 1e-6 for v in getattr(terrain, name)):
            out.append(f"«Terrain» {name} is {tuple(getattr(terrain, name))}, not zero: Apply > All Transforms (Ctrl A) or undo the move")
    if terrain.rotation_mode == "QUATERNION" and any(abs(a - b) > 1e-6 for a, b in zip(terrain.rotation_quaternion, (1, 0, 0, 0))):
        out.append("«Terrain» has a quaternion rotation: apply it")
    for name in ("scale", "delta_scale"):
        if any(abs(v - 1.0) > 1e-6 for v in getattr(terrain, name)):
            out.append(f"«Terrain» {name} is {tuple(getattr(terrain, name))}, not one: apply it or undo it")
    return out


def lattice_reasons(coordinates):
    """Moved vertices (X/Y) and heights out of range, listing the first few of each by vertex (column, row)."""
    moved, low, high = [], [], []
    for vertex_id in range(tc.COUNT):
        x, y, z = coordinates[3 * vertex_id:3 * vertex_id + 3]
        ex, ey = tc.vertex_xy(vertex_id)
        if abs(x - ex) > XY_TOLERANCE_M or abs(y - ey) > XY_TOLERANCE_M:
            moved.append(vertex_id)
        if tc.height_to_unit(z) is None:
            (low if z < 0 else high).append(vertex_id)
    out = []
    for ids, what in ((moved, f"moved in X or Y by more than {XY_TOLERANCE_M} m (only Z may change)"),
                      (low, "below 0 m"), (high, f"above {tc.MAX_HEIGHT_M} m")):
        if ids:
            named = ", ".join(f"({i % tc.SIDE}, {i // tc.SIDE})" for i in ids[:MAX_LISTED])
            out.append(f"{len(ids)} vertices {what}: {named}{' ...' if len(ids) > MAX_LISTED else ''}")
    return out


def read_voids(terrain, mesh):
    group = terrain.vertex_groups.get("void")
    voids = [False] * tc.COUNT
    if group is None:
        return voids
    index = group.index
    for vertex in mesh.vertices:
        for element in vertex.groups:
            if element.group == index and element.weight >= VOID_WEIGHT:
                voids[vertex.index] = True
    return voids


def read_roles(mesh):
    attribute = mesh.color_attributes.get("roles")
    if attribute is None:
        return None, []
    if attribute.domain != "POINT":
        return None, [f"colour attribute «roles» is on {attribute.domain}, not per vertex (POINT): recreate it with terrain_make_blend.py"]
    flat = [0.0] * (4 * tc.COUNT)
    attribute.data.foreach_get("color", flat)
    roles = []
    for i in range(tc.COUNT):
        r, g, b, a = flat[4 * i:4 * i + 4]
        roles.append((tc.linear_to_srgb(r), tc.linear_to_srgb(g), tc.linear_to_srgb(b), round(min(max(a, 0.0), 1.0) * 255.0)))
    return roles, []


def write_all(out_dir, files):
    """Writes every (name, bytes) through a temporary name, so a failure half way leaves the old files whole."""
    temporaries = []
    for name, data in files:
        temporary = out_dir / (name + ".tmp")
        temporary.write_bytes(data)
        temporaries.append((temporary, out_dir / name))
    for temporary, final in temporaries:
        os.replace(temporary, final)


def main():
    args = tc.user_args()
    if "out" not in args or args["out"] is True:
        refuse(["pass -- --out=<map dir> (and optionally --force)"])
    out_dir = Path(args["out"]).resolve()
    terrain = bpy.data.objects.get("Terrain")
    if terrain is None or terrain.type != "MESH":
        refuse(["no mesh object «Terrain» in this .blend (make one with terrain_make_blend.py)"])
    mesh = terrain.data
    if len(mesh.vertices) != tc.COUNT:
        refuse([f"«Terrain» has {len(mesh.vertices)} vertices, not {tc.COUNT} ({tc.SIDE} x {tc.SIDE}): vertices were added or deleted; undo it or make the .blend again"])

    reasons = transform_reasons(terrain)
    coordinates = [0.0] * (3 * tc.COUNT)
    mesh.vertices.foreach_get("co", coordinates)
    reasons += lattice_reasons(coordinates)
    roles, role_reasons = read_roles(mesh)
    reasons += role_reasons
    manifest = tc.read_manifest(out_dir)
    if "force" not in args:
        if manifest is None:
            reasons.append(f"no {tc.WORK_DIR}/{tc.MANIFEST_NAME} in {out_dir}: make the .blend with terrain_make_blend.py, or pass --force")
        elif manifest.get("source_sha256") != tc.sources_hash(out_dir):
            reasons.append(f"the images in {out_dir} changed since this .blend was made (hash differs): make it again, or pass --force to overwrite them")
    if reasons:
        refuse(reasons)

    units = [tc.height_to_unit(coordinates[3 * i + 2]) for i in range(tc.COUNT)]
    voids = read_voids(terrain, mesh)
    files = [(tc.HEIGHTS_PNG, tc.encode_heights(units))]
    if any(voids) or (out_dir / tc.VOID_PNG).is_file():
        files.append((tc.VOID_PNG, tc.encode_void(voids)))
    if roles is not None:
        files.append((tc.ROLES_PNG, tc.encode_roles(roles)))
    write_all(out_dir, files)
    tc.write_manifest(out_dir, {
        "made_from": (manifest or {}).get("made_from", "unknown"),
        "source_sha256": tc.sources_hash(out_dir),
        "vertex_count": len(mesh.vertices),
        "voids": sum(voids),
        "roles": roles is not None,
    })
    print(f"TERRAIN EXPORT {out_dir}: {', '.join(name for name, _ in files)} ({sum(voids)} voids)")


main()
