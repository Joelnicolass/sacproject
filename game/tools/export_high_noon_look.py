#!/usr/bin/env python3
"""Pull High Noon look and James roster numbers from the local install.

Writes game/cache/look/, which is gitignored. Does not copy the wads.
"""

import json
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INSTALL = Path("/Users/joelsartori/Downloads/sacgame/Sacrifice")
OUT = ROOT / "cache" / "look"


def parse_le(b):
    return int.from_bytes(b, "little")


def iter_entries(data: bytes):
    info = zlib.decompress(data[parse_le(data[4:8]) :])
    offset = 20
    while len(info) >= 28:
        name = info[:4][::-1].decode("latin1", "replace").rstrip("\x00")
        ext = info[4:8][::-1].decode("latin1", "replace").rstrip("\x00")
        info = info[8:]
        zsize = parse_le(info[:4])
        info = info[4:]
        size = parse_le(info[:4])
        info = info[4:]
        subfiles = parse_le(info[:4])
        info = info[4:]
        typ = parse_le(info[:4])
        info = info[4:]
        info = info[4:]
        if typ not in (0, 1, 2):
            if subfiles != 0:
                typ = 1
            elif zsize < size:
                typ = 2
            else:
                typ = 0
        yield typ, name, ext, offset, zsize, size
        if typ == 0:
            offset += size
        elif typ == 2:
            offset += zsize


def extract(wad: Path, want_name: str, want_ext: str) -> bytes:
    data = wad.read_bytes()
    for typ, name, ext, offset, zsize, size in iter_entries(data):
        if ext == want_ext and (not want_name or name == want_name):
            blob = data[offset : offset + (size if typ == 0 else zsize)]
            return blob if typ == 0 else zlib.decompress(blob)
    raise SystemExit(f"missing {want_name}.{want_ext} in {wad.name}")


def decode_txtr(wad: Path, name: str) -> tuple[int, int, bytes]:
    raw = extract(wad, name, "TXTR")
    width = parse_le(raw[0:4])
    height = parse_le(raw[4:8])
    pal = raw[8:12][::-1].decode("latin1").rstrip("\x00")
    cursor = 12
    has_alpha_color = bool(raw[cursor] & 4)
    has_explicit_alpha = bool(raw[cursor + 2] & 1)
    alpha_color = (raw[cursor + 6], raw[cursor + 5], raw[cursor + 4])
    cursor += 8
    cursor += 16
    indexes = raw[cursor : cursor + width * height]
    alpha = b""
    if has_explicit_alpha:
        alpha = raw[cursor + width * height : cursor + 2 * width * height]
    if pal.lower() == "gray":
        palette = None
    else:
        palt = extract(wad, pal, "PALT")[8:]
        palette = palt
    rgb = bytearray(width * height * 3)
    for i, color in enumerate(indexes):
        if palette is None:
            pixel = (color, color, color)
        else:
            pixel = (
                palette[3 * color],
                palette[3 * color + 1],
                palette[3 * color + 2],
            )
        if has_alpha_color and pixel == alpha_color:
            pixel = (0, 0, 0)
        rgb[3 * i : 3 * i + 3] = bytes(pixel)
    return width, height, bytes(rgb)


def write_png(path: Path, width: int, height: int, rgb: bytes) -> None:
    def chunk(tag: bytes, payload: bytes) -> bytes:
        return (
            struct.pack(">I", len(payload))
            + tag
            + payload
            + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)
        )

    raw = b"".join(b"\x00" + rgb[y * width * 3 : (y + 1) * width * 3] for y in range(height))
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)


def envi_colors() -> dict:
    scp = INSTALL / "maps" / "(2) High Noon.scp"
    raw = extract(scp, "", "ENVI")
    sky_r, sky_g, sky_b = raw[26], raw[25], raw[24]
    return {
        "sky_rgb": [sky_r / 255.0, sky_g / 255.0, sky_b / 255.0],
        "tileset": "james",
        "tileset_tag": "A_AJ",
    }


def export_atlas(james: Path) -> None:
    palt = extract(james, "LAND", "PALT")[8:]
    atlas = bytearray(1024 * 1024 * 3)
    found = 0
    for index in range(256):
        try:
            raw = extract(james, f"{index:04d}", "MAPT")
        except SystemExit:
            continue
        data = raw[:4096]
        if len(data) < 4096:
            continue
        found += 1
        origin_x = (index % 16) * 64
        origin_y = (index // 16) * 64
        for y in range(64):
            for x in range(64):
                color = data[64 * y + x]
                pixel = palt[3 * color : 3 * color + 3]
                dest = ((origin_y + y) * 1024 + (origin_x + x)) * 3
                atlas[dest : dest + 3] = pixel
    write_png(OUT / "atlas.png", 1024, 1024, bytes(atlas))
    print("atlas", found)


def export_maps(scp: Path) -> None:
    tmap = extract(scp, "", "TMAP")
    tiles = tmap[512 : 512 + 256 * 256]
    gray = bytearray(256 * 256 * 3)
    for i, tile in enumerate(tiles):
        gray[i * 3 : i * 3 + 3] = bytes((tile, tile, tile))
    write_png(OUT / "tiles.png", 256, 256, bytes(gray))
    lmap = extract(scp, "", "LMAP")
    light = bytearray(256 * 256 * 3)
    for i in range(256 * 256):
        light[i * 3 : i * 3 + 3] = lmap[i * 4 : i * 4 + 3]
    write_png(OUT / "light.png", 256, 256, bytes(light))
    print("tiles", len(tiles), "light", len(lmap))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    james = INSTALL / "data" / "james_a.wad"
    spells = INSTALL / "data" / "spells.wad"
    main_wad = INSTALL / "data" / "main.wad"
    for wad, name, dest in (
        (james, "SKY_", OUT / "sky.png"),
        (james, "SKYT", OUT / "skyt.png"),
        (james, "SKYB", OUT / "skyb.png"),
        (james, "DT00", OUT / "ground.png"),
        (main_wad, "rock", OUT / "rock.png"),
    ):
        width, height, rgb = decode_txtr(wad, name)
        write_png(dest, width, height, rgb)
        print(dest.name, width, height)
    export_atlas(james)
    export_maps(INSTALL / "maps" / "(2) High Noon.scp")
    cre8 = extract(spells, "orcy", "CRE8")
    spel = extract(spells, "rock", "SPEL")
    trogg_speed = int.from_bytes(cre8[50:52], "little") / 100.0
    rock_per_tick = struct.unpack_from("<f", spel, 72)[0]
    roster = {
        "wizard": {"name": "James", "tag": "jnwr", "speed": 10.0, "mesh": "res://cache/james.obj"},
        "creature": {
            "name": "Trogg",
            "tag": "ycro",
            "model": "eorc",
            "speed": trogg_speed,
            "mesh": "res://cache/trogg.obj",
        },
        "spell": {
            "name": "Rock",
            "tag": "kcor",
            "speed_per_tick": rock_per_tick,
            "speed": rock_per_tick * 60.0,
            "texture": "res://cache/look/rock.png",
        },
        "ground": "res://cache/look/ground.png",
        "sky": "res://cache/look/sky.png",
        **envi_colors(),
    }
    (OUT / "roster.json").write_text(json.dumps(roster, indent=2) + "\n")
    print(json.dumps(roster, indent=2))


if __name__ == "__main__":
    main()
