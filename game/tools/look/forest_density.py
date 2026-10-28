#!/usr/bin/env python3
"""Paints a first forest for a map: the density PNG of its `Forest` FloraLayer (land_role TREE).

    python3 tools/look/forest_density.py scenes/map/maps/high_noon [--seed 7]

Reads the map's own data and writes scenes/map/maps/<map>/flora/forest.png (L8, 1 px = CELL_M m,
white = the layer's max_per_cell). A starting point to paint over with the «Flora» brush in the
editor, not a rule: run it again only for a map that has no hand-painted forest yet.

Where trees grow:
- on land (void.png: 0 = land, 255 = the void) and never on the path role (ground_roles.png A, grown by a cell);
- in groves: low-frequency value noise, thresholded, so the land has woods and clearings;
- away from what is played around: the starts (wizards and altars), the mana founts and the
  buildings, with a soft edge;
- thicker on slopes and near the island's edge, thinner on rock and in the open middle.
Decorative trees have no collision, so the open middle stays mostly clear.
"""

import math
import random
import re
import sys
from pathlib import Path

from PIL import Image

CELL_M = 16.0
ROLE_CELL_M = 10.0
KEEP_OUT_M = {"start": 70.0, "fount": 40.0, "building": 18.0}
EDGE_M = 70.0


def map_points(scene: str) -> list[tuple[float, float, float]]:
    """(x, z, keep-out radius) of the starts, founts and buildings placed in map.tscn."""
    points = []
    for node in re.finditer(r'\[node name="([^"]+)" parent="([^"]+)"[^\]]*\]\n((?:[^\[\n][^\n]*\n)*)', scene):
        name, parent, body = node.groups()
        moved = re.search(r"transform = Transform3D\(([^)]*)\)", body)
        if not moved:
            continue
        values = [float(v) for v in moved.group(1).split(",")]
        x, z = values[9], values[11]
        if parent == "MapProps/Starts":
            points.append((x, z, KEEP_OUT_M["start"]))
        elif parent == "MapProps/Founts":
            points.append((x, z, KEEP_OUT_M["fount"]))
        elif parent in ("Buildings", "Npcs", "MapProps/Houses") or parent.startswith("Buildings"):
            points.append((x, z, KEEP_OUT_M["building"]))
    return points


def value_noise(seed: int, size: int, cells: int) -> list[list[float]]:
    rng = random.Random(seed)
    grid = [[rng.random() for _ in range(cells + 2)] for _ in range(cells + 2)]
    out = []
    for j in range(size):
        row = []
        for i in range(size):
            u, v = i / size * cells, j / size * cells
            i0, j0 = int(u), int(v)
            fu, fv = u - i0, v - j0
            fu, fv = fu * fu * (3 - 2 * fu), fv * fv * (3 - 2 * fv)
            a = grid[j0][i0] * (1 - fu) + grid[j0][i0 + 1] * fu
            b = grid[j0 + 1][i0] * (1 - fu) + grid[j0 + 1][i0 + 1] * fu
            row.append(a * (1 - fv) + b * fv)
        out.append(row)
    return out


def smoothstep(a: float, b: float, x: float) -> float:
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def main() -> None:
    folder = Path(sys.argv[1])
    seed = int(sys.argv[sys.argv.index("--seed") + 1]) if "--seed" in sys.argv else 7
    roles = Image.open(folder / "ground_roles.png").convert("RGBA")
    land = Image.open(folder / "void.png").convert("L")
    heights = Image.open(folder / "heights.png")
    side_m = roles.width * ROLE_CELL_M
    size = int(side_m / CELL_M)
    points = map_points((folder / "map.tscn").read_text())
    h = heights.load()
    hw = heights.width
    hmax = max(heights.getextrema()[1], 1)
    groves = value_noise(seed, size, 10)
    detail = value_noise(seed + 1, size, 34)
    rp, lp = roles.load(), land.load()
    out = Image.new("L", (size, size), 0)
    op = out.load()
    for j in range(size):
        for i in range(size):
            x, z = (i + 0.5) * CELL_M, (j + 0.5) * CELL_M
            ri, rj = min(int(x / ROLE_CELL_M), roles.width - 1), min(int(z / ROLE_CELL_M), roles.height - 1)
            if lp[ri, rj] >= 128:
                continue
            path = max(rp[min(max(ri + di, 0), roles.width - 1), min(max(rj + dj, 0), roles.height - 1)][3]
                       for di in (-1, 0, 1) for dj in (-1, 0, 1))
            if path > 40:
                continue
            rock = rp[ri, rj][2] / 255.0
            # edge of the island: distance to the nearest hole, in role cells (search 7 around)
            edge = 1.0
            for r in range(1, 8):
                ring = [(ri + a, rj + b) for a in range(-r, r + 1) for b in (-r, r)] + \
                       [(ri + a, rj + b) for a in (-r, r) for b in range(-r + 1, r)]
                if any(not (0 <= a < roles.width and 0 <= b < roles.height) or lp[a, b] >= 128 for a, b in ring):
                    edge = r * ROLE_CELL_M / EDGE_M
                    break
            hi = min(int(x / side_m * hw), hw - 1)
            hj = min(int(z / side_m * hw), hw - 1)
            slope = abs(h[min(hi + 1, hw - 1), hj] - h[max(hi - 1, 0), hj]) + abs(h[hi, min(hj + 1, hw - 1)] - h[hi, max(hj - 1, 0)])
            slope = min(slope / hmax * 40.0, 1.0)
            clear = 1.0
            for px, pz, radius in points:
                d = math.hypot(px - x, pz - z)
                clear = min(clear, smoothstep(radius, radius * 1.4, d))
            grove = smoothstep(0.38, 0.58, groves[j][i] * 0.75 + detail[j][i] * 0.25)
            want = grove * clear * (0.45 + 0.35 * slope + 0.4 * (1.0 - min(edge, 1.0))) * (1.0 - 0.6 * rock)
            op[i, j] = int(round(min(want, 1.0) * 255))
    (folder / "flora").mkdir(exist_ok=True)
    out.save(folder / "flora" / "forest.png")
    lit = sum(1 for v in out.getdata() if v > 0)
    print(f"{folder.name}: {size}x{size} px, {lit / (size * size):.0%} of the cells with trees")


if __name__ == "__main__":
    main()
