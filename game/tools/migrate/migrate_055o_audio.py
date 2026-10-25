#!/usr/bin/env python3
"""One-shot migration of RFC-055 cut 055o-a: FX sounds by text become typed SoundCue files.

Reads data/audio/fx_sounds.tres (99 text keys) and the Xquk/Xanm/Xfbl cues of data/audio/world.tres, then writes:
  - data/audio/cues/<name>.tres        one SoundCue file per cue that something uses;
  - the 74 SoundEmitter3D nodes of scenes/**/*.tscn: `cue = &"key"` becomes `cue = ExtResource(...)`, `source = "world"` goes;
  - `sound = ExtResource(...)` in the ParticleType (data/fx/**) and BeamType (data/fx/beams) named like a key;
  - a `Sound` child (SoundEmitter3D) in the FX scenes that FxBus.broadcast_scene names by file;
  - tools/migrate/055o_fx_parity.json: what every consumer sounded like before, so Godot can check it
    (tools/migrate/migrate_055o_audio.gd) once, and then it is deleted with this script.
It does not open Godot and changes nothing it cannot rebuild from git. Run from game/:
    python3 tools/migrate/migrate_055o_audio.py            # writes everything
    python3 tools/migrate/migrate_055o_audio.py --dry-run  # only the report
The old fx_sounds.tres and fx_sound_map.gd are removed by the caller (git rm), not here.
"""
import glob
import json
import os
import re
import sys

GAME = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FX_TABLE = "data/audio/fx_sounds.tres"
WORLD_TABLE = "data/audio/world.tres"
CUES_DIR = "data/audio/cues"
PARITY = "tools/migrate/055o_fx_parity.json"
EMITTER_SCENE = "res://scenes/audio/sound_emitter_3d.tscn"
## Keys of world.tres that scenes used through `source = "world"` -> the human name of their file.
WORLD_KEYS = {"Xquk": "quake", "Xanm": "animate_dead", "Xfbl": "soul_wind"}
## FX scenes FxBus.broadcast_scene plays by file name; they get a Sound child.
SCENE_FX = {
    "spike_field": "scenes/fx/spike_field.tscn",
    "quake_ring": "scenes/fx/quake_ring.tscn",
    "wall_spike": "scenes/fx/wall_spike.tscn",
    "explosion_burst": "scenes/spells/zones/explosion_burst.tscn",
    "ice_shatter": "scenes/spells/zones/ice_shatter.tscn",
    "erupt_burst": "scenes/spells/zones/erupt_burst.tscn",
}


def read(path):
    with open(os.path.join(GAME, path), encoding="utf-8") as handle:
        return handle.read()


def write(path, text):
    full = os.path.join(GAME, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)


class Table:
    """The ext_resources, sub_resources and the `cues` dictionary of a SoundSet-like .tres."""

    def __init__(self, text):
        self.ext = {}
        self.subs = {}
        self.keys = {}
        section = None
        body = None
        for line in text.split("\n"):
            head = re.match(r"^\[(\w+)(.*)\]\s*$", line)
            if head:
                kind, rest = head.group(1), head.group(2)
                section = kind
                body = None
                if kind == "ext_resource":
                    ident = re.search(r' id="([^"]+)"', rest).group(1)
                    path = re.search(r' path="([^"]+)"', rest).group(1)
                    self.ext[ident] = (line, path)
                elif kind == "sub_resource":
                    ident = re.search(r' id="([^"]+)"', rest).group(1)
                    body = []
                    self.subs[ident] = body
                continue
            if section == "sub_resource" and body is not None and line.strip():
                body.append(line)
            if section == "resource":
                match = re.match(r'^&"([^"]+)": SubResource\("([^"]+)"\)', line)
                if match:
                    self.keys[match.group(1)] = match.group(2)

    def cue(self, sub):
        """(properties without the script line, streams as res:// paths, ext ids used)."""
        props = []
        used = []
        for line in self.subs[sub]:
            if line.startswith("script = "):
                continue
            props.append(line)
            used += re.findall(r'ExtResource\("([^"]+)"\)', line)
        streams = []
        for line in props:
            if line.startswith("streams = "):
                streams = [self.ext[i][1] for i in re.findall(r'ExtResource\("([^"]+)"\)', line)]
        return props, streams, list(dict.fromkeys(used))


