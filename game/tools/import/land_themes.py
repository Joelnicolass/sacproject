"""Requiere el juego original instalado (SAC_INSTALL). Ver tools/import/local.cfg.example.

Per-god land from the local install: the sky and edge textures and ENVI colours (tools/import/import_themes.py writes
assets/original/themes/ with them), and the tiles, tile groups and maps the ground tools read (bake_ground_roles.py,
bake_role_sheets.py).

Layout follows sacengine sacmap.d: the LAND folder of each god holds LAND.PALT,
0000-0255.MAPT, the MAPG tile groups, the ENVI and the sky textures it names (SKY_ is read by its
literal name, like sacengine does).
"""

import json
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sac_formats.install import INSTALL as DATA, MAPS, require_maps  # noqa: E402
from sac_formats.txtr import folder_texture  # noqa: E402
from sac_formats.wad import extract, walk  # noqa: E402

require_maps()

MAP = MAPS / "(2) High Noon.scp"

# nttData.d landFolders; sun strength from renderer.d setupEnvironment.
GODS = {
    "persephone": ("prsc.wad", "prsc.LAND", 6.0),
    "pyro": ("pyro_a.wad", "PY_A.LAND", 2.0),
    "james": ("james_a.wad", "JA_A.LAND", 14.0),
    "stratos": ("strato_a.wad", "ST_A.LAND", 12.0),
    "charnel": ("char.wad", "char.LAND", 4.0),
}


def tag(raw: bytes) -> str:
    return raw[::-1].decode("latin1").rstrip("\x00")


def land_folder(wad: Path, suffix: str) -> dict:
    folder = {}
    for odir, name, ext, raw in walk(wad.read_bytes()):
        if odir.endswith(suffix):
            folder[(name, ext)] = raw
    return folder


def parse_envi(raw: bytes) -> dict:
    """envi.d Envi (428 bytes); colors are stored BGR."""
    direct, ambi, amb_r, amb_g, amb_b = struct.unpack_from("<5f", raw, 4)
    shadow, sun_x, sun_y, sun_z = struct.unpack_from("<4f", raw, 368)
    fog_near, fog_far, fog_density = struct.unpack_from("<3f", raw, 416)
    return {
        "sun_direct_strength": direct,
        "sun_ambient_strength": ambi,
        "ambient_rgb": [amb_r, amb_g, amb_b],
        "sky_rgb": [raw[26], raw[25], raw[24]],
        "textures": {
            "sky_": tag(raw[48:52]),
            "skyt": tag(raw[112:116]),
            "skyb": tag(raw[176:180]),
            "sun_": tag(raw[240:244]),
            "undr": tag(raw[304:308]),
            "edge": tag(raw[404:408]),
        },
        "shadow_strength": shadow,
        "sun_direction": [sun_x, sun_y, sun_z],
        "sun_rgb": list(raw[384:387]),
        "fog_rgb": [raw[410], raw[409], raw[408]],
        "fog_type": raw[412],
        "fog_near": fog_near,
        "fog_far": fog_far,
        "fog_density": fog_density,
    }


def cap(values) -> list:
    return [round(max(0.0, min(v, 1.0)), 4) for v in values]


def godot_colors(envi: dict) -> dict:
    """Same formulas as sacengine renderer.d setupEnvironment."""
    direct = envi["sun_direct_strength"]
    ambi = envi["sun_ambient_strength"]
    ambient = cap([ambi * c / 255.0 for c in envi["ambient_rgb"]])
    sun = cap([c / 255.0 for c in envi["sun_rgb"]])
    total = direct + ambi
    mixed = cap([(ambi * a + direct * s) / total for a, s in zip(ambient, sun)]) if total > 0 else sun
    return {
        "background_color": cap([c / 255.0 for c in envi["sky_rgb"]]),
        "ambient_color": ambient,
        "sun_color": mixed,
        "fog_color": cap([c / 255.0 for c in envi["fog_rgb"]]),
        "fog_begin": envi["fog_near"],
        "fog_end": envi["fog_far"],
    }


def tile_groups(folder: dict) -> dict:
    """MGnn.MAPG (maps.d MapGroup, 60 bytes; loadDTIndex reads num at 33, indices at 34, the detail layer DTnn at 55).
    Base groups start with a normalized height band (4 floats); transition groups have
    byte 32 set and start with the two base group numbers they blend."""
    groups = {}
    for (name, ext), raw in folder.items():
        if ext != "MAPG" or len(raw) != 60 or not name[2:].isdigit():
            continue
        group = {"tiles": list(raw[34 : 34 + raw[33]]), "detail": raw[55]}
        if raw[32]:
            group["pair"] = struct.unpack_from("<2i", raw, 0)
        else:
            group["band"] = struct.unpack_from("<4f", raw, 0)
        groups[int(name[2:])] = group
    return groups


def patch_color(folder: dict, palt: bytes, index: int, x0: int, y0: int, size: int) -> tuple:
    data = folder[(f"{index:04d}", "MAPT")]
    total = [0, 0, 0]
    for y in range(y0, y0 + size):
        for x in range(x0, x0 + size):
            color = data[64 * y + x]
            for c in range(3):
                total[c] += palt[3 * color + c]
    return tuple(t / (size * size) for t in total)


