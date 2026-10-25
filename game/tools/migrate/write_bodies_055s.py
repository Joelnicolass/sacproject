#!/usr/bin/env python3
"""055s s1 (one-shot migration): writes the body scene of every creature and wizard and points each type at it.

For each file in data/catalog/creatures/ and data/catalog/wizards/ it writes
    scenes/units/bodies/<name>.tscn      (creatures)
    scenes/wizards/bodies/<name>.tscn    (wizards)
a BodyFrame scene: Bounds/Capsule (+ FlyingCapsule for a hybrid flier), Bounds/Footprint, Sockets/Reach|Center|Top
(+ Muzzle and Feet for wizards) and an empty Look. Then it adds `body = ExtResource(...)` to the type's .tres.

The numbers are the ones BodyCatalog.info(model) gives today, computed here from the same text files (no Godot needed):
    data/catalog/body_sizes/<model>.tres  +  data/bodies/pose_overrides.tres  (BodyCatalog.info, body_catalog.gd:72-93)
The capsule keeps the rule BodyCollider had: height >= 0.6, radius <= 0.45 of the ground height (units: the height as a double;
wizards and the Sac Doctor: the height as the float32 the shape stores, as wizard_body._fit_shape and doctor_body did).
The wizard Muzzle is (UP * h * 0.65).y and reach, computed with 32-bit floats like Godot does. Every value is written with the
shortest text that parses to the same 32-bit float the engine keeps, so the scene holds exactly what the code used to compute.

Usage (from game/):   python3 tools/migrate/write_bodies_055s.py [--dry] [--check]
    --dry     print the table and write nothing
    --check   after writing (or with --dry), re-read the scenes and compare them with the table; exit 1 on any difference
Safe to run again: scenes are rewritten, types that already have `body =` are left alone.
"""
import argparse
import glob
import os
import re
import struct
import sys

GAME = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SIZES = "data/catalog/body_sizes"
OVERRIDES = "data/bodies/pose_overrides.tres"
KINDS = (
    ("creatures", "data/catalog/creatures", "scenes/units/bodies", False),
    ("wizards", "data/catalog/wizards", "scenes/wizards/bodies", True),
)
MIN_CAPSULE_M = 0.6
RADIUS_PER_HEIGHT = 0.45
HAND_FRACTION = 0.65
BODY_ID = "body_scene"


def f32(x):
    """The 32-bit float Godot keeps for a value, as a Python float."""
    return struct.unpack("<f", struct.pack("<f", x))[0]


def num(x):
    """Shortest text that parses to the same 32-bit float, always with a decimal point."""
    value = f32(x)
    text = repr(value)
    for digits in range(1, 10):
        text = "%.*g" % (digits, value)
        if f32(float(text)) == value:
            break
    if "e" in text or "E" in text:
        text = repr(float(text))
    if "." not in text:
        text += ".0"
    return text


def read(path):
    with open(os.path.join(GAME, path), encoding="utf-8") as handle:
        return handle.read()


def fields(block):
    """`key = value` lines of a .tres block as {key: raw text}."""
    out = {}
    for line in block.splitlines():
        match = re.match(r"^([A-Za-z_][A-Za-z0-9_/]*) = (.*)$", line)
        if match:
            out[match.group(1)] = match.group(2).strip()
    return out


def text_of(raw):
    return raw.strip('"')


def load_sizes():
    sizes = {}
    for path in sorted(glob.glob(os.path.join(GAME, SIZES, "*.tres"))):
        block = open(path, encoding="utf-8").read().split("[resource]", 1)[1]
        found = fields(block)
        sizes[text_of(found["tag"])] = {
            "height": float(found.get("height", "0")),
            "radius": float(found.get("radius", "0")),
            "reach": float(found.get("reach", "0")),
        }
    return sizes


def load_overrides():
    overrides = {}
    for block in read(OVERRIDES).split("[sub_resource ")[1:]:
        found = fields(block)
        if "model" not in found:
            continue
        scale = found.get("model_scale", "Vector3(1, 1, 1)")
        if scale.replace(" ", "") != "Vector3(1,1,1)":
            sys.exit("model_scale other than 1 is not supported by this migration: " + found["model"])
        overrides[text_of(found["model"])] = {
            "height": float(found.get("capsule_height", "0")),
            "flying": float(found.get("capsule_height_flying", "0")),
            "radius": float(found.get("capsule_radius", "0")),
            "reach": float(found.get("reach", "0")),
        }
    return overrides


