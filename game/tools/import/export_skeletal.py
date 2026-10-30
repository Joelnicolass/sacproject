#!/usr/bin/env python3
"""Needs the original game installed (SAC_INSTALL). See tools/import/local.cfg.example.

Skeletal models: saxs*.wad -> one glTF binary per model (versioned asset, WADs stay out of git).

For each model writes, into the output folder (`--out`, default assets/original/models (versioned assets)):
    <m>.glb            Skeleton3D + one skinned mesh (one primitive per material: body parts that share a texture are merged, <= 4 influences)
                       + every SXSK clip of the model as bone tracks (root displacement = root position track)
    <m>.glb.import     Godot import parameters (written next to the .glb)
    index.json         model -> bones, clips (frames, framerate, hands, ...), bind discrepancy, AABB
All paths stored inside index.json are relative to the output folder.

Format knowledge comes from reading sacengine's saxs.d / sxmd.d / sxsk.d / skel.d (GPL-3, read only);
this file is written independently from the layout and does not copy its code.

Axes: the OBJs of sacengine's saveObj are (x, z, -y) of the engine axes, where the
engine axes are fromSXMD(v) = (-x, -z, y). In the OBJ space a raw SXMD vector (x, y, z) is therefore
(-x, y, z) and a raw SXSK quaternion (x, y, z, w) is (-x, y, z, w). Lengths are scaled by SAXS `scaling`.
Root displacement of a frame (game rule, sxsk.d frameOffset) = scaling * zfactor/referenceHeight * (-d0, d1, d2).

Usage: python3 tools/import/export_skeletal.py [--out DIR] [model ...]      (default models: eorc jnwr)
"""

import argparse
import importlib.util
import json
import math
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "import"))
from sac_formats.gltf_writer import FLOAT, UINT, USHORT, Gltf, import_params, write_glb as pack_glb  # noqa: E402
## The single place that names the output folder; everything else is relative to --out.
DEFAULT_OUT = ROOT / "assets" / "original" / "models"
DEFAULT_MODELS = ["eorc", "jnwr"]
MAX_BONES = 32
## Engine flags used when the game builds a body (saxs.d loadSaxs): selection of rings and vertices.
ACTOR_FLAGS = 0x1C10

EVENT_KINDS = {
    b"!xfs": "sound",
    b"kcta": "attack",
    b"liba": "load",
    b"lrba": "shoot",
    b"tsac": "cast",
    b"hted": "death",
    b"barg": "grab",
    b"toof": "foot",
}


def _load(name: str, filename: str):
    spec = importlib.util.spec_from_file_location(name, ROOT / "tools" / "import" / filename)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


sys.path.insert(0, str(ROOT / "tools" / "import"))
from sac_formats import wad as ex  # noqa: E402  (walk)
stats = _load("export_stats", "export_stats.py")


# ---------------------------------------------------------------------------------------------------------
# SXMD / SAXS: skeleton and mesh
# ---------------------------------------------------------------------------------------------------------


def u8(b, o):
    return b[o]


def u16(b, o):
    return struct.unpack_from("<H", b, o)[0]


def u32(b, o):
    return struct.unpack_from("<I", b, o)[0]


def f32(b, o):
    return struct.unpack_from("<f", b, o)[0]


def to_obj(v, scale):
    """Raw SXMD vector -> OBJ space, scaled."""
    return (-v[0] * scale, v[1] * scale, v[2] * scale)


class Entry:
    """A ring entry (10 bytes) read live from the SXMD buffer."""

    __slots__ = ("offset", "indices", "u", "v", "flags")

    def __init__(self, data, offset):
        a, b, c, self.u, self.v, self.flags = struct.unpack_from("<HHHBBH", data, offset)
        self.indices = [i for i in (a, b, c) if i != 0xFFFF]
        self.offset = offset


