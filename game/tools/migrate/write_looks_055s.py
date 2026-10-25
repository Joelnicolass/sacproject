#!/usr/bin/env python3
"""055s s2 (one-shot migration): writes the look scene of every creature and wizard and takes the appearance out of their types.

For each file in data/catalog/creatures/ and data/catalog/wizards/ it writes
    scenes/units/bodies/<name>_look.tscn      (creatures)
    scenes/wizards/bodies/<name>_look.tscn    (wizards)
a BodyLook scene: the model (an instance of scenes/bodies/models/<model>.tscn) or, for the 11 hybrids no clip animates, the static
mesh scenes/bodies/meshes/<model>.res; the `sounds` set and the `carried_fx` scene the type had; and the pose that
BodyCatalog.pose(model, true, skeletal) gave the model, as the transform of the root. Then:
  - the `Look` node of the body scene (scenes/*/bodies/<name>.tscn, written by write_bodies_055s.py) becomes an instance placeholder
    of that look, so loading the body scene does not load the model nor the sounds;
  - the type loses `model`, `sounds` and `carried_fx` (and the ext_resource lines only they used). `model` lives on in the body scene
    (BodyFrame.model_id), so the wire is the same text as always.

Usage (from game/):   python3 tools/migrate/write_looks_055s.py [--dry]
    --dry     print the table and write nothing
Safe to run again: looks are rewritten, a type that no longer has `model =` is only checked.
Run write_bodies_055s.py first (the body scenes), and tools/migrate/bake_hands_055s.gd + write_hands_055s.py for the hands.
"""
import argparse
import glob
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import write_bodies_055s as bodies  # noqa: E402

GAME = bodies.GAME
MODELS = "scenes/bodies/models"
MESHES = "scenes/bodies/meshes"
BODY_SCRIPT = "res://scenes/bodies/body_look.gd"
SIZES = bodies.SIZES
OVERRIDES = bodies.OVERRIDES


def exists(path):
    return os.path.exists(os.path.join(GAME, path))


def vector(raw, fallback=(0.0, 0.0, 0.0)):
    """`Vector3(a, b, c)` or `PackedFloat64Array(a, b, c)` as a tuple of floats."""
    found = re.search(r"\((.*)\)", raw or "")
    if not found or not found.group(1).strip():
        return fallback
    return tuple(float(part) for part in found.group(1).split(","))


def load_poses():
    """The inputs of BodyCatalog.pose for every model: upright_fix, foot_offset, pose_source and the hand correction."""
    sizes = {}
    for path in sorted(glob.glob(os.path.join(GAME, SIZES, "*.tres"))):
        found = bodies.fields(open(path, encoding="utf-8").read().split("[resource]", 1)[1])
        sizes[bodies.text_of(found["tag"])] = {
            "upright": vector(found.get("upright_fix")),
            "foot": float(found.get("foot_offset", "0")),
            "source": bodies.text_of(found.get("pose_source", '""')),
        }
    corrections = {}
    for block in bodies.read(OVERRIDES).split("[sub_resource ")[1:]:
        found = bodies.fields(block)
        if "model" in found:
            corrections[bodies.text_of(found["model"])] = {
                "turn": vector(found.get("rotation_degrees")), "at": vector(found.get("position_offset"))}
    return sizes, corrections


def matrix(turn_deg):
    """Basis.from_euler(turn, YXZ) as rows (Y * X * Z)."""
    x, y, z = (math.radians(v) for v in turn_deg)
    cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
    rx = ((1, 0, 0), (0, cx, -sx), (0, sx, cx))
    ry = ((cy, 0, sy), (0, 1, 0), (-sy, 0, cy))
    rz = ((cz, -sz, 0), (sz, cz, 0), (0, 0, 1))

    def mul(a, b):
        return tuple(tuple(sum(a[r][k] * b[k][c] for k in range(3)) for c in range(3)) for r in range(3))
    return mul(mul(ry, rx), rz)


def pose(model, sizes, corrections, skeletal):
    """BodyCatalog.pose(model, stand_on_feet = true, skeletal): (rows, origin), or None when it is the identity."""
    data = sizes[model]
    bind_fix = not (skeletal and not data["source"])
    turn = list(data["upright"]) if bind_fix else [0.0, 0.0, 0.0]
    at = [0.0, 0.0, 0.0]
    entry = corrections.get(model)
    if entry:
        turn = [a + b for a, b in zip(turn, entry["turn"])]
        at = list(entry["at"])
    if bind_fix:
        at[1] += data["foot"]
    if all(abs(v) < 1e-9 for v in turn + at):
        return None
    return matrix(turn), at


def number(value):
    text = "%.6f" % value
    text = text.rstrip("0").rstrip(".")
    return "0" if text in ("", "-0") else text


def transform_text(rows, origin):
    flat = [rows[r][c] for r in range(3) for c in range(3)] + list(origin)
    return "Transform3D(%s)" % ", ".join(number(v) for v in flat)


def type_info(path):
    """model, the ext_resource path of `sounds` and of `carried_fx` (None without one) from a type .tres."""
    text = bodies.read(path)
    ext = {m.group(2): m.group(1) for m in re.finditer(r'\[ext_resource [^\]]*path="(res://[^"]+)" id="([^"]+)"\]', text)}
    found = bodies.fields(text.split("[resource]", 1)[1])

    def target(key):
        raw = found.get(key)
        match = re.match(r'ExtResource\("([^"]+)"\)', raw or "")
        return ext.get(match.group(1)) if match else None
    return bodies.text_of(found["model"]) if "model" in found else None, target("sounds"), target("carried_fx")


