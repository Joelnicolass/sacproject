#!/usr/bin/env python3
"""055s s2 (one-shot migration): puts the hands in the model scenes. Second half of bake_hands_055s.gd.

Reads tools/migrate/hands_055s.json (written by bake_hands_055s.gd: for each model, its hand nodes with bone and offset) and, in
scenes/bodies/models/<model>.tscn:
  - appends, under Model/Skeleton3D, a BoneAttachment3D per hand (hidden: the clips that have the hand show it with a `visible` track)
    with a Marker3D `Socket` at the offset the original gave;
  - removes the `clips = {...}` table (clip tag -> hands) of the root node: the hands are nodes now and BodyModel no longer has it.
Models with no hand only lose the table. Safe to run again.

Usage (from game/):   python3 tools/migrate/write_hands_055s.py [--dry]
"""
import argparse
import glob
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import write_bodies_055s as bodies  # noqa: E402

GAME = bodies.GAME
MODELS = "scenes/bodies/models"
HANDS = "tools/migrate/hands_055s.json"
TABLE = re.compile(r"^clips = \{\n.*?^\}\n(?=\n)", re.S | re.M)


def hand_text(node):
    offset = node["offset"]
    return "\n".join([
        '[node name="%s" type="BoneAttachment3D" parent="Model/Skeleton3D"]' % node["name"],
        "visible = false",
        'bone_name = "%s"' % node["bone"],
        "",
        '[node name="Socket" type="Marker3D" parent="Model/Skeleton3D/%s"]' % node["name"],
        "transform = " + bodies.transform(*offset),
        "",
    ])


def patch(path, nodes, dry):
    text = bodies.read(path)
    out, removed = TABLE.subn("", text, count=1)
    added = 0
    extra = []
    for node in nodes:
        if '[node name="%s" type="BoneAttachment3D"' % node["name"] in out:
            continue
        extra.append(hand_text(node))
        added += 1
    if extra:
        out = out.rstrip("\n") + "\n\n" + "\n".join(extra)
    if not dry and out != text:
        with open(os.path.join(GAME, path), "w", encoding="utf-8", newline="\n") as handle:
            handle.write(out)
    return removed, added


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry", action="store_true")
    args = parser.parse_args()
    if not os.path.exists(os.path.join(GAME, HANDS)):
        sys.exit("%s is missing: run bake_hands_055s.gd with Godot first" % HANDS)
    hands = json.loads(bodies.read(HANDS))
    models = tables = nodes = 0
    for path in sorted(glob.glob(os.path.join(GAME, MODELS, "*.tscn"))):
        model = os.path.basename(path)[:-5]
        removed, added = patch(os.path.relpath(path, GAME), hands.get(model, {}).get("nodes", []), args.dry)
        models += 1
        tables += removed
        nodes += added
    print("HANDS %d models, %d clip tables removed, %d hand nodes added%s" % (models, tables, nodes, " (dry)" if args.dry else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
