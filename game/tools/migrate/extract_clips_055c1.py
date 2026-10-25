#!/usr/bin/env python3
"""055c1 / c1-c1, step 1 of 2 (no Godot needed): the clip plan, the 85 animation libraries and the 74 model scenes.

What it does (once; the result is committed):
  1. Reads the 74 scenes/bodies/models/<model>.tscn (the Tree states, the `clips` table, the Events method tracks) and the 72
     CreatureType + 15 WizardType .tres (the dictionaries), and builds the plan: for every model, role -> animation, with the
     exact length, the `hit`/`shoot` markers and the method keys. Written to tools/migrate/clips_plan_055c1.json.
  2. Writes scenes/bodies/models/<model>_clips.tres (an AnimationLibrary: role -> Animation) for the 85 models (74 with a scene
     and 11 without one: their Animations have no tracks, only the time the rules read).
  3. Rewrites the 74 scenes: a `Clips` AnimationPlayer with the library, the Tree pointing at it, one state per role that plays
     `&"<role>"` (no custom timeline), no `Events` node.
Step 2 (Godot) writes the ~900 scenes/bodies/models/<model>_clips/<clip>.res the libraries point at:
  bash tools/migrate/run_extract_clips_055c1.sh

Run from game/:  python3 tools/migrate/extract_clips_055c1.py [--dry-run]
It stops if a scene already has `Clips` (already migrated). Prints the conflicts it found (a role two owners name differently).
"""
import glob
import json
import os
import random
import re
import sys

GAME = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MODELS = os.path.join(GAME, "scenes", "bodies", "models")
PLAN_PATH = os.path.join(GAME, "tools", "migrate", "clips_plan_055c1.json")
CREATURES = os.path.join(GAME, "data", "catalog", "creatures")
WIZARDS = os.path.join(GAME, "data", "catalog", "wizards")
RES_DIR = "res://scenes/bodies/models/"

# Same lists as BodyModel (scenes/bodies/body_model.gd): the roles the bodies know, which end by themselves and which hold.
ROLES = ["idle", "run", "walk", "attack", "attack2", "attack3", "shoot", "shoot2", "cast", "cast_run", "hit", "death", "death2", "death3",
         "fly_death", "fall", "held", "thrash", "rise", "fly", "hover", "takeoff", "land", "cower", "talk_cower", "work", "pull", "knock",
         "get_up", "fly_damage", "hit_floor", "gesture", "ghost_rise", "unghost"]
ONE_SHOT = {"attack", "attack2", "attack3", "shoot", "shoot2", "cast", "hit", "rise", "hit_floor", "ghost_rise", "unghost"}
HOLD = {"death", "death2", "death3", "fly_death", "fall"}
FLIGHT = ["takeoff", "fly", "land", "hover"]
STUN = ["knock", "get_up", "fly_damage", "hit_floor"]
EXTRA = ["cower", "talk_cower", "work", "pull"]
DEATH = ["death", "fly_death"]
CAPTIVE = ["rise", "held", "thrash"]
MELEE_ROLES = ["attack", "attack2", "attack3"]
SHOOT_ROLES = ["shoot", "shoot2"]
SCENE_FPS = 30


def kind_of(role):
    return "hold" if role in HOLD else ("once" if role in ONE_SHOT else "loop")


# --- reading the .tres dictionaries -------------------------------------------------------------------------------------------

def read_props(path):
    """name -> python value of the [resource] section (only the clip dictionaries and the plain numbers are decoded)."""
    props = {}
    lines = open(path, encoding="utf-8").read().split("\n")
    in_resource = False
    i = 0
    while i < len(lines):
        line = lines[i]
        if line.startswith("[resource]"):
            in_resource = True
        elif in_resource:
            match = re.match(r"^(\w+) = (.*)$", line)
            if match:
                raw = match.group(2)
                depth = sum(raw.count(c) for c in "{[(") - sum(raw.count(c) for c in "}])")
                while depth > 0:
                    i += 1
                    raw += "\n" + lines[i]
                    depth += sum(lines[i].count(c) for c in "{[(") - sum(lines[i].count(c) for c in "}])")
                props[match.group(1)] = _decode(raw)
        i += 1
    return props