class Model:
    """Everything the skeleton, the weights and the faces need from one SXMD + SAXS + SXTX heights."""

    def __init__(self, sxmd: bytes, saxs: bytes, tex_heights: list):
        self.data = bytearray(sxmd)
        d = self.data
        self.scaling = f32(saxs, 0)
        self.vertex_step = int(f32(saxs, 8) * 65536.0)
        self.ring_step = int(f32(saxs, 12) * 65536.0)
        assert self.vertex_step > 0 and self.ring_step > 0, "SAXS quality values"
        self.zfactor = f32(d, 8)
        num_parts = d[0]
        num_bones = u32(d, 28) - 1
        bone_off = u32(d, 32) + 140
        vertex_off = u32(d, 36)
        # Bones: index 0 is a synthetic root; file bone i is index i + 1 (parents refer to this indexing).
        self.bone_pos = [(0.0, 0.0, 0.0)]
        self.bone_parent = [0]
        for i in range(num_bones):
            o = bone_off + 140 * i
            raw = struct.unpack_from("<3f", d, o)
            self.bone_pos.append(to_obj(raw, self.scaling))
            self.bone_parent.append(u16(d, o + 12))
        assert all(self.bone_parent[i] < i for i in range(1, len(self.bone_parent)))
        # Body parts.
        self.parts = []
        num_positions = 0
        for k in range(num_parts):
            off = u32(d, 40 + 4 * k)
            num_rings, extra, num_explicit = d[off], d[off + 1], u16(d, off + 2)
            flags, explicit_off, strips_off = struct.unpack_from("<III", d, off + 20)
            rings = []
            for r in range(num_rings):
                ro = u32(d, off + 36 + 4 * r)
                count = d[ro] + 256 * extra
                eo = u32(d, ro + 4)
                rings.append({"header": ro, "count": count, "entries_at": eo, "selector": d[ro + 1]})
                for e in range(count):
                    for idx in struct.unpack_from("<HHH", d, eo + 10 * e):
                        if idx != 0xFFFF and idx >= num_positions:
                            num_positions = idx + 1
            explicit = []
            if num_explicit:
                for f in range(num_explicit):
                    explicit.append(struct.unpack_from("<HHH", d, explicit_off + 6 * f))
            part = {
                "flags": flags,
                "rings": rings,
                "num_explicit": num_explicit,
                "explicit": explicit,
                "strips_off": strips_off,
                "strips": [],
                "other_part": 0,
                "wrap_u": 0,
            }
            if strips_off:
                n = u16(d, strips_off + 2)
                part["num_strips"] = n
            self.parts.append(part)
        self.positions = []
        for p in range(num_positions):
            o = vertex_off + 16 * p
            px, py, pz, bone, weight = struct.unpack_from("<hhhhH", d, o)
            self.positions.append(
                {"bone": bone, "offset": to_obj((px, py, pz), self.scaling), "weight": weight / 16384.0}
            )
        self._prepare_uvs(tex_heights)
        for part in self.parts:
            if part["strips_off"]:
                so = part["strips_off"]
                part["other_part"] = d[so]
                part["wrap_u"] = d[so + 1]
                part["strips"] = [
                    struct.unpack_from("<HHHBB", d, so + 8 + 8 * s) for s in range(part["num_strips"])
                ]
        self._build()

    # -- texture coordinates as the game prepares them (in place, like the original buffer) -----------------
    def _prepare_uvs(self, heights):
        d = self.data
        for bi, part in enumerate(self.parts):
            loaded_h = heights[bi]
            for ri, ring in enumerate(part["rings"]):
                if part["num_explicit"]:
                    v_scale = 1.0 / ((loaded_h - 1.0) / 256.0 + 0.001)
                    for e in range(ring["count"]):
                        o = ring["entries_at"] + 10 * e
                        d[o + 6] = d[o + 6] & 0xFF  # textureU * 256 / 256
                        d[o + 7] = int(d[o + 7] * v_scale) & 0xFF
                else:
                    if ri + 1 == len(part["rings"]):
                        row = 255
                    else:
                        row = (255 * (u16(d, ring["header"] + 2) + 1) + 8192) // 16384
                    for e in range(ring["count"]):
                        o = ring["entries_at"] + 10 * e
                        d[o + 7] = row & 0xFF
                struct.pack_into("<H", d, ring["header"] + 2, 256)
            if part["strips_off"]:
                so = part["strips_off"]
                d[so + 1] = 255
                n = u16(d, so + 2)
                for s in range(n):
                    o = so + 8 + 8 * s
                    d[o + 6] = d[o + 6] & 0xFF
                    d[o + 7] = d[o + 7] & 0xFF

    def entry(self, offset):
        return Entry(self.data, offset)

    # -- ring / vertex / face construction (fixed topology, same as the game) -------------------------------
    def _build(self):
        parts = self.parts
        # Seam bodies: records rotated so the first owner record with u == 0 leads.
        seam = []
        for pi, part in enumerate(parts):
            records = list(part["strips"])
            flags = part["flags"]
            if flags & 0x80 and records:
                for a, rec in enumerate(records):
                    if rec[0] != pi or rec[3] != 0:
                        continue
                    records = records[a:] + records[:a]
                    flags |= 0x100 if records[0][1] == 0 else 0x200
                    break
            seam.append(
                {
                    "records": records,
                    "flags": flags,
                    "other": part["other_part"],
                    "wrap_u": part["wrap_u"],
                    "rings": [{"vertices": None, "active": True, "selector": r["selector"]} for r in part["rings"]],
                }
            )
        selected_rings = [select_rings(seam[i], self.ring_step) for i in range(len(parts))]
        selected_vertices = []
        emitted = {}
        for part in parts:
            for ring in part["rings"]:
                for e in range(ring["count"]):
                    emitted[ring["entries_at"] + 10 * e] = False
        for pi, part in enumerate(parts):
            per_ring = [None] * len(part["rings"])
            for rj in selected_rings[pi]:
                ring = part["rings"][rj]
                entries = [self.entry(ring["entries_at"] + 10 * e) for e in range(ring["count"])]
                flags = [e.flags & 0xFEFF for e in entries]
                sel = select_vertices(flags, self.vertex_step, part["num_explicit"] != 0)
                per_ring[rj] = sel
                for k in sel:
                    emitted[entries[k].offset] = True
            selected_vertices.append(per_ring)
        ring_lengths = [[r["count"] for r in part["rings"]] for part in parts]
        for owner, body in enumerate(seam):
            for rec in body["records"]:
                if rec[0] == owner:
                    if body["flags"] & 0x80:
                        ring = selected_rings[owner][0] if body["flags"] & 0x100 else selected_rings[owner][-1]
                    else:
                        ring = rec[1]
                    if 0 <= ring < len(parts[owner]["rings"]):
                        ring_lengths[owner][ring] = max(ring_lengths[owner][ring], rec[2] + 1)
                other = body["other"]
                if other < len(parts) and rec[0] == other and rec[1] < len(parts[other]["rings"]):
                    ring_lengths[other][rec[1]] = max(ring_lengths[other][rec[1]], rec[2] + 1)
        for pi, part in enumerate(parts):
            rings = []
            for rj, ring in enumerate(part["rings"]):
                source = []
                for k in range(ring_lengths[pi][rj]):
                    e = self.entry(ring["entries_at"] + 10 * k)
                    active = emitted[e.offset] if e.offset in emitted else (e.flags & 0x100) != 0
                    source.append({"indices": e.indices, "u": e.u, "v": e.v, "active": active})
                rings.append({"vertices": source, "active": rj in selected_rings[pi], "selector": ring["selector"]})
            seam[pi]["rings"] = rings
        self.part_meshes = []
        for pi, part in enumerate(parts):
            vertices = []  # (indices, u, v)
            vrt = [None] * len(part["rings"])
            for rj in selected_rings[pi]:
                ring = part["rings"][rj]
                sel = selected_vertices[pi][rj]
                vrt[rj] = [0] * (len(sel) + 1)
                for ordinal, k in enumerate(sel):
                    e = self.entry(ring["entries_at"] + 10 * k)
                    vrt[rj][ordinal] = len(vertices)
                    vertices.append([e.indices, e.u / 256.0, e.v / 256.0])
                vrt[rj][len(sel)] = len(vertices)
                first = vertices[vrt[rj][0]]
                vertices.append([first[0], u16(self.data, ring["header"] + 2) / 256.0, first[2]])
            faces = []
            sr = selected_rings[pi]
            for k in range(len(sr) - 1):
                j, nxt = sr[k], sr[k + 1]
                old_ring = part["rings"][j]
                new_ring = part["rings"][nxt]
                old_entries = [self.entry(old_ring["entries_at"] + 10 * e) for e in range(old_ring["count"])]
                new_entries = [self.entry(new_ring["entries_at"] + 10 * e) for e in range(new_ring["count"])]
                old_rv = [[e.flags, e.u, False] for e in old_entries]
                new_rv = [[e.flags, e.u, False] for e in new_entries]
                for n in selected_vertices[pi][j]:
                    old_rv[n][2] = True
                for n in selected_vertices[pi][nxt]:
                    new_rv[n][2] = True
                old_post = self.entry(old_ring["entries_at"] + 10 * old_ring["count"]).flags
                new_post = self.entry(new_ring["entries_at"] + 10 * new_ring["count"]).flags
                base = vrt[j][0]
                for f in build_ring_faces(old_rv, new_rv, old_post, new_post):
                    faces.append((f[0] + base, f[2] + base, f[1] + base))
            for first_cap in (True, False):
                j = sr[0] if first_cap else sr[-1]
                if (j != 0) if first_cap else (j != len(part["rings"]) - 1):
                    continue
                count = len(selected_vertices[pi][j]) + (0 if first_cap else 1)
                for f in build_cap(part["flags"], first_cap, vrt[j][0], count):
                    faces.append((f[0], f[2], f[1]))
            if part["explicit"]:
                assert len(vrt) == 1
                for ef in part["explicit"]:
                    faces.append((vrt[0][ef[0]], vrt[0][ef[1]], vrt[0][ef[2]]))
            self.part_meshes.append({"vertices": vertices, "faces": faces})
        for pi, body in enumerate(seam):
            if not body["records"]:
                continue
            sv, sf = build_seam(seam, pi, selected_rings[pi][0], selected_rings[pi][-1])
            mesh = self.part_meshes[pi]
            base = len(mesh["vertices"])
            for indices, u, v in sv:
                mesh["vertices"].append([indices, u, v])
            for f in sf:
                mesh["faces"].append((f[0] + base, f[2] + base, f[1] + base))

    # -- bind pose and weights ----------------------------------------------------------------------------
    def abs_pos(self):
        out = [(0.0, 0.0, 0.0)]
        for i in range(1, len(self.bone_pos)):
            p = out[self.bone_parent[i]]
            b = self.bone_pos[i]
            out.append((p[0] + b[0], p[1] + b[1], p[2] + b[2]))
        return out

    def influences(self, indices):
        """[(bone, offset, weight)] for a vertex, in file order."""
        return [(self.positions[k]["bone"], self.positions[k]["offset"], self.positions[k]["weight"]) for k in indices]


