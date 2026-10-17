#!/usr/bin/env python3
"""Import the original's 2D art (HUD, spell icons, cursors, X menu, particle atlases) to assets/original/{ui,fx}/.

RFC-033 (033d). Writes only assets/original/ui/{icons,hud,cursors,xmenu}/ and assets/original/fx/. Deterministic and
idempotent: a second run writes nothing, and an existing .png.import is never touched (it carries the UID).

  python3 tools/import_ui.py            # write
  python3 tools/import_ui.py --check    # report what would change, write nothing

Source: the PNGs that tools/export_icons.py and tools/export_particles.py leave in cache/look/ (copied byte for byte, so
the pixels are the ones the game drew before), plus the sprite `scri` of Divine Sight's eye, decoded here from
charlie.wad with the same TXTR reader (Bloo.WAD!/Pers.FLDR/tex.FLDR, sacobject.d:3851-3865 names it tex_ZERO_.FLDR).
fx.json is the particle catalog with its `png` paths moved to res://assets/original/fx/. The raw WAD extraction of the
other images stays in the exporters until 033h; this step only copies. Run it once; the result is versioned.

Import settings (so the pixels reach the screen as before): lossless, no fix_alpha_border, and mipmaps only where the old
code generated them: fx atlases the catalog lists (FxAtlas.catalog_texture) and `scri`. The atlases read without mipmaps
(FxAtlas.texture: tethers, portals, spikes) and every ui image have none.
"""

import json
import shutil
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

ROOT = Path(__file__).resolve().parents[1]
LOOK = ROOT / "cache" / "look"
OUT = ROOT / "assets" / "original"
FAMILIES = ("icons", "hud", "cursors", "xmenu")
OLD_FX = "res://cache/look/fx/"
NEW_FX = "res://assets/original/fx/"
# Sprites decoded from the install here: tag -> (wad, folder).
EXTRA_FX = {"scri": ("charlie.wad", "Bloo.WAD!/Pers.FLDR/tex.FLDR")}

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


def decode_extra(tag: str, wad_name: str, folder: str) -> bytes:
    from export_particles import export_atlas, index_folders
    from export_persephone import INSTALL

    files = index_folders(INSTALL / wad_name)
    with tempfile.TemporaryDirectory() as tmp:
        dest = Path(tmp) / f"{tag}.png"
        size = export_atlas(files, folder, tag, dest)
        assert size is not None, f"{tag} not found in {wad_name}!{folder}"
        return dest.read_bytes()


def main() -> None:
    writer = Writer("--check" in sys.argv)
    counts = {}
    for family in FAMILIES:
        for png in sorted((LOOK / family).glob("*.png")):
            writer.put(OUT / "ui" / family / png.name, png.read_bytes(), mips=False)
            counts[family] = counts.get(family, 0) + 1

    catalog = json.loads((LOOK / "fx" / "fx.json").read_text())
    with_mips = {entry["txtr"] for entry in catalog.values()} | set(EXTRA_FX)
    for png in sorted((LOOK / "fx").glob("*.png")):
        writer.put(OUT / "fx" / png.name, png.read_bytes(), mips=png.stem in with_mips)
        counts["fx"] = counts.get("fx", 0) + 1
    for tag, (wad_name, folder) in sorted(EXTRA_FX.items()):
        writer.put(OUT / "fx" / f"{tag}.png", decode_extra(tag, wad_name, folder), mips=True)
        counts["fx"] += 1
    for entry in catalog.values():
        assert entry["png"].startswith(OLD_FX), entry["png"]
        entry["png"] = NEW_FX + entry["png"][len(OLD_FX):]
    writer.put(OUT / "fx" / "fx.json", (json.dumps(catalog, indent=2) + "\n").encode())
    print("ui/fx %s: %d written, %d unchanged%s" % (counts, writer.written, writer.kept, " [check]" if writer.check else ""))


if __name__ == "__main__":
    main()
