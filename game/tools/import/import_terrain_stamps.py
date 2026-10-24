#!/usr/bin/env python3
"""Requiere el juego original instalado (SAC_INSTALL). Ver tools/import/local.cfg.example.

Import what Volcano (RFC-057, 061k-2) reads from the original:

  assets/original/terrain/volcano_shape.png   the 33x33 shape of the mound (volc.DATA of xmenu.wad), 8-bit grey, byte for byte:
                                              pixel (x, y) is the vertex x cells east and y cells south of the corner of the stamp
  assets/original/fx/sprt.png                 the lava tube's skin (atlas 4x2, MAIN.WAD!/bits.FLDR)
  assets/original/fx/vsmk.png                 the smoke cloud over the crater (atlas 4x4, Pyro's textures)
  assets/original/fx/sptr.png                 the lava spatter on the ground (atlas 4x4, Pyro's textures)

  python3 tools/import/import_terrain_stamps.py            # write
  python3 tools/import/import_terrain_stamps.py --check    # report what would change, write nothing

Deterministic and idempotent: a second run writes nothing, and an existing .png.import is never touched (it carries the UID).
"""

import struct
import sys
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import fx_catalog  # noqa: E402
from import_ui import IMPORT_TEMPLATE  # noqa: E402
from sac_formats import txtr, wad  # noqa: E402
from sac_formats.install import INSTALL  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
ARGS = {a.split("=", 1)[0]: (a.split("=", 1)[1] if "=" in a else True) for a in sys.argv[1:]}
OUT = Path(ARGS.get("--out", ROOT / "assets" / "original"))
CHECK = "--check" in ARGS

SIDE = 33
# (wad, folder) of each texture, as sacobject.d SacVolcanoLava / SacVolcanoCloud / SacVolcanoSpatter load them.
FX = {
    "sprt": ("main.wad", "MAIN.WAD!/bits.FLDR"),
    "vsmk": ("charlie.wad", "Bloo.WAD!/Pyro.FLDR/txtr.FLDR"),
    "sptr": ("charlie.wad", "Bloo.WAD!/Pyro.FLDR/txtr.FLDR"),
}


def grey_png(width: int, height: int, data: bytes) -> bytes:
    """A deterministic 8-bit grey PNG: the pixels are exactly `data` (width*height bytes)."""
    def chunk(tag: bytes, payload: bytes) -> bytes:
        return struct.pack(">I", len(payload)) + tag + payload + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)

    raw = b"".join(b"\x00" + data[y * width: (y + 1) * width] for y in range(height))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 0, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def put(path: Path, data: bytes, mips: bool, counts: list) -> None:
    if path.exists() and path.read_bytes() == data:
        counts[1] += 1
        return
    counts[0] += 1
    if CHECK:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    imp = path.with_name(path.name + ".import")
    if not imp.exists():
        imp.write_text(IMPORT_TEMPLATE.format(rel=path.relative_to(OUT).as_posix(), mips="true" if mips else "false"))


def main() -> None:
    counts = [0, 0]
    shape = wad.extract(INSTALL / "xmenu.wad", "volc", "DATA")
    if len(shape) != SIDE * SIDE:
        sys.exit("volc.DATA is %d bytes, expected %d" % (len(shape), SIDE * SIDE))
    put(OUT / "terrain" / "volcano_shape.png", grey_png(SIDE, SIDE, shape), False, counts)
    wads = {}
    for tag, (wad_name, folder) in FX.items():
        if wad_name not in wads:
            wads[wad_name] = wad.index_flat(INSTALL / wad_name)
        found = fx_catalog.atlas_images(wads[wad_name], folder, tag)
        if found is None:
            print("atlas missing", tag, wad_name, folder)
            continue
        width, height, rgba = found[tag]
        put(OUT / "fx" / (tag + ".png"), txtr.png_bytes(width, height, rgba), True, counts)
    print("terrain stamps: %d written, %d unchanged%s" % (counts[0], counts[1], " [check]" if CHECK else ""))


if __name__ == "__main__":
    main()
