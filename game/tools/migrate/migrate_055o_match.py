#!/usr/bin/env python3
"""One-shot migration of RFC-055 cut 055o-c: the sounds of the match (music, ambience, advisor, sacrifice) become typed.

Reads what the game has today and writes the typed version, without opening Godot:
  - data/gods/*.tres                 GodType.music and GodType.ambience (the god's own sets);
  - data/audio/ambience/*.tres       the one-shots the god played from world.tres by text key (AchC, AjaN...) become cues of
                                     the set itself (`one_shots`); `one_shot_keys` goes away;
  - data/audio/cues/{sacrifice_round,sacrifice_end,soul}.tres   the three cues the sacrifice and the souls took from world.tres;
  - scenes/sacrifice/ritual.tscn, scenes/souls/soul.tscn        RitualSounds and SoulSounds carry those cues;
  - scenes/audio/advisor/advisor.tscn   AdvisorVoice + Channel + AdvisorWatch with the 14 AdvisorLine the game uses
                                     (the 22 `advi` keys of advisor.tres, minus the 8 nobody says); the priorities, the quiet
                                     times and the refusal table come from the advisor_voice.gd that this cut removes;
  - scenes/match/match.tscn          the advisor is an instance of advisor.tscn; MusicDirector.default_music = common.tres;
                                     CommandVoice gets its Channel child;
  - scenes/core/boot.tscn            MusicDirector.music = the menu's set;
  - data/audio/world.tres and advisor.tres are deleted (git rm);
  - tools/migrate/055o_match_parity.json: how everything sounded BEFORE, so Godot can check it once
    (tools/migrate/migrate_055o_match.gd) and then it is deleted with this script.
Run from game/:
    python3 tools/migrate/migrate_055o_match.py --dry-run   # only the report
    python3 tools/migrate/migrate_055o_match.py             # writes everything
"""
import glob
import hashlib
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import migrate_055o_bodies as bodies  # noqa: E402  (OldSet, Cue, cue_file_text, read, write, add_ext_and_steps)

GAME = bodies.GAME
read, write = bodies.read, bodies.write
PARITY = "tools/migrate/055o_match_parity.json"
WORLD = "data/audio/world.tres"
ADVISOR = "data/audio/advisor.tres"
CUE_SCRIPT = "res://scenes/audio/sound_cue.gd"

## The cues the sacrifice and the souls took from the world set (file name -> old key).
SACRIFICE_CUES = {"sacrifice_round": "sacrifice_round", "sacrifice_end": "sacrifice_end", "soul": "soul"}

## name, old `advi` code, priority (AdvisorLine.Priority: 0 ANNOY, 1 IMPORTANT, 2 CRUCIAL), quiet_s. Priorities and quiet times as the
## removed advisor_voice.gd had them (`priorities`, `cooldowns`; the rest: ANNOY, 2.0 s).
LINES = [
    ("wizard_attacked", "watt", 1, 15.0),
    ("wizard_low_health", "whlt", 2, 5.0),
    ("creatures_attacked", "uatt", 1, 15.0),
    ("creature_died", "cdie", 1, 5.0),
    ("building_attacked", "bdam", 2, 5.0),
    ("building_destroyed", "bdst", 1, 1.0),
    ("desecrated", "dese", 2, 5.0),
    ("sacrifice_complete", "sacc", 1, 2.0),
    ("low_mana", "lowm", 0, 5.0),
    ("not_ready", "nred", 0, 2.0),
    ("out_of_range", "orng", 0, 2.0),
    ("invalid_target", "invl", 0, 2.0),
    ("need_souls", "spir", 0, 2.0),
    ("far_from_altar", "ealt", 0, 2.0),
]
## Refusal key -> line (the removed `refusal_events`).
REFUSALS = {
    "no_mana": "low_mana",
    "cooling": "not_ready",
    "out_of_range": "out_of_range",
    "bad_target": "invalid_target",
    "no_target": "invalid_target",
    "no_souls": "need_souls",
    "far_from_altar": "far_from_altar",
}
## The first six lines are AdvisorWatch's exports (same names), the rest are refusals.
WATCH = [name for name, _c, _p, _q in LINES[:8]]


