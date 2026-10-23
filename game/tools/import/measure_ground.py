#!/usr/bin/env python3
"""No necesita el juego original: mide PNG ya versionados o capturas.

Measures the colour of the ground against the targets of RFC-059 (Persephone's biome). Two modes.

  Atlas, weighted by a map's tiles (what the ground WOULD look like before light and fog):
    python3 -I tools/import/measure_ground.py --atlas=assets/original/themes/persephone/atlas.png \\
        --weights=assets/original/maps/high_noon/tiles.png
  prints the mean RGB, saturation, value and hue (degrees) of the atlas, each tile counted as many times as the map
  uses it (tiles.png holds the tile id in the R channel).

  Capture (a screenshot of the game with a fixed camera), one box of it:
    python3 -I tools/import/measure_ground.py --png=capture.png --box=x0,y0,x1,y1 [--expect=near|mid|far]
  prints the mean RGB, HSV saturation / value (0..1), hue (degrees) and the % of green pixels (G > 1.15 R and G > 1.3 B).
  With --expect it also prints PASS or FAIL per criterion and exits 1 when one fails:
    near  saturation >= 0.60, value 0.28..0.45, hue 70..95, green >= 80 %      (ground closer than 60 m)
    mid   saturation >= 0.35                                                    (hills)
    far   saturation <= 0.35 and hue >= 120                                     (fog keeps its colour)

Saturation, value and hue are those of the MEAN colour of the box (like the plan's table), not the mean of the pixels' HSV.
"""

import colorsys
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ARGS = {a.split("=", 1)[0]: (a.split("=", 1)[1] if "=" in a else True) for a in sys.argv[1:]}

# name -> list of (label, test(stats), wanted text)
TARGETS = {
    "near": [
        ("saturation", lambda s: s["sat"] >= 0.60, ">= 0.60"),
        ("value", lambda s: 0.28 <= s["val"] <= 0.45, "0.28..0.45"),
        ("hue", lambda s: 70.0 <= s["hue"] <= 95.0, "70..95"),
        ("green %", lambda s: s["green"] >= 80.0, ">= 80"),
    ],
    "mid": [("saturation", lambda s: s["sat"] >= 0.35, ">= 0.35")],
    "far": [
        ("saturation", lambda s: s["sat"] <= 0.35, "<= 0.35"),
        ("hue", lambda s: s["hue"] >= 120.0, ">= 120"),
    ],
}


def hsv_of(rgb) -> dict:
    h, s, v = colorsys.rgb_to_hsv(*(float(c) / 255.0 for c in rgb))
    return {"rgb": [round(float(c), 1) for c in rgb], "sat": round(s, 3), "val": round(v, 3), "hue": round(h * 360.0, 1)}


def atlas_stats(atlas_path: str, weights_path: str) -> dict:
    atlas = np.asarray(Image.open(atlas_path).convert("RGB"), dtype=np.float64)
    size = atlas.shape[0] // 16
    ids = np.asarray(Image.open(weights_path).convert("RGB"))[:, :, 0].ravel()
    counts = np.bincount(ids, minlength=256).astype(np.float64)
    total = 0.0
    acc = np.zeros(3)
    for tile in np.nonzero(counts)[0]:
        y, x = divmod(int(tile), 16)
        acc += atlas[y * size:(y + 1) * size, x * size:(x + 1) * size].reshape(-1, 3).mean(0) * counts[tile]
        total += counts[tile]
    stats = hsv_of(acc / total)
    stats["tiles used"] = int((counts > 0).sum())
    return stats


def box_stats(png_path: str, box: str) -> dict:
    x0, y0, x1, y1 = (int(v) for v in box.split(","))
    pixels = np.asarray(Image.open(png_path).convert("RGB"), dtype=np.float64)[y0:y1, x0:x1].reshape(-1, 3)
    if len(pixels) == 0:
        sys.exit("measure_ground: the box is empty")
    stats = hsv_of(pixels.mean(0))
    r, g, b = pixels[:, 0], pixels[:, 1], pixels[:, 2]
    stats["green"] = round(float(((g > 1.15 * r) & (g > 1.3 * b)).mean()) * 100.0, 1)
    stats["pixels"] = len(pixels)
    return stats


def main() -> int:
    if "--atlas" in ARGS and "--weights" in ARGS:
        for key, value in atlas_stats(str(ARGS["--atlas"]), str(ARGS["--weights"])).items():
            print("%-10s %s" % (key, value))
        return 0
    if "--png" in ARGS and "--box" in ARGS:
        stats = box_stats(str(ARGS["--png"]), str(ARGS["--box"]))
        for key, value in stats.items():
            print("%-10s %s" % (key, value))
        expect = ARGS.get("--expect")
        if expect is None:
            return 0
        if expect not in TARGETS:
            sys.exit("measure_ground: --expect is near, mid or far")
        failed = False
        for label, test, wanted in TARGETS[expect]:
            key = {"saturation": "sat", "value": "val", "hue": "hue", "green %": "green"}[label]
            ok = test(stats)
            failed = failed or not ok
            print("%s  %s %s (wanted %s)" % ("PASS" if ok else "FAIL", label, stats[key], wanted))
        return 1 if failed else 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