def _decode(raw):
    if raw.startswith("Array[Dictionary]("):
        raw = raw[len("Array[Dictionary]("):-1]
    elif raw.startswith("PackedInt32Array("):
        return [int(x) for x in raw[len("PackedInt32Array("):-1].split(",") if x.strip()]
    try:
        return json.loads(raw)
    except ValueError:
        return raw


def type_roles(props, wizard):
    """role -> {tag, frames, fps, hits, shots} of one CreatureType / WizardType (the translation table of the plan)."""
    out = {}

    def put(role, entry, hits=None, shots=None):
        if not isinstance(entry, dict) or not entry.get("tag") or float(entry.get("frames", 0)) <= 0:
            return
        fps = float(int(round(float(entry.get("framerate", 30)))))
        out[role] = {"tag": entry["tag"], "frames": int(round(float(entry["frames"]))), "fps": int(round(float(entry.get("framerate", 30)))),
                     "hits": [float(t) / fps for t in entry.get("attack_ticks", [])] if hits else [],
                     "shots": [float(t) / fps for t in entry.get("shoot_ticks", [])] if shots else []}

    put("idle", props.get("stance_animation"))
    put("gesture", props.get("idle_animation"))
    put("run", props.get("run_animation"))
    walk = props.get("walk_animation")
    if isinstance(walk, dict) and walk.get("tag") and walk.get("tag") != (props.get("run_animation") or {}).get("tag"):
        put("walk", walk)
    for i, entry in enumerate(props.get("melee_animations") or []):
        if i < len(MELEE_ROLES):
            put(MELEE_ROLES[i], entry, hits=True)
    for i, entry in enumerate(props.get("shoot_animations") or []):
        if i < len(SHOOT_ROLES):
            put(SHOOT_ROLES[i], entry, shots=True)
    for table, names in ((props.get("extra_animations"), EXTRA), (props.get("flight_animations"), FLIGHT), (props.get("stun_animations"), STUN),
                         (props.get("death_animations"), DEATH), (props.get("captive_animations"), CAPTIVE)):
        for role in names:
            if isinstance(table, dict) and role in table:
                put(role, table[role])
    if wizard:
        cast = props.get("cast_animations") or {}
        put("cast", cast.get("cast"))
        put("cast_run", cast.get("run_cast"))
        # No clip tag: the wizard's rules only know how many frames these last (30 fps).
        for role, frames in zip(["death", "death2", "death3"], props.get("death_frames") or []):
            if frames > 0:
                out[role] = {"tag": "", "frames": int(frames), "fps": SCENE_FPS, "hits": [], "shots": []}
        for role, key in (("ghost_rise", "corpse_rise_frames"), ("unghost", "float_to_stance_frames")):
            if int(props.get(key, 0)) > 0:
                out[role] = {"tag": "", "frames": int(props[key]), "fps": SCENE_FPS, "hits": [], "shots": []}
    return out


# --- reading a model scene ----------------------------------------------------------------------------------------------------

def split_sections(text):
    """The file as [(header line, [body lines])]; the first header is [gd_scene]."""
    sections = []
    for line in text.split("\n"):
        if line.startswith("["):
            sections.append((line, []))
        elif sections:
            sections[-1][1].append(line)
    return sections


def header_attrs(header):
    return dict(re.findall(r'(\w+)="([^"]*)"', header))


def read_scene(path):
    text = open(path, encoding="utf-8").read()
    sections = split_sections(text)
    info = {"sections": sections, "glb": "", "states": {}, "state_nodes": {}, "clips": {}, "events": {}}
    ids = {}
    for header, body in sections:
        attrs = header_attrs(header)
        if header.startswith("[ext_resource") and attrs.get("type") == "PackedScene" and "/models/" in attrs.get("path", ""):
            info["glb"] = attrs["path"]
        if header.startswith('[sub_resource type="AnimationNodeAnimation"'):
            ids[attrs["id"]] = dict(re.findall(r"^(\w+) = (.*)$", "\n".join(body), re.M))
        if header.startswith('[sub_resource type="AnimationNodeStateMachine"'):
            for role, sid in re.findall(r'^states/(\w+)/node = SubResource\("([^"]+)"\)', "\n".join(body), re.M):
                info["state_nodes"][role] = sid
    for role, sid in info["state_nodes"].items():
        info["states"][role] = ids[sid]
    root_body = "\n".join(next(b for h, b in sections if h.startswith("[node name=") and 'parent=' not in h))
    for tag, fps, frames in re.findall(r'"(\w+)": \{\n"framerate": (\d+),\n"frames": (\d+),', root_body):
        info["clips"][tag] = {"fps": int(fps), "frames": int(frames)}
    info["events"] = read_events(sections, info["clips"])
    return info