# -- selection helpers -------------------------------------------------------------------------------------


def advance_ring(lod_step, body, selector, boundary_selector):
    result = selector + lod_step
    scan = (selector >> 16) + 1
    target = result >> 16
    boundary = boundary_selector >> 16
    while scan < target and scan < boundary:
        if body["rings"][scan]["selector"] & 1:
            result = scan << 16
            target = scan
        else:
            body["rings"][scan]["selector"] &= ~2 & 0xFF
        scan += 1
    return result


def select_rings(body, lod_step):
    count = len(body["rings"])
    boundary_selector = count << 16
    selector = 0
    if body["flags"] & 0x80 and (ACTOR_FLAGS & 0x1400) == 0x1400:
        if body["flags"] & 0x100:
            selector = advance_ring(lod_step, body, 0, boundary_selector)
        elif body["flags"] & 0x200:
            candidate = boundary_selector - lod_step
            boundary_selector = candidate if candidate >= 0x20000 else count << 16
    result = []
    while True:
        if selector >= boundary_selector:
            if boundary_selector != count << 16:
                break
            if ((selector - lod_step) >> 16) == count - 1:
                break
            selector = (count - 1) << 16
        result.append(selector >> 16)
        selector = advance_ring(lod_step, body, selector, boundary_selector)
    return result


def select_vertices(flags, vertex_step, has_explicit):
    end = len(flags) << 16
    step = 0x10000 if has_explicit else vertex_step
    if end // step < 3:
        step = end // 3 + 1
    result = []
    selector = 0
    while selector < end:
        current = selector >> 16
        flags[current] |= 0x100
        result.append(current)
        nxt = selector + step
        skipped_fixed = selector + 0x10000
        skipped = current + 1
        while skipped < (nxt >> 16) and skipped_fixed < end:
            if not (ACTOR_FLAGS & 0x4000) and flags[skipped] & 0x80:
                flags[skipped] |= 0x100
                result.append(skipped)
            else:
                flags[skipped] &= 0xFEFF
            skipped += 1
            skipped_fixed += 0x10000
        selector = nxt
    return result


def build_cap(body_flags, first, base, count):
    if not (ACTOR_FLAGS & 0x402) or not (ACTOR_FLAGS & 0x800) or not (body_flags & (1 if first else 2)) or count < 3:
        return []
    out = []
    for k in range(1, count - 1):
        out.append((base, base + k + 1, base + k) if first else (base, base + k, base + k + 1))
    return out