def color_distance(a: tuple, b: tuple) -> float:
    return sum((x - y) ** 2 for x, y in zip(a, b))


CORNERS = ((0, 0), (48, 0), (0, 48), (48, 48))


def tile_signatures(folder: dict, palt: bytes, groups: dict, present: set) -> dict:
    """Tile index -> (group, position, base group seen at each 16x16 corner)."""
    base_color = {}
    for number, group in groups.items():
        tiles = [t for t in group["tiles"] if t in present]
        if "band" in group and tiles:
            colors = [patch_color(folder, palt, t, 0, 0, 64) for t in tiles]
            base_color[number] = tuple(sum(c[i] for c in colors) / len(colors) for i in range(3))
    signatures = {}
    for number in sorted(groups):
        group = groups[number]
        for position, tile in enumerate(group["tiles"]):
            if tile in signatures or tile not in present:
                continue
            if "band" in group:
                corners = (number,) * 4
            else:
                sides = [s for s in group["pair"] if s in base_color]
                if not sides:
                    continue
                corners = tuple(
                    min(sides, key=lambda s: color_distance(patch_color(folder, palt, tile, x, y, 16), base_color[s]))
                    for x, y in CORNERS
                )
            signatures[tile] = (number, position, corners)
    return signatures


def band_center(group: dict) -> float | None:
    """None for a zero-width band ([0,0,0,0], or James MG05 [1,1,1,1]): no height role."""
    band = group.get("band")
    if band is None or band[0] == band[3]:
        return None
    return (band[1] + band[2]) / 2.0


def land_tiles(folder: dict) -> dict | None:
    palt = folder.get(("LAND", "PALT"))
    if palt is None:
        return None
    palt = palt[8:]
    present = {int(name) for (name, ext) in folder if ext == "MAPT" and name.isdigit()}
    groups = tile_groups(folder)
    return {
        "palt": palt,
        "present": present,
        "groups": groups,
        "signatures": tile_signatures(folder, palt, groups, present),
    }


def build_god(god: str, wad_name: str, land: str, sun_strength: float):
    """({png name: (width, height, RGBA)}, theme dict with the ENVI colours)."""
    folder = land_folder(DATA / wad_name, land)
    missing = []
    envi_raw = folder.get(("ENVI", "ENVI"))
    envi = parse_envi(envi_raw) if envi_raw and len(envi_raw) == 428 else None
    if envi is None:
        missing.append("ENVI")
    names = envi["textures"] if envi else {}
    # sacmap.d reads SKY_ by its literal name (the ENVI may point to an smk).
    sources = {
        "skyt.png": names.get("skyt", "SKYT"),
        "skyb.png": names.get("skyb", "SKYB"),
        "sky.png": "SKY_",
        "undr.png": names.get("undr", "UNDR"),
        "sun.png": names.get("sun_", "SUN_"),
        "edge.png": names.get("edge", "EDGE"),
    }
    images = {}
    for filename, name in sources.items():
        found = folder_texture(folder, name)
        if found is not None:
            images[filename] = found
        else:
            missing.append(filename)
    theme = {
        "god": god,
        "land": f"{wad_name}/{land}",
        "sun_strength": sun_strength,
        "found": sorted(images),
        "missing": missing,
    }
    if envi:
        theme.update(godot_colors(envi))
        theme["envi"] = envi
    return images, theme


# The land each map's LEVL names, by the last four bytes of the LEVL reversed (levl.d detectTileset), in lower case.
LEVL_LAND = {"ja_a": "james", "py_a": "pyro", "st_a": "stratos", "char": "charnel", "prsc": "persephone"}


def map_god(scp: Path) -> str:
    """The god whose land (tileset) the map is made of."""
    return LEVL_LAND[extract(scp, "", "LEVL")[-4:][::-1].decode("latin1").lower()]


def god_land(god: str) -> dict | None:
    wad_name, land, _ = GODS[god]
    return land_tiles(land_folder(DATA / wad_name, land))


def native_tiles(scp: Path) -> bytes:
    """The map's 256x256 tile ids as the .scp stores them: indices of the MAPTs of the map's own land (sacmap.d loads the LEVL land)."""
    return bytes(extract(scp, "", "TMAP")[512: 512 + 256 * 256])


def imported_maps() -> list:
    """The .scp of every map under assets/original/maps/ except High Noon (`MAP`, named apart), by the `map` of its ntts.json."""
    folder = Path(__file__).resolve().parents[2] / "assets" / "original" / "maps"
    found = []
    for ntts in sorted(folder.glob("*/ntts.json")):
        name = json.loads(ntts.read_text())["map"]
        scp = next((c for c in (MAPS / name, MAPS / "Tutorial" / name) if c.exists()), MAPS / name)
        if scp != MAP and scp.exists():
            found.append(scp)
    return found


def build_all() -> dict:
    """{god: (images, theme)} for the five gods (the ground is not here: tools/import/bake_role_sheets.py)."""
    return {god: build_god(god, wad_name, land, sun_strength) for god, (wad_name, land, sun_strength) in GODS.items()}
