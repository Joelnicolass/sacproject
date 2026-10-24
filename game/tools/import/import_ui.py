#!/usr/bin/env python3
"""Requiere el juego original instalado (SAC_INSTALL). Ver tools/import/local.cfg.example.

Import the original's 2D art (HUD, spell icons, cursors, X menu, particle atlases) to assets/original/{ui,fx}/.

RFC-033 (033d, from the WAD in 033h). Writes only assets/original/ui/{icons,hud,cursors,xmenu}/ and assets/original/fx/.
Deterministic and idempotent: a second run writes nothing, and an existing .png.import is never touched (it carries the UID).

  python3 tools/import/import_ui.py                 # write
  python3 tools/import/import_ui.py --check         # report what would change, write nothing
  python3 tools/import/import_ui.py --out=DIR       # write under DIR/{ui,fx} instead (to compare with the versioned ones)

Source: the installation's WAD files, read with tools/import/sac_formats (the only TXTR reader):
  main.wad     icon.FLDR (spell, creature and ability icons, order icons), curs.FLDR (cursors), huds/bits/font.FLDR (HUD sheets),
               bits.FLDR (most particle atlases)
  xmenu.wad    the XMNU of the X menu, whose icon is an icon.FLDR one (SacXmenu.load)
  charlie.wad, shawn.wad   the other particle atlases; `scri` is Divine Sight's eye (Bloo.WAD!/Pers.FLDR/tex.FLDR,
               sacobject.d:3851-3865 names it tex_ZERO_.FLDR)
The icon names come from assets/original/data/{creatures,spells,abilities}.json (tools/import/export_stats.py --out). The six stat bar
strips are byte arrays in the D source (SacHud, sacobject.d:2111-2122), read from the local sacengine checkout (read-only:
the numbers, no code). The particle numbers (size, energy, lifetime...) live in tools/import/fx_catalog.py; fx.json is that catalog
with the `png` paths on res://assets/original/fx/.

Import settings (so the pixels reach the screen as before): lossless, no fix_alpha_border, and mipmaps only where the old
code generated them: fx atlases the catalog lists (FxAtlas.catalog_texture) and `scri`. The atlases read without mipmaps
(FxAtlas.texture: tethers, portals, spikes) and every ui image have none.
"""