def look_text(stem, model, sounds, carried, placed):
    skeletal = exists("%s/%s.tscn" % (MODELS, model))
    refs = [('Script', BODY_SCRIPT, "1_look")]
    if skeletal:
        refs.append(("PackedScene", "res://%s/%s.tscn" % (MODELS, model), "2_model"))
    else:
        refs.append(("Mesh", "res://%s/%s.res" % (MESHES, model), "2_mesh"))
    if sounds:
        refs.append(("Resource", sounds, "3_sounds"))
    if carried:
        refs.append(("PackedScene", carried, "4_fx"))
    lines = ["[gd_scene load_steps=%d format=3]" % (len(refs) + 1), ""]
    lines += ['[ext_resource type="%s" path="%s" id="%s"]' % ref for ref in refs]
    lines.append("")
    head = '[node name="%sLook" type="Node3D"' % bodies.pascal(stem)
    if skeletal:
        head += ' node_paths=PackedStringArray("model")'
    lines.append(head + "]")
    if placed:
        lines.append("transform = " + transform_text(*placed))
    lines.append('script = ExtResource("1_look")')
    if skeletal:
        lines.append('model = NodePath("Model")')
    else:
        lines.append('static_mesh = ExtResource("2_mesh")')
    if sounds:
        lines.append('sounds = ExtResource("3_sounds")')
    if carried:
        lines.append('carried_fx = ExtResource("4_fx")')
    if skeletal:
        lines += ["", '[node name="Model" parent="." instance=ExtResource("2_model")]']
    return "\n".join(lines) + "\n"


def patch_body_scene(scene_path, look_res):
    """The `Look` node of a body scene becomes an instance placeholder of its look. False when it already is."""
    text = bodies.read(scene_path)
    plain = '[node name="Look" type="Node3D" parent="."]'
    holder = '[node name="Look" parent="." instance_placeholder="%s"]' % look_res
    if holder in text:
        return False
    if plain not in text:
        sys.exit("%s: no plain Look node to turn into a placeholder (run write_bodies_055s.py first)" % scene_path)
    with open(os.path.join(GAME, scene_path), "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text.replace(plain, holder))
    return True


def patch_type(type_path):
    """Removes `model`, `sounds` and `carried_fx` from a type .tres and the ext_resource lines only they used."""
    text = bodies.read(type_path)
    lines = text.split("\n")
    drop_ids = set()
    kept = []
    for line in lines:
        match = re.match(r"^(model|sounds|carried_fx) = (.*)$", line)
        if match:
            ref = re.match(r'ExtResource\("([^"]+)"\)', match.group(2))
            if ref:
                drop_ids.add(ref.group(1))
            continue
        kept.append(line)
    body = "\n".join(kept)
    removed = 0
    for ext_id in drop_ids:
        if body.count('ExtResource("%s")' % ext_id) == 0:
            body, count = re.subn(r'\[ext_resource [^\]]*id="%s"\]\n' % re.escape(ext_id), "", body)
            removed += count
    head = re.match(r"\[gd_resource (.*?)load_steps=(\d+)(.*?)\]", body)
    if head:
        steps = int(head.group(2)) - removed
        body = body.replace(head.group(0), "[gd_resource %sload_steps=%d%s]" % (head.group(1), steps, head.group(3)), 1)
    with open(os.path.join(GAME, type_path), "w", encoding="utf-8", newline="\n") as handle:
        handle.write(body)
    return body != text


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry", action="store_true")
    args = parser.parse_args()
    sizes, corrections = load_poses()
    written = patched = 0
    bad = []
    for _kind, type_dir, scene_dir, _wizard in bodies.KINDS:
        for path in sorted(glob.glob(os.path.join(GAME, type_dir, "*.tres"))):
            stem = os.path.basename(path)[:-5]
            type_path = os.path.relpath(path, GAME)
            model, sounds, carried = type_info(type_path)
            look_file = "%s/%s_look.tscn" % (scene_dir, stem)
            if model is None:
                if not exists(look_file):
                    bad.append("%s: the type has no `model` and there is no look" % stem)
                continue
            if model not in sizes:
                sys.exit("%s: model %s has no body_sizes file" % (stem, model))
            skeletal = exists("%s/%s.tscn" % (MODELS, model))
            if not skeletal and not exists("%s/%s.res" % (MESHES, model)):
                bad.append("%s: model %s has neither a scene nor a mesh" % (stem, model))
                continue
            placed = pose(model, sizes, corrections, skeletal)
            print("%-22s %-5s %-8s %s%s%s" % (stem, model, "model" if skeletal else "mesh", "sounds " if sounds else "",
                                              "fx " if carried else "", "pose" if placed else ""))
            written += 1
            if args.dry:
                continue
            with open(os.path.join(GAME, look_file), "w", encoding="utf-8", newline="\n") as handle:
                handle.write(look_text(stem, model, sounds, carried, placed))
            patch_body_scene("%s/%s.tscn" % (scene_dir, stem), "res://" + look_file)
            if patch_type(type_path):
                patched += 1
    print("LOOKS %d scenes, %d types patched%s" % (written, patched, " (dry)" if args.dry else ""))
    for line in bad:
        print("DIFF " + line)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
