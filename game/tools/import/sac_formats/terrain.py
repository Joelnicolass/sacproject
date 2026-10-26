"""The height map (HMAP) of a .scp as a grid of void flags and heights, and the land height under a point of it.

The game's ground is not written from here: tools/terrain/heights_from_original.gd reads the HMAP of each map of the original
into its heights.png and void.png, and the game derives the triangles from those (scenes/map/terrain/terrain_faces.gd).
This module serves the Python tools that need the land of a map of the installation (import_map.py --list, scaffold_map.py).
The HMAP of any .scp is found by its tag in the file directory (wad.extract), so every map of the installation goes through the same path.
"""

from pathlib import Path

from .wad import extract

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


def godot(i, j, h):
    return (CELL * i, h, CELL * j)


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
    The land triangles the game derives (TerrainFaces), so it answers what Terrain.height_at answers in the game."""
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
