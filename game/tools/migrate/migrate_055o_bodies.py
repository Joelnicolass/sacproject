#!/usr/bin/env python3
"""One-shot migration of RFC-055 cut 055o-b: the sound sets of creatures and wizards get named fields and human names.

Reads the sets of today (data/audio/creatures, wizards, melee: a `cues` dictionary of text keys, found by file name) and writes:
  - data/audio/creatures/<human name>.tres   the 67 creature sets renamed after the display name of the creature (trogg.tres) and
                                             written with named fields (selected, ack, attack_ack, annoyed, swing, shoot, damaged,
                                             death...); the melee set is their `fallback`;
  - data/audio/wizards/*.tres                the 15 wizard sets with named fields (their names are already human);
  - data/audio/melee/{fist,saw,stab}.tres    the melee sets as fields (bsaw -> saw); they hold the swing of whoever has none;
  - data/audio/cues/summon.tres              the summon sound every creature shares (UnitSounds.summon);
  - data/catalog/creatures/*.tres and wizards/*.tres   `sounds = <their set>`; scenes/units/unit.tscn   UnitSounds.summon;
  - the fixtures of debug/audio/ that were sets with a `cues` dictionary;
  - tools/migrate/055o_bodies_parity.json: how every creature and wizard sounded BEFORE (the stream list of each event the
    game plays, read the way BodySounds, CommandVoice and the old aliases did), so Godot can check it once
    (tools/migrate/migrate_055o_bodies.gd) and then it is deleted with this script.
It does not open Godot. The renames go through tools/migrate/rename_resources.py (git mv + references). Run from game/:
    python3 tools/migrate/migrate_055o_bodies.py            # writes everything
    python3 tools/migrate/migrate_055o_bodies.py --dry-run  # only the report (the old -> new table and the parity patches)
The old text keys that nothing plays (Xres, Xrun, TNT*, grp*, asg*... and the melee Xstn/Xwud) are dropped; their audio files
stay in assets/original/audio/. Where the old code answered an event through an alias (shoot -> swing, attack_ack -> Xcat -> ack)
the new set gets that cue written in the field, so what is heard is the same without any alias in the code.
"""
import glob
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile

GAME = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PARITY = "tools/migrate/055o_bodies_parity.json"
SET_SCRIPT = "res://scenes/audio/sound_set.gd"
CUE_SCRIPT = "res://scenes/audio/sound_cue.gd"
CUES_DIR = "data/audio/cues"
WORLD = "data/audio/world.tres"
## The fields of SoundSet in the order of the inspector (SoundEvent.BODY).
FIELDS = ["selected", "ack", "attack_ack", "annoyed", "swing", "shoot", "damaged", "death", "summon", "incantation", "ghost"]
## Old text key of the original -> the field it fills when the set has no key of the field's own name.
CODE_OF = {"attack_ack": "Xcat", "annoyed": "Xann"}
## The old CommandVoice.aliases: the keys tried in order, each through the fallback chain.
COMMAND_KEYS = {
    "selected": ["selected"],
    "ack": ["ack"],
    "attack_ack": ["attack_ack", "Xcat", "ack"],
    "annoyed": ["annoyed", "Xann"],
}
## The old BodySounds.aliases (one hop in the own set, through the fallback chain).
BODY_ALIAS = {"swing": "Xhit", "shoot": "swing"}
CREATURE_EVENTS = ["selected", "ack", "attack_ack", "annoyed", "swing", "shoot", "damaged", "death", "summon"]
WIZARD_EVENTS = ["incantation", "damaged", "death", "ghost"]
MELEE_RENAMES = {"bsaw": "saw"}


def read(path):
    with open(os.path.join(GAME, path), encoding="utf-8") as handle:
        return handle.read()


def write(path, text):
    full = os.path.join(GAME, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)


def slug(text):
    return re.sub(r"[^a-z0-9]+", "_", text.lower()).strip("_")


class Cue:
    """One SoundCue sub-resource: its streams (res:// paths), the ext_resource line of each and its other property lines."""

    def __init__(self, file, sub, streams, ext_lines, props):
        self.file, self.sub = file, sub
        self.streams, self.ext_lines, self.props = streams, ext_lines, props

    def content(self):
        return (tuple(self.streams), tuple(self.props))

    def silent(self):
        return not self.streams


