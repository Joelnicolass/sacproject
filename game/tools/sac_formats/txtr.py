"""TXTR (indexed texture + optional alpha plane) and PALT (palette), and the PNG the tools write from them.

Layout: 36-byte header (width u32, height u32, palette tag, flags, key colour), then width*height palette indices, then an
optional width*height alpha plane. The palette sits next to the texture in the same folder.
"""

from . import png


def palette_name(raw: bytes) -> str:
    return raw[8:12][::-1].decode("latin1").rstrip("\x00")


def decode_txtr(raw: bytes, palette):
    """(width, height, RGBA bytes). palette None = grey ramp. A texel of the key colour is transparent, whatever the alpha
    plane says (the order the particle atlases were always read with; the building and plant textures never set both)."""
    width = int.from_bytes(raw[0:4], "little")
    height = int.from_bytes(raw[4:8], "little")
    has_alpha_color = bool(raw[12] & 4)
    has_explicit_alpha = bool(raw[14] & 1)
    alpha_color = (raw[18], raw[17], raw[16])
    count = width * height
    indexes = raw[36: 36 + count]
    explicit = raw[36 + count: 36 + 2 * count] if has_explicit_alpha else b""
    rgba = bytearray(count * 4)
    for i, color in enumerate(indexes):
        if palette is None:
            pixel = (color, color, color)
        else:
            pixel = (palette[3 * color], palette[3 * color + 1], palette[3 * color + 2])
        alpha = explicit[i] if explicit else 255
        if has_alpha_color and pixel == alpha_color:
            alpha = 0
        rgba[4 * i: 4 * i + 4] = bytes(pixel) + bytes((alpha,))
    return width, height, bytes(rgba)


def folder_texture(folder: dict, name: str):
    """(width, height, RGBA) of <name>.TXTR with the palette of the same folder ({(name, ext): payload}); None if missing."""
    raw = folder.get((name, "TXTR"))
    if raw is None:
        return None
    pal_name = palette_name(raw)
    palette = None
    if pal_name.lower() != "gray":
        pal = folder.get((pal_name, "PALT"))
        if pal is None:
            return None
        palette = pal[8:]
    return decode_txtr(raw, palette)


def wad_texture(files: dict, palettes: dict, name: str):
    """(width, height, RGBA) of the first <name>.TXTR of an index_wad() result, palette by name from the whole WAD."""
    rows = files.get((name, "TXTR"), [])
    if not rows:
        return None
    raw = rows[0][1]
    pal_name = palette_name(raw)
    palette = None if pal_name.lower() == "gray" else palettes.get(pal_name)
    if palette is None and pal_name.lower() != "gray":
        return None
    return decode_txtr(raw, palette)


def flat_texture(files: dict, folder: str, name: str, ext: str = "TXTR"):
    """Same, from an index_flat() result: the palette is <pal>.PALT in the same folder."""
    raw = files.get((folder, name, ext))
    if raw is None:
        return None
    pal_name = palette_name(raw)
    palette = None
    if pal_name.lower() != "gray":
        pal = files.get((folder, pal_name, "PALT"))
        if pal is None:
            return None
        palette = pal[8:]
    return decode_txtr(raw, palette)


def png_bytes(width: int, height: int, rgba: bytes) -> bytes:
    """The PNG the exporters wrote (RGBA8, no filter, zlib 6). Same pixels, same bytes."""
    return png.encode(width, height, rgba, 4, 6)
