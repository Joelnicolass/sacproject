#!/usr/bin/env python3
"""One-shot migration of RFC-055 cut 055o-d: the UI sounds by text key become typed SoundCue files.

Reads data/audio/ui.tres (the set `ifac`: a `cues` dictionary of text keys) and writes:
  - data/audio/cues/{ui_click,ui_book_click,menu_open,menu_back}.tres   the four cues the game plays (click, Iclk, XMNU, Ibak);
  - scenes/audio/sound_bus.tscn   a UiClickSounds child with `click = ui_click.tres`;
  - scenes/ui/spell_book/spell_slot.tscn   `metadata/ui_sound` is the cue (ui_book_click.tres), not the key `Iclk`;
  - scenes/ui/radial/radial_menu.tscn   only the MenuSounds node: `opened`, `chosen`, `cancelled` are cues;
  - tools/migrate/055o_ui_parity.json: how every UI event sounded BEFORE (the stream list and numbers of each cue and who plays
    it), so Godot can check it once (tools/migrate/migrate_055o_ui.gd) and then it is deleted with this script.
The keys of ui.tres that nothing plays (back, goda, godd, lvdn, lvup, spav, spir) are dropped; the audio files stay in
assets/original/audio/. It does not open Godot. The old ui.tres is removed by the caller (git rm), not here. Run from game/:
    python3 tools/migrate/migrate_055o_ui.py            # writes everything
    python3 tools/migrate/migrate_055o_ui.py --dry-run  # only the report
"""
import json
import os
import re
import sys

GAME = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TABLE = "data/audio/ui.tres"
CUES_DIR = "data/audio/cues"
PARITY = "tools/migrate/055o_ui_parity.json"
## Old text key -> the human name of the cue file.
NAMES = {"click": "ui_click", "Iclk": "ui_book_click", "XMNU": "menu_open", "Ibak": "menu_back"}
## Who played each key before: (kind, scene or code path, node or "", the event of the log entry).
CONSUMERS = [
    ("click", "button", "scenes/audio/sound_bus.tscn", "UiClickSounds", "click"),
    ("Iclk", "button_meta", "scenes/ui/spell_book/spell_slot.tscn", ".", "click"),
    ("XMNU", "menu", "scenes/ui/radial/radial_menu.tscn", "MenuSounds", "menu_open"),
    ("Iclk", "menu", "scenes/ui/radial/radial_menu.tscn", "MenuSounds", "click"),
    ("Ibak", "menu", "scenes/ui/radial/radial_menu.tscn", "MenuSounds", "menu_back"),
]


def read(path):
    with open(os.path.join(GAME, path), encoding="utf-8") as handle:
        return handle.read()


def write(path, text):
    full = os.path.join(GAME, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)


def parse(text):
    """(ext {id: (line, path)}, subs {id: [property lines]}, keys {key: sub id}) of a SoundSet-like .tres."""
    ext, subs, keys = {}, {}, {}
    section, body = None, None
    for line in text.split("\n"):
        head = re.match(r"^\[(\w+)(.*)\]\s*$", line)
        if head:
            section, rest, body = head.group(1), head.group(2), None
            if section == "ext_resource":
                ext[re.search(r' id="([^"]+)"', rest).group(1)] = (line, re.search(r' path="([^"]+)"', rest).group(1))
            elif section == "sub_resource":
                body = subs.setdefault(re.search(r' id="([^"]+)"', rest).group(1), [])
            continue
        if section == "sub_resource" and body is not None and line.strip():
            body.append(line)
        if section == "resource":
            match = re.match(r'^&"([^"]+)": SubResource\("([^"]+)"\)', line)
            if match:
                keys[match.group(1)] = match.group(2)
    return ext, subs, keys


def cue_file(ext, props):
    props = [line for line in props if not line.startswith("script = ")]
    used = list(dict.fromkeys(i for line in props for i in re.findall(r'ExtResource\("([^"]+)"\)', line)))
    lines = ['[ext_resource type="Script" path="res://scenes/audio/sound_cue.gd" id="1_cue"]'] + [ext[i][0] for i in used]
    out = ['[gd_resource type="Resource" script_class="SoundCue" load_steps=%d format=3]' % (len(lines) + 1), ""]
    out += lines + ["", "[resource]", 'script = ExtResource("1_cue")'] + props
    return "\n".join(out) + "\n", props


def replace_once(text, old, new, label):
    if text.count(old) != 1:
        raise SystemExit("%s: esperaba 1 vez %r y hay %d" % (label, old, text.count(old)))
    return text.replace(old, new)


