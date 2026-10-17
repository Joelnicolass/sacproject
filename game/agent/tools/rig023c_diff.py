#!/usr/bin/env python3
"""RFC-023 023c: numeric diff of the baked and the skeletal captures of debug/rig023c/rig023c_shots.tscn.

python3 agent/tools/rig023c_diff.py BAKED_DIR SKELETAL_DIR EMPTY_DIR

Per creature column and role: the body is whatever differs from the empty scene; `silhouette` is the share of the
union of both bodies that only one draws, `mean` is the mean channel difference (0-255) over that union.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

TAGS = ["ycro", "amuh", "raeb", "grdg", "mtsl", "saep"]
ROLES = ["idle", "run", "attack", "idle0"]
# The peasant had no clips in the baked cache (a static body), and idle0 only matches where the baked rest is idle0.
SKIP = {("saep", "idle"), ("saep", "run"), ("saep", "attack"), ("saep", "idle0"),
        ("raeb", "idle0"), ("grdg", "idle0"), ("mtsl", "idle0")}
BODY_THRESHOLD = 16
INK_THRESHOLD = 24


def columns(report: Path, width: int):
    """Column limits from the screen x of each creature (report.txt of the harness): halfway between neighbours."""
    xs = {}
    for line in report.read_text().splitlines():
        parts = line.split("\t")
        xs[parts[0]] = float(parts[-1].split("=")[1])
    centers = [xs[t] for t in TAGS]
    edges = [0] + [int((a + b) / 2) for a, b in zip(centers, centers[1:])] + [width]
    return list(zip(edges, edges[1:]))


def load(path):
    return np.asarray(Image.open(path).convert("RGB")).astype(np.int16)


def main():
    baked, skeletal, empty = (Path(a) for a in sys.argv[1:4])
    worst = 0.0
    print("creature\trole\tbody_px\tsilhouette_%\tmean_diff\tink_%")
    for role in ROLES:
        a, b, e = load(baked / f"{role}.png"), load(skeletal / f"{role}.png"), load(empty / f"{role}.png")
        limits = columns(skeletal / "report.txt", a.shape[1])
        for i, tag in enumerate(TAGS):
            if (tag, role) in SKIP:
                continue
            sl = slice(limits[i][0], limits[i][1])
            ma = np.abs(a[:, sl] - e[:, sl]).max(axis=2) > BODY_THRESHOLD
            mb = np.abs(b[:, sl] - e[:, sl]).max(axis=2) > BODY_THRESHOLD
            union = ma | mb
            n = max(int(union.sum()), 1)
            only_one = int((ma ^ mb).sum())
            diff = np.abs(a[:, sl] - b[:, sl])
            mean = float(diff.max(axis=2)[union].mean()) if union.any() else 0.0
            ink = float((diff.max(axis=2)[union] > INK_THRESHOLD).mean() * 100.0) if union.any() else 0.0
            worst = max(worst, only_one / n * 100.0)
            print(f"{tag}\t{role}\t{n}\t{only_one / n * 100.0:.2f}\t{mean:.2f}\t{ink:.2f}")
    print(f"worst silhouette {worst:.2f} %")


main()