def read_events(sections, clips):
    """tag -> [[seconds, kind]] from the Events library: the Animation sub_resources and the library that names them by tag."""
    anims = {}
    library = {}
    for header, body in sections:
        attrs = header_attrs(header)
        text = "\n".join(body)
        if header.startswith('[sub_resource type="Animation"'):
            times = re.search(r"PackedFloat32Array\(([^)]*)\)", text)
            kinds = re.findall(r'"args": \["(\w+)"\]', text)
            keys = [float(x) for x in times.group(1).split(",")] if times and times.group(1).strip() else []
            if len(keys) != len(kinds):
                raise SystemExit("events: %s has %d times and %d kinds" % (attrs["id"], len(keys), len(kinds)))
            anims[attrs["id"]] = list(zip(keys, kinds))
        elif header.startswith('[sub_resource type="AnimationLibrary"'):
            library = dict(re.findall(r'&"(\w+)": SubResource\("([^"]+)"\)', text))
    out = {}
    for tag, sid in library.items():
        out[tag] = [[_snap(at), kind] for at, kind in anims[sid]]
    return out


def _snap(at):
    """A float32 time printed by Godot (0.46666667) back to its frame at 30 or 20 fps (the Events were baked at the clip's own rate)."""
    for fps in (30, 20):
        frame = round(at * fps)
        if abs(at * fps - frame) < 0.01:
            return frame / float(fps)
    return round(at, 6)


# --- the plan -----------------------------------------------------------------------------------------------------------------

def build_plan():
    scenes = {os.path.basename(p)[:-5]: read_scene(p) for p in sorted(glob.glob(os.path.join(MODELS, "*.tscn")))}
    owners = {}
    for folder, wizard in ((CREATURES, False), (WIZARDS, True)):
        for path in sorted(glob.glob(os.path.join(folder, "*.tres"))):
            props = read_props(path)
            owners.setdefault(props.get("model", ""), []).append((os.path.basename(path), type_roles(props, wizard)))
    conflicts = []
    plan = {}
    for model in sorted(set(scenes) | {m for m in owners if m}):
        plan[model] = build_model(model, scenes.get(model), owners.get(model, []), conflicts)
    return plan, conflicts, scenes


def build_model(model, scene, owner_list, conflicts):
    roles = {}  # role -> {tag, frames, fps, drawn}
    markers = {}  # tag -> {"hit": [seconds], "shoot": [seconds]}
    if scene:
        for role, state in scene["states"].items():
            tag = state["animation"][2:-1]
            clip = scene["clips"].get(tag)
            if clip is None:
                raise SystemExit("%s: role %s plays %s, which the clips table does not list" % (model, role, tag))
            roles[role] = {"tag": tag, "frames": clip["frames"], "fps": clip["fps"], "drawn": True}
    for file, from_type in owner_list:
        for role, entry in from_type.items():
            have = roles.get(role)
            if have is not None and entry["tag"] and (have["tag"] != entry["tag"] or abs(have["frames"] / have["fps"] - entry["frames"] / entry["fps"]) > 1e-4):
                conflicts.append("%s: role %s is %s %d@%d in %s, %s %d@%d in %s" % (model, role, have["tag"], have["frames"], have["fps"],
                                 have.get("owner", "the scene"), entry["tag"], entry["frames"], entry["fps"], file))
                continue
            if have is None:
                roles[role] = {"tag": entry["tag"] or role, "frames": entry["frames"], "fps": entry["fps"], "drawn": False, "owner": file,
                               "tagless": not entry["tag"]}
                have = roles[role]
            elif entry["tag"] and entry["fps"] != have["fps"] and abs(have["frames"] / have["fps"] - entry["frames"] / entry["fps"]) < 1e-4:
                have["frames"], have["fps"] = entry["frames"], entry["fps"]  # the dictionary keeps the clip's own rate (20 fps shoot)
            slot = markers.setdefault(have["tag"], {"hit": None, "shoot": None})
            for name, ticks in (("hit", entry["hits"]), ("shoot", entry["shots"])):
                if not ticks:
                    continue
                if slot[name] is None:
                    slot[name] = ticks
                elif slot[name] != ticks:
                    conflicts.append("%s: clip %s has %s ticks %s in one owner and %s in %s" % (model, have["tag"], name, slot[name], ticks, file))
    return {"scene": scene is not None, "glb": scene["glb"] if scene else "", "roles": roles, "markers": markers,
            "events": scene["events"] if scene else {}, "state_nodes": scene["state_nodes"] if scene else {}}