def build_ring_faces(old_ring, new_ring, old_post, new_post):
    """Triangle strip between two rings of selected vertices; entries are [flags, u, active]."""
    old_active = sum(1 for v in old_ring if v[2])
    new_active = sum(1 for v in new_ring if v[2])
    out = []
    if not old_active or not new_active:
        return out
    old_base = 0
    new_base = old_active + 1
    s = {"oc": 0, "nc": 0, "oo": 0, "no": 0, "oi": -1, "ni": -1, "prev": -1, "have": False,
         "ow": False, "nw": False, "fetched_new": True}

    def special(ring, cur):
        return (ring[cur][0] & 0x60) != 0

    def next_special(ring, cur, post):
        raw = cur + 1
        flags = ring[raw][0] if raw < len(ring) else post
        return (flags & 0x60) != 0

    def fetch_old():
        while not old_ring[s["oc"]][2]:
            s["oc"] += 1
            if s["oc"] == len(old_ring):
                s["oc"] = 0
                s["ow"] = True
        s["oi"] = old_base + s["oo"]
        s["oo"] += 1
        s["fetched_new"] = False

    def fetch_new():
        while not new_ring[s["nc"]][2]:
            s["nc"] += 1
            if s["nc"] == len(new_ring):
                s["nc"] = 0
                s["nw"] = True
        s["ni"] = new_base + s["no"]
        s["no"] += 1
        s["fetched_new"] = True

    while True:
        if s["oi"] < 0:
            fetch_old()
        if s["ni"] < 0:
            fetch_new()
        if s["have"]:
            if s["fetched_new"]:
                out.append((s["prev"], s["oi"], s["ni"]))
            else:
                out.append((s["ni"], s["prev"], s["oi"]))
        consume_old = (old_ring[s["oc"]][1] < new_ring[s["nc"]][1] or s["nw"]) and not s["ow"]
        old_special = special(old_ring, s["oc"])
        new_special = special(new_ring, s["nc"])
        if old_special and consume_old and next_special(new_ring, s["nc"], new_post):
            consume_old = False
        elif not old_special and new_special and not consume_old and next_special(old_ring, s["oc"], old_post):
            consume_old = True
        if consume_old:
            s["prev"] = s["oi"]
            s["have"] = True
            s["oi"] = -1
            s["oc"] += 1
            if s["oc"] == len(old_ring):
                if s["nw"]:
                    out.append((s["ni"], s["prev"], old_base + s["oo"]))
                    return out
                s["oc"] = 0
                s["oi"] = old_base + s["oo"]
                s["oo"] = 0
                s["fetched_new"] = not s["fetched_new"]
                s["ow"] = True
        else:
            s["prev"] = s["ni"]
            s["have"] = True
            s["ni"] = -1
            s["nc"] += 1
            if s["nc"] == len(new_ring):
                if s["ow"]:
                    out.append((s["prev"], s["oi"], new_base + s["no"]))
                    return out
                s["nc"] = 0
                s["ni"] = new_base + s["no"]
                s["no"] = 0
                s["fetched_new"] = not s["fetched_new"]
                s["nw"] = True
        if s["ow"] and s["nw"]:
            return out


def build_seam(bodies, owner, first_ring, last_ring):
    """Returns ([(indices, u, v)], [(a, b, c)]) of the seam strip joining two body parts."""
    body = bodies[owner]
    records = body["records"]
    vertices, faces = [], []
    if not records:
        return vertices, faces
    boundary = (body["flags"] & 0x80) != 0
    selected_ring = first_ring if body["flags"] & 0x100 else last_ring
    if boundary and selected_ring >= len(body["rings"]):
        return vertices, faces
    st = {"a": 0, "b": 0, "wa": False, "wb": False}

    def scan(key, wkey, is_owner):
        crossed = False
        while True:
            r = records[st[key]]
            part = owner if is_owner else body["other"]
            if r[0] == part:
                ring = selected_ring if (is_owner and boundary) else r[1]
                source = bodies[part]["rings"][ring]
                if source["active"] and source["vertices"][r[2]]["active"]:
                    return source["vertices"][r[2]]
            st[key] += 1
            if st[key] == len(records):
                st[key] = 0
                st[wkey] = True
                if crossed:
                    return None
                crossed = True

    have_a = have_b = have_prev = False
    cur_a = cur_b = prev = 0
    while True:
        if not have_a:
            src = scan("a", "wa", True)
            if src is None:
                return vertices, faces
            cur_a = len(vertices)
            vertices.append((src["indices"], (body["wrap_u"] if st["wa"] else src["u"]) / 256.0, src["v"] / 256.0))
            have_a = True
        if not have_b:
            src = scan("b", "wb", False)
            if src is None:
                return vertices, faces
            cur_b = len(vertices)
            r = records[st["b"]]
            if boundary:
                ra = records[st["a"]]
                v = bodies[owner]["rings"][ra[1]]["vertices"][ra[2]]["v"]
            else:
                v = r[4]
            vertices.append((src["indices"], (body["wrap_u"] if st["wb"] else r[3]) / 256.0, v / 256.0))
            have_b = True
        if have_prev:
            faces.append((cur_a, prev, cur_b))
            if st["wa"] and st["wb"]:
                return vertices, faces
        if (st["a"] < st["b"] and not st["wa"]) or st["wb"]:
            prev = cur_a
            have_a = False
            st["a"] += 1
            if st["a"] == len(records):
                st["a"] = 0
                st["wa"] = True
        else:
            prev = cur_b
            have_b = False
            st["b"] += 1
            if st["b"] == len(records):
                st["b"] = 0
                st["wb"] = True
        have_prev = True


# ---------------------------------------------------------------------------------------------------------
# SXSK / SKEL: clips
# ---------------------------------------------------------------------------------------------------------


