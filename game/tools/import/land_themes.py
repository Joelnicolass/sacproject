"""Requiere el juego original instalado (SAC_INSTALL). Ver tools/import/local.cfg.example.

Per-god land look (sky, ground atlas, ENVI colors) from the local install.

Layout follows sacengine sacmap.d: the LAND folder of each god holds LAND.PALT,
0000-0255.MAPT, the ENVI and the sky textures it names (SKY_ is read by its
literal name, like sacengine does). tools/import/import_themes.py writes assets/original/themes/ with it.
"""

import itertools
import json
import struct
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sac_formats.install import INSTALL as DATA, MAPS, require_maps  # noqa: E402
from sac_formats.txtr import folder_texture  # noqa: E402
from sac_formats.wad import extract, walk  # noqa: E402

require_maps()

MAP = MAPS / "(2) High Noon.scp"
# Land High Noon's LEVL names (levl.d detectTileset); its TMAP ids index this land's MAPTs.
MAP_GOD = "james"

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
    """MGnn.MAPG (maps.d MapGroup, 60 bytes; loadDTIndex reads num at 33, indices at 34).
    Base groups start with a normalized height band (4 floats); transition groups have
    byte 32 set and start with the two base group numbers they blend."""
    groups = {}
    for (name, ext), raw in folder.items():
        if ext != "MAPG" or len(raw) != 60 or not name[2:].isdigit():
            continue
        group = {"tiles": list(raw[34 : 34 + raw[33]])}
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


# RFC-059a. Persephone's ground is made only of Persephone's own tiles (the ones the tutorial paints), never of tiles that
# look like James's: High Noon's base groups (MAPG numbers of James's land) take a native base group by role. Which native
# group plays which role comes from how tu02 (sacengine/maps/Tutorial/(tu02).scp, land prsc) uses its tiles: group 3 is its
# grass (5 665 of 18 520 painted cells, the largest; mean RGB 119,152,20), 2 the grey-green earth around it (3 444), 1 the
# pale stone of the rings and paths (2 217), 4 the warm dirt of the banks. Each pair of roles that touch on High Noon has a
# native transition group (3-2 = MG11, 2-1 = MG10, 3-4 = MG12), so the seams keep blending.
#   James MG00 open ground (91 % of High Noon)  -> MG03 grass
#   James MG01 hill earth                       -> MG04 dirt
#   James MG02 low ground, pale paths           -> MG02 grey-green earth
#   James MG03 rock and cliff                   -> MG01 pale stone
# James MG04..MG06 have no height role: they take the native group of the ground they border (base_mapping, as before).
NATIVE_ROLES = {"persephone": {0: 3, 1: 4, 2: 2, 3: 1}}

# Source land -> James groups, decided by hand for the maps of another land (map_tiles). The height bands alone sent Peaks's
# dominant low ground (Charnel MG04, 43 % of the map, a band of zeros) to James's pale low ground MG02 and its rim to
# the rock MG03, so every god showed Peaks as snow. Charnel MG04 and its rim MG00 are the open ground (James MG00), the
# heights (MG01) take the hill earth MG01, the peaks the rock MG03, the low pockets MG02.
JAMES_ROLES = {"charnel": {4: 0, 0: 0, 1: 1, 2: 3, 3: 2, 5: 2}}


