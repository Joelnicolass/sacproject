"""Does not need the original game: shared by bake_ground_roles.py and check_ground_roles.py.

A map's ground_roles.png is 256x256, one pixel per 10 m cell, RGBA = how much of each ground role the cell has:
R open (grass), G earth, B rock, A path. The four weights of a cell add up to 255.
"""

from pathlib import Path

import numpy as np
from PIL import Image

ROLES = ("open", "earth", "rock", "path")
SIZE = 256
# A role "dominates" a cell when it holds more than half of it (w > 128 of 255). A 50/50 transition dominates nothing.
DOMINANT = 128
# A neighbour "has" a role when it is its strongest one or holds at least half of the cell.
HALF = 128
MAPS_DIR = Path(__file__).resolve().parents[2] / "scenes" / "map" / "maps"
REPORT = Path(__file__).resolve().parent / "ground_roles_report.json"
FLAT_MAPS = ("test_flat", "test_flat4")


def png_path(tag: str) -> Path:
    return MAPS_DIR / tag / "ground_roles.png"


def load(tag: str) -> np.ndarray:
    """(256, 256, 4) int array of the weights of `tag`."""
    return np.asarray(Image.open(png_path(tag)).convert("RGBA"), dtype=np.int32)


def shift(a: np.ndarray, dy: int, dx: int) -> np.ndarray:
    """`a` moved by (dy, dx) cells; what falls off the map is lost and the new border is zero (no wrap-around)."""
    out = np.zeros_like(a)
    h, w = a.shape[:2]
    out[max(dy, 0):h + min(dy, 0), max(dx, 0):w + min(dx, 0)] = a[max(-dy, 0):h + min(-dy, 0), max(-dx, 0):w + min(-dx, 0)]
    return out


def _neighbours(mask: np.ndarray) -> np.ndarray:
    """True where one of the 4 neighbours of the cell is True."""
    out = np.zeros_like(mask)
    out[1:, :] |= mask[:-1, :]
    out[:-1, :] |= mask[1:, :]
    out[:, 1:] |= mask[:, :-1]
    out[:, :-1] |= mask[:, 1:]
    return out


def loose_mask(weights: np.ndarray) -> np.ndarray:
    """Cells whose dominant role none of their 4 neighbours has (a lone square of a role in the middle of another)."""
    strongest = weights.argmax(-1)
    dominant = weights.max(-1) > DOMINANT
    loose = np.zeros(strongest.shape, dtype=bool)
    for role in range(len(ROLES)):
        has = (strongest == role) | (weights[..., role] >= HALF)
        loose |= dominant & (strongest == role) & ~_neighbours(has)
    return loose


def loose_by_role(weights: np.ndarray) -> dict:
    mask = loose_mask(weights)
    strongest = weights.argmax(-1)
    return {name: int((mask & (strongest == i)).sum()) for i, name in enumerate(ROLES)}