def parse_clip(sxsk: bytes, skel: bytes | None, model: Model):
    frames = u16(sxsk, 2)
    reference = f32(sxsk, 4)
    num_bones = u16(sxsk, 8)
    if num_bones != len(model.bone_pos) or frames == 0:
        return None
    ratio = model.zfactor / reference if reference > 0 else 1.0
    s = model.scaling
    rots, disp = [], []
    for i in range(frames):
        _unk, d0, d1, d2, offset = struct.unpack_from("<hhhhI", sxsk, 12 + 12 * i)
        disp.append((-d0 * s * ratio, d1 * s * ratio, d2 * s * ratio))
        frame = []
        for b in range(num_bones):
            x, y, z, w = struct.unpack_from("<hhhh", sxsk, offset + 8 * b)
            n = math.sqrt(x * x + y * y + z * z + w * w)
            if n == 0.0:
                # A bone with no rotation in the SXSK (all four shorts zero). sacengine's dlib normalize() turns a
                # zero vector into (0, 0, 0, 1), the identity; glTF needs a unit quaternion.
                frame.append((0.0, 0.0, 0.0, 1.0))
                continue
            frame.append((-x / n, y / n, z / n, w / n))  # OBJ space, normalized
        rots.append(frame)
    # Keep neighbouring quaternions in the same hemisphere so interpolation takes the short way.
    for b in range(num_bones):
        for i in range(1, frames):
            p, q = rots[i - 1][b], rots[i][b]
            if p[0] * q[0] + p[1] * q[1] + p[2] * q[2] + p[3] * q[3] < 0:
                rots[i][b] = (-q[0], -q[1], -q[2], -q[3])
    clip = {"frames": frames, "framerate": 30, "reference_height": reference, "rot": rots, "disp": disp,
            "events": [], "hands": []}
    if skel and len(skel) >= 140:
        clip["framerate"] = max(1, u32(skel, 4))
        for i in range(min(u32(skel, 8), 8)):
            frame = min(u32(skel, 12 + 12 * i), frames - 1)
            tag = bytes(skel[16 + 12 * i : 20 + 12 * i])
            kind = EVENT_KINDS.get(tag)
            if tag == b"\0\0\0\0":
                continue
            clip["events"].append({"frame": frame, "kind": kind or ("unknown:" + tag[::-1].decode("latin1")),
                                   "parameter": round(f32(skel, 20 + 12 * i), 6)})
        for h in range(2):
            o = 108 + 16 * h
            bone = u16(skel, o)
            off = list(struct.unpack_from("<3f", skel, o + 4))
            if off[1] == 275.0:
                off[1] *= 1e-3  # same fix the game applies to the yogo walking cast clip
            clip["hands"].append({"bone": bone, "offset_raw": [round(c, 6) for c in off]})
    return clip


# ---------------------------------------------------------------------------------------------------------
# glTF writer
# ---------------------------------------------------------------------------------------------------------


def smooth_normals(positions, faces):
    acc = [[0.0, 0.0, 0.0] for _ in positions]
    for a, b, c in faces:
        pa, pb, pc = positions[a], positions[b], positions[c]
        u = (pb[0] - pa[0], pb[1] - pa[1], pb[2] - pa[2])
        v = (pc[0] - pa[0], pc[1] - pa[1], pc[2] - pa[2])
        n = (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0])
        for i in (a, b, c):
            for k in range(3):
                acc[i][k] += n[k]
    out = []
    for n in acc:
        length = math.sqrt(n[0] ** 2 + n[1] ** 2 + n[2] ** 2) or 1.0
        out.append((n[0] / length, n[1] / length, n[2] / length))
    return out


def bone_name(i):
    return "root" if i == 0 else "bone_%02d" % i


## Quantization of the helper-joint bind shift (metres): 0.5 mm (error <= 0.43 mm per influence).
SHIFT_STEP = 5e-4
## A vertex gets helper joints only when its influences disagree by more than this (metres); below it the
## averaged bind is used with the real bones (error < the threshold). Together they stay inside 1 mm.
BIND_THRESHOLD = 5e-4
## Vertices whose raw weights do not sum to 1 within this are reported (the game does not normalize them).
WEIGHT_SUM_TOLERANCE = 0.002
## Largest bind error (mm) a model may have with one bind per vertex; above it the model gets helper joints.
MAX_ERROR_MM = 30.0


def build_skin_parts(model: Model, exact: bool = True):
    """Bind positions, joints, weights per part.

    The game gives every influence its own offset in bone space; glTF skinning has one bind position per vertex.
    exact=True: the bind position is the point of the heaviest influence and every other influence gets a helper
    joint (same world transform as its bone, child of it, never animated) whose inverse bind is shifted by
    s = q_k - q_main, so that skin = T_bone(off_k) exactly. exact=False: one averaged bind (cheap, off by the
    reported discrepancy). Returns (parts, stats, helpers) with helpers = [(bone, (kx, ky, kz))]."""
    abs_pos = model.abs_pos()
    nbones = len(model.bone_pos)
    parts = []
    helper_index = {}
    helpers = []
    unnormalized = []  # (surface, vertex before dropping, weight sum, bind distance from the root origin)
    worst, total, count = 0.0, 0.0, 0
    residual = 0.0  # largest bind error left after the helper joints (vertices that keep an averaged bind)
    worst_per_part = []
    for mesh in model.part_meshes:
        pos, joints, weights = [], [], []
        part_worst = 0.0
        for indices, _u, _v in mesh["vertices"]:
            infl = model.influences(indices)
            if not infl:
                pos.append((0.0, 0.0, 0.0))
                joints.append((0, 0, 0, 0))
                weights.append((1.0, 0.0, 0.0, 0.0))
                continue
            wsum = sum(w for _b, _o, w in infl) or 1.0
            world = [
                (abs_pos[b][0] + o[0], abs_pos[b][1] + o[1], abs_pos[b][2] + o[2]) for b, o, _w in infl
            ]
            avg = tuple(sum(w * p[k] for (_b, _o, w), p in zip(infl, world)) / wsum for k in range(3))
            d = max(math.dist(p, avg) for p in world)
            part_worst = max(part_worst, d)
            total += d
            count += 1
            main = max(range(len(infl)), key=lambda i: infl[i][2])
            order = [main] + [i for i in range(len(infl)) if i != main]
            if abs(wsum - 1.0) > WEIGHT_SUM_TOLERANCE:
                unnormalized.append((len(parts), len(pos), wsum, math.sqrt(sum(c * c for c in avg))))
            if exact and d > BIND_THRESHOLD:
                bind = world[main]
                j = []
                for i in order:
                    b = infl[i][0]
                    shift = tuple(world[i][k] - bind[k] for k in range(3))
                    key = tuple(round(c / SHIFT_STEP) for c in shift)
                    if i == main or key == (0, 0, 0):
                        j.append(b)
                    else:
                        hk = (b, key)
                        if hk not in helper_index:
                            helper_index[hk] = nbones + len(helpers)
                            helpers.append(hk)
                        j.append(helper_index[hk])
            else:
                residual = max(residual, d)
                bind = avg
                j = [infl[i][0] for i in order]
            w = [infl[i][2] / wsum for i in order]
            pos.append(bind)
            joints.append(tuple(j + [0] * (4 - len(j))))
            weights.append(tuple(w + [0.0] * (4 - len(w))))
        worst = max(worst, part_worst)
        worst_per_part.append(part_worst)
        parts.append({"pos": pos, "joints": joints, "weights": weights})
    stats_out = {"max_mm": round(worst * 1000.0, 4), "residual_max_mm": round(residual * 1000.0, 4), "mean_mm": round(total / max(count, 1) * 1000.0, 4),
                 "per_part_max_mm": [round(w * 1000.0, 4) for w in worst_per_part],
                 "helper_joints": len(helpers), "exact": exact, "bind_threshold_mm": BIND_THRESHOLD * 1000.0,
                 "shift_step_mm": SHIFT_STEP * 1000.0}
    return parts, stats_out, helpers, unnormalized


