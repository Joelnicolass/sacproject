#!/usr/bin/env python3
"""Requiere el juego original instalado (SAC_INSTALL). Ver tools/import/local.cfg.example.

Import the original's ground marks (SCAR resources: burns, cracks, craters, blood) to assets/original/scars/<tag>.png.

RFC-061 (061k-5). One RGBA PNG per SCAR, every one the game ships (19). The game reads them from the effect scenes' ScarMark
nodes (scenes/spells/scar_mark.gd). Writes only assets/original/scars/. Deterministic and idempotent: a second run writes
nothing, and an existing .png.import is never touched (it carries the UID).

  python3 tools/import/import_scars.py            # write
  python3 tools/import/import_scars.py --check    # report what would change, write nothing

Source: every *.wad of the install, filtered by extension SCAR (the folder does not matter), read with tools/import/sac_formats.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from import_ui import IMPORT_TEMPLATE  # noqa: E402
from sac_formats import scar, wad  # noqa: E402
from sac_formats.install import INSTALL  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
ARGS = {a.split("=", 1)[0]: (a.split("=", 1)[1] if "=" in a else True) for a in sys.argv[1:]}
OUT = Path(ARGS.get("--out", ROOT / "assets" / "original" / "scars"))
CHECK = "--check" in ARGS


def main() -> None:
    written = kept = 0
    found = {}
    for path in sorted(INSTALL.glob("*.wad")):
        for _folder, name, ext, raw in wad.walk(path.read_bytes()):
            if ext == "SCAR":
                found.setdefault(name, raw)
    for name, raw in sorted(found.items()):
        data = scar.png_bytes(*scar.decode_scar(raw))
        target = OUT / (name + ".png")
        if target.exists() and target.read_bytes() == data:
            kept += 1
            continue
        written += 1
        if CHECK:
            continue
        OUT.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        imp = target.with_name(target.name + ".import")
        if not imp.exists():
            text = IMPORT_TEMPLATE.format(rel="scars/" + target.name, mips="false")
            imp.write_text(text.replace("compress_to=1", "compress_to=0"))
    print("scars: %d found, %d written, %d unchanged%s" % (len(found), written, kept, " [check]" if CHECK else ""))


if __name__ == "__main__":
    main()
