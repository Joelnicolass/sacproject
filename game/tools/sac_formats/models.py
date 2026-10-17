"""Static models: MRMM (buildings, spell models) and WIDG (plants), as Wavefront OBJ text in Godot's axes.

The text keeps 5 decimals, the precision the project has always imported them at.
"""

import struct


def _le(b: bytes) -> int:
    return int.from_bytes(b, "little")


def widg_obj(raw: bytes):
    """(OBJ text, texture tag) of a plant."""
    count = _le(raw[0:4])
    faces = int.from_bytes(raw[4:6], "little")
    tex = raw[8:12][::-1].decode("latin1").rstrip("\x00")
    verts = []
    base = 12
    for i in range(count):
        o = base + i * 20
        x, y, z, u, v = struct.unpack_from("<fffff", raw, o)
        # sacengine samples (u, -v); the OBJ reader flips vt once more.
        verts.append((x, z, y, u, 1.0 + v))
    face_off = 8 + count * 20 + 4
    lines = ["o plant", "usemtl plant"]
    for x, y, z, u, v in verts:
        lines.append(f"v {x:.5f} {y:.5f} {z:.5f}")
        lines.append(f"vt {u:.5f} {v:.5f}")
    for i in range(faces):
        o = face_off + i * 4
        a, b, c = raw[o], raw[o + 1], raw[o + 2]
        lines.append(f"f {a+1}/{a+1} {c+1}/{c+1} {b+1}/{b+1}")
    return "\n".join(lines) + "\n", tex


def mrmm_obj(raw: bytes):
    """(OBJ text, texture tags in order of first use). Only the faces of the highest LOD, like the game draws them."""
    num_v = _le(raw[4:8])
    num_f = _le(raw[12:16])
    v_off = _le(raw[184:188])
    f_off = _le(raw[188:192])
    lines = ["o building"]
    names = []
    current = None
    for i in range(num_v):
        o = v_off + i * 40
        x, y, z, u, v = struct.unpack_from("<fffff", raw, o)
        nx, ny, nz = struct.unpack_from("<fff", raw, o + 28)
        lines.append(f"v {x:.5f} {z:.5f} {y:.5f}")
        lines.append(f"vt {u:.5f} {1.0 - v:.5f}")
        lines.append(f"vn {nx:.5f} {nz:.5f} {ny:.5f}")
    lods = [_le(raw[f_off + i * 36 + 32: f_off + i * 36 + 36]) for i in range(num_f)]
    top = max(lods) if lods else 0
    for i in range(num_f):
        if lods[i] != top:
            continue
        o = f_off + i * 36
        a, b, c = struct.unpack_from("<III", raw, o)
        tex = raw[o + 16: o + 20][::-1].decode("latin1").rstrip("\x00")
        if tex != current:
            current = tex
            names.append(tex)
            lines.append(f"usemtl {tex}")
        lines.append(f"f {a+1}/{a+1}/{a+1} {c+1}/{c+1}/{c+1} {b+1}/{b+1}/{b+1}")
    return "\n".join(lines) + "\n", names
