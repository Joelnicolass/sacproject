"""The WAD container: a zlib-compressed directory at the end of the file, then the (maybe compressed) payloads.

The only WAD reader of the tools. Written from the layout: 4-byte names are stored reversed.
"""

import zlib
from pathlib import Path


def parse_le(b: bytes) -> int:
    return int.from_bytes(b, "little")


def walk(data: bytes):
    """Yield (folder path, name, extension, payload) for every file, folders as 'WAD!/a.FLDR/b.FLDR'."""
    info = zlib.decompress(data[parse_le(data[4:8]):])
    offset = 20
    odir = ""
    stack = []
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
            typ = 1 if subfiles else (2 if zsize < size else 0)
        filename = f"{odir}/{name}" if odir else name
        if typ == 1:
            if stack:
                stack[-1] -= 1
            odir = f"{filename}.{ext}"
            stack.append(subfiles)
        else:
            blob = data[offset: offset + (size if typ == 0 else zsize)]
            raw = blob if typ == 0 else (zlib.decompress(blob) if blob else b"")
            yield odir, name, ext, raw
            offset += size if typ == 0 else zsize
            if stack:
                stack[-1] -= 1
        while stack and stack[-1] == 0:
            stack.pop()
            odir = odir.rsplit("/", 1)[0] if "/" in odir else ""


def index_wad(wad: Path):
    """({(name, ext): [(folder, payload)]}, {palette name: palette bytes})."""
    files = {}
    palettes = {}
    for odir, name, ext, raw in walk(wad.read_bytes()):
        files.setdefault((name, ext), []).append((odir, raw))
        if ext == "PALT":
            palettes[name] = raw[8:]
    return files, palettes


def index_folders(wad: Path):
    """{folder: {(name, ext): payload}}."""
    folders = {}
    for odir, name, ext, raw in walk(wad.read_bytes()):
        folders.setdefault(odir, {})[(name, ext)] = raw
    return folders


def index_flat(wad: Path):
    """{(folder, name, ext): payload}."""
    files = {}
    for odir, name, ext, raw in walk(wad.read_bytes()):
        files[(odir, name, ext)] = raw
    return files


def extract(wad: Path, want_name: str, want_ext: str) -> bytes:
    """The first file with that extension (and name, when given) of a WAD or SCP, folders ignored."""
    data = wad.read_bytes()
    info = zlib.decompress(data[parse_le(data[4:8]):])
    offset = 20
    while len(info) >= 28:
        name = info[:4][::-1].decode("latin1", "replace").rstrip("\x00")
        ext = info[4:8][::-1].decode("latin1", "replace").rstrip("\x00")
        zsize = parse_le(info[8:12])
        size = parse_le(info[12:16])
        subfiles = parse_le(info[16:20])
        typ = parse_le(info[20:24])
        info = info[28:]
        if typ not in (0, 1, 2):
            typ = 1 if subfiles != 0 else (2 if zsize < size else 0)
        if ext == want_ext and (not want_name or name == want_name):
            blob = data[offset: offset + (size if typ == 0 else zsize)]
            return blob if typ == 0 else zlib.decompress(blob)
        if typ == 0:
            offset += size
        elif typ == 2:
            offset += zsize
    raise LookupError(f"missing {want_name}.{want_ext} in {wad.name}")
