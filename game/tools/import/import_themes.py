#!/usr/bin/env python3
"""Needs the original game installed (SAC_INSTALL). See tools/import/local.cfg.example.

Import the five gods' land images (tileset, sky, sun) to assets/original/themes/<god>/.

Writes only assets/original/themes/. Deterministic and idempotent: a second run writes nothing, and an
existing .png.import is never touched (it carries the UID).

  python3 tools/import/import_themes.py            # write
  python3 tools/import/import_themes.py --check    # report what would change, write nothing

Source: the god WADs (prsc, pyro_a, james_a, strato_a, char), read with tools/import/sac_formats; tools/import/land_themes.py
finds the textures the ENVI names. Run it once; the result is versioned. The ground of each god is not here: its role sheets
(themes/<god>/roles/) come from tools/import/bake_role_sheets.py.

Per god: edge.png (lossless texture: exact pixels, no mipmaps, no compression; the cliff walls of the GodGround),
skyt.png / skyb.png / sky.png (mipmapped textures: the sky sampled them with Image.generate_mipmaps()), sun.png and
undr.png (textures without mipmaps; no consumer yet). The ENVI colours (background, fog) are no longer written: they were copied once into
data/look/sky/<god>_sky.tres, which the game and the inspector own from then on.

The cloud/sky textures of persephone are the ones the old sky read from a duplicate (same md5).
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import land_themes  # noqa: E402
from import_ui import IMPORT_TEMPLATE  # noqa: E402
from sac_formats import txtr  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
ARGS = {a.split("=", 1)[0]: (a.split("=", 1)[1] if "=" in a else True) for a in sys.argv[1:]}
OUT = Path(ARGS.get("--out", ROOT / "assets" / "original" / "themes"))
# file -> "lossless" (texture, exact pixels, no mipmaps, never VRAM-compressed), "mips" (texture with mipmaps) or "plain" (texture without)
KINDS = {"edge": "lossless", "skyt": "mips", "skyb": "mips", "sky": "mips", "sun": "plain", "undr": "plain"}

IMAGE_TEMPLATE = """[remap]

importer="image"
type="Image"

[deps]

source_file="res://assets/original/{rel}"

[params]

"""

class Writer:
    def __init__(self, check: bool):
        self.check = check
        self.written = 0
        self.kept = 0

    def put(self, path: Path, data: bytes, kind: str | None = None) -> None:
        if path.exists() and path.read_bytes() == data:
            self.kept += 1
        else:
            self.written += 1
            if not self.check:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
        if kind is not None:
            imp = path.with_name(path.name + ".import")
            if not imp.exists() and not self.check:
                rel = path.relative_to(OUT.parent).as_posix()
                if kind == "image":
                    imp.write_text(IMAGE_TEMPLATE.format(rel=rel))
                elif kind == "lossless":
                    text = IMPORT_TEMPLATE.format(rel=rel, mips="false")
                    imp.write_text(text.replace("compress_to=1", "compress_to=0"))
                else:
                    imp.write_text(IMPORT_TEMPLATE.format(rel=rel, mips="true" if kind == "mips" else "false"))


def main() -> None:
    writer = Writer("--check" in ARGS)
    for god, (images, theme) in land_themes.build_all().items():
        assert not theme["missing"], (god, theme["missing"])
        for name, kind in KINDS.items():
            writer.put(OUT / god / (name + ".png"), txtr.png_bytes(*images[name + ".png"]), kind)
    print("themes: %d written, %d unchanged%s" % (writer.written, writer.kept, " [check]" if writer.check else ""))


if __name__ == "__main__":
    main()