def finish_plan(plan):
    """Turns each model into {scene, glb, roles: {role: anim file}, anims: {file: {...}}} (the JSON the Godot step reads)."""
    out = {}
    for model, data in plan.items():
        anims = {}  # file -> animation
        by_tag = {}  # tag -> [files] in creation order
        role_file = {}
        ordered = sorted(data["roles"], key=lambda r: (ROLES.index(r) if r in ROLES else 99, r))
        # drawn roles first: they own the tracks; sim-only roles then reuse an Animation of their tag.
        for pass_drawn in (True, False):
            for role in ordered:
                info = data["roles"][role]
                if info["drawn"] != pass_drawn:
                    continue
                tag = info["tag"]
                kind = kind_of(role)
                existing = by_tag.get(tag, [])
                reuse = [f for f in existing if anims[f]["loop"] == kind] or (existing if not pass_drawn else [])
                if reuse:
                    role_file[role] = reuse[0]
                    continue
                file = tag if not existing else "%s_%s" % (tag, kind)
                if file in anims:
                    file = "%s_%s" % (tag, kind)
                mark = data["markers"].get(tag, {})
                anims[file] = {"tag": tag, "frames": info["frames"], "fps": info["fps"], "loop": kind, "tracks": info["drawn"],
                               "hit": mark.get("hit") or [], "shoot": mark.get("shoot") or [],
                               "events": data["events"].get(tag, []) if info["drawn"] else []}
                by_tag.setdefault(tag, []).append(file)
                role_file[role] = file
        for file, anim in anims.items():
            if not anim["hit"] and not anim["shoot"]:
                attack = [at for at, kind in anim["events"] if kind == "attack"]
                if attack:
                    anim["hit"] = [attack[0]]
        out[model] = {"scene": data["scene"], "glb": data["glb"], "roles": {r: role_file[r] for r in ordered}, "anims": anims}
    return out


# --- writing the libraries and the scenes -------------------------------------------------------------------------------------

def write_library(model, data):
    lines = ['[gd_resource type="AnimationLibrary" format=3]', ""]
    files = []
    for role, file in data["roles"].items():
        if file not in files:
            files.append(file)
    ids = {f: "%d_%s" % (i + 1, re.sub(r"\W", "_", f)) for i, f in enumerate(files)}
    for file in files:
        lines.append('[ext_resource type="Animation" path="%s%s_clips/%s.res" id="%s"]' % (RES_DIR, model, file, ids[file]))
    lines += ["", "[resource]", "_data = {"]
    entries = ['&"%s": ExtResource("%s")' % (role, ids[file]) for role, file in data["roles"].items()]
    lines.append(",\n".join(entries))
    lines += ["}", ""]
    return "\n".join(lines)


