"""Reads High Noon's ground from assets/original/maps/high_noon/terrain.res (a MapTerrainData, RFC-033 033f) without Godot.

The binary .res stores each PackedArray property as: name index u32, variant type u32, count u32, raw little-endian values.
Property name indices come from the resource's own string table (vertices = 3, normals = 4, indices = 5 for MapTerrainData);
the reader finds them by the variant type and checks that the counts agree, so a changed layout fails loudly instead of lying.
"""

import os
import struct

PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "original", "maps", "high_noon", "terrain.res")
VARIANT_PACKED_INT32 = 32
VARIANT_PACKED_VECTOR3 = 35


def _arrays(raw):
    """[(variant type, count, offset of the values)] for every packed array property, in file order."""
    found = []
    for at in range(0, len(raw) - 12, 4):
        name, kind, count = struct.unpack_from("<III", raw, at)
        if name < 1 or name > 16 or kind not in (VARIANT_PACKED_INT32, VARIANT_PACKED_VECTOR3) or count < 3:
            continue
        width = 12 if kind == VARIANT_PACKED_VECTOR3 else 4
        if at + 12 + count * width <= len(raw):
            found.append((name, kind, count, at + 12))
    return found


def load(path=None):
    """(vertices, indices): vertices a list of (x, y, z) in Godot axes, indices a tuple of ints. None without the file."""
    try:
        raw = open(path or PATH, "rb").read()
    except OSError:
        return None
    if raw[:4] != b"RSRC":
        return None
    verts = idx = None
    # The first big Vector3 array is `vertices`, the next one `normals`, and the Int32 array after them `indices`.
    for name, kind, count, off in _arrays(raw):
        if count < 1000:
            continue
        if kind == VARIANT_PACKED_VECTOR3 and verts is None:
            verts = [struct.unpack_from("<fff", raw, off + 12 * i) for i in range(count)]
        elif kind == VARIANT_PACKED_INT32 and idx is None and verts is not None:
            idx = struct.unpack_from("<%di" % count, raw, off)
    if verts is None or idx is None or max(idx) >= len(verts):
        raise ValueError("terrain.res: unexpected layout")
    return verts, idx