class OldSet:
    """A SoundSet .tres of today: ext_resources, cue sub-resources, the `cues` dictionary and the fallback path."""

    def __init__(self, path):
        self.path = path
        text = read(path)
        ext, subs, self.keys = {}, {}, {}
        fallback_id = None
        section, body = None, None
        for line in text.split("\n"):
            head = re.match(r"^\[(\w+)(.*)\]\s*$", line)
            if head:
                kind, rest = head.group(1), head.group(2)
                section, body = kind, None
                if kind == "ext_resource":
                    ident = re.search(r' id="([^"]+)"', rest).group(1)
                    ext[ident] = (line, re.search(r' path="([^"]+)"', rest).group(1))
                elif kind == "sub_resource":
                    body = []
                    subs[re.search(r' id="([^"]+)"', rest).group(1)] = body
                continue
            if section == "sub_resource" and body is not None and line.strip():
                body.append(line)
            if section == "resource":
                match = re.match(r'^&"([^"]+)": SubResource\("([^"]+)"\)', line)
                if match:
                    self.keys[match.group(1)] = match.group(2)
                match = re.match(r'^fallback = ExtResource\("([^"]+)"\)', line)
                if match:
                    fallback_id = match.group(1)
        self.fallback_path = ext[fallback_id][1].removeprefix("res://") if fallback_id else None
        self.cues = {}
        for key, sub in self.keys.items():
            streams, lines, ext_lines = [], [], {}
            for line in subs[sub]:
                if line.startswith("script = "):
                    continue
                if line.startswith("streams = "):
                    for ident in re.findall(r'ExtResource\("([^"]+)"\)', line):
                        streams.append(ext[ident][1])
                        ext_lines[ext[ident][1]] = ext[ident][0]
                    continue
                lines.append(line)
            self.cues[key] = Cue(path, sub, streams, ext_lines, lines)


def chain(sets, start, key):
    """SoundSet.cue of the old code: the key here, else in the fallback chain (a cue even when silent)."""
    current, hops = start, 0
    while current is not None and hops < 8:
        found = current.cues.get(key)
        if found is not None:
            return found
        current = sets.get(current.fallback_path) if current.fallback_path else None
        hops += 1
    return None


def usable(cue):
    return cue if cue is not None and not cue.silent() else None


def old_body(sets, own, world, event):
    """The old BodySounds.cue_for: the own set, then the alias in it, then the world set."""
    found = chain(sets, own, event) if own else None
    if found is None and own and event in BODY_ALIAS:
        found = chain(sets, own, BODY_ALIAS[event])
    if found is None:
        found = world.cues.get(event)
    return usable(found)


def old_command(sets, own, event):
    """The old CommandVoice.cue_for: the event key and its aliases, each through the fallback chain."""
    if own is None:
        return None
    for key in COMMAND_KEYS[event]:
        found = usable(chain(sets, own, key))
        if found is not None:
            return found
    return None


def old_event(sets, own, world, event):
    return old_command(sets, own, event) if event in COMMAND_KEYS else old_body(sets, own, world, event)


class NewSet:
    """A set with named fields and a fallback, ready to be written."""

    def __init__(self, fallback=None):
        self.fields = {}
        self.fallback = fallback
        self.fallback_path = None

    def resolve(self, event, default):
        current, hops = self, 0
        while current is not None and hops < 8:
            found = current.fields.get(event)
            if found is not None:
                return usable(found)
            current, hops = current.fallback, hops + 1
        return usable(default)


def emit_set(new):
    """The text of a .tres for `new`: its fields, each cue a sub-resource (a cue shared by two fields is one sub-resource)."""
    ext_lines = ['[ext_resource type="Script" path="%s" id="1_set"]' % SET_SCRIPT,
                 '[ext_resource type="Script" path="%s" id="2_cue"]' % CUE_SCRIPT]
    stream_ids = {}
    sub_of = {}
    subs = []
    for field in FIELDS:
        cue = new.fields.get(field)
        if cue is None:
            continue
        key = id(cue)
        if key in sub_of:
            continue
        sub_of[key] = "cue_" + field
        ids = []
        for path in cue.streams:
            if path not in stream_ids:
                stream_ids[path] = "s%d" % (len(stream_ids) + 1)
                ext_lines.append(re.sub(r' id="[^"]+"', ' id="%s"' % stream_ids[path], cue.ext_lines[path]))
            ids.append(stream_ids[path])
        lines = ['[sub_resource type="Resource" id="%s"]' % sub_of[key], 'script = ExtResource("2_cue")']
        lines.append("streams = Array[AudioStream]([%s])" % ", ".join('ExtResource("%s")' % i for i in ids))
        lines.extend(cue.props)
        subs.append("\n".join(lines))
    body = ["[resource]", 'script = ExtResource("1_set")']
    for field in FIELDS:
        cue = new.fields.get(field)
        if cue is not None:
            body.append('%s = SubResource("%s")' % (field, sub_of[id(cue)]))
    if new.fallback_path:
        ext_lines.append('[ext_resource type="Resource" path="res://%s" id="3_fallback"]' % new.fallback_path)
        body.append('fallback = ExtResource("3_fallback")')
    steps = len(ext_lines) + len(subs) + 1
    head = '[gd_resource type="Resource" script_class="SoundSet" load_steps=%d format=3]' % steps
    return head + "\n\n" + "\n".join(ext_lines) + "\n\n" + ("\n\n".join(subs) + "\n\n" if subs else "") + "\n".join(body) + "\n"


