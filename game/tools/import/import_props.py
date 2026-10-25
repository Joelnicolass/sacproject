#!/usr/bin/env python3
"""Requiere el juego original instalado (SAC_INSTALL). Ver tools/import/local.cfg.example.

Import the original's static models (buildings, BLDG components, plants) to assets/original/props/ as .glb.

RFC-033 (033c). One .glb per model, no textures: one primitive per OBJ material label, with a glTF material that only
carries the label as its name (Godot names the surface after it; the baked .res puts the shared textured material on
top by that name). The geometry is the one the game used to build with ObjMesh.build (scenes/bodies/obj_mesh.gd):
winding checked against the file normals, plants drawn on both sides with their own normals. Written into Godot's
clockwise winding mirrored for glTF (the importer flips it back), so the vertices that reach the game are the same.
Also writes the hybrid bodies of RFC-023 023c (STATIC_BODIES, no clip animates them) as static props: their bind-pose
OBJ (`--bodies-from=DIR`, DIR/<m>/<m>.obj) with z mirrored (the game's axes, ObjMesh.MIRROR_Z): the geometry
the game baked these bodies from, vertex by vertex. The skeletal .glb is not the source: its bind pose differs from that OBJ
by up to several cm. The WAD files give no such OBJ (sacengine's saveObj makes it), so they are left alone without the flag.

  python3 tools/import/import_props.py            # write
  python3 tools/import/import_props.py --check    # report what would change, write nothing
  python3 tools/import/import_props.py --list-static   # the names of the static bodies (tools/audit/check_original_assets.sh skips them)
  python3 tools/import/import_props.py --verify   # read the written .glb files back and compare them with the OBJ (mm; the static bodies with `--bodies-from`)

Source: the installation's WAD files, read with tools/import/sac_formats (the god WADs joby, pyromod, jamesmod and stratmod for
every BLDG component, the land WADs prsc, char, pyro_a and strato_a for the plants, models.wad for the spell models): the model
is built in memory as the OBJ text it has always been imported from (5 decimals), so the vertices are the same. Run it once;
the result is versioned. An existing .glb.import is never touched (it carries the UID). Deterministic: a second run writes
nothing.

The mesh the game draws is not read from these .glb at run time since 055s: each prop it uses is a scenes/props/meshes/<tag>.res
(materials included). To use a new prop: open the imported .glb in the editor, save its mesh as a .res in scenes/props/meshes/, give the
surfaces the materials of scenes/bodies/materials/ and drag the .res onto the part, species or shot that uses it. This script writes
no measures (the size of a building is the box of its scene).
"""

import json
import math
import struct
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sac_formats.gltf_writer import (ARRAY_BUFFER, ELEMENT_ARRAY_BUFFER, FLOAT, UINT, USHORT, Gltf,  # noqa: E402
                                     import_params, write_glb)

from sac_formats import props as propslib  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
ARGS = {a.split("=", 1)[0]: (a.split("=", 1)[1] if "=" in a else True) for a in sys.argv[1:]}
OUT = Path(ARGS.get("--out", ROOT / "assets" / "original" / "props"))
## RFC-023 023h: where the bind-pose OBJ of the static bodies is (<dir>/<model>/<model>.obj, sacengine's saveObj). Only needed
## to (re)write those 11 files; the result is versioned. Without it they are left alone.
BODIES_FROM = Path(ARGS["--bodies-from"]) if "--bodies-from" in ARGS else None

## RFC-023 023h: bodies drawn as a static bind-pose mesh because no clip of their skeleton is the one their creature rests on
## (the hybrids of 023c, with a single clip). Everything else in models/ is drawn by a BodyRig.
STATIC_BODIES = ("faez", "thes", "the2", "sara", "hoom", "bane", "ban2", "sirc", "surt", "gamm", "baby")

## The glTF asset.generator of every prop. Frozen at the script's path when the props were first written (it has since
## moved to tools/import/): changing it would rewrite every versioned .glb for one string, and `--check` compares bytes.
GENERATOR = "sacproject tools/import_props.py"

## Area share of near-horizontal faces above which a plant lies on the ground (ObjMesh.GROUND_WIDGET_RATIO).
GROUND_WIDGET_RATIO = 0.7


def f32(x: float) -> float:
    return struct.unpack("<f", struct.pack("<f", x))[0]


