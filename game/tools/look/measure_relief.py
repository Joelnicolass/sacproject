#!/usr/bin/env python3
"""No necesita el juego original: mide PNG (dos capturas de la misma vista fija).

How much relief a normal map adds (RFC-067 C1, C2, C4). Two captures of the same fixed view: `before` with the maps off and
`after` with them on, plus the screen box of every model (`rects`, written by the capture harness):

    python3 -I tools/look/measure_relief.py --before=before.png --after=after.png --rects=rects.json

Inside each box, the model is every pixel that is not the background colour (in either capture), shrunk by --erode px so the
outline against the background (the same in both) does not count. Per model it prints the mean |laplacian| of the luminance
(4 neighbours, 0..255) and its standard deviation, before and after. Criteria, by the row of the model:
- flat (copies of the materials with no maps): 0 pixels change between before and after (C1);
- product (the real materials, now with maps): the laplacian rises >= --gain (C2) and no pixel turns black (luminance <= 2) that
  was not black before (a NaN draws black);
- effects (StoneLook, BuildReveal over a model with maps): the laplacian rises >= --effects-gain (C4).
Exits 1 when one fails.
"""
import argparse
import json
import sys

import numpy as np
from PIL import Image

BLACK = 2.0


def luminance(rgb: np.ndarray) -> np.ndarray:
    return rgb[..., 0] * 0.2126 + rgb[..., 1] * 0.7152 + rgb[..., 2] * 0.0722


def laplacian(lum: np.ndarray) -> np.ndarray:
    out = np.zeros_like(lum)
    out[1:-1, 1:-1] = np.abs(4.0 * lum[1:-1, 1:-1] - lum[:-2, 1:-1] - lum[2:, 1:-1] - lum[1:-1, :-2] - lum[1:-1, 2:])
    return out


def erode(mask: np.ndarray, px: int) -> np.ndarray:
    out = mask.copy()
    for _ in range(px):
        shrunk = out.copy()
        shrunk[1:, :] &= out[:-1, :]
        shrunk[:-1, :] &= out[1:, :]
        shrunk[:, 1:] &= out[:, :-1]
        shrunk[:, :-1] &= out[:, 1:]
        shrunk[0, :] = shrunk[-1, :] = shrunk[:, 0] = shrunk[:, -1] = False
        out = shrunk
    return out


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--before", required=True)
    parser.add_argument("--after", required=True)
    parser.add_argument("--rects", required=True)
    parser.add_argument("--tol", type=float, default=3.0, help="0..255: how far from the background a model pixel is")
    parser.add_argument("--erode", type=int, default=2)
    parser.add_argument("--gain", type=float, default=0.15)
    parser.add_argument("--effects-gain", type=float, default=0.10)
    args = parser.parse_args()
    before = np.asarray(Image.open(args.before).convert("RGB"), dtype=np.float64)
    after = np.asarray(Image.open(args.after).convert("RGB"), dtype=np.float64)
    with open(args.rects, encoding="utf-8") as handle:
        layout = json.load(handle)
    background = np.array(layout["background"], dtype=np.float64)
    failed = False
    print("%-22s %-8s %8s %8s %8s %8s %8s %8s  %s" % ("model", "row", "pixels", "lap_b", "lap_a", "gain", "std_b", "std_a", "result"))
    for item in layout["items"]:
        x0, y0, x1, y1 = [int(v) for v in item["rect"]]
        x0, y0 = max(0, x0), max(0, y0)
        x1, y1 = min(before.shape[1], x1), min(before.shape[0], y1)
        b = before[y0:y1, x0:x1]
        a = after[y0:y1, x0:x1]
        if b.size == 0:
            print("%-22s %-8s empty box" % (item["name"], item["row"]))
            failed = True
            continue
        model = (np.abs(b - background).max(axis=2) > args.tol) | (np.abs(a - background).max(axis=2) > args.tol)
        inside = erode(model, args.erode)
        count = int(inside.sum())
        lum_b, lum_a = luminance(b), luminance(a)
        lap_b = float(laplacian(lum_b)[inside].mean()) if count else 0.0
        lap_a = float(laplacian(lum_a)[inside].mean()) if count else 0.0
        gain = (lap_a / lap_b - 1.0) if lap_b > 0.0 else 0.0
        row = item["row"]
        if row == "flat":
            changed = int((np.abs(a - b).max(axis=2) > 0.0).sum())
            ok = changed == 0 and count > 0
            result = "C1 %s (%d px changed)" % ("PASS" if ok else "FAIL", changed)
        else:
            new_black = int(((lum_a <= BLACK) & (lum_b > BLACK) & inside).sum())
            want = args.gain if row == "product" else args.effects_gain
            ok = count > 0 and gain >= want and new_black == 0
            result = "%s %s (want +%d%%, %d new black px)" % ("C2" if row == "product" else "C4", "PASS" if ok else "FAIL",
                    round(want * 100), new_black)
        failed = failed or not ok
        std_b = float(lum_b[inside].std()) if count else 0.0
        std_a = float(lum_a[inside].std()) if count else 0.0
        print("%-22s %-8s %8d %8.2f %8.2f %+7.1f%% %8.2f %8.2f  %s" % (item["name"], row, count, lap_b, lap_a, gain * 100.0, std_b,
                std_a, result))
    print("measure_relief: %s" % ("FAIL" if failed else "PASS"))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