def base_mapping(source: dict, target: dict, tmap: bytes, by_corners: dict, fixed: dict | None = None) -> dict:
    """Source base group -> target base group.

    `fixed` (NATIVE_ROLES) decides the groups with a height role by hand; only the groups without a role are inferred.

    Groups with a height role keep the band order and, among the orders that keep the most
    map cells of each transition blended (the target land has that pair, or both sides
    land on one group), take the nearest bands. A group without a role takes the group
    its cells border most on the map."""
    roles = {n: c for n, g in source["groups"].items() if (c := band_center(g)) is not None}
    targets = {n: c for n, g in target["groups"].items() if (c := band_center(g)) is not None}
    if not roles or not targets:
        return {}
    cells = Counter(tmap)
    seams = Counter()
    for tile, count in cells.items():
        signature = source["signatures"].get(tile)
        if signature and len(set(signature[2])) > 1:
            seams[signature[2]] += count

    def kept(mapping: dict) -> int:
        total = 0
        for corners, count in seams.items():
            wanted = tuple(mapping.get(c, -1) for c in corners)
            if -1 not in wanted and (len(set(wanted)) == 1 or wanted in by_corners):
                total += count
        return total

    if fixed is not None:
        mapping = {n: fixed[n] for n in roles}
    else:
        order = sorted(roles, key=lambda n: (roles[n], n))
        best = None
        for choice in itertools.product(sorted(targets), repeat=len(order)):
            if any(targets[a] > targets[b] for a, b in zip(choice, choice[1:])):
                continue
            mapping = dict(zip(order, choice))
            distance = sum(abs(targets[mapping[n]] - roles[n]) for n in order)
            score = (-kept(mapping), distance, choice)
            if best is None or score < best[0]:
                best = (score, mapping)
        mapping = dict(best[1])

    width = 256
    neighbors = {}
    for index, tile in enumerate(tmap):
        signature = source["signatures"].get(tile)
        if signature is None or signature[0] in roles or "band" not in source["groups"][signature[0]]:
            continue
        x, y = index % width, index // width
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < width and 0 <= ny < len(tmap) // width:
                other = source["signatures"].get(tmap[ny * width + nx])
                if other:
                    for corner in other[2]:
                        if corner in roles:
                            neighbors.setdefault(signature[0], Counter())[corner] += 1
    for number, counter in neighbors.items():
        mapping[number] = mapping[counter.most_common(1)[0][0]]
    if fixed is not None:
        mapping.update(fixed)
    return mapping


def land_remap(source: dict, target: dict, tmap: bytes, extra: frozenset = frozenset(), fixed: dict | None = None) -> tuple:
    """Tile id of the source land -> MAPT index of the target land with the same role, and the base group map.

    The base group map is decided by `tmap` alone (High Noon's cells for the themes). `extra` are more ids (the ones other maps
    use) that take that same group map, so adding a map never moves what an id already maps to."""
    by_corners = {}
    for tile, (number, _, corners) in sorted(target["signatures"].items()):
        is_base = "band" in target["groups"][number]
        if len(set(corners)) == 1 and not is_base:
            continue
        by_corners.setdefault(corners, []).append(tile)
    base_map = base_mapping(source, target, tmap, by_corners, fixed)
    remap = {}
    for tile in sorted(set(tmap) | set(extra)):
        signature = source["signatures"].get(tile)
        if signature is None:
            continue
        _, position, corners = signature
        wanted = tuple(base_map.get(c, -1) for c in corners)
        if -1 in wanted:
            continue
        options = by_corners.get(wanted)
        if not options:
            majority = max(set(wanted), key=lambda g: (wanted.count(g), -wanted.index(g)))
            options = by_corners.get((majority,) * 4, [])
        if options:
            remap[tile] = options[position % len(options)]
    return remap, base_map


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


