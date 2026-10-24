"""SCAR: a ground mark (a small image the game paints into the ground texture) and the RGBA it decodes to.

Layout (little endian): u32 0, u32 payload size, u32 width, u32 height, 256 palette entries of B,G,R,0 (1024 bytes), then
width*height pairs (palette index u8, alpha u8) with alpha 0..8 (eighths of a mix over the ground). Size is 16 + 1024 + 2*w*h.
Ref: rfcs/research/061S-scar-ground-marks.md section 1.
"""

from . import png

HEADER = 16
PALETTE = 1024
ALPHA_STEPS = 8


def decode_scar(raw: bytes):
    """(width, height, RGBA bytes). Alpha 0..8 becomes round(a * 255 / 8); the colour of a transparent pixel is kept."""
    width = int.from_bytes(raw[8:12], "little")
    height = int.from_bytes(raw[12:16], "little")
    if len(raw) != HEADER + PALETTE + 2 * width * height:
        raise ValueError("SCAR size %d does not match %dx%d" % (len(raw), width, height))
    palette = raw[HEADER: HEADER + PALETTE]
    pixels = raw[HEADER + PALETTE:]
    rgba = bytearray(width * height * 4)
    for i in range(width * height):
        index = pixels[2 * i]
        alpha = min(pixels[2 * i + 1], ALPHA_STEPS)
        rgba[4 * i: 4 * i + 4] = bytes((palette[4 * index + 2], palette[4 * index + 1], palette[4 * index], round(alpha * 255 / ALPHA_STEPS)))
    return width, height, bytes(rgba)


def png_bytes(width: int, height: int, rgba: bytes) -> bytes:
    return png.encode(width, height, rgba, 4, 6)