def main():
    dry = "--dry-run" in sys.argv
    if not os.path.exists(os.path.join(GAME, TABLE)):
        raise SystemExit("falta %s: ¿ya se migró?" % TABLE)
    ext, subs, keys = parse(read(TABLE))
    parity_cues, unused = {}, sorted(set(keys) - set(NAMES))
    for key, name in NAMES.items():
        text, props = cue_file(ext, subs[keys[key]])
        streams = [ext[i][1] for line in props if line.startswith("streams = ")
                   for i in re.findall(r'ExtResource\("([^"]+)"\)', line)]
        parity_cues[name] = {"streams": streams, "props": props}
        print("cue %-14s <- %-5s %d streams" % (name, key, len(streams)))
        if not dry:
            write("%s/%s.tres" % (CUES_DIR, name), text)
    consumers = [{"old_key": key, "cue": NAMES[key], "kind": kind, "path": path, "node": node, "event": event}
                 for key, kind, path, node, event in CONSUMERS]
    print("claves descartadas sin consumidor:", ", ".join(unused))
    if dry:
        return
    write(PARITY, json.dumps({"cues": parity_cues, "consumers": consumers, "unused_keys": unused}, indent=1, sort_keys=True) + "\n")

    bus = read("scenes/audio/sound_bus.tscn")
    if "UiClickSounds" not in bus:
        bus = replace_once(bus, "[gd_scene load_steps=3 format=3]", "[gd_scene load_steps=5 format=3]", "sound_bus.tscn")
        bus = replace_once(bus, '[ext_resource type="Script" path="res://scenes/audio/fx_sounds.gd" id="2_fx"]\n',
            '[ext_resource type="Script" path="res://scenes/audio/fx_sounds.gd" id="2_fx"]\n'
            '[ext_resource type="Script" path="res://scenes/audio/ui_click_sounds.gd" id="3_ui"]\n'
            '[ext_resource type="Resource" path="res://data/audio/cues/ui_click.tres" id="4_click"]\n', "sound_bus.tscn")
        bus = replace_once(bus, 'node_paths=PackedStringArray("fx_sounds")', 'node_paths=PackedStringArray("fx_sounds", "ui_clicks")', "sound_bus.tscn")
        bus = replace_once(bus, 'fx_sounds = NodePath("FxSounds")\n', 'fx_sounds = NodePath("FxSounds")\nui_clicks = NodePath("UiClickSounds")\n', "sound_bus.tscn")
        bus = bus.rstrip("\n") + (
            '\n\n[node name="UiClickSounds" type="Node" parent="."]\n'
            'editor_description = "Cada botón que entra al árbol suena `click` al apretarlo. Un botón con el dato `ui_sound` (un SoundCue) suena ese; con `no_ui_sound` en true, ninguno."\n'
            'script = ExtResource("3_ui")\n'
            'click = ExtResource("4_click")\n')
        write("scenes/audio/sound_bus.tscn", bus)

    slot = read("scenes/ui/spell_book/spell_slot.tscn")
    if 'metadata/ui_sound = &"Iclk"' in slot:
        slot = replace_once(slot, "[gd_scene load_steps=4 format=3]", "[gd_scene load_steps=5 format=3]", "spell_slot.tscn")
        slot = replace_once(slot, '[ext_resource type="Script" path="res://scenes/ui/spell_book/spell_slot.gd" id="1_slot"]\n',
            '[ext_resource type="Script" path="res://scenes/ui/spell_book/spell_slot.gd" id="1_slot"]\n'
            '[ext_resource type="Resource" path="res://data/audio/cues/ui_book_click.tres" id="2_click"]\n', "spell_slot.tscn")
        slot = replace_once(slot, 'metadata/ui_sound = &"Iclk"', 'metadata/ui_sound = ExtResource("2_click")', "spell_slot.tscn")
        write("scenes/ui/spell_book/spell_slot.tscn", slot)

    radial = read("scenes/ui/radial/radial_menu.tscn")
    if "a055_open" not in radial:
        radial = replace_once(radial, '[ext_resource type="Script" path="res://scenes/audio/menu_sounds.gd" id="a052_menu_sounds"]\n',
            '[ext_resource type="Script" path="res://scenes/audio/menu_sounds.gd" id="a052_menu_sounds"]\n'
            '[ext_resource type="Resource" path="res://data/audio/cues/menu_open.tres" id="a055_open"]\n'
            '[ext_resource type="Resource" path="res://data/audio/cues/ui_book_click.tres" id="a055_chosen"]\n'
            '[ext_resource type="Resource" path="res://data/audio/cues/menu_back.tres" id="a055_back"]\n', "radial_menu.tscn")
        radial = replace_once(radial,
            'editor_description = "RFC-052 052h: abrir (XMNU), elegir (Iclk) y cerrar sin elegir (Ibak) del menú X. Sin audio no hace nada."\n'
            'script = ExtResource("a052_menu_sounds")\nmenu = NodePath("..")\n',
            'editor_description = "Lo que suena al abrir, elegir una entrada y cerrar sin elegir del menú X: tres SoundCue (data/audio/cues/). Vaciá uno y ese momento queda en silencio. Sin audio no hace nada."\n'
            'script = ExtResource("a052_menu_sounds")\nmenu = NodePath("..")\n'
            'opened = ExtResource("a055_open")\nchosen = ExtResource("a055_chosen")\ncancelled = ExtResource("a055_back")\n', "radial_menu.tscn")
        write("scenes/ui/radial/radial_menu.tscn", radial)
    print("hecho; falta git rm %s" % TABLE)


if __name__ == "__main__":
    main()
