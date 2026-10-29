#!/usr/bin/env python3
"""Gives a light (an FxLightSpec inside the file) to every additive ParticleType of the spells and the
gods that has none, so every spell lights its surroundings while it is cast and while it plays.

  python3 tools/bake/add_fx_lights.py            # print what it would do
  python3 tools/bake/add_fx_lights.py --apply    # write the lights

Which types: the additive ones (they glow) found from each spell's folder, the scenes that point at its
SpellType and the gods' cast particles. Smoke, dust and dirt (`additive = false`) never glow, and trails
(many puffs a second), ash, the second flash of an explosion and a type with no atlas are left out. A
type that already has a light keeps it.

The light: the color is the brightness-weighted mean of the atlas (the light keeps the sprite's
palette, its brightest channel raised to 1); energy, range and timing depend on the role:
  cast    the hands' particle (a SpellAction's cast_fx or a god's): short and close, at hand height
  burst   a one-shot effect: brighter and wider
  steady  an emitter that keeps going (rate_per_s > 0): softer, slower to rise and fall
"""
import glob
import os
import re
import sys
from collections import defaultdict
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
REF = re.compile(r'path="res://([^"]+)"')
## Trails (many puffs a second), ash and the second flash of an explosion whose first already lights.
SKIP_WORDS = ("trail", "ash", "blast2", "explosion2")
ROLES = {
    #        energy range attack decay power height attenuation
    "cast": (2.5, 6.0, 0.05, 0.35, 1.0, 1.2, 0.8),
    "burst": (3.0, 8.0, 0.03, 0.5, 1.5, 0.8, 0.8),
    "steady": (1.6, 7.0, 0.2, 0.8, 1.0, 1.0, 1.0),
}
SPEC_SCRIPT = "res://scenes/fx/fx_light_spec.gd"


def read(p):
    return (ROOT / p).read_text(encoding="utf-8", errors="replace")


def resources():
    files = []
    for pattern in ("spells/**/*.t*", "gods/**/*.t*", "scenes/**/*.t*"):
        files += [
            os.path.relpath(p, ROOT)
            for p in glob.glob(str(ROOT / pattern), recursive=True)
            if p.endswith((".tres", ".tscn"))
        ]
    return sorted(set(files))


def is_particle(p):
    return p.endswith(".tres") and 'script_class="ParticleType"' in read(p)[:300]


def ext_ids(text):
    return {i: path for path, i in re.findall(r'path="res://([^"]+)" id="([^"]+)"', text)}


def cast_particles(files):
    found = set()
    for p in files:
        text = read(p)
        m = re.search(r'^cast_fx = ExtResource\("([^"]+)"\)', text, re.M)
        if m:
            path = ext_ids(text).get(m.group(1))
            if path:
                found.add(path)
    return found


def spell_particles(files):
    refs = {p: set(REF.findall(read(p))) for p in files}
    back = defaultdict(set)
    for p, rs in refs.items():
        for r in rs:
            back[r].add(p)
    out = set()
    for typ in glob.glob(str(ROOT / "spells/*/*.tres")):
        rel = os.path.relpath(typ, ROOT)
        if Path(rel).stem != Path(rel).parent.name:
            continue
        roots = [rel] + [b for b in back[rel] if b.endswith(".tscn") and not b.startswith("scenes/match/")]
        seen, frontier = set(roots), list(roots)
        for _ in range(5):
            nxt = []
            for f in frontier:
                for r in refs.get(f, ()):
                    if r in seen or r.startswith(("creatures/", "wizards/", "gods/", "assets/")):
                        continue
                    if r in refs:
                        seen.add(r)
                        nxt.append(r)
            frontier = nxt
        out |= {f for f in seen if is_particle(f)}
    return out


def atlas_color(path):
    img = Image.open(ROOT / path).convert("RGBA").resize((64, 64))
    total = [0.0, 0.0, 0.0]
    weight = 0.0
    for r, g, b, a in img.getdata():
        lum = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
        w = lum * (a / 255.0)
        total[0] += r * w
        total[1] += g * w
        total[2] += b * w
        weight += w
    if weight <= 0.0:
        return (1.0, 1.0, 1.0)
    rgb = [c / weight / 255.0 for c in total]
    top = max(rgb) or 1.0
    return tuple(min(1.0, c / top) for c in rgb)


def add_light(path, role, apply):
    text = read(path)
    atlas_id = re.search(r'^atlas = ExtResource\("([^"]+)"\)', text, re.M)
    atlas = ext_ids(text).get(atlas_id.group(1)) if atlas_id else None
    color = atlas_color(atlas) if atlas else (1.0, 1.0, 1.0)
    energy, range_m, attack, decay, power, height, attenuation = ROLES[role]
    print(f"  {role:6s} {path}  color=({color[0]:.2f}, {color[1]:.2f}, {color[2]:.2f})")
    if not apply:
        return
    spec = (
        '[sub_resource type="Resource" id="fx_light"]\n'
        'script = ExtResource("fx_light_script")\n'
        f"color = Color({color[0]:.3f}, {color[1]:.3f}, {color[2]:.3f}, 1)\n"
        f"energy = {energy}\nrange_m = {range_m}\nattack_s = {attack}\ndecay_s = {decay}\n"
        f"decay_power = {power}\nheight_m = {height}\nattenuation = {attenuation}\n\n"
    )
    header_end = text.index("\n\n[resource]") if "\n\n[resource]" in text else text.index("[resource]")
    ext_line = f'[ext_resource type="Script" path="{SPEC_SCRIPT}" id="fx_light_script"]\n'
    last_ext = text.rfind("[ext_resource", 0, header_end)
    line_end = text.index("\n", last_ext) + 1
    text = text[:line_end] + ext_line + text[line_end:]
    text = text.replace("[resource]", spec + "[resource]", 1)
    text = text.rstrip("\n") + '\nlight = SubResource("fx_light")\n'
    text = re.sub(r"load_steps=(\d+)", lambda m: f"load_steps={int(m.group(1)) + 2}", text, count=1)
    (ROOT / path).write_text(text, encoding="utf-8")


def main():
    apply = "--apply" in sys.argv
    files = resources()
    casts = cast_particles(files)
    for god in glob.glob(str(ROOT / "gods/*/*.tres")):
        rel = os.path.relpath(god, ROOT)
        m = re.search(r'^cast_fx = ExtResource\("([^"]+)"\)', read(rel), re.M)
        if m and ext_ids(read(rel)).get(m.group(1)):
            casts.add(ext_ids(read(rel))[m.group(1)])
    targets = sorted(spell_particles(files) | casts)
    done = 0
    for path in targets:
        text = read(path)
        if "\nlight = " in text:
            continue
        if re.search(r"^additive = false", text, re.M):
            continue
        if any(word in Path(path).stem for word in SKIP_WORDS):
            continue
        if not re.search(r"^atlas = ", text, re.M):
            continue
        if path in casts:
            role = "cast"
        elif re.search(r"^rate_per_s = [1-9]", text, re.M):
            role = "steady"
        else:
            role = "burst"
        add_light(path, role, apply)
        done += 1
    print(f"{done} particle types {'got' if apply else 'would get'} a light")


if __name__ == "__main__":
    main()