def cue_text(table, sub):
    props, _streams, used = table.cue(sub)
    ext = ['[ext_resource type="Script" path="res://scenes/audio/sound_cue.gd" id="1_cue"]']
    ext += [table.ext[i][0] for i in used]
    steps = len(ext) + 1
    out = ['[gd_resource type="Resource" script_class="SoundCue" load_steps=%d format=3]' % steps, ""]
    out += ext
    out += ["", "[resource]", 'script = ExtResource("1_cue")']
    out += props
    return "\n".join(out) + "\n"


def add_ext_and_steps(text, ext_lines, header_re):
    """Appends ext_resource lines after the last one (or after the header) and bumps load_steps."""
    lines = text.split("\n")
    last = max((i for i, ln in enumerate(lines) if ln.startswith("[ext_resource")), default=0)
    lines[last + 1:last + 1] = ext_lines
    out = "\n".join(lines)
    return re.sub(header_re, lambda m: m.group(1) + str(int(m.group(2)) + len(ext_lines)) + m.group(3), out, count=1)


def scene_nodes(text):
    """[(line index, node name, parent or None)] of the node headers of a .tscn."""
    nodes = []
    for i, line in enumerate(text.split("\n")):
        match = re.match(r'^\[node name="([^"]+)"(?: type="[^"]*")?(?: parent="([^"]*)")?', line)
        if match:
            nodes.append((i, match.group(1), match.group(2)))
    return nodes


def node_path(name, parent):
    if parent is None:
        return "."
    return name if parent == "." else parent + "/" + name


