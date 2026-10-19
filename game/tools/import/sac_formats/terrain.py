"""The height map (HMAP) and cliff walls as the HNTR v1 mesh bin: vertices and flat normals in Godot axes, then the
triangle indices. tools/import/import_map.py writes it outside the repo and tools/bake/import_terrain.gd turns it into terrain.res.

The HMAP of any .scp is found by its tag in the file directory (wad.extract), so every map of the installation goes through the same path.
"""

import struct
from pathlib import Path

from .wad import extract

MAP_DEPTH = 50.0
CELL = 10.0


def le_u16(b):
    return int.from_bytes(b, "little")


def di(k):
    return 1 if k in (1, 2) else 0


def dj(k):
    return 1 if k in (2, 3) else 0


def get_faces(edges, j, i):
    n = len(edges)
    m = len(edges[0])
    if j + 1 >= n or i + 1 >= m:
        return
    out = []
    if not edges[j][i]:
        if not edges[j + 1][i + 1] and not edges[j][i + 1]:
            out.append((0, 1, 2))
    elif not edges[j][i + 1] and not edges[j + 1][i + 1] and not edges[j + 1][i]:
        out.append((1, 2, 3))
    if not edges[j + 1][i + 1]:
        if not edges[j][i] and not edges[j + 1][i]:
            out.append((2, 3, 0))
    elif not edges[j][i] and not edges[j][i + 1] and not edges[j + 1][i]:
        out.append((0, 1, 3))
    return out


def edge_wall_exists(n, m, edges, j, i, slot):
    def e(yy, xx):
        if yy < 0 or xx < 0 or yy >= n or xx >= m:
            return True
        return edges[yy][xx]

    if slot == 0:
        return (j == 0 or (e(j - 1, i) and e(j - 1, i + 1))) and (not e(j, i)) and (not e(j, i + 1)) and ((not e(j + 1, i)) or (not e(j + 1, i + 1)))
    if slot == 1:
        return (j + 1 == n - 1 or (e(j + 2, i + 1) and e(j + 2, i))) and (not e(j + 1, i + 1)) and (not e(j + 1, i)) and ((not e(j, i)) or (not e(j, i + 1)))
    if slot == 2:
        return (i == 0 or (e(j + 1, i - 1) and e(j, i - 1))) and (not e(j + 1, i)) and (not e(j, i)) and ((not e(j + 1, i + 1)) or (not e(j, i + 1)))
    if slot == 3:
        return (i + 1 == m - 1 or (e(j, i + 2) and e(j + 1, i + 2))) and (not e(j, i + 1)) and (not e(j + 1, i + 1)) and ((not e(j, i)) or (not e(j + 1, i)))
    if slot == 4:
        return e(j, i + 1) and (not e(j, i)) and (not e(j + 1, i + 1)) and (not e(j + 1, i))
    if slot == 5:
        return e(j + 1, i + 1) and (not e(j, i + 1)) and (not e(j + 1, i)) and (not e(j, i))
    if slot == 6:
        return e(j + 1, i) and (not e(j + 1, i + 1)) and (not e(j, i)) and (not e(j, i + 1))
    if slot == 7:
        return e(j, i) and (not e(j + 1, i)) and (not e(j, i + 1)) and (not e(j + 1, i + 1))
    return False


def slot_ends(i, j, slot):
    return {
        0: (i, j, i + 1, j),
        1: (i + 1, j + 1, i, j + 1),
        2: (i, j + 1, i, j),
        3: (i + 1, j, i + 1, j + 1),
        4: (i, j, i + 1, j + 1),
        5: (i + 1, j, i, j + 1),
        6: (i + 1, j + 1, i, j),
        7: (i, j + 1, i + 1, j),
    }[slot]


def godot(i, j, h):
    return (CELL * i, h, CELL * j)


def cross(a, b):
    return (
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    )


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def norm(v):
    length = (v[0] ** 2 + v[1] ** 2 + v[2] ** 2) ** 0.5
    if length == 0:
        return (0.0, 1.0, 0.0)
    return (v[0] / length, v[1] / length, v[2] / length)