def cue_file_text(cue):
    ext = ['[ext_resource type="Script" path="%s" id="1_cue"]' % CUE_SCRIPT]
    ids = []
    for index, path in enumerate(cue.streams, 2):
        ext.append(re.sub(r' id="[^"]+"', ' id="s%d"' % index, cue.ext_lines[path]))
        ids.append("s%d" % index)
    out = ['[gd_resource type="Resource" script_class="SoundCue" load_steps=%d format=3]' % (len(ext) + 1), ""]
    out += ext + ["", "[resource]", 'script = ExtResource("1_cue")']
    out.append("streams = Array[AudioStream]([%s])" % ", ".join('ExtResource("%s")' % i for i in ids))
    out += cue.props
    return "\n".join(out) + "\n"


def catalog_stem(path):
    return os.path.basename(path)[:-5]


def display_name(path):
    match = re.search(r'^display_name\s*=\s*"((?:[^"\\]|\\.)*)"', read(path), re.M)
    return match.group(1) if match else ""


def set_name_rows(creature_files):
    """[(old audio path, new audio path)] for the creature sets: the display name of the creature in snake_case."""
    names = {}
    for old in creature_files:
        stem = catalog_stem(old)
        catalog = "data/catalog/creatures/%s.tres" % stem
        shown = display_name(catalog) if os.path.isfile(os.path.join(GAME, catalog)) else ""
        if not shown:
            sys.exit("%s has no catalog creature with a display_name" % old)
        names[old] = slug(shown)
    count = {}
    for name in names.values():
        count[name] = count.get(name, 0) + 1
    rows = []
    for old, name in names.items():
        if count[name] > 1:  # two creatures with one display name (the two Faestus): the god tells them apart
            god = re.search(r'^god\s*=\s*"([^"]*)"', read("data/catalog/creatures/%s.tres" % catalog_stem(old)), re.M).group(1)
            name = "%s_%s" % (name, slug(god))
        rows.append((old, "data/audio/creatures/%s.tres" % name))
    return rows


def parity_snapshot(sets, world, creatures, wizards):
    """How each creature and wizard of the catalog sounded before: {cues: id -> {streams, props}, bodies: [...]}."""
    cues, ids, bodies = {}, {}, []

    def cue_id(cue):
        if cue is None:
            return None
        digest = hashlib.sha1(json.dumps(cue.content()).encode()).hexdigest()[:10]
        if digest not in cues:
            cues[digest] = {"streams": list(cue.streams), "props": list(cue.props)}
        return digest

    for kind, catalog_files, events, folder in (("creature", creatures, CREATURE_EVENTS, "creatures"),
                                                ("wizard", wizards, WIZARD_EVENTS, "wizards")):
        for path in catalog_files:
            audio = "data/audio/%s/%s.tres" % (folder, catalog_stem(path))
            own = sets.get(audio)
            bodies.append({"kind": kind, "catalog": path, "old_set": audio if own else None,
                           "events": {event: cue_id(old_event(sets, own, world, event)) for event in events}})
    return {"cues": cues, "bodies": bodies}