def rewrite_scene(model, scene, data):
    """The scene text with Clips + role states + no Events. `scene` is read_scene's dict."""
    keep_timeline = {}
    for role, sid in scene["state_nodes"].items():
        state = scene["states"][role]
        frames = scene["clips"][state["animation"][2:-1]]
        length = frames["frames"] / frames["fps"]
        if abs(float(state.get("timeline_length", length)) - length) > 1e-4 or float(state.get("start_offset", 0)) != 0.0:
            keep_timeline[sid] = True
    events_sub = set()
    for header, body in scene["sections"]:
        if header.startswith('[sub_resource type="Animation"') or header.startswith('[sub_resource type="AnimationLibrary"'):
            events_sub.add(header_attrs(header)["id"])
    role_of = {sid: role for role, sid in scene["state_nodes"].items()}
    if len(role_of) != len(scene["state_nodes"]):
        raise SystemExit("%s: two roles share one AnimationNodeAnimation" % model)
    text_all = "\n".join("\n".join([h] + b) for h, b in scene["sections"])
    used_ids = set(re.findall(r"unique_id=(\d+)", text_all))
    rng = random.Random(model)
    while True:
        new_id = str(rng.randint(1000000, 2000000000))
        if new_id not in used_ids:
            break
    out = []
    lib_id = "clips_lib"
    last_ext = max(i for i, (h, _) in enumerate(scene["sections"]) if h.startswith("[ext_resource"))
    for index, (header, body) in enumerate(scene["sections"]):
        attrs = header_attrs(header)
        if header.startswith("[sub_resource") and attrs.get("id") in events_sub:
            continue
        if header.startswith("[node name=\"Events\""):
            continue
        body = list(body)
        if header.startswith('[sub_resource type="AnimationNodeAnimation"') and attrs["id"] in role_of:
            role = role_of[attrs["id"]]
            if attrs["id"] in keep_timeline:
                body = [('animation = &"%s"' % role) if l.startswith("animation = ") else l for l in body]
            else:
                body = [l for l in body if l.strip() == "" or l.startswith("animation = ")]
                body = [('animation = &"%s"' % role) if l.startswith("animation = ") else l for l in body]
        if header.startswith('[node name="Tree"'):
            out.append(('[node name="Clips" type="AnimationPlayer" parent="." unique_id=%s]' % new_id,
                        ['unique_name_in_owner = true', 'root_node = NodePath("../Model")', 'libraries/ = ExtResource("%s")' % lib_id, ""]))
            body = [('anim_player = NodePath("../Clips")') if l.startswith("anim_player = ") else l for l in body]
        if index == last_ext:
            out.append((header, []))
            out.append(('[ext_resource type="AnimationLibrary" path="%s%s_clips.tres" id="%s"]' % (RES_DIR, model, lib_id), body))
        else:
            out.append((header, body))
    return "\n".join("\n".join([h] + b) for h, b in out)


def main():
    dry = "--dry-run" in sys.argv
    scene_files = sorted(glob.glob(os.path.join(MODELS, "*.tscn")))
    if any("[node name=\"Clips\"" in open(p, encoding="utf-8").read() for p in scene_files):
        raise SystemExit("already migrated: a scene has Clips (the plan is in %s)" % PLAN_PATH)
    plan, conflicts, scenes = build_plan()
    final = finish_plan(plan)
    lower = {}
    for model, data in final.items():
        if model.lower() in lower:
            raise SystemExit("two models differ only by case: %s / %s" % (model, lower[model.lower()]))
        lower[model.lower()] = model
        seen = {}
        for file in data["anims"]:
            if file.lower() in seen:
                raise SystemExit("%s: files %s / %s differ only by case" % (model, file, seen[file.lower()]))
            seen[file.lower()] = file
    anim_count = sum(len(d["anims"]) for d in final.values())
    track_count = sum(1 for d in final.values() for a in d["anims"].values() if a["tracks"])
    print("models=%d (with scene %d) animations=%d with_tracks=%d" % (len(final), sum(1 for d in final.values() if d["scene"]), anim_count, track_count))
    for line in conflicts:
        print("CONFLICT " + line)
    print("conflicts=%d" % len(conflicts))
    if dry:
        return
    with open(PLAN_PATH, "w", encoding="utf-8") as handle:
        json.dump({"version": 1, "models": final}, handle, indent=1, sort_keys=True)
        handle.write("\n")
    for model, data in final.items():
        with open(os.path.join(MODELS, model + "_clips.tres"), "w", encoding="utf-8") as handle:
            handle.write(write_library(model, data))
        if data["scene"]:
            with open(os.path.join(MODELS, model + ".tscn"), "w", encoding="utf-8") as handle:
                handle.write(rewrite_scene(model, scenes[model], data))
    print("wrote %s, %d libraries, %d scenes" % (PLAN_PATH, len(final), sum(1 for d in final.values() if d["scene"])))


if __name__ == "__main__":
    main()