def main():
    dry = "--dry-run" in sys.argv
    if os.path.isdir(os.path.join(GAME, CUES_DIR)) and os.listdir(os.path.join(GAME, CUES_DIR)) and not dry:
        sys.exit("data/audio/cues/ is not empty: this migration runs once (git checkout it to run again).")
    fx = Table(read(FX_TABLE))
    world = Table(read(WORLD_TABLE))

    ## sub id -> file name, in table order (the first key of a shared cue names the file).
    file_of_sub = {}
    key_file = {}
    for key, sub in fx.keys.items():
        name = key.replace("/", "_")
        if sub not in file_of_sub:
            file_of_sub[sub] = name
        key_file[key] = file_of_sub[sub]
    world_file = {key: name for key, name in WORLD_KEYS.items()}

    particles = {}
    for path in sorted(glob.glob(os.path.join(GAME, "data/fx/**/*.tres"), recursive=True)):
        rel = os.path.relpath(path, os.path.join(GAME, "data/fx"))[:-5]
        if rel.startswith("beams/"):
            continue
        if 'script_class="ParticleType"' in open(path, encoding="utf-8").readline():
            particles[rel] = os.path.relpath(path, GAME)
    beams = {}
    for path in sorted(glob.glob(os.path.join(GAME, "data/fx/beams/*.tres"))):
        if 'script_class="BeamType"' in open(path, encoding="utf-8").readline():
            beams[os.path.basename(path)[:-5]] = os.path.relpath(path, GAME)

    consumers = []  # {"kind", "path", "node", "cue"}
    used_files = set()

    ## Scenes: the emitters.
    scene_edits = {}
    for path in sorted(glob.glob(os.path.join(GAME, "scenes/**/*.tscn"), recursive=True)):
        rel = os.path.relpath(path, GAME)
        text = open(path, encoding="utf-8").read()
        if not re.search(r'^cue = &"', text, re.M):
            continue
        lines = text.split("\n")
        heads = scene_nodes(text)
        new_ext = {}
        out = []
        current = None
        for i, line in enumerate(lines):
            for at, name, parent in heads:
                if at == i:
                    current = (name, parent)
            match = re.match(r'^cue = &"([^"]+)"$', line)
            if match:
                key = match.group(1)
                if key in world_file:
                    name = world_file[key]
                elif key in key_file:
                    name = key_file[key]
                else:
                    sys.exit("%s: key %s is in no table" % (rel, key))
                ident = "cue_" + name
                new_ext[ident] = name
                out.append('cue = ExtResource("%s")' % ident)
                used_files.add(name)
                consumers.append({"kind": "emitter", "path": rel, "node": node_path(*current), "cue": name, "old_key": key})
            elif re.match(r'^source = "world"$', line):
                continue
            elif re.match(r"^source = ", line):
                sys.exit("%s: a source other than world: %s" % (rel, line))
            else:
                out.append(line)
        ext_lines = ['[ext_resource type="Resource" path="res://%s/%s.tres" id="%s"]' % (CUES_DIR, name, ident) for ident, name in new_ext.items()]
        edited = add_ext_and_steps("\n".join(out), ext_lines, r"(\[gd_scene load_steps=)(\d+)(.*)")
        scene_edits[rel] = edited

    ## ParticleType / BeamType: `sound`.
    type_edits = {}
    for key, name in key_file.items():
        for kind, table in (("particle", particles), ("beam", beams)):
            if key in table:
                rel = table[key]
                ident = "cue_" + name
                text = open(os.path.join(GAME, rel), encoding="utf-8").read()
                ext_line = '[ext_resource type="Resource" path="res://%s/%s.tres" id="%s"]' % (CUES_DIR, name, ident)
                text = add_ext_and_steps(text, [ext_line], r"(load_steps=)(\d+)(.*)")
                type_edits[rel] = text.rstrip("\n") + '\nsound = ExtResource("%s")\n' % ident
                used_files.add(name)
                consumers.append({"kind": kind, "path": rel, "node": "", "cue": name, "old_key": key})

    ## FX scenes: a Sound child.
    for key, rel in SCENE_FX.items():
        name = key_file[key]
        ident = "cue_" + name
        text = scene_edits.get(rel) or open(os.path.join(GAME, rel), encoding="utf-8").read()
        ext_lines = ['[ext_resource type="Resource" path="res://%s/%s.tres" id="%s"]' % (CUES_DIR, name, ident)]
        if key == "wall_spike":
            base = read(SCENE_FX["spike_field"])
            index = sum(1 for _i, _n, parent in scene_nodes(base) if parent == ".")
            text = add_ext_and_steps(text, ext_lines, r"(\[gd_scene load_steps=)(\d+)(.*)")
            text = text.rstrip("\n") + '\n\n[node name="Sound" parent="." index="%d"]\ncue = ExtResource("%s")\n' % (index, ident)
        else:
            ext_lines.insert(0, '[ext_resource type="PackedScene" path="%s" id="sound_emitter"]' % EMITTER_SCENE)
            text = add_ext_and_steps(text, ext_lines, r"(\[gd_scene load_steps=)(\d+)(.*)")
            text = text.rstrip("\n") + '\n\n[node name="Sound" parent="." instance=ExtResource("sound_emitter")]\ncue = ExtResource("%s")\n' % ident
        scene_edits[rel] = text
        used_files.add(name)
        consumers.append({"kind": "scene", "path": rel, "node": "Sound", "cue": name, "old_key": key})

    ## Cue files.
    cue_files = {}
    parity_cues = {}
    for sub, name in file_of_sub.items():
        if name in used_files:
            cue_files[name] = cue_text(fx, sub)
            props, streams, _used = fx.cue(sub)
            parity_cues[name] = {"streams": streams, "props": props}
    for key, name in WORLD_KEYS.items():
        sub = world.keys[key]
        cue_files[name] = cue_text(world, sub)
        props, streams, _used = world.cue(sub)
        parity_cues[name] = {"streams": streams, "props": props}
    unused = sorted(k for k, n in key_file.items() if n not in used_files)

    print("cues written:        %d (fx %d + world %d)" % (len(cue_files), len(cue_files) - len(WORLD_KEYS), len(WORLD_KEYS)))
    print("emitter nodes:       %d in %d scenes" % (sum(1 for c in consumers if c["kind"] == "emitter"),
                                                 len({c["path"] for c in consumers if c["kind"] == "emitter"})))
    print("ParticleType.sound:  %d" % sum(1 for c in consumers if c["kind"] == "particle"))
    print("BeamType.sound:      %d" % sum(1 for c in consumers if c["kind"] == "beam"))
    print("FX scenes with Sound: %d" % sum(1 for c in consumers if c["kind"] == "scene"))
    print("discarded keys (no consumer): %s" % ", ".join(unused))
    if dry:
        return
    for name, text in cue_files.items():
        write("%s/%s.tres" % (CUES_DIR, name), text)
    for rel, text in {**scene_edits, **type_edits}.items():
        write(rel, text)
    write(PARITY, json.dumps({"cues": parity_cues, "consumers": consumers, "unused_keys": unused}, indent=1, sort_keys=True) + "\n")
    print("wrote %d cue files, %d scenes, %d types, %s" % (len(cue_files), len(scene_edits), len(type_edits), PARITY))


if __name__ == "__main__":
    main()
