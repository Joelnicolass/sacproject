#!/usr/bin/env python3
"""Proposes a biome's GrassPalette from the color of its original ground (RFC-022e §11, 022e4b).

Ground color = mean of the slot-0 tiles (grass tiles of data/look/ground/high_noon_tiles.tres) of the
god's atlas (assets/original/themes/<god>/atlas.png), weighted by how often each tile is used on the map
(R channel of assets/original/maps/high_noon/tiles.png). The palette is that color moved by the same HSV transfer that
takes Persephone's ground to meadow.tres (hue offset, saturation and value gains), with a saturation
cap. Self-check: on Persephone the proposal must equal meadow within 0.02 per channel.

Known limit: Persephone's saturation gain is ~2.6x (meadow is much greener than its ground), so on warm
grounds (Pyro, James, Charnel) the proposal comes out far too saturated, near pure orange, even under the
default cap. There, start from the approved Pyro palette's ratios to its ground instead and tune by hand;
the shipped James, Stratos and Charnel palettes were tuned against the grass bench (grass vs grass-off ground,
in sun and in shadow, agent/flows/rfc022e4b_shade_<god>.json), not taken from this proposal.

The proposal is a starting point: tune the written .tres by hand in the inspector against a capture.
--write only replaces color_mid and color_tip; every other field of an existing palette is kept.

Usage (from game/):
  python3 tools/import/sample_grass_palette.py <god> [<god> ...] [--write] [--sat-cap 0.9]
"""
import argparse
import colorsys
import os
import re

import numpy as np
from PIL import Image

MEADOW_MID = (0.28, 0.55, 0.08)  # data/look/grass/types/meadow.tres (Persephone's look, approved)
MEADOW_TIP = (0.55, 0.8, 0.2)
GRASS_SLOT = 0


def grass_slot_tiles() -> list:
    text = open("data/look/ground/high_noon_tiles.tres").read()
    slots = [int(s) for s in re.search(r"PackedByteArray\(([^)]*)\)", text).group(1).split(",")]
    return [tile for tile, slot in enumerate(slots) if slot == GRASS_SLOT]


def ground_color(god: str, tiles: list) -> tuple:
    atlas = np.asarray(Image.open(f"assets/original/themes/{god}/atlas.png").convert("RGB"), dtype=float) / 255.0
    cell = atlas.shape[0] // 16
    use = np.bincount(np.asarray(Image.open("assets/original/maps/high_noon/tiles.png").convert("RGB"))[..., 0].ravel(), minlength=256)
    total = np.zeros(3)
    weight = 0.0
    for tile in tiles:
        if use[tile] == 0:
            continue
        row, col = divmod(tile, 16)
        mean = atlas[row * cell:(row + 1) * cell, col * cell:(col + 1) * cell].reshape(-1, 3).mean(0)
        total += mean * use[tile]
        weight += use[tile]
    return tuple(total / weight)


def transfer(ground: tuple, ref_ground: tuple, ref: tuple, sat_cap: float) -> tuple:
    gh, gs, gv = colorsys.rgb_to_hsv(*ground)
    rh, rs, rv = colorsys.rgb_to_hsv(*ref_ground)
    th, ts, tv = colorsys.rgb_to_hsv(*ref)
    h = (gh + (th - rh)) % 1.0
    s = min(gs * ts / rs, sat_cap)
    v = min(gv * tv / rv, 1.0)
    return colorsys.hsv_to_rgb(h, s, v)


def fmt(c: tuple) -> str:
    return "Color(%.3g, %.3g, %.3g, 1)" % tuple(round(x, 3) for x in c)


def write_palette(god: str, mid: tuple, tip: tuple) -> str:
    path = f"data/look/grass/palettes/{god}.tres"
    if os.path.exists(path):
        text = open(path).read()
        text = re.sub(r"color_mid = Color\([^)]*\)", "color_mid = " + fmt(mid), text)
        text = re.sub(r"color_tip = Color\([^)]*\)", "color_tip = " + fmt(tip), text)
    else:
        text = ('[gd_resource type="Resource" script_class="GrassPalette" load_steps=2 format=3]\n\n'
                '[ext_resource type="Script" path="res://scenes/look/grass/grass_palette.gd" id="1_p"]\n\n'
                '[resource]\nscript = ExtResource("1_p")\n'
                f"color_mid = {fmt(mid)}\ncolor_tip = {fmt(tip)}\n")
    open(path, "w").write(text)
    return path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("gods", nargs="+")
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--sat-cap", type=float, default=0.9)
    args = parser.parse_args()
    tiles = grass_slot_tiles()
    ref_ground = ground_color("persephone", tiles)
    check_mid = transfer(ref_ground, ref_ground, MEADOW_MID, args.sat_cap)
    check_tip = transfer(ref_ground, ref_ground, MEADOW_TIP, args.sat_cap)
    err = max(abs(a - b) for a, b in zip(check_mid + check_tip, MEADOW_MID + MEADOW_TIP))
    print("self-check persephone -> meadow: max error %.4f %s" % (err, "OK" if err <= 0.02 else "FAIL"))
    if err > 0.02:
        raise SystemExit(1)
    for god in args.gods:
        ground = ground_color(god, tiles)
        mid = transfer(ground, ref_ground, MEADOW_MID, args.sat_cap)
        tip = transfer(ground, ref_ground, MEADOW_TIP, args.sat_cap)
        hexc = "#%02x%02x%02x" % tuple(int(round(x * 255)) for x in ground)
        print(f"{god}: ground {hexc}  color_mid = {fmt(mid)}  color_tip = {fmt(tip)}")
        if args.write:
            print("  wrote", write_palette(god, mid, tip))


if __name__ == "__main__":
    main()