import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import fx_catalog  # noqa: E402
from sac_formats import txtr  # noqa: E402
from sac_formats.install import INSTALL  # noqa: E402
from sac_formats.wad import index_flat  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
ARGS = {a.split("=", 1)[0]: (a.split("=", 1)[1] if "=" in a else True) for a in sys.argv[1:]}
OUT = Path(ARGS.get("--out", ROOT / "assets" / "original"))
DATA = ROOT / "assets" / "original" / "data"
SACOBJECT = ROOT.parent / "sacengine" / "source" / "sacobject.d"
NEW_FX = "res://assets/original/fx/"
ICON_ROOT = "MAIN.WAD!/icon.FLDR"
CURSOR_ROOT = "MAIN.WAD!/curs.FLDR"
# SacCursor (sacobject.d:1973-2021): the order icons and the invalid-target icon live in icon.FLDR.
ORDER_ICONS = ("Matt", "Mgua", "Mgot", "ncst")
# SacHud: huds.FLDR/{fram,page,tabs}.TXTR, bits.FLDR/spi2.TXTR; SacSoul (sacobject.d:1170) and SacFont fn10 (sacfont.d:27).
HUD_SHEETS = {
    "tabs": "MAIN.WAD!/huds.FLDR",
    "page": "MAIN.WAD!/huds.FLDR",
    "fram": "MAIN.WAD!/huds.FLDR",
    "spi2": "MAIN.WAD!/bits.FLDR",
    "spir": "MAIN.WAD!/bits.FLDR",
    "fn10": "MAIN.WAD!/font.FLDR",
    # SacHud.minimapIcons (sacobject.d:2125): the minimap icon atlas (RFC-037 037b).
    "mmic": "MAIN.WAD!/icon.FLDR",
}
# SacHud mana[0..2] / health[0..2]: name of the D array -> (output file, height); all 32 wide, RGBA.
STAT_STRIPS = {
    "manaTopData": ("stat_mana_top", 4),
    "manaData": ("stat_mana_mid", 1),
    "manaBottomData": ("stat_mana_bottom", 6),
    "healthTopData": ("stat_health_top", 4),
    "healthData": ("stat_health_mid", 1),
    "healthBottomData": ("stat_health_bottom", 6),
}
# Sprites decoded from the install here: tag -> (wad, folder).
EXTRA_FX = {
    "scri": ("charlie.wad", "Bloo.WAD!/Pers.FLDR/tex.FLDR"),
    # The order marker's cone texture (SacCommandCone, sacobject.d:4483-4505), F220.
    "aura": ("main.wad", "MAIN.WAD!/bits.FLDR"),
    # RFC 061b: Air Shield's bubble (shld; icec is only the exe's default and Frozen's ice), its sparks (pash) and Protective Swarm's bug.
    "icec": ("charlie.wad", "Bloo.WAD!/Stra.FLDR/txtr.FLDR"),
    "shld": ("charlie.wad", "Bloo.WAD!/Stra.FLDR/txtr.FLDR"),
    "pash": ("charlie.wad", "Bloo.WAD!/Stra.FLDR/txtr.FLDR"),
    "pswm": ("charlie.wad", "Bloo.WAD!/Char.FLDR/tex.FLDR"),
    # RFC 061b (SPEL): Protective Swarm's pus burst (puss, mix) and the common spark burst (sprk, Stratos blue stars; Ethereal Form).
    "puss": ("charlie.wad", "Bloo.WAD!/Char.FLDR/tex.FLDR"),
    "sprk": ("charlie.wad", "Bloo.WAD!/Stra.FLDR/txtr.FLDR"),
    # RFC 061c: Freeze's ice block (frez: the SPEL's ttex; icec is the exe's default and belongs to Frozen Ground), Grasping Vines' tube (vine) and its cast particle (cst1); Slime's wet skin (lthg), splash (lth2) and the cast particle
    # sacengine uses (cfx1, the SPEL's tcst). Daniel.wad is spelled with a capital D in the install.
    "frez": ("charlie.wad", "Bloo.WAD!/Stra.FLDR/txtr.FLDR"),
    "vine": ("charlie.wad", "Bloo.WAD!/Pers.FLDR/tex.FLDR"),
    "cst1": ("main.wad", "MAIN.WAD!/bits.FLDR"),
    "lthg": ("Daniel.wad", "DanC.WAD!/char.FLDR"),
    "lth2": ("Daniel.wad", "DanC.WAD!/char.FLDR"),
    "cfx1": ("Daniel.wad", "DanC.WAD!/char.FLDR"),
    # RFC 061f (SPEL): Explosion's casting balls (exeg), its blast particles (xplo 5x5, exp2), ash (frck), smoke (smok) and fireball (fbal); Demonic Rift's
    # edge (rif2), swirl (rif3) and spirit trail (rift); Healing Aura's sphere (haur). cfx1 (Rift's cast) came with 061c.
    "exeg": ("charlie.wad", "Bloo.WAD!/Pyro.FLDR/txtr.FLDR"),
    "frck": ("charlie.wad", "Bloo.WAD!/Pyro.FLDR/txtr.FLDR"),
    "smok": ("charlie.wad", "Bloo.WAD!/Pyro.FLDR/txtr.FLDR"),
    "xplo": ("main.wad", "MAIN.WAD!/bits.FLDR"),
    "exp2": ("main.wad", "MAIN.WAD!/bits.FLDR"),
    "fbal": ("main.wad", "MAIN.WAD!/bits.FLDR"),
    "rif2": ("Daniel.wad", "DanC.WAD!/char.FLDR"),
    "rif3": ("Daniel.wad", "DanC.WAD!/char.FLDR"),
    "rift": ("Daniel.wad", "DanC.WAD!/char.FLDR"),
    "haur": ("charlie.wad", "Bloo.WAD!/Pers.FLDR/tex.FLDR"),
}

IMPORT_TEMPLATE = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://assets/original/{rel}"

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate={mips}
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=false
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""


class Writer:
    def __init__(self, check: bool):
        self.check = check
        self.written = 0
        self.kept = 0

    def put(self, path: Path, data: bytes, mips: bool | None = None) -> None:
        if path.exists() and path.read_bytes() == data:
            self.kept += 1
        else:
            self.written += 1
            if not self.check:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
        if mips is not None and path.suffix == ".png":
            imp = path.with_name(path.name + ".import")
            if not imp.exists() and not self.check:
                rel = path.relative_to(OUT).as_posix()
                imp.write_text(IMPORT_TEMPLATE.format(rel=rel, mips="true" if mips else "false"))


def stat_strips() -> dict:
    """{file stem: PNG bytes}: the SacHud bar strips (sacobject.d:2111-2122), 32 px wide RGBA byte arrays in the D source."""
    if not SACOBJECT.exists():
        print("stat strips: no", SACOBJECT)
        return {}
    source = SACOBJECT.read_text(errors="replace")
    out = {}
    for array, (name, height) in STAT_STRIPS.items():
        match = re.search(r"ubyte\[\]\s+%s\s*=\s*\[([0-9,\s]+)\]" % array, source)
        if match is None:
            print("stat strip missing", array)
            continue
        data = bytes(int(v) for v in match.group(1).replace(" ", "").split(",") if v)
        if len(data) != 32 * height * 4:
            print("stat strip size", array, len(data))
            continue
        out[name] = txtr.png_bytes(32, height, data)
    return out


def icon_file(tag: str) -> str:
    """File stem of an icon tag: each capital letter becomes "_" + lower case. Mirrors OriginalAssets.icon_file (GDScript)."""
    return "".join("_" + c.lower() if c != c.lower() else c for c in tag)


def png_of(found) -> bytes | None:
    return None if found is None else txtr.png_bytes(*found)


