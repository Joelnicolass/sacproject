#!/usr/bin/env python3
"""Persephone sky, vegetation and structures from the local install.

Writes game/cache/look/persephone/. Does not copy the wads.
"""

import json
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INSTALL = Path("/Users/joelsartori/Downloads/sacgame/Sacrifice/data")
OUT = ROOT / "cache" / "look" / "persephone"


def parse_le(b):
    return int.from_bytes(b, "little")


def walk(data: bytes):
    info = zlib.decompress(data[parse_le(data[4:8]) :])
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
            blob = data[offset : offset + (size if typ == 0 else zsize)]
            raw = blob if typ == 0 else (zlib.decompress(blob) if blob else b"")
            yield odir, name, ext, raw
            offset += size if typ == 0 else zsize
            if stack:
                stack[-1] -= 1
        while stack and stack[-1] == 0:
            stack.pop()
            odir = odir.rsplit("/", 1)[0] if "/" in odir else ""


def decode_txtr(raw: bytes, palette: bytes | None) -> tuple[int, int, bytes]:
    width = parse_le(raw[0:4])
    height = parse_le(raw[4:8])
    cursor = 12
    has_alpha_color = bool(raw[cursor] & 4)
    has_explicit_alpha = bool(raw[cursor + 2] & 1)
    alpha_color = (raw[cursor + 6], raw[cursor + 5], raw[cursor + 4])
    cursor += 24
    indexes = raw[cursor : cursor + width * height]
    explicit = b""
    if has_explicit_alpha:
        explicit = raw[cursor + width * height : cursor + 2 * width * height]
    rgba = bytearray(width * height * 4)
    for i, color in enumerate(indexes):
        if palette is None:
            pixel = (color, color, color)
        else:
            pixel = (palette[3 * color], palette[3 * color + 1], palette[3 * color + 2])
        alpha = 255
        if has_alpha_color and pixel == alpha_color:
            alpha = 0
        if explicit:
            alpha = explicit[i]
        rgba[4 * i : 4 * i + 4] = bytes(pixel) + bytes((alpha,))
    return width, height, bytes(rgba)


def write_png(path: Path, width: int, height: int, rgba: bytes) -> None:
    def chunk(tag: bytes, payload: bytes) -> bytes:
        return struct.pack(">I", len(payload)) + tag + payload + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)

    raw = b"".join(b"\x00" + rgba[y * width * 4 : (y + 1) * width * 4] for y in range(height))
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 6))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)


def index_wad(wad: Path):
    files = {}
    palettes = {}
    for odir, name, ext, raw in walk(wad.read_bytes()):
        files.setdefault((name, ext), []).append((odir, raw))
        if ext == "PALT":
            palettes[name] = raw[8:]
    return files, palettes


def index_folders(wad: Path):
    folders = {}
    for odir, name, ext, raw in walk(wad.read_bytes()):
        folders.setdefault(odir, {})[(name, ext)] = raw
    return folders


def txtr_png(files, palettes, name: str, dest: Path) -> bool:
    rows = files.get((name, "TXTR"), [])
    if not rows:
        return False
    raw = rows[0][1]
    pal_name = raw[8:12][::-1].decode("latin1").rstrip("\x00")
    palette = None if pal_name.lower() == "gray" else palettes.get(pal_name)
    if palette is None and pal_name.lower() != "gray":
        return False
    width, height, rgba = decode_txtr(raw, palette)
    dest.parent.mkdir(parents=True, exist_ok=True)
    write_png(dest, width, height, rgba)
    return True


def folder_txtr_png(folder: dict, name: str, dest: Path) -> bool:
    """Texture and palette from the same WAD folder, like sacengine loadTXTR."""
    raw = folder.get((name, "TXTR"))
    if raw is None:
        return False
    pal_name = raw[8:12][::-1].decode("latin1").rstrip("\x00")
    palette = None
    if pal_name.lower() != "gray":
        pal = folder.get((pal_name, "PALT"))
        if pal is None:
            return False
        palette = pal[8:]
    width, height, rgba = decode_txtr(raw, palette)
    dest.parent.mkdir(parents=True, exist_ok=True)
    write_png(dest, width, height, rgba)
    return True


def obj_widg(raw: bytes, dest: Path) -> str:
    count = parse_le(raw[0:4])
    faces = int.from_bytes(raw[4:6], "little")
    tex = raw[8:12][::-1].decode("latin1").rstrip("\x00")
    verts = []
    base = 12
    for i in range(count):
        o = base + i * 20
        x, y, z, u, v = struct.unpack_from("<fffff", raw, o)
        # sacengine samples (u, -v); the OBJ reader flips vt once more.
        verts.append((x, z, y, u, 1.0 + v))
    face_off = 8 + count * 20 + 4
    lines = ["o plant", "usemtl plant"]
    for x, y, z, u, v in verts:
        lines.append(f"v {x:.5f} {y:.5f} {z:.5f}")
        lines.append(f"vt {u:.5f} {v:.5f}")
    for i in range(faces):
        o = face_off + i * 4
        a, b, c = raw[o], raw[o + 1], raw[o + 2]
        lines.append(f"f {a+1}/{a+1} {c+1}/{c+1} {b+1}/{b+1}")
    dest.write_text("\n".join(lines) + "\n")
    return tex


