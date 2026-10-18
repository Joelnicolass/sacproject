#!/usr/bin/env python3
"""Import the five gods' land look (tileset, sky, sun, ENVI colours) to assets/original/themes/<god>/.

RFC-033 (033e). Writes only assets/original/themes/. Deterministic and idempotent: a second run writes nothing, and an
existing .png.import is never touched (it carries the UID).

  python3 tools/import_themes.py            # write
  python3 tools/import_themes.py --check    # report what would change, write nothing

Source: the god WADs (prsc, pyro_a, james_a, strato_a, char) and High Noon's .scp, read with tools/sac_formats; tools/land_themes.py
holds the tileset logic (LAND/MAPG, the remap of High Noon's tile ids onto every land) and the ENVI colours. Run it once; the
result is versioned.

Per god: atlas.png and edge.png (lossless textures: exact pixels, no mipmaps, no compression; ground_classic.tres uses them),
skyt.png / skyb.png / sky.png (mipmapped textures: the sky sampled them with Image.generate_mipmaps()), sun.png and
undr.png (textures without mipmaps; no consumer yet), and envi.tres (a GodEnvi: the ENVI colours, fog range and sun strength the game reads, in the order sacengine's
renderer.d setupEnvironment gives them; the ENVI fields nobody reads stay in theme.json, not in the asset).

The cloud/sky textures of persephone are the ones the old sky read from a duplicate (same md5).
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import land_themes  # noqa: E402
from import_ui import IMPORT_TEMPLATE  # noqa: E402
from sac_formats import txtr  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
ARGS = {a.split("=", 1)[0]: (a.split("=", 1)[1] if "=" in a else True) for a in sys.argv[1:]}
OUT = Path(ARGS.get("--out", ROOT / "assets" / "original" / "themes"))
# file -> "lossless" (texture, exact pixels, no mipmaps, never VRAM-compressed; RFC-035b), "mips" (texture with mipmaps) or "plain" (texture without)
KINDS = {"atlas": "lossless", "edge": "lossless", "skyt": "mips", "skyb": "mips", "sky": "mips", "sun": "plain", "undr": "plain"}

IMAGE_TEMPLATE = """[remap]

importer="image"
type="Image"

[deps]

source_file="res://assets/original/{rel}"

[params]

"""

ENVI_HEAD = """[gd_resource type="Resource" script_class="GodEnvi" load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/world/god_envi.gd" id="1_envi"]

[resource]
script = ExtResource("1_envi")
"""


def color(rgb: list) -> str:
    return "Color(%s, %s, %s, 1)" % tuple(repr(float(v)) for v in rgb[:3])


def envi_tres(theme: dict) -> str:
    envi = theme["envi"]
    lines = [
        "background_color = " + color(theme["background_color"]),
        "ambient_color = " + color(theme["ambient_color"]),
        "sun_color = " + color(theme["sun_color"]),
        "fog_color = " + color(theme["fog_color"]),
        "fog_begin = " + repr(float(theme["fog_begin"])),
        "fog_end = " + repr(float(theme["fog_end"])),
        "sun_direct_strength = " + repr(float(envi["sun_direct_strength"])),
    ]
    return ENVI_HEAD + "\n".join(lines) + "\n"


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
        writer.put(OUT / god / "envi.tres", envi_tres(theme).encode())
    print("themes: %d written, %d unchanged%s" % (writer.written, writer.kept, " [check]" if writer.check else ""))


if __name__ == "__main__":
    main()