def parse_obj(text: str):
    """ObjMesh.parse: [(label, verts, uvs, normals)] with three corners per face, plus whether the file has normals."""
    positions, normals, uvs, surfaces = [], [], [], []
    for line in text.split("\n"):
        parts = line.split()
        if not parts:
            continue
        tag = parts[0]
        if tag == "v" and len(parts) >= 4:
            positions.append((f32(float(parts[1])), f32(float(parts[2])), f32(float(parts[3]))))
        elif tag == "vt" and len(parts) >= 3:
            uvs.append((f32(float(parts[1])), f32(1.0 - float(parts[2]))))
        elif tag == "vn" and len(parts) >= 4:
            normals.append((f32(float(parts[1])), f32(float(parts[2])), f32(float(parts[3]))))
        elif tag == "usemtl":
            surfaces.append([parts[1] if len(parts) > 1 else "", [], [], []])
        elif tag == "f" and len(parts) >= 4:
            if not surfaces:
                surfaces.append(["", [], [], []])
            cur = surfaces[-1]
            for corner in parts[1:4]:
                bits = corner.split("/")
                vi = int(bits[0]) - 1
                ti = int(bits[1]) - 1 if len(bits) >= 2 and bits[1] != "" else -1
                ni = int(bits[2]) - 1 if len(bits) >= 3 and bits[2] != "" else -1
                cur[1].append(positions[vi])
                cur[2].append(uvs[ti] if 0 <= ti < len(uvs) else (0.0, 0.0))
                cur[3].append(normals[ni] if 0 <= ni < len(normals) else (0.0, 0.0, 0.0))
    return surfaces, bool(normals)


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def needs_flip(surfaces, has_normals):
    """ObjMesh._needs_flip: the triangles face away from the file normals."""
    assert has_normals, "an OBJ without normals needs ObjMesh's smoothing, which this importer does not replicate"
    score = 0.0
    for _label, verts, _uvs, normals in surfaces:
        for i in range(0, len(verts) - 2, 3):
            a, b, c = verts[i], verts[i + 1], verts[i + 2]
            face = cross(sub(a, c), sub(a, b))
            n = (normals[i][0] + normals[i + 1][0] + normals[i + 2][0],
                 normals[i][1] + normals[i + 1][1] + normals[i + 2][1],
                 normals[i][2] + normals[i + 1][2] + normals[i + 2][2])
            score += dot(face, n)
    return score < 0.0


def is_ground_widget(surfaces):
    flat = total = 0.0
    for _label, verts, _uvs, _n in surfaces:
        for i in range(0, len(verts) - 2, 3):
            face = cross(sub(verts[i], verts[i + 2]), sub(verts[i], verts[i + 1]))
            area = math.sqrt(dot(face, face))
            total += area
            if area > 0.0 and abs(face[1]) / area > 0.5:
                flat += area
    return total > 0.0 and flat / total >= GROUND_WIDGET_RATIO


def swap_triangles(values):
    """Swap corners 1 and 2 of every triangle."""
    out = list(values)
    for i in range(0, len(out), 3):
        out[i + 1], out[i + 2] = out[i + 2], out[i + 1]
    return out