def build_new(sets, world, creature_rows, wizard_files, melee_rows):
    """The new sets (with the cues copied where the old code answered through an alias) and the patch report."""
    melee_new = {}
    for old, new in melee_rows:
        source = sets[old]
        built = NewSet()
        for field in FIELDS:
            if field in source.cues:
                built.fields[field] = source.cues[field]
        # the swing of a set with no `swing` key is its Xhit; its shoot is the `swing` key it has (no Xhit hop, as before)
        if "swing" not in source.cues and "Xhit" in source.cues:
            built.fields["swing"] = source.cues["Xhit"]
        if "swing" in source.cues:
            built.fields["shoot"] = source.cues["swing"]
        melee_new[old] = built
    patches = []
    out = {}
    summon = world.cues["summon"]
    for kind, rows, events in (("creature", creature_rows, CREATURE_EVENTS), ("wizard", [(f, f) for f in wizard_files], WIZARD_EVENTS)):
        for old, new in rows:
            source = sets[old]
            built = NewSet()
            built.fallback_path = source.fallback_path
            built.fallback = melee_new.get(source.fallback_path) if source.fallback_path else None
            for field in FIELDS:
                key = field if field in source.cues else CODE_OF.get(field)
                if key in source.cues:
                    built.fields[field] = source.cues[key]
            default = summon if kind == "creature" else None
            for event in events:
                target = old_event(sets, source, world, event)
                got = built.resolve(event, default if event == "summon" else None)
                same = (target is None and got is None) or (target is not None and got is not None and target.content() == got.content())
                if same:
                    continue
                if target is None:
                    sys.exit("%s: %s would sound %s and it was silent" % (old, event, got.file))
                if target is summon:
                    sys.exit("%s: %s is the shared summon but the set answers otherwise" % (old, event))
                built.fields[event] = target
                patches.append((new, event, target.file))
            out[old] = (new, built)
    return melee_new, out, patches


def add_ext_and_steps(text, ext_lines, header_re):
    lines = text.split("\n")
    last = max((i for i, ln in enumerate(lines) if ln.startswith("[ext_resource")), default=0)
    lines[last + 1:last + 1] = ext_lines
    joined = "\n".join(lines)
    return re.sub(header_re, lambda m: m.group(1) + str(int(m.group(2)) + len(ext_lines)) + m.group(3), joined, count=1)


def assign_sounds(catalog_path, set_path):
    """Adds `sounds = <set>` to a catalog .tres (an ext_resource and the property at the end of [resource])."""
    text = read(catalog_path)
    if re.search(r"^sounds = ", text, re.M):
        return
    ident = "sounds_set"
    ext = '[ext_resource type="Resource" path="res://%s" id="%s"]' % (set_path, ident)
    lines = text.split("\n")
    last = max(i for i, ln in enumerate(lines) if ln.startswith("[ext_resource"))
    lines.insert(last + 1, ext)
    text = "\n".join(lines).rstrip("\n") + '\nsounds = ExtResource("%s")\n' % ident
    text = re.sub(r"(\[gd_resource [^\]]*?load_steps=)(\d+)", lambda m: m.group(1) + str(int(m.group(2)) + 1), text, count=1)
    write(catalog_path, text)


def convert_fixture(path):
    """A debug fixture that was a set with a `cues` dictionary -> named fields (keys that are not a field are dropped)."""
    source = OldSet(path)
    built = NewSet()
    built.fallback_path = source.fallback_path
    for field in FIELDS:
        key = field if field in source.cues else CODE_OF.get(field)
        if key in source.cues:
            built.fields[field] = source.cues[key]
    write(path, emit_set(built))


