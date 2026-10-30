#!/usr/bin/env python3
"""Does not need the original game: it measures PNGs (game captures or references).

Measures two things of a capture of the ground.

  Seams (needs a JSON written next to the PNG by the capture harness: where the 10 m cell borders and
  some lines inside the cells fall in the picture, with the screen normal of each):
    python3 -I tools/import/measure_seams.py --png=shot.png [--grid=shot.json] [--max-ratio=1.2]
  For each sample it reads the luminance along the line's normal at -3..+3 px and keeps the range (max - min): a bright line or a
  step on the border both raise it. ratio = mean range on the borders / mean range on the lines inside the cells (5 % trimmed at
  both ends, so a unit or the HUD over a few samples does not decide). A ground with no seams gives about 1.0; the criterion is
  ratio < --max-ratio (default 1.2). Exits 1 when it fails.

  Sharpness (any PNG or JPG, a reference too):
    python3 -I tools/import/measure_seams.py --png=ref.jpg --sharp [--box=x0,y0,x1,y1] [--width=724] [--min-sharp=N]
  variance of the Laplacian of the luminance inside the box (default: the lower half of the picture, where the near ground is).
  --width first scales the picture to that width (and the box with it), so a 1280 px capture and a 724 px reference compare
  at the same scale. --min-sharp makes it a criterion (exit 1 below it).

Both can run in one call (--png with a grid and --sharp). Luminance is Rec. 709 on the 0..255 sRGB values.
"""

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ARGS = {a.split("=", 1)[0]: (a.split("=", 1)[1] if "=" in a else True) for a in sys.argv[1:]}
OFFSETS_PX = np.arange(-3.0, 3.01, 1.0)
TRIM = 0.05


def luminance(image: Image.Image) -> np.ndarray:
    rgb = np.asarray(image.convert("RGB"), dtype=np.float64)
    return rgb @ np.array([0.2126, 0.7152, 0.0722])


def bilinear(lum: np.ndarray, x: np.ndarray, y: np.ndarray) -> np.ndarray:
    h, w = lum.shape
    x = np.clip(x, 0.0, w - 1.001)
    y = np.clip(y, 0.0, h - 1.001)
    x0, y0 = np.floor(x).astype(int), np.floor(y).astype(int)
    fx, fy = x - x0, y - y0
    top = lum[y0, x0] * (1 - fx) + lum[y0, x0 + 1] * fx
    bottom = lum[y0 + 1, x0] * (1 - fx) + lum[y0 + 1, x0 + 1] * fx
    return top * (1 - fy) + bottom * fy


def ranges(lum: np.ndarray, samples: list, scale: tuple) -> np.ndarray:
    """Luminance range along each sample's normal; `scale` maps the grid's pixels to the picture's (a resized capture)."""
    if not samples:
        return np.zeros(0)
    s = np.asarray(samples, dtype=np.float64)
    px, py = s[:, 0:1] * scale[0], s[:, 1:2] * scale[1]
    nx, ny = s[:, 2:3], s[:, 3:4]
    profile = bilinear(lum, px + nx * OFFSETS_PX, py + ny * OFFSETS_PX)
    return profile.max(axis=1) - profile.min(axis=1)


def trimmed_mean(values: np.ndarray) -> float:
    if values.size == 0:
        return float("nan")
    v = np.sort(values)
    cut = int(v.size * TRIM)
    return float(v[cut: v.size - cut].mean()) if v.size - 2 * cut > 0 else float(v.mean())


def measure_seams(lum: np.ndarray, grid_path: Path) -> bool:
    grid = json.loads(grid_path.read_text())
    gw, gh = grid["size"]
    scale = (lum.shape[1] / gw, lum.shape[0] / gh)
    border = ranges(lum, grid["border"], scale)
    inside = ranges(lum, grid["inside"], scale)
    b, i = trimmed_mean(border), trimmed_mean(inside)
    ratio = b / i if i > 0 else float("inf")
    wanted = float(ARGS.get("--max-ratio", 1.2))
    ok = ratio < wanted
    print("seams: border %.2f (n=%d, median %.2f)  inside %.2f (n=%d, median %.2f)  ratio %.3f  wanted < %.2f  %s" % (
        b, border.size, float(np.median(border)) if border.size else float("nan"),
        i, inside.size, float(np.median(inside)) if inside.size else float("nan"), ratio, wanted, "PASS" if ok else "FAIL"))
    return ok


def laplacian_variance(lum: np.ndarray) -> float:
    lap = lum[1:-1, :-2] + lum[1:-1, 2:] + lum[:-2, 1:-1] + lum[2:, 1:-1] - 4.0 * lum[1:-1, 1:-1]
    return float(lap.var())


def measure_sharpness(image: Image.Image) -> bool:
    width, height = image.size
    box = [int(v) for v in ARGS["--box"].split(",")] if "--box" in ARGS else [0, height // 2, width, height]
    if "--width" in ARGS:
        factor = int(ARGS["--width"]) / width
        image = image.resize((int(ARGS["--width"]), max(1, round(height * factor))), Image.LANCZOS)
        box = [round(v * factor) for v in box]
    lum = luminance(image)[box[1]: box[3], box[0]: box[2]]
    sharp = laplacian_variance(lum)
    line = "sharpness: laplacian variance %.1f in box %s at %dx%d" % (sharp, ",".join(map(str, box)), image.size[0], image.size[1])
    if "--min-sharp" not in ARGS:
        print(line)
        return True
    ok = sharp >= float(ARGS["--min-sharp"])
    print("%s  wanted >= %s  %s" % (line, ARGS["--min-sharp"], "PASS" if ok else "FAIL"))
    return ok


def main() -> int:
    if "--png" not in ARGS:
        print(__doc__)
        return 2
    png = Path(ARGS["--png"])
    image = Image.open(png)
    ok = True
    grid = Path(ARGS.get("--grid", png.with_suffix(".json")))
    if grid.exists():
        ok = measure_seams(luminance(image), grid) and ok
    elif "--grid" in ARGS or "--sharp" not in ARGS:
        print("seams: no grid %s (capture with --views=ground)" % grid)
        ok = False
    if "--sharp" in ARGS:
        ok = measure_sharpness(image) and ok
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