def side_normals(verts):
    """ObjMesh._side_normals: smooth normal per (snapped position, front/back half)."""
    half = len(verts) // 2
    faces = [cross(sub(verts[i], verts[i + 2]), sub(verts[i], verts[i + 1])) for i in range(0, len(verts) - 2, 3)]

    def key(p, front):
        return (round(p[0] / 0.0001), round(p[1] / 0.0001), round(p[2] / 0.0001), front)

    sums = {}
    for i, p in enumerate(verts):
        k = key(p, i < half)
        f = faces[i // 3]
        s = sums.get(k, (0.0, 0.0, 0.0))
        sums[k] = (s[0] + f[0], s[1] + f[1], s[2] + f[2])
    out = []
    for i, p in enumerate(verts):
        s = sums[key(p, i < half)]
        length = math.sqrt(dot(s, s))
        out.append(tuple(f32(c / length) for c in s) if length > 0.0 else (0.0, 1.0, 0.0))
    return out


def build_surfaces(obj: str, foliage: bool):
    """ObjMesh.build: [(label, verts, uvs, normals)] in the order and winding the game used."""
    surfaces, has_normals = parse_obj(obj)
    flip = False if foliage else needs_flip(surfaces, has_normals)
    ground = foliage and is_ground_widget(surfaces)
    out = []
    for label, verts, uvs, normals in surfaces:
        if not verts:
            continue
        if flip:
            verts, uvs, normals = swap_triangles(verts), swap_triangles(uvs), swap_triangles(normals)
        if foliage:
            verts = verts + swap_triangles(verts)
            uvs = uvs + swap_triangles(uvs)
            normals = side_normals(verts) if ground else [(0.0, 1.0, 0.0)] * len(verts)
        out.append((label, verts, uvs, normals))
    return out


def write_prop(path: Path, name: str, surfaces) -> None:
    g = Gltf()
    primitives, materials, material_of = [], [], {}
    lo = [1e30] * 3
    hi = [-1e30] * 3
    for label, verts, uvs, normals in surfaces:
        slot, corners, ids = {}, [], []
        for v, u, n in zip(verts, uvs, normals):
            k = (v, u, n)
            if k not in slot:
                slot[k] = len(corners)
                corners.append(k)
            ids.append(slot[k])
        count = len(corners)
        # Godot arrays are clockwise; glTF is counter-clockwise (the importer swaps back).
        indices = []
        for i in range(0, len(ids), 3):
            indices += [ids[i], ids[i + 2], ids[i + 1]]
        slo = [min(c[0][k] for c in corners) for k in range(3)]
        shi = [max(c[0][k] for c in corners) for k in range(3)]
        lo = [min(a, b) for a, b in zip(lo, slo)]
        hi = [max(a, b) for a, b in zip(hi, shi)]
        flat = [x for c in corners for x in c[0]]
        pos = g.accessor(struct.pack("<%df" % len(flat), *flat), FLOAT, count, "VEC3", ARRAY_BUFFER, slo, shi)
        flat = [x for c in corners for x in c[2]]
        nrm = g.accessor(struct.pack("<%df" % len(flat), *flat), FLOAT, count, "VEC3", ARRAY_BUFFER)
        flat = [x for c in corners for x in c[1]]
        uv = g.accessor(struct.pack("<%df" % len(flat), *flat), FLOAT, count, "VEC2", ARRAY_BUFFER)
        if count < 65536:
            idx = g.accessor(struct.pack("<%dH" % len(indices), *indices), USHORT, len(indices), "SCALAR", ELEMENT_ARRAY_BUFFER)
        else:
            idx = g.accessor(struct.pack("<%dI" % len(indices), *indices), UINT, len(indices), "SCALAR", ELEMENT_ARRAY_BUFFER)
        primitive = {"attributes": {"POSITION": pos, "NORMAL": nrm, "TEXCOORD_0": uv}, "indices": idx, "mode": 4}
        if label:
            if label not in material_of:
                material_of[label] = len(materials)
                materials.append({"name": label})
            primitive["material"] = material_of[label]
        primitives.append(primitive)
    doc = {
        "asset": {"version": "2.0", "generator": GENERATOR},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"name": name, "mesh": 0}],
        "meshes": [{"name": name, "primitives": primitives}],
    }
    if materials:
        doc["materials"] = materials
    write_glb(path, doc, g)


def read_glb(path: Path):
    """The primitives of a .glb written by write_prop: [(material name, verts, uvs, normals)] in Godot's winding."""
    raw = path.read_bytes()
    magic, version, _length = struct.unpack_from("<III", raw, 0)
    assert magic == 0x46546C67 and version == 2
    jlen, jtype = struct.unpack_from("<II", raw, 12)
    doc = json.loads(raw[20:20 + jlen])
    blen, _btype = struct.unpack_from("<II", raw, 20 + jlen)
    blob = raw[28 + jlen:28 + jlen + blen]

    def accessor(i, fmt, width):
        a = doc["accessors"][i]
        v = doc["bufferViews"][a["bufferView"]]
        values = struct.unpack_from("<%d%s" % (a["count"] * width, fmt), blob, v["byteOffset"])
        return [values[k:k + width] for k in range(0, len(values), width)] if width > 1 else list(values)

    out = []
    for prim in doc["meshes"][0]["primitives"]:
        attrs = prim["attributes"]
        pos, nrm, uv = accessor(attrs["POSITION"], "f", 3), accessor(attrs["NORMAL"], "f", 3), accessor(attrs["TEXCOORD_0"], "f", 2)
        idx_acc = doc["accessors"][prim["indices"]]
        idx = accessor(prim["indices"], "H" if idx_acc["componentType"] == USHORT else "I", 1)
        verts, uvs, normals = [], [], []
        for i in range(0, len(idx), 3):
            for k in (idx[i], idx[i + 2], idx[i + 1]):      # undo the glTF winding swap
                verts.append(pos[k]), uvs.append(uv[k]), normals.append(nrm[k])
        label = doc["materials"][prim["material"]]["name"] if "material" in prim else ""
        out.append((label, verts, uvs, normals))
    return out