def digest(cue):
    return hashlib.sha1(json.dumps(cue.content()).encode()).hexdigest()[:10]


def parse_tres(path):
    """{ext: id -> (line, res path), subs: id -> [lines]} of a .tres."""
    ext, subs, current = {}, {}, None
    for line in read(path).split("\n"):
        head = re.match(r"^\[(\w+)(.*)\]\s*$", line)
        if head:
            current = None
            if head.group(1) == "ext_resource":
                ident = re.search(r' id="([^"]+)"', head.group(2)).group(1)
                ext[ident] = (line, re.search(r' path="([^"]+)"', head.group(2)).group(1))
            elif head.group(1) == "sub_resource":
                current = []
                subs[re.search(r' id="([^"]+)"', head.group(2)).group(1)] = current
            continue
        if current is not None and line.strip():
            current.append(line)
    return ext, subs


def cue_of_sub(path, ext, sub, lines):
    streams, props, ext_lines = [], [], {}
    for line in lines:
        if line.startswith("script = "):
            continue
        if line.startswith("streams = "):
            for ident in re.findall(r'ExtResource\("([^"]+)"\)', line):
                streams.append(ext[ident][1])
                ext_lines[ext[ident][1]] = ext[ident][0]
            continue
        props.append(line)
    return bodies.Cue(path, sub, streams, ext_lines, props)


def cue_sub_text(sub_id, cue, script_id, stream_id):
    """A SoundCue sub_resource (streams get `stream_id(path)` ids)."""
    ids = ", ".join('ExtResource("%s")' % stream_id(p) for p in cue.streams)
    lines = ['[sub_resource type="Resource" id="%s"]' % sub_id, 'script = ExtResource("%s")' % script_id,
             "streams = Array[AudioStream]([%s])" % ids]
    return "\n".join(lines + cue.props)


def ext_line_for(cue, path, ident):
    return re.sub(r' id="[^"]+"', ' id="%s"' % ident, cue.ext_lines[path])


def insert_after_ext(text, lines):
    split = text.split("\n")
    last = max(i for i, ln in enumerate(split) if ln.startswith("[ext_resource"))
    split[last + 1:last + 1] = lines
    return "\n".join(split)


def god_tags():
    out = {}
    for path in sorted(glob.glob(os.path.join(GAME, "data/gods/*.tres"))):
        rel = os.path.relpath(path, GAME)
        match = re.search(r'^tag = "([^"]*)"', read(rel), re.M)
        out[rel] = match.group(1) if match else os.path.basename(rel)[:-5]
    return out


def ambience_before(path, world):
    """(bed cue or None, [one-shot cues in the order the director played them]) of an ambience set of today."""
    text = read(path)
    ext, subs = parse_tres(path)
    bed = None
    match = re.search(r'^bed = SubResource\("([^"]+)"\)', text, re.M)
    if match:
        bed = cue_of_sub(path, ext, match.group(1), subs[match.group(1)])
    shots = []
    keys = re.search(r"^one_shot_keys = Array\[StringName\]\(\[(.*)\]\)", text, re.M)
    if keys:
        for key in re.findall(r'&"([^"]+)"', keys.group(1)):
            cue = world.cues.get(key)
            if cue is None or cue.silent():
                sys.exit("%s names the key %s and world.tres has no sound for it" % (path, key))
            shots.append(cue)
    if re.search(r"^one_shots = ", text, re.M):
        sys.exit("%s already has one_shots: this migration runs once" % path)
    return bed, shots


