"""Mean luma of a disc (r < r1) and of a ring (r2..r3) around a centre in a PNG, and their ratio.

Usage: python3 light_pool_ratio.py image.png cx cy r1 r2 r3   (pixels)
Used by the 055z V1 check: the night pool of the wizard light must lose >= 35 % of disc/ring and stay >= 1.15.
"""
import sys

from PIL import Image


def mean_luma(img, cx, cy, r_in, r_out):
    w, h = img.size
    px = img.load()
    total = 0.0
    count = 0
    for y in range(max(0, int(cy - r_out)), min(h, int(cy + r_out) + 1)):
        for x in range(max(0, int(cx - r_out)), min(w, int(cx + r_out) + 1)):
            d2 = (x - cx) ** 2 + (y - cy) ** 2
            if r_in * r_in <= d2 < r_out * r_out:
                r, g, b = px[x, y][:3]
                total += 0.2126 * r + 0.7152 * g + 0.0722 * b
                count += 1
    return total / count if count else 0.0


def main():
    if len(sys.argv) != 7:
        sys.exit(__doc__)
    img = Image.open(sys.argv[1]).convert("RGB")
    cx, cy, r1, r2, r3 = (float(a) for a in sys.argv[2:])
    disc = mean_luma(img, cx, cy, 0.0, r1)
    ring = mean_luma(img, cx, cy, r2, r3)
    ratio = disc / ring if ring else float("inf")
    print(f"disc={disc:.3f} ring={ring:.3f} ratio={ratio:.4f}")


main()