def load_grid(scp: Path) -> tuple:
    """(void flags, heights) of the map's HMAP as rows [j][i], the land lowered so its lowest point is 0."""
    raw = extract(scp, "", "HMAP")
    width = le_u16(raw[0:2])
    height = le_u16(raw[2:4])
    need = 4 + 2 * width * height
    if len(raw) < need:
        raise ValueError("hmap short %d < %d" % (len(raw), need))
    edges = []
    heights = []
    for y in range(height):
        row_e = []
        row_h = []
        for x in range(width):
            elev = le_u16(raw[4 + 2 * (y * width + x): 6 + 2 * (y * width + x)])
            row_e.append(bool(elev & (1 << 15)))
            row_h.append((elev & ~(1 << 15)) * 0.1)
        edges.append(row_e)
        heights.append(row_h)
    land = [heights[j][i] for j in range(height) for i in range(width) if not edges[j][i]]
    if not land:
        raise ValueError("no land")
    base = min(land)
    for j in range(height):
        for i in range(width):
            if not edges[j][i]:
                heights[j][i] -= base
    return edges, heights


def ground_height_fn(scp: Path):
    """f(x, z) -> the land height under that point in Godot units (the plane of the ground triangle there), None over a hole.
    The same triangles hntr() writes, so it answers what Terrain.ground_height answers in the game."""
    edges, heights = load_grid(scp)

    def height_at(x: float, z: float):
        i, j = int(x // CELL), int(z // CELL)
        if j < 0 or i < 0 or j >= len(edges) - 1 or i >= len(edges[0]) - 1:
            return None
        for f in get_faces(edges, j, i) or []:
            pts = [godot(i + di(f[k]), j + dj(f[k]), heights[j + dj(f[k])][i + di(f[k])]) for k in range(3)]
            (ax, ay, az), (bx, by, bz), (cx, cy, cz) = pts
            det = (bz - cz) * (ax - cx) + (cx - bx) * (az - cz)
            if det == 0:
                continue
            u = ((bz - cz) * (x - cx) + (cx - bx) * (z - cz)) / det
            v = ((cz - az) * (x - cx) + (ax - cx) * (z - cz)) / det
            if min(u, v, 1.0 - u - v) >= -1e-9:
                return round(u * ay + v * by + (1.0 - u - v) * cy, 4)
        return None

    return height_at


def hntr(scp: Path) -> bytes:
    """The HNTR v1 bytes of the map's ground and cliff walls."""
    edges, heights = load_grid(scp)
    n, m = len(edges), len(edges[0])
    width, height = m, n

    verts = []
    normals = []
    indices = []

    def push_tri(a, b, c, flip_winding):
        start = len(verts)
        verts.extend((a, b, c))
        rhs = cross(sub(b, a), sub(c, a))
        # Godot's front normal is the opposite of the right-hand normal.
        # Land keeps sac order so the floor faces up. Walls stay flipped;
        # that side is the one already visible from the canyon.
        if flip_winding:
            nn = norm(rhs)
            indices.extend((start, start + 2, start + 1))
        else:
            nn = norm((-rhs[0], -rhs[1], -rhs[2]))
            indices.extend((start, start + 1, start + 2))
        normals.extend((nn, nn, nn))

    for j in range(n - 1):
        for i in range(m - 1):
            faces = get_faces(edges, j, i) or []
            for f in faces:
                corners = []
                for k in range(3):
                    jj = j + dj(f[k])
                    ii = i + di(f[k])
                    corners.append(godot(ii, jj, heights[jj][ii]))
                push_tri(*corners, False)

    for j in range(n - 1):
        for i in range(m - 1):
            for slot in range(8):
                if not edge_wall_exists(n, m, edges, j, i, slot):
                    continue
                x1, y1, x2, y2 = slot_ends(i, j, slot)
                top_a = godot(x1, y1, heights[y1][x1])
                top_b = godot(x2, y2, heights[y2][x2])
                bot_b = add(top_b, (0.0, -MAP_DEPTH, 0.0))
                bot_a = add(top_a, (0.0, -MAP_DEPTH, 0.0))
                push_tri(top_a, bot_b, top_b, True)
                push_tri(bot_b, top_a, bot_a, True)

    payload = bytearray()
    payload += b"HNTR"
    payload += struct.pack("<HHH", 1, width, height)
    payload += struct.pack("<II", len(verts), len(indices))
    for v in verts:
        payload += struct.pack("<fff", *v)
    for v in normals:
        payload += struct.pack("<fff", *v)
    for idx in indices:
        payload += struct.pack("<I", idx)
    return bytes(payload)
