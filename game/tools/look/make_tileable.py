#!/usr/bin/env python3
"""Makes a PNG tile horizontally, for the sky bands (and any other texture that wraps around).

Usage:
    python3 tools/look/make_tileable.py INPUT.png [OUTPUT.png] [--width 0.25]

Writes OUTPUT (default: INPUT's name + "_tileable.png" next to it). The classic cross-fade: the last `--width` of the
image (default 25 %) is blended into the first `--width`, and the image loses that many columns, so the last column is
followed by the column that used to precede the blended strip and u = 0 meets u = 1 with no seam. The rows are not
touched (the sky bands clamp the top and bottom edges). Alpha is blended premultiplied, so a transparent edge does not
drag its meaningless colour in.
Needs Pillow and numpy.
"""
import argparse
import sys

import numpy as np
from PIL import Image


def make_tileable(pixels: np.ndarray, width: float) -> np.ndarray:
    """pixels: height x width x channels float array. Returns the same height and `n` fewer columns."""
    w = pixels.shape[1]
    n = min(max(1, int(round(w * width))), w // 2)
    out = pixels[:, : w - n].copy()
    for i in range(n):
        t = i / n
        t = t * t * (3.0 - 2.0 * t)
        # Column i sits n - i... columns after the cut; blend it with the strip that ended the image.
        out[:, i] = pixels[:, w - n + i] * (1.0 - t) + pixels[:, i] * t
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("input")
    parser.add_argument("output", nargs="?")
    parser.add_argument("--width", type=float, default=0.25, help="fraction of the width to cross-fade (default 0.25)")
    args = parser.parse_args()
    output = args.output or args.input.rsplit(".", 1)[0] + "_tileable.png"
    data = np.asarray(Image.open(args.input).convert("RGBA"), dtype=np.float64)
    alpha = data[:, :, 3:4] / 255.0
    premultiplied = np.concatenate([data[:, :, :3] * alpha, data[:, :, 3:4]], axis=2)
    blended = make_tileable(premultiplied, args.width)
    a = blended[:, :, 3:4]
    rgb = blended[:, :, :3] / np.maximum(a / 255.0, 1e-6)
    result = np.concatenate([np.clip(rgb, 0, 255), np.clip(a, 0, 255)], axis=2).round().astype(np.uint8)
    Image.fromarray(result, "RGBA").save(output)
    print(f"{args.input} -> {output} ({data.shape[1]} -> {result.shape[1]} px wide, cross-fade {args.width:.0%})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
