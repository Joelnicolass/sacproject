"""The one Python copy of a map ground's numbers and image formats, shared by the Blender round trip (terrain_make_blend.py,
terrain_export_images.py) and the terrain checks. No bpy: it runs inside Blender's Python and with `python3 -I`.

What it holds:
- the lattice (SIDE x SIDE vertices, CELL_M apart; the mirror of scenes/map/terrain/terrain_grid.gd) and its axes in Blender:
  Blender X = game x, Blender Y = -(game z), Blender Z = height. Vertex id = row * SIDE + column, as in TerrainGrid, and
  pixel (column, row) of every map image is that vertex;
- the height step of heights.png (M_PER_UNIT metres per 16-bit grey unit);
- a small PNG reader and writer (zlib + struct) for the three map images: heights.png (16-bit grey), void.png
  (1- or 8-bit grey, white = void) and ground_roles.png (8-bit RGB / RGBA / palette, read as RGBA);
- the hash of a map's sources, which guards an export against a source that changed since its .blend was made, and the
  terrain_work/ folder (the .blend, manifest.json and the .gdignore that keeps Godot out);
- the user arguments after Blender's `--` and the sRGB curve the «roles» colours are shown with.

Not: Blender objects (the two scripts own those) nor how the game turns the images into a ground (the Godot importer).
Interlaced PNGs are refused with a message, never misread.
"""

import hashlib
import json
import sys
import struct
import zlib
from pathlib import Path

SIDE = 256
CELL_M = 10.0
COUNT = SIDE * SIDE
M_PER_UNIT = 0.1
MAX_UNIT = 65535
MAX_HEIGHT_M = MAX_UNIT * M_PER_UNIT

HEIGHTS_PNG = "heights.png"
VOID_PNG = "void.png"
ROLES_PNG = "ground_roles.png"
WORK_DIR = "terrain_work"
BLEND_NAME = "terrain.blend"
MANIFEST_NAME = "manifest.json"
## The images a .blend is made from, in hash order. heights.png is required; the others are optional.
SOURCES = (HEIGHTS_PNG, VOID_PNG, ROLES_PNG)

_SIGNATURE = b"\x89PNG\r\n\x1a\n"
_CHANNELS = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}


class PngError(Exception):
    """A PNG this module cannot read or that is not the map image it was asked for (the message names the file)."""


class Png:
    """A decoded PNG: `samples` row-major, channels interleaved, each sample an int of `depth` bits (palette: indices)."""

    def __init__(self, width, height, color_type, depth, samples, palette=None):
        self.width = width
        self.height = height
        self.color_type = color_type
        self.depth = depth
        self.channels = _CHANNELS[color_type]
        self.samples = samples
        self.palette = palette


# --- lattice and axes ------------------------------------------------------------------------------------------------