def ambience_after(path, shots):
    text = read(path)
    ext, _subs = parse_tres(path)
    lines, subs, streams = [], [], {}
    if "res://scenes/audio/sound_cue.gd" not in [p for _l, p in ext.values()]:
        script_id = "shot_script"
        lines.append('[ext_resource type="Script" path="%s" id="%s"]' % (CUE_SCRIPT, script_id))
    else:
        script_id = [i for i, (_l, p) in ext.items() if p == CUE_SCRIPT][0]

    def stream_id(stream_path):
        if stream_path not in streams:
            streams[stream_path] = "shot_s%d" % (len(streams) + 1)
        return streams[stream_path]

    names = []
    for index, cue in enumerate(shots):
        sub = "OneShot_%d" % index
        names.append('SubResource("%s")' % sub)
        subs.append(cue_sub_text(sub, cue, script_id, stream_id))
        for stream_path in cue.streams:
            line = ext_line_for(cue, stream_path, stream_id(stream_path))
            if line not in lines:
                lines.append(line)
    text = insert_after_ext(text, lines)
    text = text.replace("\n[resource]", "\n" + "\n\n".join(subs) + "\n\n[resource]", 1)
    text = re.sub(r"^one_shot_keys = .*$", "one_shots = Array[SoundCue]([%s])" % ", ".join(names), text, flags=re.M)
    return text


def advisor_scene(advisor):
    """The text of advisor.tscn: AdvisorVoice, its Channel and its AdvisorWatch, with the 14 lines embedded."""
    ext = ['[ext_resource type="Script" path="res://scenes/audio/advisor/advisor_voice.gd" id="1_voice"]',
           '[ext_resource type="Script" path="res://scenes/audio/advisor/advisor_watch.gd" id="2_watch"]',
           '[ext_resource type="Script" path="res://scenes/audio/advisor/advisor_line.gd" id="3_line"]',
           '[ext_resource type="Script" path="%s" id="4_cue"]' % CUE_SCRIPT]
    streams = {}

    def stream_id(path):
        if path not in streams:
            streams[path] = "s%d" % (len(streams) + 1)
        return streams[path]

    subs = []
    for name, code, priority, quiet in LINES:
        cue = advisor.cues[code]
        subs.append(cue_sub_text("Cue_" + name, cue, "4_cue", stream_id))
        for path in cue.streams:
            line = ext_line_for(cue, path, stream_id(path))
            if line not in ext:
                ext.append(line)
        body = ['[sub_resource type="Resource" id="Line_%s"]' % name, 'resource_name = "%s"' % name, 'script = ExtResource("3_line")',
                'cue = SubResource("Cue_%s")' % name]
        if priority:
            body.append("priority = %d" % priority)
        if quiet != 2.0:
            body.append("quiet_s = %s" % quiet)
        subs.append("\n".join(body))
    refusals = ",\n".join('&"%s": SubResource("Line_%s")' % (key, line) for key, line in REFUSALS.items())
    watch = "\n".join('%s = SubResource("Line_%s")' % (name, name) for name in WATCH)
    nodes = '''[node name="AdvisorVoice" type="Node" node_paths=PackedStringArray("channel")]
editor_description = "El consejero: un canal con cola y prioridad (Channel, bus Voice). Los rechazos llegan por command_log (CommandLog.said) y salen de refusal_lines; los avisos del juego, por el hijo AdvisorWatch. Cada AdvisorLine trae su sonido, su prioridad y su silencio. Sin audio (dedicado, headless) no dice nada."
script = ExtResource("1_voice")
channel = NodePath("Channel")
refusal_lines = Dictionary[StringName, ExtResource("3_line")]({
%s
})

[node name="Channel" type="AudioStreamPlayer" parent="."]
bus = &"Voice"

[node name="AdvisorWatch" type="Node" parent="." node_paths=PackedStringArray("advisor")]
editor_description = "Los avisos del juego (el mago local recibe daño, un edificio o una criatura propia caen, el altar se profana): lee estado replicado y le pide una línea al consejero. Sacá el nodo y solo hablan los rechazos."
script = ExtResource("2_watch")
advisor = NodePath("..")
%s
''' % (refusals, watch)
    return "[gd_scene format=3]\n\n" + "\n".join(ext) + "\n\n" + "\n\n".join(subs) + "\n\n" + nodes


def edit_god(path, tag):
    text = read(path)
    if re.search(r"^music = ", text, re.M):
        sys.exit("%s already has music: this migration runs once" % path)
    text = insert_after_ext(text, ['[ext_resource type="Resource" path="res://data/audio/music/%s.tres" id="gm_music"]' % tag,
                                   '[ext_resource type="Resource" path="res://data/audio/ambience/%s.tres" id="gm_ambience"]' % tag])
    return text.rstrip("\n") + '\nmusic = ExtResource("gm_music")\nambience = ExtResource("gm_ambience")\n'