def ui_images() -> dict:
    """{family: {file stem: PNG bytes}} of the HUD, icons, cursors and X menu."""
    files = index_flat(INSTALL / "main.wad")
    # makeIconByTag: every .ICON under icon.FLDR, by file name.
    icon_folder = {}
    for folder, name, ext in files:
        if ext == "ICON" and folder.startswith(ICON_ROOT) and name not in icon_folder:
            icon_folder[name] = folder

    def icon(name: str) -> bytes | None:
        folder = icon_folder.get(name)
        return png_of(txtr.flat_texture(files, folder, name, "ICON")) if folder else None

    out = {"icons": {}, "hud": {}, "cursors": {}, "xmenu": {}}
    missing = []
    for table in ("creatures", "spells", "abilities"):
        path = DATA / f"{table}.json"
        if not path.exists():
            print("no", path, "(run tools/import/export_stats.py --out assets/original/data)")
            continue
        for spell_tag, row in json.loads(path.read_text()).items():
            name = str(row.get("icon", "")).strip("\x00")[::-1]
            if not name:
                continue
            png = icon(name)
            if png is None:
                missing.append(f"{spell_tag}:{name[::-1]}")
            else:
                out["icons"][icon_file(spell_tag)] = png
    for name in ORDER_ICONS:
        png = icon(name)
        if png is None:
            print("order icon missing", name)
        else:
            out["icons"][icon_file(name)] = png
    # Every cursor of curs.FLDR (Cnor, Cfun, ... Tnon), palette Cur1.PALT of the folder.
    for folder, name, ext in sorted(files):
        if ext == "ICON" and folder == CURSOR_ROOT:
            png = png_of(txtr.flat_texture(files, folder, name, "ICON"))
            if png is not None:
                out["cursors"][name] = png
    # The icon of every XMNU of xmenu.wad (SacXmenu.load: XMNU.icon names an icon.FLDR icon).
    for (_folder, _name, ext), raw in sorted(index_flat(INSTALL / "xmenu.wad").items()):
        if ext != "XMNU" or len(raw) < 12:
            continue
        tag = raw[0:4].decode("latin1").rstrip("\x00")
        png = icon(raw[8:12][::-1].decode("latin1").rstrip("\x00"))
        if png is None:
            print("xmenu sin icono", tag)
        else:
            out["xmenu"][tag] = png
    for name, folder in HUD_SHEETS.items():
        png = png_of(txtr.flat_texture(files, folder, name))
        if png is None:
            print("hud sheet missing", name)
        else:
            out["hud"][name] = png
    out["hud"].update(stat_strips())
    for family, images in out.items():
        seen = {}
        for stem in images:
            if seen.setdefault(stem.lower(), stem) != stem:
                raise SystemExit("%s: %s and %s are one file on macOS/Windows" % (family, seen[stem.lower()], stem))
    if missing:
        print("icons without art:", len(missing), missing[:12])
    return out


def fx_images() -> tuple:
    """({png stem: PNG bytes}, catalog with res:// paths). Includes `scri`, Divine Sight's eye."""
    wads = {}
    images, png_paths = {}, {}
    atlases = dict(fx_catalog.ATLASES)
    atlases.update(EXTRA_FX)
    for tag, (wad_name, folder) in atlases.items():
        if wad_name not in wads:
            wads[wad_name] = index_flat(INSTALL / wad_name)
        found = fx_catalog.atlas_images(wads[wad_name], folder, tag)
        if found is None:
            print("atlas missing", tag, wad_name, folder)
            continue
        for stem, (width, height, rgba) in found.items():
            images[stem] = txtr.png_bytes(width, height, rgba)
            png_paths[stem] = f"{NEW_FX}{stem}.png"
    return images, fx_catalog.catalog(png_paths)


def icon_tags() -> list:
    """Every tag the game can ask HudIcons.icon for: the keys of creatures, spells and abilities, and the order icons."""
    tags = list(ORDER_ICONS)
    for table in ("creatures", "spells", "abilities"):
        tags += json.loads((DATA / f"{table}.json").read_text()).keys()
    return sorted(set(tags))


def main() -> None:
    if "--icon-files" in ARGS:      # tag<TAB>file, for tools/audit/check_icon_files.gd
        Path(ARGS["--icon-files"]).write_text("".join(f"{t}\t{icon_file(t)}.png\n" for t in icon_tags()))
        return
    writer = Writer("--check" in ARGS)
    counts = {}
    for family, images in ui_images().items():
        for stem, data in sorted(images.items()):
            writer.put(OUT / "ui" / family / f"{stem}.png", data, mips=False)
            counts[family] = counts.get(family, 0) + 1
    images, catalog = fx_images()
    with_mips = {entry["txtr"] for entry in catalog.values()} | set(EXTRA_FX)
    for stem, data in sorted(images.items()):
        writer.put(OUT / "fx" / f"{stem}.png", data, mips=stem in with_mips)
        counts["fx"] = counts.get("fx", 0) + 1
    writer.put(OUT / "fx" / "fx.json", (json.dumps(catalog, indent=2) + "\n").encode())
    print("ui/fx %s: %d written, %d unchanged%s" % (counts, writer.written, writer.kept, " [check]" if writer.check else ""))


if __name__ == "__main__":
    main()