def winding_is_flipped(model: Model, parts) -> bool:
    """True when the faces (engine order) are clockwise seen from outside in OBJ space.

    The game's ObjMesh decides this per mesh from the file normals; here the bind-pose geometry is compared
    with the vertex normals stored in the SXMD (first influence)."""
    score = 0.0
    for mesh, data in zip(model.part_meshes, parts):
        for a, b, c in mesh["faces"]:
            pa, pb, pc = data["pos"][a], data["pos"][b], data["pos"][c]
            u = (pb[0] - pa[0], pb[1] - pa[1], pb[2] - pa[2])
            v = (pc[0] - pa[0], pc[1] - pa[1], pc[2] - pa[2])
            n = (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0])
            c3 = ((pa[0] + pb[0] + pc[0]) / 3.0, (pa[1] + pb[1] + pc[1]) / 3.0, (pa[2] + pb[2] + pc[2]) / 3.0)
            score += n[0] * c3[0] + n[1] * c3[1] + n[2] * c3[2]
    return score < 0.0


_TEXTURE_INDEX = None


def material_key(model_tag: str, part: int):
    """What the game draws body part `part` with: (owner, file, cutout) of textures/index.json. Parts with the same key
    share one material and so one primitive. A part with no entry stays alone."""
    global _TEXTURE_INDEX
    if _TEXTURE_INDEX is None:
        path = ROOT / "assets" / "original" / "textures" / "index.json"
        _TEXTURE_INDEX = json.loads(path.read_text())["models"] if path.exists() else {}
    entry = _TEXTURE_INDEX.get(model_tag.lower(), {}).get("bodypart%03d" % (part + 1))
    return (entry["owner"], entry["file"], entry["cutout"]) if entry else ("part", part)


