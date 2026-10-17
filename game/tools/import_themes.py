#!/usr/bin/env python3
"""Import the five gods' land look (tileset, sky, sun, ENVI colours) to assets/original/themes/<god>/.

RFC-033 (033e). Writes only assets/original/themes/. Deterministic and idempotent: a second run writes nothing, and an
existing .png.import is never touched (it carries the UID).

  python3 tools/import_themes.py            # write
  python3 tools/import_themes.py --check    # report what would change, write nothing

Source: what tools/export_tilesets.py leaves in cache/look/themes/<god>/ (PNG copied byte for byte, so the pixels are
the ones the game drew before; theme.json holds the ENVI colours). The raw WAD extraction stays in the exporter until
033h; this step only copies and converts. Run it once; the result is versioned.

Per god: atlas.png and edge.png (CPU images: TerrainMesh reads them as Image, exact, no mipmaps, no compression),
skyt.png / skyb.png / sky.png (mipmapped textures: the sky sampled them with Image.generate_mipmaps()), sun.png and
undr.png (textures without mipmaps; no consumer yet), and envi.tres (a GodEnvi: the ENVI colours the old theme.json
carried, in the order sacengine's renderer.d setupEnvironment gives them).

The cloud/sky textures of persephone are the ones the old sky read from cache/look/persephone/ (a duplicate, same md5).
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from import_ui import IMPORT_TEMPLATE  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "cache" / "look" / "themes"
OUT = ROOT / "assets" / "original" / "themes"
GODS = ("persephone", "pyro", "james", "stratos", "charnel")
# file -> "image" (CPU Image), "mips" (texture with mipmaps) or "plain" (texture without)
KINDS = {"atlas": "image", "edge": "image", "skyt": "mips", "skyb": "mips", "sky": "mips", "sun": "plain", "undr": "plain"}

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
    sun = envi["sun_direction"]
    lines = [
        "background_color = " + color(theme["background_color"]),
        "ambient_color = " + color(theme["ambient_color"]),
        "sun_color = " + color(theme["sun_color"]),
        "fog_color = " + color(theme["fog_color"]),
        "fog_begin = " + repr(float(theme["fog_begin"])),
        "fog_end = " + repr(float(theme["fog_end"])),
        "fog_density = " + repr(float(envi["fog_density"])),
        "sun_direct_strength = " + repr(float(envi["sun_direct_strength"])),
        "sun_ambient_strength = " + repr(float(envi["sun_ambient_strength"])),
        "shadow_strength = " + repr(float(envi["shadow_strength"])),
        "sun_direction = Vector3(%s, %s, %s)" % tuple(repr(float(v)) for v in sun),
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
                else:
                    imp.write_text(IMPORT_TEMPLATE.format(rel=rel, mips="true" if kind == "mips" else "false"))


def main() -> None:
    writer = Writer("--check" in sys.argv)
    for god in GODS:
        for name, kind in KINDS.items():
            png = SRC / god / (name + ".png")
            writer.put(OUT / god / png.name, png.read_bytes(), kind)
        theme = json.loads((SRC / god / "theme.json").read_text())
        assert not theme["missing"], (god, theme["missing"])
        writer.put(OUT / god / "envi.tres", envi_tres(theme).encode())
    print("themes: %d written, %d unchanged%s" % (writer.written, writer.kept, " [check]" if writer.check else ""))


if __name__ == "__main__":
    main()