def edit_sounds_scene(path, node, props, cues):
    """Adds the cue ext_resources and properties to `node` (after its last property line)."""
    text = read(path)
    ids = {name: "a055_" + name for name in cues}
    ext = ['[ext_resource type="Resource" path="res://data/audio/cues/%s.tres" id="%s"]' % (name, ids[name]) for name in cues]
    text = bodies.add_ext_and_steps(text, ext, r"(\[gd_scene load_steps=)(\d+)(.*)")
    start = text.index('[node name="%s"' % node)
    end = text.find("\n\n", start)
    end = len(text) if end < 0 else end
    block = text[start:end].rstrip("\n")
    block += "\n" + "\n".join('%s = ExtResource("%s")' % (prop, ids[cue]) for prop, cue in props)
    return text[:start] + block + ("\n" if end == len(text) else "") + text[end:]


def edit_match(text):
    text = text.replace('[ext_resource type="Script" path="res://scenes/audio/advisor_voice.gd" id="a052_advisor"]\n', "")
    text = text.replace('[ext_resource type="Script" path="res://scenes/audio/advisor_watch.gd" id="a052_advisor_watch"]\n',
                        '[ext_resource type="PackedScene" path="res://scenes/audio/advisor/advisor.tscn" id="a055_advisor"]\n'
                        '[ext_resource type="Resource" path="res://data/audio/music/common.tres" id="a055_common_music"]\n')
    old = text[text.index('[node name="AdvisorVoice"'):text.index('[node name="CombatGauge"')]
    new = '''[node name="AdvisorVoice" parent="." node_paths=PackedStringArray("command_log") instance=ExtResource("a055_advisor")]
command_log = NodePath("../Hud/Battle")

[node name="AdvisorWatch" parent="AdvisorVoice" index="1" node_paths=PackedStringArray("world")]
world = NodePath("../..")

'''
    text = text.replace(old, new)
    old_cv = '''script = ExtResource("a052_command_voice")
selection = NodePath("../Selection")
orders = NodePath("../Orders")
'''
    if old_cv not in text:
        sys.exit("match.tscn: CommandVoice node not found")
    text = text.replace(old_cv, old_cv + 'channel = NodePath("Channel")\n\n[node name="Channel" type="AudioStreamPlayer" parent="CommandVoice"]\nbus = &"Voice"\n', 1)
    text = text.replace('[node name="CommandVoice" type="Node" parent="." node_paths=PackedStringArray("selection", "orders")]',
                        '[node name="CommandVoice" type="Node" parent="." node_paths=PackedStringArray("selection", "orders", "channel")]')
    old_md = 'camera = NodePath("../Camera")\n\n[node name="AmbienceDirector"'
    if old_md not in text:
        sys.exit("match.tscn: MusicDirector node not found")
    text = text.replace(old_md, 'camera = NodePath("../Camera")\ndefault_music = ExtResource("a055_common_music")\n\n[node name="AmbienceDirector"')
    return text


def edit_boot(text):
    old = 'set_path = "music/menu"\nfallback_path = ""\n'
    if old not in text:
        sys.exit("boot.tscn: MusicDirector.set_path not found")
    text = text.replace(old, 'music = ExtResource("a055_menu_music")\n')
    ext = ['[ext_resource type="Resource" path="res://data/audio/music/menu.tres" id="a055_menu_music"]']
    return bodies.add_ext_and_steps(text, ext, r"(\[gd_scene load_steps=)(\d+)(.*)")


