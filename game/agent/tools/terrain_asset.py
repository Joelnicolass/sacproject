"""Reads High Noon's land from scenes/map/maps/high_noon/heights.png and void.png (the map's one ground source) without Godot.

Returns the land triangles the game derives from those pictures (scenes/map/terrain/terrain_faces.gd): up to two per 10 m cell,
the diagonal picked by tools/import/sac_formats/terrain.py get_faces. The cliff walls are left out: the expect scripts only ask
the height of the land. The PNG reader and the height step are tools/blender/terrain_common.py, the one Python copy of them.
"""

import os
import sys

GAME = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
MAP_DIR = os.path.join(GAME, "scenes", "map", "maps", "high_noon")
sys.path.insert(0, os.path.join(GAME, "tools", "blender"))
sys.path.insert(0, os.path.join(GAME, "tools", "import"))
import terrain_common as tc  # noqa: E402
from sac_formats.terrain import di, dj, get_faces  # noqa: E402


def load(map_dir=None):
    """(vertices, indices): vertices a list of (x, y, z) in Godot axes, three per land triangle, indices a tuple of ints.
    None without the map's heights.png."""
    folder = map_dir or MAP_DIR
    heights_png = os.path.join(folder, tc.HEIGHTS_PNG)
    if not os.path.exists(heights_png):
        return None
    units = tc.read_heights(heights_png)
    void_png = os.path.join(folder, tc.VOID_PNG)
    voids = tc.read_void(void_png) if os.path.exists(void_png) else [False] * tc.COUNT
    edges = [voids[row * tc.SIDE:(row + 1) * tc.SIDE] for row in range(tc.SIDE)]
    verts = []
    for j in range(tc.SIDE - 1):
        for i in range(tc.SIDE - 1):
            for face in get_faces(edges, j, i) or []:
                for k in face:
                    column, row = i + di(k), j + dj(k)
                    verts.append((column * tc.CELL_M, units[row * tc.SIDE + column] * tc.M_PER_UNIT, row * tc.CELL_M))
    return verts, tuple(range(len(verts)))
