"""Texture helpers shared by the importers: TGA/PNG sources to PNG, and the colour key stored in a model's limb records.

Written from the file layouts (the offsets below are the ones scenes/bodies/obj_mesh.gd used to read at runtime).
"""

import hashlib
import struct
from pathlib import Path

import numpy as np
from PIL import Image

## A limb record is 6 bytes at 0x58 + 6 * limb: a flags byte (bit 0 = colour key on) and a u32 whose low 24 bits are 0xRRGGBB.
LIMB_RECORDS_AT = 0x58
LIMB_COUNT = 16


def chroma_keys(saxs: bytes) -> dict:
    """label ("bodypartNNN", limb NNN-1) -> 0xRRGGBB for the limbs whose colour key is on."""
    keys = {}
    for limb in range(LIMB_COUNT):
        at = LIMB_RECORDS_AT + limb * 6
        if at + 6 > len(saxs):
            break
        if saxs[at] & 1:
            keys["bodypart%03d" % (limb + 1)] = struct.unpack_from("<I", saxs, at + 2)[0] & 0xFFFFFF
    return keys


def load_rgb_or_rgba(path: Path) -> np.ndarray:
    """H x W x 3 or H x W x 4 uint8. Opaque sources stay RGB; a real alpha channel is kept."""
    img = Image.open(path)
    img.load()
    rgba = np.asarray(img.convert("RGBA"))
    if rgba[..., 3].min() == 255:
        return np.ascontiguousarray(rgba[..., :3])
    return np.ascontiguousarray(rgba)


def apply_chroma(pixels: np.ndarray, key: int) -> np.ndarray:
    """The texels equal to the key become transparent (RGB left as is, like the runtime did)."""
    rgb = pixels[..., :3]
    hit = (rgb[..., 0] == (key >> 16) & 0xFF) & (rgb[..., 1] == (key >> 8) & 0xFF) & (rgb[..., 2] == key & 0xFF)
    rgba = np.concatenate([rgb, np.full(rgb.shape[:2] + (1,), 255, np.uint8)], axis=2) if pixels.shape[2] == 3 else pixels.copy()
    rgba[hit, 3] = 0
    return rgba


def is_cutout(pixels: np.ndarray) -> bool:
    return pixels.shape[2] == 4 and bool(pixels[..., 3].min() < 255)


def digest(pixels: np.ndarray) -> str:
    return hashlib.sha1(struct.pack("<II", pixels.shape[1], pixels.shape[0]) + bytes(pixels.shape[2:3]) + pixels.tobytes()).hexdigest()


def png_bytes(pixels: np.ndarray) -> bytes:
    """Deterministic PNG: same pixels, same bytes. No metadata, fixed compression."""
    import io

    buf = io.BytesIO()
    Image.fromarray(pixels, "RGBA" if pixels.shape[2] == 4 else "RGB").save(buf, "PNG", compress_level=9, optimize=False)
    return buf.getvalue()
