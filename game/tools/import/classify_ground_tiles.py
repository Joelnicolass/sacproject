#!/usr/bin/env python3
"""Writes data/look/ground/high_noon_tiles.tres (TileLayerMap) from the average color of each
tile of Persephone's atlas: green = open ground (slot 0, grass), pale grey = the pale rings
and paths (slot 3), in between = the transition tiles around them (slot 2, soil).
Slot numbers are positions in the biome's GroundSet. Correct the result by hand if a tile is wrong.
Usage: python3 tools/import/classify_ground_tiles.py   (run from game/)"""
import numpy as np
from PIL import Image

GRASS, SOIL, PATH, NONE = 0, 2, 3, 255

atlas = np.array(Image.open("assets/original/themes/persephone/atlas.png").convert("RGB")).astype(float)
cell = atlas.shape[0] // 16
slots = []
for tile in range(256):
    px = atlas[(tile // 16) * cell:(tile // 16 + 1) * cell, (tile % 16) * cell:(tile % 16 + 1) * cell].reshape(-1, 3).mean(0)
    r, g, b = px
    if r >= 174.0:
        slots.append(PATH)
    elif r >= 140.0:
        slots.append(SOIL)
    else:
        slots.append(GRASS)

text = f'''[gd_resource type="Resource" script_class="TileLayerMap" load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/look/ground/tile_layer_map.gd" id="1_map"]

[resource]
script = ExtResource("1_map")
slots = PackedByteArray({", ".join(str(s) for s in slots)})
'''
open("data/look/ground/high_noon_tiles.tres", "w").write(text)
print({s: slots.count(s) for s in (GRASS, SOIL, PATH)})