def build_atlas(folder: dict, tmap: bytes, map_land: dict | None, extra: frozenset = frozenset(), god: str = "") -> dict:
    """16x16 grid of 64x64 MAPT, like terrain.gd / sacrifice_ground.gdshader expect."""
    land = land_tiles(folder)
    if land is None:
        return {"ok": False}
    palt = land["palt"]
    present = land["present"]
    used = set(tmap)
    # WORKAROUND: High Noon's tile ids index James's MAPTs (sacmap.d:192-195 loads the
    # LEVL land only; a missing MAPT stays blank, 695). To show the map under another
    # god, each used id takes the MAPT of that land with the same role: base groups by
    # MAPG height band (base_mapping), transitions by which base group each corner shows.
    # Nearest band alone sent James's rock (MG03) and MG05 to Persephone's MG00, a single
    # near-white tile (0000, also the filler under void cells), and lost the seams Persephone's
    # chain of groups can't blend: flat square cells.
    remap = {}
    groups = {}
    if map_land is not None:
        remap, groups = land_remap(map_land, land, tmap, extra, NATIVE_ROLES.get(god))
    atlas = bytearray(1024 * 1024 * 4)
    for index in range(256):
        source = remap.get(index, index if map_land is None else None)
        if source is None or source not in present:
            continue
        data = folder[(f"{source:04d}", "MAPT")][:4096]
        ox = (index % 16) * 64
        oy = (index // 16) * 64
        for y in range(64):
            row = data[64 * y : 64 * y + 64]
            out = ((oy + y) * 1024 + ox) * 4
            for x, color in enumerate(row):
                atlas[out + 4 * x : out + 4 * x + 4] = palt[3 * color : 3 * color + 3] + b"\xff"
    unmapped = sorted((used | set(extra)) - set(remap)) if map_land is not None else sorted(used - present)
    return {
        "ok": True,
        "image": (1024, 1024, bytes(atlas)),
        "mapt": len(present),
        "groups": {str(k): v for k, v in sorted(groups.items())},
        "remap": {str(k): v for k, v in remap.items()},
        "unmapped": unmapped,
    }


def build_god(god: str, wad_name: str, land: str, sun_strength: float, tmap: bytes, map_land: dict | None, extra: frozenset = frozenset()):
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
    atlas = build_atlas(folder, tmap, map_land, extra, god)
    if atlas["ok"]:
        images["atlas.png"] = atlas["image"]
    else:
        missing.append("atlas.png")
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


def map_tiles(scp: Path) -> tuple:
    """(the map's 256x256 tile ids in James's tileset, the number of cells whose id found no James tile, the number of cells).

    The ground atlases index James's MAPTs (the themes remap them onto the other lands). A map of another land (Charnel, Pyro,
    Stratos) is moved onto James with the same land_remap the themes use, by role, so the ground of every map is read the same way.
    WORKAROUND: the original reads each map in its own land; ids that find no James tile keep their number (they paint a tile
    of another role, or none)."""
    tmap = bytes(extract(scp, "", "TMAP")[512: 512 + 256 * 256])
    god = map_god(scp)
    if god == MAP_GOD:
        return tmap, 0, len(tmap)
    remap, _ = land_remap(god_land(god), god_land(MAP_GOD), tmap, frozenset(), JAMES_ROLES.get(god))
    missed = sum(1 for tile in tmap if tile not in remap)
    return bytes(remap.get(tile, tile) for tile in tmap), missed, len(tmap)


def native_tiles(scp: Path) -> bytes:
    """The map's 256x256 tile ids as the .scp stores them: indices of the MAPTs of the map's own land (sacmap.d loads the LEVL land)."""
    return bytes(extract(scp, "", "TMAP")[512: 512 + 256 * 256])


def native_atlas(god: str, scp: Path) -> tuple:
    """(1024, 1024, RGBA) atlas of the tiles `scp` paints, each at its own id, from the land of `god` (the map's land, map_god(scp)).

    RFC-059b. No remap: the tile ids of a Persephone map index Persephone's MAPTs, as in the original. The ids the map does not
    paint stay blank, so the file says what the map uses."""
    if map_god(scp) != god:
        sys.exit("land_themes: %s is a %s map; its native atlas is that god's, not %s's" % (scp.name, map_god(scp), god))
    wad_name, land, _ = GODS[god]
    folder = land_folder(DATA / wad_name, land)
    palt = folder[("LAND", "PALT")][8:]
    atlas = bytearray(1024 * 1024 * 4)
    for index in sorted(set(native_tiles(scp))):
        data = folder.get((f"{index:04d}", "MAPT"))
        if data is None:
            continue
        ox, oy = (index % 16) * 64, (index // 16) * 64
        for y in range(64):
            out = ((oy + y) * 1024 + ox) * 4
            for x, color in enumerate(data[64 * y: 64 * y + 64]):
                atlas[out + 4 * x: out + 4 * x + 4] = palt[3 * color: 3 * color + 3] + b"\xff"
    return 1024, 1024, bytes(atlas)


def imported_maps() -> list:
    """The .scp of every map under assets/original/maps/ except High Noon (the base of the themes), by the `map` of its ntts.json."""
    folder = Path(__file__).resolve().parents[2] / "assets" / "original" / "maps"
    found = []
    for ntts in sorted(folder.glob("*/ntts.json")):
        name = json.loads(ntts.read_text())["map"]
        scp = next((c for c in (MAPS / name, MAPS / "Tutorial" / name) if c.exists()), MAPS / name)
        if scp != MAP and scp.exists():
            found.append(scp)
    return found


def build_all() -> dict:
    """{god: (images, theme)} for the five gods; High Noon's tile ids (and the ones of the other imported maps) are remapped
    onto every land that is not James's. The other maps only add ids: High Noon's tiles map as before."""
    tmap = extract(MAP, "", "TMAP")[512: 512 + 256 * 256]
    extra = frozenset(tile for scp in imported_maps() for tile in set(map_tiles(scp)[0]))
    wad_name, land, _ = GODS[MAP_GOD]
    map_land = land_tiles(land_folder(DATA / wad_name, land))
    return {
        god: build_god(god, wad_name, land, sun_strength, tmap, None if god == MAP_GOD else map_land, extra)
        for god, (wad_name, land, sun_strength) in GODS.items()
    }
