#!/usr/bin/env python3
"""Measures whether a storm cloud of a match_shots capture (`--views=cloud`) reads as a volume and not as a flat black oval (RFC-061h).

  python3 tools/look/cloud_stats.py shot.png [--box=x0,y0,x1,y1] [--dark=25] [--min-std=5]

The cloud is the dark blob: the pixels darker than `--dark` (0-255 luminance) inside `--box` (default: the upper half of the picture, below the
HUD strips). Three numbers, each with its pass level:
  core_std     standard deviation of the luminance inside the blob (the flat oval: 3.7; lumps, a rim and a lit top: `--min-std` or more)
  fringe       share of the blob's bounding-box width that the edge takes to go from the blob to the sky, averaged over the rows of the blob
               (a smooth disc ~ 0.01-0.03; a frayed edge, where the twenty layers do not agree, > `--min-fringe`)
  edge_rows    how many rows have a ragged edge: the left edge of the blob moves more than 2 px between neighbour rows (a smooth oval moves <= 1)
Exit code 0 when core_std passes (fringe and edge_rows are reported: they move with the sky behind the cloud). The flat black oval of the first
capture of 061h measured core_std 3.7 at `--dark=25`; level 5 asks for a cloud with visible lumps.
"""

import sys

import numpy as np
from PIL import Image

ARGS = {a.split("=", 1)[0]: (a.split("=", 1)[1] if "=" in a else True) for a in sys.argv[2:]}


def main() -> int:
    image = np.asarray(Image.open(sys.argv[1]).convert("RGB")).astype(float)
    lum = image @ np.array([0.2126, 0.7152, 0.0722])
    h, w = lum.shape
    x0, y0, x1, y1 = (int(v) for v in ARGS["--box"].split(",")) if "--box" in ARGS else (int(w * 0.15), int(h * 0.05), int(w * 0.85), int(h * 0.5))
    dark = float(ARGS.get("--dark", 25))
    crop = lum[y0:y1, x0:x1]
    mask = crop < dark
    if mask.sum() < 200:
        print("cloud_stats: no dark blob found (%d px)" % mask.sum())
        return 2
    rows = np.where(mask.any(axis=1))[0]
    cols = np.where(mask.any(axis=0))[0]
    box_w = max(int(cols.max() - cols.min()), 1)
    sky = float(np.median(crop[~mask])) if (~mask).any() else 255.0
    fringes, lefts = [], []
    for r in rows:
        line = crop[r]
        inside = np.where(line < dark)[0]
        if len(inside) < 3:
            continue
        left = int(inside.min())
        lefts.append(left)
        # from the first pixel under `dark` outwards to the sky, how many pixels still sit between the blob and the sky level
        ramp = line[max(left - box_w // 4, 0):left]
        fringes.append(float(np.sum((ramp > dark) & (ramp < sky - 0.15 * (sky - dark)))) / box_w)
    core = crop[mask]
    std = float(core.std())
    fringe = float(np.mean(fringes)) if fringes else 0.0
    ragged = int(np.sum(np.abs(np.diff(lefts)) > 2)) if len(lefts) > 1 else 0
    ok = std >= float(ARGS.get("--min-std", 5))
    print("cloud_stats: blob %d px, box %dx%d, sky %.0f | core_std %.2f | fringe %.3f | edge_rows %d/%d | %s" % (
        int(mask.sum()), box_w, int(rows.max() - rows.min()), sky, std, fringe, ragged, len(lefts), "PASS" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