def obj_mrmm(raw: bytes, dest: Path) -> list[str]:
    num_v = parse_le(raw[4:8])
    num_f = parse_le(raw[12:16])
    v_off = parse_le(raw[184:188])
    f_off = parse_le(raw[188:192])
    lines = ["o building"]
    names = []
    current = None
    for i in range(num_v):
        o = v_off + i * 40
        x, y, z, u, v = struct.unpack_from("<fffff", raw, o)
        nx, ny, nz = struct.unpack_from("<fff", raw, o + 28)
        lines.append(f"v {x:.5f} {z:.5f} {y:.5f}")
        lines.append(f"vt {u:.5f} {1.0 - v:.5f}")
        lines.append(f"vn {nx:.5f} {nz:.5f} {ny:.5f}")
    # sacengine draws only the faces of the highest LOD (sacobject.d convertModel).
    lods = [parse_le(raw[f_off + i * 36 + 32 : f_off + i * 36 + 36]) for i in range(num_f)]
    top = max(lods) if lods else 0
    for i in range(num_f):
        if lods[i] != top:
            continue
        o = f_off + i * 36
        a, b, c = struct.unpack_from("<III", raw, o)
        tex = raw[o + 16 : o + 20][::-1].decode("latin1").rstrip("\x00")
        if tex != current:
            current = tex
            names.append(tex)
            lines.append(f"usemtl {tex}")
        lines.append(f"f {a+1}/{a+1}/{a+1} {c+1}/{c+1}/{c+1} {b+1}/{b+1}/{b+1}")
    dest.write_text("\n".join(lines) + "\n")
    return names


# Spell models of models.wad (renderer.d loads them from MODL.WAD!/<tag>.MRMC/<tag>.MRMM).
SPELL_MODELS = ("rock",)


def export_spell_models() -> list[dict]:
    folders = index_folders(INSTALL / "models.wad")
    (OUT / "models").mkdir(parents=True, exist_ok=True)
    (OUT / "models" / ".gdignore").write_text("")
    out = []
    for name in SPELL_MODELS:
        odir = f"MODL.WAD!/{name}.MRMC"
        files = folders.get(odir, {})
        raw = files.get((name, "MRMM"))
        if raw is None:
            print("model missing", name)
            continue
        folder = OUT / "models" / name
        folder.mkdir(parents=True, exist_ok=True)
        textures = obj_mrmm(raw, folder / f"{name}.obj")
        if not all(folder_txtr_png(files, tex, folder / f"{tex}.png") for tex in textures):
            print("model texture missing", name, textures)
            continue
        out.append({"name": name, "mesh": f"res://cache/look/persephone/models/{name}/{name}.obj", "texture": ""})
    print("spell models", [m["name"] for m in out])
    return out


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    prsc, prsc_pal = index_wad(INSTALL / "prsc.wad")
    for tag, filename in (("SKY_", "sky.png"), ("SKYT", "skyt.png"), ("SKYB", "skyb.png")):
        ok = txtr_png(prsc, prsc_pal, tag, OUT / filename)
        print("sky", tag, ok)

    plants = []
    plant_dir = OUT / "plants"
    plant_dir.mkdir(exist_ok=True)
    prsc_dirs = index_folders(INSTALL / "prsc.wad")
    seen = set()
    for (name, ext), rows in prsc.items():
        if ext != "WIDG":
            continue
        for odir, raw in rows:
            if "prsc.LAND" not in odir and "LAND" not in odir:
                continue
            if name in seen:
                continue
            seen.add(name)
            try:
                tex = obj_widg(raw, plant_dir / f"{name}.obj")
            except Exception as exc:
                print("widg fail", name, exc)
                continue
            png = plant_dir / f"{name}.png"
            if folder_txtr_png(prsc_dirs.get(odir, {}), tex, png):
                plants.append({
                    "name": name,
                    "mesh": f"res://cache/look/persephone/plants/{name}.obj",
                    "texture": f"res://cache/look/persephone/plants/{name}.png",
                })
    print("plants", len(plants))

    joby, joby_pal = index_wad(INSTALL / "joby.wad")
    joby_dirs = index_folders(INSTALL / "joby.wad")
    structures = []
    bldg_dir = OUT / "buildings"
    bldg_dir.mkdir(exist_ok=True)
    seen_b = set()
    for (name, ext), rows in joby.items():
        if ext != "MRMM":
            continue
        for odir, raw in rows:
            if "prsc" not in odir.lower():
                continue
            if name in seen_b:
                continue
            seen_b.add(name)
            folder = bldg_dir / name
            folder.mkdir(exist_ok=True)
            try:
                textures = obj_mrmm(raw, folder / f"{name}.obj")
            except Exception as exc:
                print("mrmm fail", name, exc)
                continue
            got = False
            for tex in textures:
                if folder_txtr_png(joby_dirs.get(odir, {}), tex, folder / f"{tex}.png"):
                    got = True
                elif txtr_png(joby, joby_pal, tex, folder / f"{tex}.png"):
                    got = True
                elif txtr_png(prsc, prsc_pal, tex, folder / f"{tex}.png"):
                    got = True
            if got:
                structures.append({
                    "name": name,
                    "mesh": f"res://cache/look/persephone/buildings/{name}/{name}.obj",
                    "texture": "",
                })
    print("structures", len(structures), [s["name"] for s in structures])
    structures.extend(export_spell_models())

    creatures = []
    if (OUT / "catalog.json").exists():
        creatures = json.loads((OUT / "catalog.json").read_text()).get("creatures", [])
    catalog = {"plants": plants, "structures": structures, "creatures": creatures}
    (OUT / "catalog.json").write_text(json.dumps(catalog, indent=2))


if __name__ == "__main__":
    main()