def write_glb(path: Path, model_tag: str, model: Model, clips: dict, exact: bool = True):
    g = Gltf()
    abs_pos = model.abs_pos()
    nbones = len(model.bone_pos)
    parts, discrepancy, helpers, unnormalized = build_skin_parts(model, exact)
    # glTF front faces are counter-clockwise. The engine order is counter-clockwise seen from outside when
    # the cross product (b-a)x(c-a) points away from the centre, so keep it; reverse otherwise.
    reverse = winding_is_flipped(model, parts)
    lo_all = [1e30] * 3
    hi_all = [-1e30] * 3
    dropped = []  # per body part: vertex indices (in the engine/OBJ order) that no face uses and so are not written
    built = []  # per body part: pos, normals, uv, joints, weights, faces (indices local to the part)
    for mesh, data in zip(model.part_meshes, parts):
        faces = [(a, c, b) if reverse else (a, b, c) for a, b, c in mesh["faces"]]
        used = sorted({i for f in faces for i in f})
        dropped.append([i for i in range(len(data["pos"])) if i not in set(used)])
        if dropped[-1]:
            remap = {old: new for new, old in enumerate(used)}
            faces = [tuple(remap[i] for i in f) for f in faces]
            data = {k: [v[i] for i in used] for k, v in data.items()}
            mesh = dict(mesh, vertices=[mesh["vertices"][i] for i in used])
        # Normals stay per body part (the seams of the engine are not welded), so merging parts changes nothing.
        built.append({"pos": data["pos"], "nrm": smooth_normals(data["pos"], faces),
                      "uv": [(u, v) for (_i, u, v) in mesh["vertices"]],
                      "joints": data["joints"], "weights": data["weights"], "faces": faces})
    # One primitive per distinct material (same texture file and cutout): parts that share one are concatenated in
    # part order, with their own indices, weights, UVs and normals. surface_parts[s] = the body parts of surface s.
    groups = {}
    for pi in range(len(built)):
        groups.setdefault(material_key(model_tag, pi), []).append(pi)
    surface_parts = list(groups.values())
    # The parity audit compares surface by surface against the OBJ (part order): groups must be runs of parts.
    assert [p for m in surface_parts for p in m] == list(range(len(built))), "%s: shared materials not contiguous" % model_tag
    part_offset = {}  # body part -> (surface, first vertex of the part inside the surface)
    primitives = []
    for si, members in enumerate(surface_parts):
        cat = {"pos": [], "nrm": [], "uv": [], "joints": [], "weights": [], "faces": []}
        for pi in members:
            base = len(cat["pos"])
            part_offset[pi] = (si, base)
            for k in ("pos", "nrm", "uv", "joints", "weights"):
                cat[k] += built[pi][k]
            cat["faces"] += [(a + base, b + base, c + base) for a, b, c in built[pi]["faces"]]
        n = len(cat["pos"])
        lo = [min(p[k] for p in cat["pos"]) for k in range(3)]
        hi = [max(p[k] for p in cat["pos"]) for k in range(3)]
        for k in range(3):
            lo_all[k], hi_all[k] = min(lo_all[k], lo[k]), max(hi_all[k], hi[k])
        flat = [c for p in cat["pos"] for c in p]
        acc_pos = g.accessor(struct.pack("<%df" % len(flat), *flat), FLOAT, n, "VEC3", 34962, lo, hi)
        flat = [c for p in cat["nrm"] for c in p]
        acc_nrm = g.accessor(struct.pack("<%df" % len(flat), *flat), FLOAT, n, "VEC3", 34962)
        flat = [c for uv in cat["uv"] for c in uv]
        acc_uv = g.accessor(struct.pack("<%df" % len(flat), *flat), FLOAT, n, "VEC2", 34962)
        flat = [c for j in cat["joints"] for c in j]
        acc_j = g.accessor(struct.pack("<%dH" % len(flat), *flat), USHORT, n, "VEC4", 34962)
        flat = [c for w in cat["weights"] for c in w]
        acc_w = g.accessor(struct.pack("<%df" % len(flat), *flat), FLOAT, n, "VEC4", 34962)
        flat = [i for f in cat["faces"] for i in f]
        if n < 65536:
            acc_i = g.accessor(struct.pack("<%dH" % len(flat), *flat), USHORT, len(flat), "SCALAR", 34963)
        else:
            acc_i = g.accessor(struct.pack("<%dI" % len(flat), *flat), UINT, len(flat), "SCALAR", 34963)
        primitives.append({"attributes": {"POSITION": acc_pos, "NORMAL": acc_nrm, "TEXCOORD_0": acc_uv,
                                          "JOINTS_0": acc_j, "WEIGHTS_0": acc_w}, "indices": acc_i, "mode": 4})
    # inverse bind matrices (column-major): translation by -absolute bind position; a helper joint's is
    # shifted by its quantized bind shift.
    ibm = []
    for p in abs_pos:
        ibm += [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -p[0], -p[1], -p[2], 1]
    for b, key in helpers:
        p = abs_pos[b]
        ibm += [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0,
                key[0] * SHIFT_STEP - p[0], key[1] * SHIFT_STEP - p[1], key[2] * SHIFT_STEP - p[2], 1]
    njoints = nbones + len(helpers)
    acc_ibm = g.accessor(struct.pack("<%df" % len(ibm), *ibm), FLOAT, njoints, "MAT4")
    children = [[] for _ in range(nbones)]
    for i in range(1, nbones):
        children[model.bone_parent[i]].append(i)
    for h, (b, _key) in enumerate(helpers):
        children[b].append(nbones + h)
    nodes = []
    for i in range(nbones):
        node = {"name": bone_name(i), "translation": [round(c, 9) for c in model.bone_pos[i]]}
        if children[i]:
            node["children"] = children[i]
        nodes.append(node)
    for h, (b, _key) in enumerate(helpers):
        nodes.append({"name": "%s_h%03d" % (bone_name(b), h)})
    mesh_node = len(nodes)
    nodes.append({"name": model_tag + "_mesh", "mesh": 0, "skin": 0})
    animations = []
    for tag, clip in clips.items():
        fps = clip["framerate"]
        times = struct.pack("<%df" % clip["frames"], *[i / fps for i in range(clip["frames"])])
        t_acc = g.accessor(times, FLOAT, clip["frames"], "SCALAR", None, [0.0], [(clip["frames"] - 1) / fps])
        samplers, channels = [], []
        for b in range(nbones):
            flat = [c for i in range(clip["frames"]) for c in clip["rot"][i][b]]
            acc = g.accessor(struct.pack("<%df" % len(flat), *flat), FLOAT, clip["frames"], "VEC4")
            samplers.append({"input": t_acc, "output": acc, "interpolation": "LINEAR"})
            channels.append({"sampler": len(samplers) - 1, "target": {"node": b, "path": "rotation"}})
        # Root motion: displacement (in place by default) added to the root rest position (zero).
        flat = [c for d in clip["disp"] for c in d]
        acc = g.accessor(struct.pack("<%df" % len(flat), *flat), FLOAT, clip["frames"], "VEC3")
        samplers.append({"input": t_acc, "output": acc, "interpolation": "LINEAR"})
        channels.append({"sampler": len(samplers) - 1, "target": {"node": 0, "path": "translation"}})
        animations.append({"name": tag, "samplers": samplers, "channels": channels})
    doc = {
        "asset": {"version": "2.0", "generator": "sacproject tools/import/export_skeletal.py"},
        "scene": 0,
        "scenes": [{"nodes": [0, mesh_node]}],
        "nodes": nodes,
        "skins": [{"name": model_tag + "_skin", "joints": list(range(njoints)), "inverseBindMatrices": acc_ibm,
                   "skeleton": 0}],
        "meshes": [{"name": model_tag, "primitives": primitives}],
        "animations": animations,
    }
    pack_glb(path, doc, g)
    # Written vertex numbering (unused vertices removed) for the vertices the game does not normalize.
    unnorm_out = []
    for part, vertex, wsum, radius in unnormalized:
        written = vertex - sum(1 for d in dropped[part] if d < vertex)
        surface, first = part_offset[part]
        unnorm_out.append({"surface": surface, "vertex": first + written, "weight_sum": round(wsum, 6),
                           "predicted_err_mm": round(abs(wsum - 1.0) * radius * 1000.0, 3)})
    discrepancy["unnormalized_count"] = len(unnorm_out)
    dropped_out = dropped
    return discrepancy, reverse, (lo_all, hi_all), dropped_out, unnorm_out, surface_parts


# Puts the clips back with every key (see tools/skeletal_post_import.gd).
POST_IMPORT_SCRIPT = "res://tools/skeletal_post_import.gd"