def main():
    dry = "--dry-run" in sys.argv
    if os.path.exists(os.path.join(GAME, "data/audio/melee/saw.tres")):
        sys.exit("data/audio/melee/saw.tres exists: this migration runs once (git checkout the data to run it again).")
    creature_files = sorted(glob.glob(os.path.join(GAME, "data/audio/creatures/*.tres")))
    creature_files = [os.path.relpath(p, GAME) for p in creature_files]
    wizard_files = [os.path.relpath(p, GAME) for p in sorted(glob.glob(os.path.join(GAME, "data/audio/wizards/*.tres")))]
    melee_files = [os.path.relpath(p, GAME) for p in sorted(glob.glob(os.path.join(GAME, "data/audio/melee/*.tres")))]
    sets = {path: OldSet(path) for path in creature_files + wizard_files + melee_files}
    world = OldSet(WORLD)
    catalog_creatures = [os.path.relpath(p, GAME) for p in sorted(glob.glob(os.path.join(GAME, "data/catalog/creatures/*.tres")))]
    catalog_wizards = [os.path.relpath(p, GAME) for p in sorted(glob.glob(os.path.join(GAME, "data/catalog/wizards/*.tres")))]

    creature_rows = set_name_rows(creature_files)
    melee_rows = [(f, "data/audio/melee/%s.tres" % MELEE_RENAMES.get(catalog_stem(f), catalog_stem(f))) for f in melee_files]
    snapshot = parity_snapshot(sets, world, catalog_creatures, catalog_wizards)
    # The new fallback path is the renamed melee file; the builder reads the old path, emit_set writes the new one.
    new_melee_path = {old: new for old, new in melee_rows}
    melee_new, bodies_new, patches = build_new(sets, world, creature_rows, wizard_files, melee_rows)
    for old, (new, built) in bodies_new.items():
        built.fallback_path = new_melee_path.get(built.fallback_path) if built.fallback_path else None
    for old, new in melee_rows:
        melee_new[old].fallback_path = None

    print("creature sets renamed: %d" % len(creature_rows))
    for old, new in creature_rows:
        print("  %-34s -> %s" % (old, new))
    for old, new in melee_rows:
        print("  %-34s -> %s" % (old, new))
    print("wizard sets (names kept): %d" % len(wizard_files))
    kinds = {}
    for _new, event, _src in patches:
        kinds[event] = kinds.get(event, 0) + 1
    print("fields written where the old code answered through an alias: %s (%d sets touched)" % (kinds, len({p[0] for p in patches})))
    silent = [b["catalog"] for b in snapshot["bodies"] if b["kind"] == "creature" and not b["old_set"]]
    print("creatures with no set (summon only): %s" % ", ".join(catalog_stem(s) for s in silent))
    dropped = sorted({key for old in creature_files + wizard_files + melee_files for key in sets[old].cues
                      if key not in FIELDS and key not in CODE_OF.values() and key != "Xhit"})
    print("keys dropped (nothing plays them): %s" % ", ".join(dropped))
    if dry:
        return

    # 1. renames (git mv + every reference), through the tool that exists for it
    with tempfile.NamedTemporaryFile("w", suffix=".csv", delete=False) as handle:
        handle.write("old,new\n")
        for old, new in creature_rows + [r for r in melee_rows if r[0] != r[1]]:
            handle.write("%s,%s\n" % (old, new))
        csv_path = handle.name
    code = subprocess.call([sys.executable, os.path.join(GAME, "tools/migrate/rename_resources.py"), "--csv", csv_path, "--apply"])
    os.unlink(csv_path)
    if code != 0:
        sys.exit("rename_resources.py failed (%d)" % code)

    # 2. the new files
    write("%s/summon.tres" % CUES_DIR, cue_file_text(world.cues["summon"]))
    for old, new in melee_rows:
        write(new, emit_set(melee_new[old]))
    for old, (new, built) in bodies_new.items():
        write(new, emit_set(built))
    for path in catalog_creatures:
        match = [new for old, (new, _b) in bodies_new.items() if catalog_stem(old) == catalog_stem(path) and "/creatures/" in old]
        if match:
            assign_sounds(path, match[0])
    for path in catalog_wizards:
        target = "data/audio/wizards/%s.tres" % catalog_stem(path)
        if target in bodies_new:
            assign_sounds(path, target)

    # 3. UnitSounds.summon in unit.tscn
    scene = read("scenes/units/unit.tscn")
    ext = '[ext_resource type="Resource" path="res://%s/summon.tres" id="a055_summon"]' % CUES_DIR
    scene = add_ext_and_steps(scene, [ext], r"(\[gd_scene load_steps=)(\d+)(.*)")
    marker = 'script = ExtResource("a052_sounds")\nbody = NodePath("..")\nhealth = NodePath("../Health")\n'
    if marker not in scene:
        sys.exit("scenes/units/unit.tscn: UnitSounds node not found")
    scene = scene.replace(marker, marker + 'summon = ExtResource("a055_summon")\n', 1)
    write("scenes/units/unit.tscn", scene)

    # 4. fixtures that were sets with a `cues` dictionary
    for path in ("debug/audio/fixtures/lab/body_set.tres", "debug/audio/fixtures/sets/creatures/test.tres",
                 "debug/audio/fixtures/voices/creatures/nmuh.tres", "debug/audio/fixtures/custom_baked/creatures/testmonster.tres",
                 "debug/audio/fixtures/custom_baked/creatures/fixture.tres"):
        if os.path.isfile(os.path.join(GAME, path)):
            convert_fixture(path)

    snapshot["renames"] = [{"old": old, "new": new} for old, new in creature_rows + melee_rows]
    snapshot["dropped_keys"] = dropped
    write(PARITY, json.dumps(snapshot, indent=1, sort_keys=True) + "\n")
    print("wrote %d creature sets, %d wizard sets, %d melee sets, summon cue, %s" % (len(creature_rows), len(wizard_files), len(melee_rows), PARITY))


if __name__ == "__main__":
    main()
