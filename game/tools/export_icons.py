#!/usr/bin/env python3
"""Spellbook icons and HUD sheets from the local install (sacspell.d icon, sacobject.d SacHud).

Writes game/cache/look/icons/<spell tag>.png for every creature and spell in cache/data
(the CRE8/SPEL `icon` field names MAIN.WAD!/icon.FLDR/**/<reversed icon>.ICON, a TXTR) and
game/cache/look/hud/{tabs,page,spi2,fram}.png. RFC-025c adds cache/look/cursors/<Name>.png (curs.FLDR),
the order icons Matt/Mgua/Mgot/ncst in icons/ and cache/look/xmenu/<xmnu tag>.png (xmenu.wad). RFC-028a adds
hud/spir.png (the 4×4 soul sheet, bits.FLDR), hud/fn10.png (font.FLDR, the soul count) and the six stat bar
strips hud/stat_{mana,health}_{top,mid,bottom}.png; sacengine builds those strips from byte arrays in
SacHud (sacobject.d:2111-2122), read here from the local sacengine checkout, so no code is copied.
Run export_stats.py first. Does not copy the wads.
"""

import json
import re
from pathlib import Path

from export_particles import decode_txtr, index_folders
from export_persephone import INSTALL, write_png

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "cache" / "data"
ICONS = ROOT / "cache" / "look" / "icons"
HUD = ROOT / "cache" / "look" / "hud"
CURSORS = ROOT / "cache" / "look" / "cursors"
XMENU = ROOT / "cache" / "look" / "xmenu"
SACOBJECT = ROOT.parent / "sacengine" / "source" / "sacobject.d"
# SacHud mana[0..2] / health[0..2]: name of the D array -> (output file, height); all 32 wide, RGBA.
STAT_STRIPS = {
    "manaTopData": ("stat_mana_top", 4),
    "manaData": ("stat_mana_mid", 1),
    "manaBottomData": ("stat_mana_bottom", 6),
    "healthTopData": ("stat_health_top", 4),
    "healthData": ("stat_health_mid", 1),
    "healthBottomData": ("stat_health_bottom", 6),
}

ICON_ROOT = "MAIN.WAD!/icon.FLDR"
# SacHud: huds.FLDR/{fram,page,tabs}.TXTR, bits.FLDR/spi2.TXTR.
CURSOR_ROOT = "MAIN.WAD!/curs.FLDR"
# SacCursor (sacobject.d:1973-2021): the order icons and the invalid-target icon live in icon.FLDR.
ORDER_ICONS = ("Matt", "Mgua", "Mgot", "ncst")
HUD_SHEETS = {
    "tabs": "MAIN.WAD!/huds.FLDR",
    "page": "MAIN.WAD!/huds.FLDR",
    "fram": "MAIN.WAD!/huds.FLDR",
    "spi2": "MAIN.WAD!/bits.FLDR",
    # SacSoul (sacobject.d:1170) and SacFont fn10 (sacfont.d:27), RFC-028a.
    "spir": "MAIN.WAD!/bits.FLDR",
    "fn10": "MAIN.WAD!/font.FLDR",
}


def export_image(files: dict, folder: str, name: str, ext: str, dest: Path) -> bool:
    """loadTXTR: the palette is <pal>.PALT next to the file (txtr.d)."""
    raw = files.get((folder, name, ext))
    if raw is None:
        return False
    pal_name = raw[8:12][::-1].decode("latin1").rstrip("\x00")
    palette = None
    if pal_name.lower() != "gray":
        pal = files.get((folder, pal_name, "PALT"))
        if pal is None:
            return False
        palette = pal[8:]
    width, height, rgba = decode_txtr(raw, palette)
    write_png(dest, width, height, rgba)
    return True


