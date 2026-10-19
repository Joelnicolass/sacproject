"""BLDG records (buildings of the god WADs) and where their models live.

Layout (RFC-024 addendum, cut 024b2): 128-byte header (flags, ground 8x8, maxHealth u32, 10 floats, tileset, numComponents u32
at 120) and 48 bytes per component.
"""

import struct

from . import wad as wadlib
from .install import INSTALL

BLDG_WADS = ("joby.wad", "pyromod.wad", "jamesmod.wad", "stratmod.wad")
BLDG_SHELTER = 1 << 15
BLDG_GROUND = 1 << 31
BLDG_HEADER = 128
BLDG_COMPONENT = 48


def _human_tag(raw: bytes, offset: int) -> str:
    return raw[offset: offset + 4][::-1].decode("latin1").rstrip("\x00")


def _u32(raw: bytes, offset: int) -> int:
    return struct.unpack_from("<I", raw, offset)[0]


def _f32(raw: bytes, offset: int) -> float:
    return round(struct.unpack_from("<f", raw, offset)[0], 4)


def decode_bldg(raw: bytes, folder: str) -> dict:
    """Name-order tags (the reverse of the stored bytes, like every WAD name). `components` come in file order."""
    flags = _u32(raw, 0)
    count = _u32(raw, 120)
    if len(raw) != BLDG_HEADER + BLDG_COMPONENT * count:
        return {}
    components = []
    for k in range(count):
        base = BLDG_HEADER + BLDG_COMPONENT * k
        components.append({
            "kind": _human_tag(raw, base),
            "tag": _human_tag(raw, base + 4),
            "destroyed": _human_tag(raw, base + 12),
            "x": _f32(raw, base + 20),
            "y": _f32(raw, base + 24),
            "z": _f32(raw, base + 28),
            "facing": _f32(raw, base + 32),
            "spell": _human_tag(raw, base + 36),
        })
    return {
        "flags": flags,
        "shelter": bool(flags & BLDG_SHELTER),
        "ground": bool(flags & BLDG_GROUND),
        "max_health": _u32(raw, 68),
        "tileset": _human_tag(raw, 112),
        "folder": folder,
        "components": components,
    }


def read_buildings():
    """Every BLDG of the god WADs (tag -> entry) and every MRMM model of those WADs (tag -> (wad, folder, files, raw)).
    A tag is kept from the first WAD of BLDG_WADS that has it (no BLDG model tag appears in two of them)."""
    buildings: dict = {}
    models: dict = {}
    for wad_name in BLDG_WADS:
        wad = INSTALL / wad_name
        if not wad.exists():
            continue
        folders = wadlib.index_folders(wad)
        for odir, files in folders.items():
            for (name, ext), raw in files.items():
                if ext == "BLDG" and name not in buildings:
                    entry = decode_bldg(raw, odir)
                    if entry:
                        buildings[name] = entry
                elif ext == "MRMM" and name not in models:
                    models[name] = (wad_name, odir, files, raw)
    return buildings, models
