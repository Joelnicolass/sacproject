#!/usr/bin/env python3
"""F126 look criterion: the shield bubble must read at the normal camera distance.
Usage: python3 -I agent/tools/f126_bubble_px.py PNG "Druid1:x0,y0,x1,y1" ["Druid4:..."]   (rects from pt126_watch.report "px")
For each body: mean(B - R) over its screen box (expanded by the bubble: x1.4) minus the same over the ring of neighbouring ground
(box x3 minus box x1.4). Shielded body must be >= +15; unshielded <= 0.
Needs Pillow."""
import sys
from PIL import Image

def mean_br(im, x0, y0, x1, y1, skip=None):
    w, h = im.size
    tot = n = 0
    px = im.load()
    for y in range(max(0, y0), min(h, y1)):
        for x in range(max(0, x0), min(w, x1)):
            if skip and skip[0] <= x < skip[2] and skip[1] <= y < skip[3]:
                continue
            r, g, b = px[x, y][:3]
            tot += b - r
            n += 1
    return tot / n if n else float("nan")

def grow(r, k):
    cx, cy, hw, hh = (r[0] + r[2]) / 2, (r[1] + r[3]) / 2, (r[2] - r[0]) / 2 * k, (r[3] - r[1]) / 2 * k
    return int(cx - hw), int(cy - hh), int(cx + hw), int(cy + hh)

im = Image.open(sys.argv[1]).convert("RGB")
for spec in sys.argv[2:]:
    name, rect = spec.split(":")
    r = tuple(int(v) for v in rect.split(","))
    inner = grow(r, 1.4)
    outer = grow(r, 3.0)
    a = mean_br(im, *inner)
    g = mean_br(im, *outer, skip=inner)
    print("%s box %s  B-R inside %.1f  ground %.1f  delta %.1f" % (name, inner, a, g, a - g))