def write_import(path: Path):
    if path.exists():
        return  # the editor adds the UID and the imported path there: an existing .import is never rewritten
    path.write_text(import_params(animation=True, import_script=POST_IMPORT_SCRIPT))


# ---------------------------------------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------------------------------------


def tga_height(raw: bytes) -> int:
    return u16(raw, 14)


def model_sources(tag: str, model_paths: dict, anim_index: dict):
    """(files of the model's SAXC folder {(name, ext): bytes}, [(clip tag, sxsk, skel)]) for one model.

    Clips are every SXSK that lives in the folder that holds the model's SAXC folder."""
    key = tag.lower()
    if key not in model_paths:
        raise SystemExit("unknown model: " + tag)
    wad_name, odir_file = model_paths[key].split("/", 1)
    odir = odir_file.rsplit("/", 1)[0]  # .../<m>.FLDR/<m>.SAXC
    files = {}
    for d, name, ext, raw in ex.walk((stats.INSTALL / wad_name).read_bytes()):
        if d == odir:
            files[(name, ext)] = raw
    clip_dir = wad_name + "/" + odir.rsplit("/", 1)[0] + "/"
    clips = []
    for name, rows in sorted(anim_index.items()):
        for path, raw, skel in rows:
            if path.startswith(clip_dir) and "/" not in path[len(clip_dir):]:
                clips.append((path.rsplit("/", 1)[1][: -len(".SXSK")], raw, skel))
    return files, clips


def export_model(tag: str, out: Path, model_paths: dict, anim_index: dict, exact=None):
    files, clip_files = model_sources(tag, model_paths, anim_index)
    key = tag.lower()
    sxmd = next(v for (n, e), v in files.items() if e == "SXMD")
    saxs = next(v for (n, e), v in files.items() if e == "SAXS")
    heights = []
    parts_count = sxmd[0]
    for i in range(parts_count):
        heights.append(tga_height(files[(".%03d" % (i + 1), "SXTX")]))
    model = Model(sxmd, saxs, heights)
    clips, skipped = {}, []
    for clip_tag, raw, skel in clip_files:
        clip = parse_clip(raw, skel, model)
        if clip is None:
            skipped.append(clip_tag)
        else:
            clips[clip_tag] = clip
    if len(model.bone_pos) > MAX_BONES:
        raise SystemExit("too many bones")
    out.mkdir(parents=True, exist_ok=True)
    # Default: one averaged bind per vertex, the model's own bones only. Its error is the
    # bind discrepancy; a model above MAX_ERROR_MM gets helper joints only for the vertices over that threshold.
    global BIND_THRESHOLD
    saved_threshold = BIND_THRESHOLD
    if exact is None:
        single = build_skin_parts(model, False)[1]
        exact = single["max_mm"] > MAX_ERROR_MM
        BIND_THRESHOLD = max(BIND_THRESHOLD, MAX_ERROR_MM / 1000.0) if exact else BIND_THRESHOLD
    try:
        discrepancy, reversed_faces, (lo, hi), dropped, unnorm, surface_parts = write_glb(out / (tag + ".glb"), tag, model, clips, exact)
    finally:
        BIND_THRESHOLD = saved_threshold
    write_import(out / (tag + ".glb.import"))
    abs_pos = model.abs_pos()
    entry = {
        "glb": tag + ".glb",
        "source": model_paths[key],
        "scaling": model.scaling,
        "zfactor": model.zfactor,
        "bones": [bone_name(i) for i in range(len(model.bone_pos))],
        "bone_parent": model.bone_parent,
        "bind_position": [[round(c, 6) for c in p] for p in abs_pos],
        "faces_reversed_for_gltf": reversed_faces,
        "bind_discrepancy": discrepancy,
        "dropped_vertices": dropped,
        "surface_parts": surface_parts,
        "unnormalized_vertices": unnorm,
        "bind_aabb": {"min": [round(c, 6) for c in lo], "max": [round(c, 6) for c in hi]},
        "skipped_clips": skipped,
        "clips": {
            t: {"frames": c["frames"], "framerate": c["framerate"], "reference_height": round(c["reference_height"], 6) if math.isfinite(c["reference_height"]) else 0.0,
                "hands": [dict(h, bone_name=bone_name(h["bone"])) for h in c["hands"]],
                "events": c["events"]}
            for t, c in sorted(clips.items())
        },
    }
    print("%s: %d bones, %d clips, %d skipped, bind error max %.3f mm (raw %.3f) mean %.3f mm, helper joints %d, reversed=%s"
          % (tag, len(model.bone_pos), len(clips), len(skipped), discrepancy["residual_max_mm"], discrepancy["max_mm"], discrepancy["mean_mm"], discrepancy["helper_joints"],
             reversed_faces))
    return entry


def main():
    global BIND_THRESHOLD, SHIFT_STEP
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--single-bind", action="store_true", help="one averaged bind per vertex for every model, whatever its error")
    parser.add_argument("--exact", action="store_true", help="helper joints for every vertex over --bind-threshold-mm (the 1 mm parity of 023a)")
    parser.add_argument("models", nargs="*", default=DEFAULT_MODELS)
    parser.add_argument("--bind-threshold-mm", type=float, default=BIND_THRESHOLD * 1000.0)
    parser.add_argument("--shift-step-mm", type=float, default=SHIFT_STEP * 1000.0)
    args = parser.parse_args()
    BIND_THRESHOLD = args.bind_threshold_mm / 1000.0
    SHIFT_STEP = args.shift_step_mm / 1000.0
    out = args.out.resolve()
    model_paths = stats.index_saxs_models()
    anim_index = stats.index_saxs_animations()
    index_path = out / "index.json"
    index = json.loads(index_path.read_text()) if index_path.exists() else {}
    for tag in args.models:
        index[tag] = export_model(tag, out, model_paths, anim_index, False if args.single_bind else (True if args.exact else None))
    out.mkdir(parents=True, exist_ok=True)
    index_path.write_text(json.dumps(index, indent=1, sort_keys=True))


if __name__ == "__main__":
    main()
