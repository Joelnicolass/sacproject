"""RFC-067 P6: how speckled (mottled) and how deep a normal map is, inside the solid texels of its albedo.

    python3 -I agent/harness/measure_mottle.py --albedo=<albedo.png> <normal.png>...

relief = mean tilt of the normal, |n.xy| (0 = flat).
mottle = mean |n.xy - its 3x3 box average|: the texel-to-texel noise that reads as speckle when the picture is magnified.
Both over the texels whose albedo alpha is >= 0.5 (every texel when the albedo has no alpha). No numpy needed.
"""
import sys
from PIL import Image


def _vec(img):
    w, h = img.size
    px = img.convert("RGB").load()
    return w, h, [[((px[x, y][0] / 127.5) - 1.0, (px[x, y][1] / 127.5) - 1.0) for x in range(w)] for y in range(h)]


def measure(normal_path, mask):
    w, h, n = _vec(Image.open(normal_path))
    tilt = noise = 0.0
    count = 0
    for y in range(h):
        for x in range(w):
            if mask is not None and not mask[y][x]:
                continue
            sx = sy = 0.0
            k = 0
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    xx, yy = min(max(x + dx, 0), w - 1), min(max(y + dy, 0), h - 1)
                    sx += n[yy][xx][0]
                    sy += n[yy][xx][1]
                    k += 1
            nx, ny = n[y][x]
            tilt += (nx * nx + ny * ny) ** 0.5
            noise += ((nx - sx / k) ** 2 + (ny - sy / k) ** 2) ** 0.5
            count += 1
    return tilt / max(count, 1), noise / max(count, 1)


def main():
    albedo = None
    normals = []
    for arg in sys.argv[1:]:
        if arg.startswith("--albedo="):
            albedo = arg.split("=", 1)[1]
        else:
            normals.append(arg)
    mask = None
    if albedo:
        a = Image.open(albedo).convert("RGBA")
        alpha = a.getchannel("A").load()
        mask = [[alpha[x, y] >= 128 for x in range(a.width)] for y in range(a.height)]
    print("%-40s %8s %8s %8s" % ("normal", "relief", "mottle", "ratio"))
    for path in normals:
        relief, mottle = measure(path, mask)
        print("%-40s %8.4f %8.4f %8.3f" % (path.split("/")[-1], relief, mottle, mottle / max(relief, 1e-6)))


if __name__ == "__main__":
    main()
