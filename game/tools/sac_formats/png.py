"""A deterministic PNG writer (no metadata, no filter): the same pixels always give the same bytes."""

import struct
import zlib


def encode(width: int, height: int, data: bytes, channels: int, level: int) -> bytes:
    """data = width*height*channels bytes, 3 (RGB) or 4 (RGBA) channels, 8 bits."""
    color_type = {3: 2, 4: 6}[channels]

    def chunk(tag: bytes, payload: bytes) -> bytes:
        return struct.pack(">I", len(payload)) + tag + payload + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)

    stride = width * channels
    raw = b"".join(b"\x00" + data[y * stride: (y + 1) * stride] for y in range(height))
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, color_type, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, level))
    png += chunk(b"IEND", b"")
    return png