def info(model, sizes, overrides):
    """BodyCatalog.info(model): the baked size with the hand corrections on top (all scales are 1 here)."""
    base = sizes[model]
    entry = overrides.get(model)
    height, radius, reach = base["height"], base["radius"], base["reach"]
    flying = 0.0
    if entry:
        height = entry["height"] if entry["height"] > 0.0 else height
        radius = entry["radius"] if entry["radius"] > 0.0 else radius
        reach = entry["reach"] if entry["reach"] > 0.0 else reach
        flying = entry["flying"]
    return {"height": height, "radius": radius, "reach": reach, "flying": flying if flying > 0.0 else None}


def derive(raw, shape_height_is_f32):
    """Everything the scene stores for one body, from the raw info."""
    height, radius, reach = raw["height"], raw["radius"], raw["reach"]
    ground = max(height, MIN_CAPSULE_M)
    ground_for_radius = f32(ground) if shape_height_is_f32 else ground
    capsule_radius = min(radius, ground_for_radius * RADIUS_PER_HEIGHT)
    out = {
        "height": height, "radius": radius, "reach": reach,
        "capsule_height": ground, "capsule_radius": capsule_radius,
        "flying_height": None,
        "center_y": height * 0.5, "top_y": height,
        "muzzle_y": f32(f32(height) * f32(HAND_FRACTION)), "muzzle_z": reach,
    }
    if raw["flying"] is not None:
        out["flying_height"] = max(raw["flying"], MIN_CAPSULE_M)
    return out


def pascal(stem):
    return "".join(part.capitalize() for part in re.split(r"[_\- ]+", stem))


def transform(x, y, z):
    return "Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)" % (num(x), num(y), num(z))


def scene_text(stem, model, values, wizard):
    flying = values["flying_height"]
    paths = ["capsule"] + (["flying_capsule"] if flying is not None else []) + [
        "footprint", "reach", "center", "top"] + (["muzzle", "feet"] if wizard else []) + ["look"]
    lines = [
        "[gd_scene load_steps=%d format=3]" % (3 + (1 if flying is not None else 0) + 1),
        "",
        '[ext_resource type="Script" path="res://scenes/bodies/body_frame.gd" id="1_frame"]',
        "",
        '[sub_resource type="CapsuleShape3D" id="Capsule_ground"]',
        "radius = " + num(values["capsule_radius"]),
        "height = " + num(values["capsule_height"]),
        "",
    ]
    if flying is not None:
        lines += [
            '[sub_resource type="CapsuleShape3D" id="Capsule_air"]',
            "radius = " + num(values["capsule_radius"]),
            "height = " + num(flying),
            "",
        ]
    lines += [
        '[sub_resource type="CylinderShape3D" id="Cylinder_footprint"]',
        "height = " + num(values["height"]),
        "radius = " + num(values["radius"]),
        "",
        '[node name="%s" type="Node3D" node_paths=PackedStringArray(%s)]' % (pascal(stem), ", ".join('"%s"' % p for p in paths)),
        'script = ExtResource("1_frame")',
        'model_id = "%s"' % model,
        'capsule = NodePath("Bounds/Capsule")',
    ]
    if flying is not None:
        lines.append('flying_capsule = NodePath("Bounds/FlyingCapsule")')
    lines += ['footprint = NodePath("Bounds/Footprint")', 'reach = NodePath("Sockets/Reach")', 'center = NodePath("Sockets/Center")',
              'top = NodePath("Sockets/Top")']
    if wizard:
        lines += ['muzzle = NodePath("Sockets/Muzzle")', 'feet = NodePath("Sockets/Feet")']
    lines += [
        'look = NodePath("Look")',
        "",
        '[node name="Bounds" type="Area3D" parent="."]',
        "collision_layer = 0",
        "collision_mask = 0",
        "monitoring = false",
        "monitorable = false",
        "",
        '[node name="Capsule" type="CollisionShape3D" parent="Bounds"]',
        "transform = " + transform(0, values["capsule_height"] * 0.5, 0),
        'shape = SubResource("Capsule_ground")',
        "",
    ]
    if flying is not None:
        lines += [
            '[node name="FlyingCapsule" type="CollisionShape3D" parent="Bounds"]',
            "transform = " + transform(0, flying * 0.5, 0),
            'shape = SubResource("Capsule_air")',
            "disabled = true",
            "",
        ]
    lines += [
        '[node name="Footprint" type="CollisionShape3D" parent="Bounds"]',
        "transform = " + transform(0, values["height"] * 0.5, 0),
        'shape = SubResource("Cylinder_footprint")',
        "",
        '[node name="Sockets" type="Node3D" parent="."]',
        "",
        '[node name="Reach" type="Marker3D" parent="Sockets"]',
        "transform = " + transform(0, 0, values["reach"]),
        "",
        '[node name="Center" type="Marker3D" parent="Sockets"]',
        "transform = " + transform(0, values["center_y"], 0),
        "",
        '[node name="Top" type="Marker3D" parent="Sockets"]',
        "transform = " + transform(0, values["top_y"], 0),
        "",
    ]
    if wizard:
        lines += [
            '[node name="Muzzle" type="Marker3D" parent="Sockets"]',
            "transform = " + transform(0, values["muzzle_y"], values["muzzle_z"]),
            "",
            '[node name="Feet" type="Marker3D" parent="Sockets"]',
            "",
        ]
    lines += ['[node name="Look" type="Node3D" parent="."]', ""]
    return "\n".join(lines)