def static_body_surfaces(model: str):
    """ObjMesh.build(<model>.obj, {MIRROR_Z}): the bind-pose OBJ of sacengine's saveObj (x, z, -y) drawn with z mirrored.
    The OBJ is the one the game baked these bodies from before 023h, so the geometry is the same vertex by vertex."""
    surfaces, has_normals = parse_obj((BODIES_FROM / model / (model + ".obj")).read_text())
    mirrored = [(label, [(x, y, f32(-z)) for x, y, z in verts], uvs, [(x, y, f32(-z)) for x, y, z in normals])
                for label, verts, uvs, normals in surfaces]
    flip = needs_flip(mirrored, has_normals)
    out = []
    for label, verts, uvs, normals in mirrored:
        if not verts:
            continue
        if flip:
            verts, uvs, normals = swap_triangles(verts), swap_triangles(uvs), swap_triangles(normals)
        out.append((label, verts, uvs, normals))
    return out


def verify() -> None:
    items = propslib.all_props()
    worst = {"position (mm)": 0.0, "uv": 0.0, "normal": 0.0}
    bad = 0
    for item in items:
        name = item.name
        want = build_surfaces(item.obj, item.foliage)
        got = read_glb(OUT / (name + ".glb"))
        if len(got) != len(want) or any(g[0] != w[0] or len(g[1]) != len(w[1]) for g, w in zip(got, want)):
            print("MISMATCH shape", name)
            bad += 1
            continue
        for g, w in zip(got, want):
            for a, b in zip(g[1], w[1]):
                worst["position (mm)"] = max(worst["position (mm)"], 1000.0 * math.dist(a, b))
            for a, b in zip(g[2], w[2]):
                worst["uv"] = max(worst["uv"], math.dist(a, b))
            for a, b in zip(g[3], w[3]):
                worst["normal"] = max(worst["normal"], math.dist(a, b))
    for model in STATIC_BODIES if BODIES_FROM else ():
        want = static_body_surfaces(model)
        got = read_glb(OUT / (model + ".glb"))
        if len(got) != len(want) or any(g[0] != w[0] or len(g[1]) != len(w[1]) for g, w in zip(got, want)):
            print("MISMATCH shape", model)
            bad += 1
            continue
        for g, w in zip(got, want):
            for a, b in zip(g[1], w[1]):
                worst["position (mm)"] = max(worst["position (mm)"], 1000.0 * math.dist(a, b))
    print("verify: %d props and %d static bodies, %d with a different shape; worst error %s" % (
        len(items), len(STATIC_BODIES) if BODIES_FROM else 0, bad, worst))
    sys.exit(1 if bad or worst["position (mm)"] > 0.01 else 0)


def write_if_changed(target: Path, name: str, surfaces, check: bool) -> tuple:
    """Writes one prop .glb (and its .import when new). Returns (bytes, written?)."""
    with tempfile.TemporaryDirectory() as tmp:
        scratch = Path(tmp) / "x.glb"
        write_prop(scratch, name, surfaces)
        data = scratch.read_bytes()
    changed = not (target.exists() and target.read_bytes() == data)
    if changed and not check:
        OUT.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    imp = target.with_name(target.name + ".import")
    if not imp.exists() and not check:
        imp.write_text(import_params(animation=False, exact=True, tangents=False))
    return len(data), changed


def main() -> None:
    if "--list-static" in ARGS:
        print(" ".join(STATIC_BODIES))
        return
    if "--verify" in ARGS:
        verify()
    check = "--check" in ARGS
    items = propslib.all_props()
    written = kept = 0
    total = 0
    for item in items:
        surfaces = build_surfaces(item.obj, item.foliage)
        assert surfaces, item.name
        size, changed = write_if_changed(OUT / (item.name + ".glb"), item.name, surfaces, check)
        total += size
        written += changed
        kept += not changed
    bodies_written = 0
    for model in STATIC_BODIES if BODIES_FROM else ():
        size, changed = write_if_changed(OUT / (model + ".glb"), model, static_body_surfaces(model), check)
        total += size
        bodies_written += changed
    print("props %d (%d written, %d unchanged); static bodies %d (%d written); %.2f MB of .glb%s" % (
        len(items), written, kept, len(STATIC_BODIES) if BODIES_FROM else 0, bodies_written, total / 1e6, " [check]" if check else ""))


if __name__ == "__main__":
    main()