def vertex_xy(vertex_id):
    """The Blender (X, Y) of a lattice vertex: X = column * CELL_M, Y = -(row * CELL_M)."""
    return (vertex_id % SIDE) * CELL_M, -(vertex_id // SIDE) * CELL_M


def cell_triangles(column, row):
    """The two triangles of the cell whose low corner is (column, row), as vertex ids, wound so their normal is +Z.

    Every cell is cut along its (column, row)-(column + 1, row + 1) diagonal, the one tools/import/sac_formats/terrain.py
    get_faces picks when no corner is a void. A void corner does not change the .blend's faces: the topology stays fixed
    and the VoidPreview modifier hides what the game will not draw."""
    c0 = row * SIDE + column
    c1 = c0 + 1
    c2 = c0 + SIDE + 1
    c3 = c0 + SIDE
    return (c0, c2, c1), (c0, c3, c2)


def height_to_unit(height_m):
    """The heights.png unit of a height in metres, or None when it falls outside 0..MAX_HEIGHT_M."""
    unit = round(height_m / M_PER_UNIT)
    if height_m < -1e-3 or unit < 0 or unit > MAX_UNIT:
        return None
    return unit


# --- map images ------------------------------------------------------------------------------------------------------


def read_heights(path):
    """heights.png as COUNT ints (16-bit grey units). Raises PngError if it is not SIDE x SIDE 16-bit grey."""
    png = read_png(path)
    _expect_side(png, path)
    if png.color_type != 0 or png.depth != 16:
        raise PngError(f"{path}: heights.png must be 16-bit grey (it is color type {png.color_type}, {png.depth} bits)")
    return png.samples


def read_void(path):
    """void.png as COUNT bools (white = void). Raises PngError if it is not SIDE x SIDE grey (1, 2, 4, 8 or 16 bits)."""
    png = read_png(path)
    _expect_side(png, path)
    if png.color_type != 0:
        raise PngError(f"{path}: void.png must be grey (it is color type {png.color_type})")
    half = ((1 << png.depth) - 1) / 2.0
    return [sample > half for sample in png.samples]


def read_roles(path):
    """ground_roles.png as COUNT (r, g, b, a) 8-bit tuples. Raises PngError if it is not SIDE x SIDE 8-bit colour."""
    png = read_png(path)
    _expect_side(png, path)
    if png.depth != 8 or png.color_type not in (2, 3, 6):
        raise PngError(f"{path}: ground_roles.png must be 8-bit RGB, RGBA or palette (color type {png.color_type}, {png.depth} bits)")
    s = png.samples
    if png.color_type == 6:
        return [tuple(s[i:i + 4]) for i in range(0, len(s), 4)]
    if png.color_type == 2:
        return [(s[i], s[i + 1], s[i + 2], 255) for i in range(0, len(s), 3)]
    return [png.palette[index] for index in s]


def encode_heights(units):
    """heights.png bytes from COUNT 16-bit units."""
    return encode_png(SIDE, SIDE, 0, 16, units)


def encode_void(voids):
    """void.png bytes (8-bit grey, 255 = void) from COUNT bools."""
    return encode_png(SIDE, SIDE, 0, 8, [255 if v else 0 for v in voids])


def encode_roles(colors):
    """ground_roles.png bytes (8-bit RGBA) from COUNT (r, g, b, a) tuples."""
    return encode_png(SIDE, SIDE, 6, 8, [c for color in colors for c in color])


def sources_hash(map_dir):
    """The sha256 of the map's source images that exist (SOURCES order, each with its name), hex. Missing ones count as absent."""
    digest = hashlib.sha256()
    for name in SOURCES:
        path = Path(map_dir) / name
        if path.is_file():
            digest.update(name.encode() + b"\0" + path.read_bytes() + b"\0")
    return digest.hexdigest()


def work_dir(map_dir):
    """<map>/terrain_work, created with its .gdignore (Godot does not import it; git ignores it, see game/.gitignore)."""
    folder = Path(map_dir) / WORK_DIR
    folder.mkdir(parents=True, exist_ok=True)
    ignore = folder / ".gdignore"
    if not ignore.exists():
        ignore.write_text("")
    return folder


def read_manifest(map_dir):
    """terrain_work/manifest.json as a dict, or None when there is none."""
    path = Path(map_dir) / WORK_DIR / MANIFEST_NAME
    return json.loads(path.read_text()) if path.is_file() else None


def write_manifest(map_dir, data):
    """Writes terrain_work/manifest.json (sorted keys, so an unchanged manifest gives the same bytes)."""
    (work_dir(map_dir) / MANIFEST_NAME).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")


def user_args(argv=None):
    """The `--key=value` and `--flag` arguments after Blender's `--`, as a dict (a flag is True)."""
    argv = sys.argv if argv is None else argv
    tail = argv[argv.index("--") + 1:] if "--" in argv else []
    out = {}
    for argument in tail:
        key, _, value = argument.lstrip("-").partition("=")
        out[key] = value if value else True
    return out


def srgb_to_linear(byte):
    """The linear value Blender shows for an sRGB byte (0..255) of ground_roles.png."""
    c = byte / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def linear_to_srgb(value):
    """The sRGB byte of a linear value: the exact inverse of srgb_to_linear once rounded."""
    v = min(max(value, 0.0), 1.0)
    c = v * 12.92 if v <= 0.0031308 else 1.055 * v ** (1.0 / 2.4) - 0.055
    return round(c * 255.0)


def _expect_side(png, path):
    if png.width != SIDE or png.height != SIDE:
        raise PngError(f"{path}: the image must be {SIDE}x{SIDE} (one pixel per vertex), it is {png.width}x{png.height}")


# --- PNG codec -------------------------------------------------------------------------------------------------------


def read_png(path):
    """Decodes a non-interlaced PNG of any colour type and bit depth. Raises PngError with the file's name."""
    data = Path(path).read_bytes()
    if data[:8] != _SIGNATURE:
        raise PngError(f"{path}: not a PNG")
    pos = 8
    header = None
    palette = None
    idat = bytearray()
    while pos + 8 <= len(data):
        length, kind = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            header = struct.unpack(">IIBBBBB", body)
        elif kind == b"PLTE":
            palette = [(body[i], body[i + 1], body[i + 2], 255) for i in range(0, len(body), 3)]
        elif kind == b"tRNS" and palette is not None:
            for i, alpha in enumerate(body[:len(palette)]):
                palette[i] = palette[i][:3] + (alpha,)
        elif kind == b"IDAT":
            idat += body
        elif kind == b"IEND":
            break
    if header is None:
        raise PngError(f"{path}: no IHDR")
    width, height, depth, color_type, _compression, _filter, interlace = header
    if color_type not in _CHANNELS or interlace != 0:
        raise PngError(f"{path}: unsupported PNG (color type {color_type}, interlace {interlace})")
    if color_type == 3 and palette is None:
        raise PngError(f"{path}: palette PNG without PLTE")
    channels = _CHANNELS[color_type]
    raw = zlib.decompress(bytes(idat))
    stride = (width * channels * depth + 7) // 8
    bpp = max(1, channels * depth // 8)
    rows = _unfilter(raw, height, stride, bpp, path)
    samples = []
    count = width * channels
    for row in rows:
        samples.extend(_unpack(row, depth, count))
    return Png(width, height, color_type, depth, samples, palette)


def encode_png(width, height, color_type, depth, samples):
    """PNG bytes for 8- or 16-bit samples, each row with the filter that leaves the smallest sum (the usual heuristic)."""
    channels = _CHANNELS[color_type]
    stride = width * channels * depth // 8
    bpp = max(1, channels * depth // 8)
    fmt = ">%dH" % (width * channels) if depth == 16 else "%dB" % (width * channels)
    per_row = width * channels
    out = bytearray()
    previous = bytes(stride)
    for y in range(height):
        row = struct.pack(fmt, *samples[y * per_row:(y + 1) * per_row])
        best = None
        for kind in range(5):
            filtered = _filter(kind, row, previous, bpp)
            score = sum(b if b < 128 else 256 - b for b in filtered)
            if best is None or score < best[0]:
                best = (score, kind, filtered)
        out.append(best[1])
        out += best[2]
        previous = row
    header = struct.pack(">IIBBBBB", width, height, depth, color_type, 0, 0, 0)
    return _SIGNATURE + _chunk(b"IHDR", header) + _chunk(b"IDAT", zlib.compress(bytes(out), 9)) + _chunk(b"IEND", b"")


def _chunk(kind, body):
    return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)


def _paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    return b if pb <= pc else c


def _filter(kind, row, previous, bpp):
    if kind == 0:
        return row
    out = bytearray(len(row))
    for i, x in enumerate(row):
        a = row[i - bpp] if i >= bpp else 0
        b = previous[i]
        c = previous[i - bpp] if i >= bpp else 0
        predictor = (0, a, b, (a + b) // 2, _paeth(a, b, c))[kind]
        out[i] = (x - predictor) & 0xFF
    return bytes(out)


def _unfilter(raw, height, stride, bpp, path):
    rows = []
    previous = bytearray(stride)
    pos = 0
    for _ in range(height):
        if pos + 1 + stride > len(raw):
            raise PngError(f"{path}: truncated image data")
        kind = raw[pos]
        row = bytearray(raw[pos + 1:pos + 1 + stride])
        pos += 1 + stride
        if kind > 4:
            raise PngError(f"{path}: bad filter {kind}")
        for i in range(stride):
            a = row[i - bpp] if i >= bpp else 0
            b = previous[i]
            c = previous[i - bpp] if i >= bpp else 0
            predictor = (0, a, b, (a + b) // 2, _paeth(a, b, c))[kind]
            row[i] = (row[i] + predictor) & 0xFF
        rows.append(row)
        previous = row
    return rows


def _unpack(row, depth, count):
    if depth == 16:
        return list(struct.unpack(">%dH" % count, bytes(row[:count * 2])))
    if depth == 8:
        return list(row[:count])
    per_byte = 8 // depth
    mask = (1 << depth) - 1
    out = []
    for i in range(count):
        byte = row[i // per_byte]
        shift = 8 - depth * (i % per_byte + 1)
        out.append((byte >> shift) & mask)
    return out
