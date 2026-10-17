#!/usr/bin/env python3
"""F151 (RFC-030 030n-b): does a ring of the Rhinok's spikes read as a ring from above?

Usage: python3 -I agent/tools/f151_bands.py <samples.json> <before.png> <after.png> [dark=0.5]

samples.json comes from agent/harness/pt151_watch.gd samples(): the screen pixels of three bands around the wave's center
(interior, the ring's strip, exterior) for the overhead camera of both captures. A pixel is dark when its luminance
(Rec. 709 on sRGB, 0..1) is under `dark`. The spikes' own share is after - before per band (huts, founts, bodies and the
HUD are in both captures and cancel out). PASS when the strip's share grows more than the interior's and the exterior's.
"""
import json
import sys

from PIL import Image


def shares(path, bands, dark):
    image = Image.open(path).convert("RGB")
    px = image.load()
    out = []
    for points in bands:
        hits = 0
        for x, y in points:
            r, g, b = px[x, y]
            if (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0 < dark:
                hits += 1
        out.append(hits / max(1, len(points)))
    return out


def main():
    if len(sys.argv) < 4:
        print(__doc__)
        sys.exit(2)
    data = json.load(open(sys.argv[1], encoding="utf-8"))
    dark = float(sys.argv[4]) if len(sys.argv) > 4 else 0.5
    bands = data["bands"]
    radii = data.get("radii", [])
    before = shares(sys.argv[2], bands, dark)
    after = shares(sys.argv[3], bands, dark)
    names = ["interior", "franja", "exterior"]
    deltas = []
    for i, points in enumerate(bands):
        name = names[i] if i < len(names) else "banda %d" % i
        span = "%.2f-%.2f m" % (radii[2 * i], radii[2 * i + 1]) if len(radii) > 2 * i + 1 else ""
        deltas.append(after[i] - before[i])
        print("%-9s %-12s %5d px  antes %.4f  después %.4f  púas %+.4f" % (name, span, len(points), before[i], after[i], deltas[i]))
    ok = len(deltas) == 3 and deltas[1] > deltas[0] and deltas[1] > deltas[2]
    print("RESULTADO %s (franja %+.4f, interior %+.4f, exterior %+.4f)" % ("PASS" if ok else "FAIL", deltas[1], deltas[0], deltas[2]))


if __name__ == "__main__":
    main()
