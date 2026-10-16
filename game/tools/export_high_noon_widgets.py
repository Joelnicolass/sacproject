#!/usr/bin/env python3
"""Export the High Noon widget list (NTTS, ntts.d Widgets) to game/cache/high_noon_widgets.json.

sacengine places these as fixed objects (state.d placeWidgets). Each entry is [x, z, facing]
in Godot axes: sac (x, y) -> Godot (x, z). Reads the local install; the cache is gitignored.
"""

import json
import struct
import sys
from pathlib import Path

from export_high_noon_look import extract

DEFAULT_SCP = "/Users/joelsartori/Downloads/sacgame/Sacrifice/maps/(2) High Noon.scp"
ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUT = ROOT / "cache" / "high_noon_widgets.json"
WIDGETS_TYPE = 8192


def main() -> int:
    scp = Path(sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SCP)
    out = Path(sys.argv[2] if len(sys.argv) > 2 else DEFAULT_OUT)
    ntts = extract(scp, "", "NTTS")
    widgets = {}
    offset = 4
    while offset < len(ntts):
        kind, size = struct.unpack_from("<II", ntts, offset)
        if kind == WIDGETS_TYPE:
            tag = ntts[offset + 8 : offset + 12][::-1].decode("latin1")
            count = struct.unpack_from("<I", ntts, offset + 12)[0]
            rows = widgets.setdefault(tag, [])
            for k in range(count):
                x, y, facing = struct.unpack_from("<fff", ntts, offset + 16 + 12 * k)
                rows.append([round(x, 3), round(y, 3), round(facing, 4)])
        offset += size
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(widgets, separators=(",", ":")))
    print("widgets", {tag: len(rows) for tag, rows in widgets.items()})
    print(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
