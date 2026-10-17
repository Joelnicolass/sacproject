#!/usr/bin/env python3
"""RFC-033: capture comparison with a measured noise floor (particles and sky dust are not seeded, so two runs
of the same build differ).

  rfc033_diff.py floor <run_a> <run_b> [<run_c> ...]
      Pairwise diffs between runs of the SAME build. Per capture: the largest pairwise count of pixels with a channel
      delta > 2/255 (the floor), and how many pixels are identical in every run (the stable pixels).
  rfc033_diff.py check <after> <run_a> <run_b> [<run_c> ...] [--out <dir>]
      The after-run against each base run. Per capture: the largest count of pixels with delta > 2/255 (to compare with
      the floor), and the changes on the stable pixels (identical across the base runs), where noise cannot hide a change.

Runs are folder names under agent/out/033/ or paths. Counts are pixels of 1280x720 (921600).
"""
import itertools
import sys
from pathlib import Path

import numpy as np
from PIL import Image

OUT_ROOT = Path(__file__).resolve().parents[1] / "out" / "033"


def folder(name):
    p = Path(name)
    return p if p.exists() else OUT_ROOT / name


def load(p):
    return np.asarray(Image.open(p).convert("RGB"), dtype=np.int16)


def delta(a, b):
    return np.abs(a - b).max(axis=2)


def main():
    args = sys.argv[1:]
    mode = args.pop(0)
    out = None
    if "--out" in args:
        i = args.index("--out")
        out = Path(args[i + 1])
        del args[i:i + 2]
    after = folder(args.pop(0)) if mode == "check" else None
    runs = [folder(a) for a in args]
    names = sorted(p.name for p in runs[0].glob("*.png"))
    head = "%-26s %9s %9s %9s %9s %9s" % ("capture", "floor>2", "floor max", "stable px", "after>2", "stable chg") if mode == "check" else "%-26s %9s %9s %9s" % ("capture", "floor>2", "floor max", "stable px")
    print(head)
    for name in names:
        imgs = [load(r / name) for r in runs]
        floor_n, floor_max = 0, 0
        for a, b in itertools.combinations(imgs, 2):
            d = delta(a, b)
            floor_n = max(floor_n, int((d > 2).sum()))
            floor_max = max(floor_max, int(d.max()))
        stable = np.ones(imgs[0].shape[:2], bool)
        for b in imgs[1:]:
            stable &= delta(imgs[0], b) == 0
        if mode == "floor":
            print("%-26s %9d %9d %9d" % (name, floor_n, floor_max, int(stable.sum())))
            continue
        img = load(after / name)
        n2 = max(int((delta(img, b) > 2).sum()) for b in imgs)
        dmax = max(int(delta(img, b).max()) for b in imgs)
        chg = delta(img, imgs[0])[stable]
        print("%-26s %9d %9d %9d %9d %5d(>0) %d(>2) max %d  [after max delta %d]" % (
            name, floor_n, floor_max, int(stable.sum()), n2, int((chg > 0).sum()), int((chg > 2).sum()), int(chg.max()) if chg.size else 0, dmax))
        if out:
            out.mkdir(parents=True, exist_ok=True)
            ov = (imgs[0] // 4).astype(np.uint8)
            ov[(delta(img, imgs[0]) > 2) & stable] = (255, 0, 255)
            Image.fromarray(ov).save(out / name)


if __name__ == "__main__":
    main()