def patch_type(type_path, scene_path):
    """Adds the ext_resource and the `body =` line to a type .tres. Returns False when it already has one."""
    text = read(type_path)
    if re.search(r"^body = ", text, re.M):
        return False
    ext_line = '[ext_resource type="PackedScene" path="res://%s" id="%s"]' % (scene_path, BODY_ID)
    lines = text.split("\n")
    last_ext = max(i for i, line in enumerate(lines) if line.startswith("[ext_resource"))
    lines.insert(last_ext + 1, ext_line)
    at = next(i for i, line in enumerate(lines) if line.startswith("model = "))
    lines.insert(at + 1, 'body = ExtResource("%s")' % BODY_ID)
    head = re.match(r"\[gd_resource (.*?)load_steps=(\d+)(.*)\]", lines[0])
    if head:
        lines[0] = "[gd_resource %sload_steps=%d%s]" % (head.group(1), int(head.group(2)) + 1, head.group(3))
    with open(os.path.join(GAME, type_path), "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(lines))
    return True


def parse_scene(path):
    """The numbers written in a body scene, to compare with the table."""
    text = read(path)

    def shape(sub_id, key):
        block = text.split('id="%s"]' % sub_id, 1)[1].split("\n\n", 1)[0]
        return float(fields(block)[key])

    def origin(node, axis):
        block = text.split('[node name="%s"' % node, 1)[1].split("\n\n", 1)[0]
        args = re.search(r"Transform3D\((.*)\)", block).group(1).split(",")
        return float(args[9 + axis])

    out = {
        "capsule_height": shape("Capsule_ground", "height"), "capsule_radius": shape("Capsule_ground", "radius"),
        "height": shape("Cylinder_footprint", "height"), "radius": shape("Cylinder_footprint", "radius"),
        "reach": origin("Reach", 2), "center_y": origin("Center", 1), "top_y": origin("Top", 1),
    }
    if 'id="Capsule_air"' in text:
        out["flying_height"] = shape("Capsule_air", "height")
    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    sizes = load_sizes()
    overrides = load_overrides()
    count = patched = 0
    bad = []
    for _kind, type_dir, scene_dir, wizard in KINDS:
        for path in sorted(glob.glob(os.path.join(GAME, type_dir, "*.tres"))):
            stem = os.path.basename(path)[:-5]
            model = text_of(fields(open(path, encoding="utf-8").read().split("[resource]", 1)[1])["model"])
            if model not in sizes:
                sys.exit("%s: model %s has no body_sizes file" % (stem, model))
            values = derive(info(model, sizes, overrides), wizard or stem == "sac_doctor")
            scene_path = "%s/%s.tscn" % (scene_dir, stem)
            count += 1
            clipped = "  clipped" if values["capsule_radius"] < values["radius"] else ""
            print("%-22s %-5s h=%-7s r=%-6s reach=%-6s cap=%s/%s%s%s" % (
                stem, model, num(values["height"]), num(values["radius"]), num(values["reach"]), num(values["capsule_height"]),
                num(values["capsule_radius"]), "  flying=" + num(values["flying_height"]) if values["flying_height"] else "", clipped))
            if args.dry:
                continue
            os.makedirs(os.path.join(GAME, scene_dir), exist_ok=True)
            with open(os.path.join(GAME, scene_path), "w", encoding="utf-8", newline="\n") as handle:
                handle.write(scene_text(stem, model, values, wizard))
            if patch_type(os.path.relpath(path, GAME), scene_path):
                patched += 1
            if args.check:
                found = parse_scene(scene_path)
                for key, value in found.items():
                    want = values[key] if key != "capsule_height" else values["capsule_height"]
                    if f32(want) != f32(value):
                        bad.append("%s %s: table %s scene %s" % (stem, key, num(want), num(value)))
    print("BODIES %d scenes, %d types patched%s" % (count, patched, " (dry)" if args.dry else ""))
    for line in bad:
        print("DIFF " + line)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