def export_stat_strips(dest: Path) -> int:
    """The SacHud bar strips (sacobject.d:2111-2122): 32 px wide RGBA byte arrays in the D source."""
    if not SACOBJECT.exists():
        print("stat strips: no", SACOBJECT)
        return 0
    source = SACOBJECT.read_text(errors="replace")
    written = 0
    for array, (name, height) in STAT_STRIPS.items():
        match = re.search(r"ubyte\[\]\s+%s\s*=\s*\[([0-9,\s]+)\]" % array, source)
        if match is None:
            print("stat strip missing", array)
            continue
        data = bytes(int(v) for v in match.group(1).replace(" ", "").split(",") if v)
        if len(data) != 32 * height * 4:
            print("stat strip size", array, len(data))
            continue
        write_png(dest / f"{name}.png", 32, height, data)
        written += 1
    return written


def files_in(files: dict, folder: str):
    return [(name, ext) for (fld, name, ext) in files if fld == folder]


def main() -> None:
    files = index_folders(INSTALL / "main.wad")
    # makeIconByTag: every .ICON under icon.FLDR, by file name.
    icon_folder = {}
    for folder, name, ext in files:
        if ext == "ICON" and folder.startswith(ICON_ROOT) and name not in icon_folder:
            icon_folder[name] = folder

    ICONS.mkdir(parents=True, exist_ok=True)
    (ICONS / ".gdignore").write_text("")
    written = 0
    missing = []
    for table in ("creatures", "spells", "abilities"):
        path = DATA / f"{table}.json"
        if not path.exists():
            continue
        rows = json.loads(path.read_text())
        for spell_tag, row in rows.items():
            icon = str(row.get("icon", "")).strip("\x00")
            if not icon:
                continue
            name = icon[::-1]
            folder = icon_folder.get(name)
            if folder and export_image(files, folder, name, "ICON", ICONS / f"{spell_tag}.png"):
                written += 1
            else:
                missing.append(f"{spell_tag}:{icon}")
    print("icons", written, "missing", len(missing), missing[:12])

    # RFC-025c: SacCursor order icons + invalid target (icon.FLDR), written next to the spell icons.
    orders = 0
    for name in ORDER_ICONS:
        folder = icon_folder.get(name)
        if folder and export_image(files, folder, name, "ICON", ICONS / f"{name}.png"):
            orders += 1
        else:
            print("order icon missing", name)
    print("ordenes", orders)

    # RFC-025c: every cursor of curs.FLDR (Cnor, Cfun, ... Tnon), palette Cur1.PALT of the folder.
    CURSORS.mkdir(parents=True, exist_ok=True)
    (CURSORS / ".gdignore").write_text("")
    cursors = 0
    for (name, ext) in sorted(files_in(files, CURSOR_ROOT)):
        if ext == "ICON" and export_image(files, CURSOR_ROOT, name, "ICON", CURSORS / f"{name}.png"):
            cursors += 1
    print("cursores", cursors)

    # RFC-025c: the icon of every XMNU of xmenu.wad (SacXmenu.load: XMNU.icon names an icon.FLDR icon).
    XMENU.mkdir(parents=True, exist_ok=True)
    (XMENU / ".gdignore").write_text("")
    xmenu = 0
    xfiles = index_folders(INSTALL / "xmenu.wad")
    for (folder_x, name, ext), raw in sorted(xfiles.items()):
        if ext != "XMNU" or len(raw) < 12:
            continue
        tag = raw[0:4].decode("latin1").rstrip("\x00")
        icon = raw[8:12][::-1].decode("latin1").rstrip("\x00")
        folder = icon_folder.get(icon)
        if folder and export_image(files, folder, icon, "ICON", XMENU / f"{tag}.png"):
            xmenu += 1
        else:
            print("xmenu sin icono", tag, icon)
    print("xmenu", xmenu)

    HUD.mkdir(parents=True, exist_ok=True)
    (HUD / ".gdignore").write_text("")
    for name, folder in HUD_SHEETS.items():
        ok = export_image(files, folder, name, "TXTR", HUD / f"{name}.png")
        print("hud", name, "ok" if ok else "missing")
    print("franjas", export_stat_strips(HUD))


if __name__ == "__main__":
    main()
