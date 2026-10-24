#!/usr/bin/env python3
"""No necesita el juego original: mide PNG (capturas del juego).

How much of a capture is (almost) black: the void under the island and the pits should show the god's picture under the
world (scenes/look/sky/sky_underside), never a black hole.

    python3 -I tools/look/measure_void.py --png=shot.png [--png=other.png ...] [--max-dark=1.0] [--dark=20]

A pixel is dark when its brightest channel is <= --dark (0..255 sRGB). The HUD of a 16:9 capture (spell bar, portrait, mana,
minimap: the boxes in HUD_BOXES, as fractions of the picture) is left out. Prints the dark percentage of each PNG; the
criterion is dark % < --max-dark (default 1.0) on every PNG. Exits 1 when one fails.
"""
import argparse
import sys

from PIL import Image

# (x0, y0, x1, y1) as fractions of the picture: left spell column, bottom-left bar, top-right portrait and bars, minimap.
HUD_BOXES = [(0.0, 0.27, 0.11, 0.72), (0.0, 0.85, 0.35, 1.0), (0.79, 0.0, 1.0, 0.22), (0.84, 0.72, 1.0, 1.0)]


def dark_percent(path: str, dark: int) -> float:
    image = Image.open(path).convert("RGB")
    width, height = image.size
    boxes = [(int(a * width), int(b * height), int(c * width), int(d * height)) for a, b, c, d in HUD_BOXES]
    pixels = image.load()
    counted = 0
    dark_count = 0
    for y in range(height):
        for x in range(width):
            if any(x0 <= x < x1 and y0 <= y < y1 for x0, y0, x1, y1 in boxes):
                continue
            counted += 1
            if max(pixels[x, y]) <= dark:
                dark_count += 1
    return 100.0 * dark_count / max(counted, 1)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--png", action="append", required=True)
    parser.add_argument("--dark", type=int, default=20)
    parser.add_argument("--max-dark", type=float, default=1.0)
    args = parser.parse_args()
    failed = False
    for path in args.png:
        percent = dark_percent(path, args.dark)
        passed = percent < args.max_dark
        failed = failed or not passed
        print("%s dark %.2f %% %s" % (path, percent, "PASS" if passed else "FAIL"))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