def main():
    dry = "--dry-run" in sys.argv
    if not os.path.exists(os.path.join(GAME, WORLD)):
        sys.exit("data/audio/world.tres is gone: this migration runs once (git checkout the data to run it again).")
    world, advisor = bodies.OldSet(WORLD), bodies.OldSet(ADVISOR)
    gods = god_tags()
    cues = {}

    def cue_id(cue):
        key = digest(cue)
        cues.setdefault(key, {"streams": list(cue.streams), "props": list(cue.props)})
        return key

    snapshot = {"gods": [], "advisor": {"lines": [], "refusals": REFUSALS, "watch": WATCH}, "sacrifice": [], "directors": {
        "boot_music": "data/audio/music/menu.tres", "match_default_music": "data/audio/music/common.tres"}}
    after = {}
    for path, tag in gods.items():
        music, ambience = "data/audio/music/%s.tres" % tag, "data/audio/ambience/%s.tres" % tag
        for needed in (music, ambience):
            if not os.path.isfile(os.path.join(GAME, needed)):
                sys.exit("%s: the god %s has no %s" % (path, tag, needed))
        bed, shots = ambience_before(ambience, world)
        snapshot["gods"].append({"tag": tag, "path": path, "music": music, "ambience": ambience,
                                 "bed": cue_id(bed) if bed else None, "one_shots": [cue_id(c) for c in shots]})
        after[ambience] = ambience_after(ambience, shots)
    for name, code, priority, quiet in LINES:
        cue = advisor.cues.get(code)
        if cue is None or cue.silent():
            sys.exit("advisor.tres has no sound for %s" % code)
        snapshot["advisor"]["lines"].append({"name": name, "code": code, "cue": cue_id(cue), "priority": priority, "quiet_s": quiet})
    for scene, node, props in (("scenes/sacrifice/ritual.tscn", "RitualSounds", [("round_cue", "sacrifice_round"), ("finished_cue", "sacrifice_end"), ("converted_cue", "soul")]),
                               ("scenes/souls/soul.tscn", "SoulSounds", [("collected_cue", "soul")])):
        for prop, cue_name in props:
            snapshot["sacrifice"].append({"scene": scene, "node": node, "prop": prop, "cue": cue_id(world.cues[SACRIFICE_CUES[cue_name]]),
                                          "file": "data/audio/cues/%s.tres" % cue_name})
    dropped_world = sorted(k for k in world.cues if k not in SACRIFICE_CUES.values())
    dropped_advisor = sorted(k for k in advisor.cues if k not in {c for _n, c, _p, _q in LINES})
    snapshot["cues"] = cues
    snapshot["dropped_advisor_keys"] = dropped_advisor
    print("gods: %s" % ", ".join(gods.values()))
    print("lines: %d (%d refusals keys); advisor.tres keys dropped (nobody says them): %s" % (len(LINES), len(REFUSALS), ", ".join(dropped_advisor)))
    for g in snapshot["gods"]:
        print("  %-10s one_shots: %d bed: %s" % (g["tag"], len(g["one_shots"]), "yes" if g["bed"] else "no"))
    print("world.tres keys not carried (the typed cues of o-a/o-b replaced them, or nobody plays them): %d" % len(dropped_world))
    if dry:
        return

    for name, key in SACRIFICE_CUES.items():
        write("data/audio/cues/%s.tres" % name, bodies.cue_file_text(world.cues[key]))
    for ambience, text in after.items():
        write(ambience, text)
    for path, tag in gods.items():
        write(path, edit_god(path, tag))
    write("scenes/audio/advisor/advisor.tscn", advisor_scene(advisor))
    write("scenes/sacrifice/ritual.tscn", edit_sounds_scene("scenes/sacrifice/ritual.tscn", "RitualSounds",
          [("round_cue", "sacrifice_round"), ("finished_cue", "sacrifice_end"), ("converted_cue", "soul")], ["sacrifice_round", "sacrifice_end", "soul"]))
    write("scenes/souls/soul.tscn", edit_sounds_scene("scenes/souls/soul.tscn", "SoulSounds", [("collected_cue", "soul")], ["soul"]))
    write("scenes/match/match.tscn", edit_match(read("scenes/match/match.tscn")))
    write("scenes/core/boot.tscn", edit_boot(read("scenes/core/boot.tscn")))
    write(PARITY, json.dumps(snapshot, indent=1, sort_keys=True) + "\n")
    for path in (WORLD, ADVISOR):
        if subprocess.call(["git", "rm", "-q", path], cwd=GAME) != 0:
            sys.exit("git rm %s failed" % path)
    print("wrote %d god files, %d ambience sets, 3 cues, advisor.tscn, ritual/soul/match/boot scenes, %s" % (len(gods), len(after), PARITY))


if __name__ == "__main__":
    main()
