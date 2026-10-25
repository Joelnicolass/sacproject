#!/usr/bin/env python3
"""055c1 / c1-c1: gives every CreatureType and WizardType its `clips` (the AnimationLibrary of its model).

Run it AFTER c1-d is merged (it edits scenes/units/creature_type.gd, scenes/wizards/wizard_type.gd and the 72 + 15 .tres, which c1-d
also touches), when the libraries exist (extract_clips_055c1.py + run_extract_clips_055c1.sh):
  python3 tools/migrate/assign_clips_055c1.py [--root <game dir>] [--dry-run]
Adds `@export var clips: AnimationLibrary` after `model` in both type scripts and, in every .tres, an ext_resource (before the
[resource] section) and `clips = ExtResource("clips_lib")` after the `model = ...` line. Idempotent. Prints what it changed.
"""
import glob
import os
import re
import sys

ARGS = sys.argv[1:]
ROOT = os.path.abspath(ARGS[ARGS.index("--root") + 1]) if "--root" in ARGS else os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DRY = "--dry-run" in ARGS
EXPORT = ('## What the model plays and how long each role lasts (scenes/bodies/models/<model>_clips.tres): the same library the body draws,\n'
          '## read by the rules through ClipFacts.\n@export var clips: AnimationLibrary\n')


def edit_script(rel):
    path = os.path.join(ROOT, rel)
    text = open(path, encoding="utf-8").read()
    if "var clips: AnimationLibrary" in text:
        return 0
    match = re.search(r'^@export var model: String = ""\n', text, re.M)
    if match is None:
        raise SystemExit("%s: no `@export var model` line" % rel)
    text = text[:match.end()] + EXPORT + text[match.end():]
    if not DRY:
        open(path, "w", encoding="utf-8").write(text)
    return 1


def edit_tres(path):
    text = open(path, encoding="utf-8").read()
    if "clips = ExtResource" in text:
        return 0
    model = re.search(r'^model = "([^"]*)"$', text, re.M)
    if model is None or not model.group(1):
        return 0
    library = os.path.join(ROOT, "scenes", "bodies", "models", model.group(1) + "_clips.tres")
    if not os.path.exists(library):
        raise SystemExit("%s: no library %s" % (os.path.basename(path), library))
    ext = '[ext_resource type="AnimationLibrary" path="res://scenes/bodies/models/%s_clips.tres" id="clips_lib"]\n' % model.group(1)
    head, body = text.split("[resource]\n", 1)
    head = head.rstrip("\n") + "\n" + ext + "\n"
    body = body.replace(model.group(0), model.group(0) + '\nclips = ExtResource("clips_lib")', 1)
    if not DRY:
        open(path, "w", encoding="utf-8").write(head + "[resource]\n" + body)
    return 1


changed = edit_script("scenes/units/creature_type.gd") + edit_script("scenes/wizards/wizard_type.gd")
files = 0
for folder in ("creatures", "wizards"):
    for path in sorted(glob.glob(os.path.join(ROOT, "data", "catalog", folder, "*.tres"))):
        files += edit_tres(path)
print("scripts changed: %d, .tres changed: %d%s" % (changed, files, " (dry run)" if DRY else ""))
