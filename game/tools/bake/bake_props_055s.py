#!/usr/bin/env python3
"""Steps 1 and 3 of 3 of the 055s props bake (step 2: tools/bake/bake_props_055s.gd, which needs Godot).

The props (buildings, plants, rocks) used to be dressed at run time: BodyVisual / BodyCatalog.mesh(tag) read the prop .glb of
assets/original/props/ and put the OriginalMaterial of each surface on it. After this bake every use holds its mesh: an ArrayMesh
.res in scenes/props/meshes/<tag>.res with its materials saved (scenes/bodies/materials/*.tres), and the scene or the .tres
that used the tag points at it.

  1. python3 tools/bake/bake_props_055s.py --list
        writes tools/bake/bake_props_055s_tags.json: every prop tag some scene, species or shot uses.
  2. "$GODOT" --headless --path . --script res://tools/bake/bake_props_055s.gd
        writes scenes/props/meshes/*.res and tools/bake/bake_props_055s.json (what the step 3 needs).
     "$GODOT" --headless --path . --script res://tools/bake/check_props_055s.gd
        compares every saved surface with what OriginalMaterial builds today, property by property (exit 1 on a difference).
  3. python3 tools/bake/bake_props_055s.py --apply [--check]
        rewrites the scenes and .tres: a BodyVisual part becomes a MeshInstance3D with `mesh`, a species and a shot look get
        `mesh` instead of `model`, the rock / snowball / debris / mole scenes get their mesh. --check changes nothing.

Running step 3 twice is safe: what is already converted is skipped.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TAGS = ROOT / "tools/bake/bake_props_055s_tags.json"
REPORT = ROOT / "tools/bake/bake_props_055s.json"

VISUAL_SCRIPT = "res://scenes/bodies/body_visual.gd"
PROP_LOOK_SCRIPT = "res://scenes/spells/carrier/prop_look.gd"
## The scenes whose BodyVisual parts show a prop (a building part, a map prop). The preview of a wizard (BodyVisual without
## `model`) and the creatures are not here.
VISUAL_DIRS = ["scenes/structures/buildings", "scenes/props", "scenes/map/props"]
SPECIES_DIR = "data/vegetation/species"
SHOTS_DIR = "data/shots"
PROP_LOOK_DIR = "scenes/spells"

## Scenes that get a mesh on a node (header text, properties dropped, property that takes the mesh, tag). The tag is the prop the
## script used to draw by default or by `model`.
NODE_EDITS = [
    ("scenes/spells/zones/debris_piece.tscn", '[node name="Rock" type="MeshInstance3D" parent="."]', [], "mesh", "bold"),
    ("scenes/spells/carrier/cow_rock.tscn", '[node name="CowRock" type="Node3D"', ["model = "], None, None),
    ("scenes/spells/carrier/cow_rock.tscn", '[node name="Rock" type="MeshInstance3D" parent="."]', [], "mesh", "rock"),
    ("scenes/spells/zones/frozen_ground.tscn", '[node name="Ball" type="MeshInstance3D" parent="Snowball"]', [], "mesh", "sbll"),
    ("scenes/spells/rock_projectile.tscn", '[node name="RockProjectile" type="Node3D"]', [], "rock_mesh", "rock"),
    ("scenes/units/abilities/rockform.tscn", '[node name="Rockform" type="Node"]', [], "rock_mesh", "rock"),
    ("scenes/map/props/manafount.tscn", '[node name="Manafount" type="StaticBody3D"', [], "fallback_mesh", "pcfn"),
]
## Tags a script drew by default (no scene says them): the list step adds them so the .gd bakes them.
DEFAULT_TAGS = {"bold": "debris_piece.tscn", "sbll": "frozen_ground.tscn", "rock": "rock_projectile.tscn, rockform.tscn, cow_rock.tscn",
                "pcfn": "manafount_body.gd (FALLBACK)"}

BLOCK = re.compile(r"^\[(gd_scene|gd_resource|ext_resource|sub_resource|node|connection|editable|resource)\b")
MODEL = re.compile(r'^model = "([^"]*)"\s*$')


class Doc:
    """A .tscn / .tres as blocks: the [header] line and the property lines under it."""

    def __init__(self, text):
        self.blocks = []
        for line in text.split("\n"):
            if BLOCK.match(line) or not self.blocks:
                self.blocks.append([line, []])
            else:
                self.blocks[-1][1].append(line)

    def text(self):
        out = []
        for head, body in self.blocks:
            out.append(head)
            out.extend(body)
        return "\n".join(out)

    def heads(self, kind):
        return [b for b in self.blocks if b[0].startswith("[" + kind)]

    def ext_id(self, path):
        for head, _ in self.heads("ext_resource"):
            if 'path="%s"' % path in head:
                return re.search(r' id="([^"]+)"', head).group(1)
        return None

    def uses(self, ext_id):
        needle = 'ExtResource("%s")' % ext_id
        return any(needle in head or any(needle in l for l in body) for head, body in self.blocks if not head.startswith("[ext_resource"))

    def drop_ext(self, ext_id):
        self.blocks = [b for b in self.blocks if not (b[0].startswith("[ext_resource") and ' id="%s"' % ext_id in b[0])]

    def add_ext(self, entry):
        """The mesh's ext_resource goes after the last ext_resource (before any sub_resource)."""
        if any(('id="%s"' % entry["id"]) in b[0] for b in self.heads("ext_resource")):
            return
        uid = 'uid="%s" ' % entry["uid"] if entry.get("uid") else ""
        head = '[ext_resource type="ArrayMesh" %spath="%s" id="%s"]' % (uid, entry["path"], entry["id"])
        last = max((i for i, b in enumerate(self.blocks) if b[0].startswith("[ext_resource")), default=0)
        trailing = self.blocks[last][1]
        self.blocks[last][1] = []
        self.blocks.insert(last + 1, [head, trailing])

    def fix_steps(self):
        head = self.blocks[0][0]
        if "load_steps=" in head:
            count = len(self.heads("ext_resource")) + len(self.heads("sub_resource")) + 1
            self.blocks[0][0] = re.sub(r"load_steps=\d+", "load_steps=%d" % count, head)


def set_property(body, line):
    """Puts a property line after the last property of a block (before its trailing blank lines)."""
    last = max((i for i, l in enumerate(body) if l.strip()), default=-1)
    body.insert(last + 1, line)


def mesh_entry(report, tag):
    info = report["props"].get(tag.lower())
    if info is None:
        raise KeyError("no baked mesh for the prop '%s' (is it in %s?)" % (tag, TAGS.name))
    return {"id": "mesh_" + re.sub(r"\W", "_", tag.lower()), "path": info["path"], "uid": info.get("uid", "")}


def convert_nodes(doc, script_path, report, wanted_mesh_property="mesh"):
    """Nodes with `script_path` and a `model = "tag"` line become plain nodes with `mesh = ExtResource(...)`. Returns how many."""
    sid = doc.ext_id(script_path)
    if sid is None:
        return 0
    done = 0
    for head, body in doc.heads("node"):
        if 'script = ExtResource("%s")' % sid not in body:
            continue
        model = next((MODEL.match(l) for l in body if MODEL.match(l)), None)
        if model is None or not model.group(1):
            continue
        entry = mesh_entry(report, model.group(1))
        doc.add_ext(entry)
        body[:] = [l for l in body if not (l == 'script = ExtResource("%s")' % sid or l.startswith("model = ") or l.startswith("stand_on_feet = "))]
        set_property(body, '%s = ExtResource("%s")' % (wanted_mesh_property, entry["id"]))
        done += 1
    if done and not doc.uses(sid):
        doc.drop_ext(sid)
    return done


def convert_resource(doc, report):
    """A species or a shot look: `model` (or, for a species, the tag) -> `mesh`. Returns 1 when the file changed."""
    for head, body in doc.blocks:
        if head != "[resource]":
            continue
        if any(l.startswith("mesh = ") for l in body):
            return 0
        model = next((MODEL.match(l) for l in body if MODEL.match(l)), None)
        tag = model.group(1) if model else ""
        if not tag:
            tag_line = next((re.match(r'^tag = "([^"]*)"', l) for l in body if l.startswith("tag = ")), None)
            tag = tag_line.group(1) if tag_line and "VegetationSpecies" in doc.blocks[0][0] else ""
        if not tag:
            return 0
        entry = mesh_entry(report, tag)
        doc.add_ext(entry)
        body[:] = [l for l in body if not l.startswith("model = ")]
        set_property(body, 'mesh = ExtResource("%s")' % entry["id"])
        return 1
    return 0


def edit_node(doc, header, drop, prop, tag, report):
    changed = 0
    for head, body in doc.heads("node"):
        if not head.startswith(header):
            continue
        if prop and any(l.startswith(prop + " = ") for l in body):
            continue
        before = len(body)
        body[:] = [l for l in body if not any(l.startswith(d) for d in drop)]
        changed += before - len(body)
        if prop:
            entry = mesh_entry(report, tag)
            doc.add_ext(entry)
            set_property(body, '%s = ExtResource("%s")' % (prop, entry["id"]))
            changed += 1
    return changed


def scenes(*dirs, suffix=".tscn"):
    for d in dirs:
        for path in sorted((ROOT / d).rglob("*" + suffix)):
            yield path


def list_tags():
    users = {}

    def note(tag, path):
        users.setdefault(tag, set()).add(str(Path(path).relative_to(ROOT)) if Path(path).is_absolute() else str(path))

    for path in scenes(*VISUAL_DIRS):
        doc = Doc(path.read_text())
        sid = doc.ext_id(VISUAL_SCRIPT)
        for head, body in doc.heads("node"):
            if sid and 'script = ExtResource("%s")' % sid in body:
                for line in body:
                    m = MODEL.match(line)
                    if m and m.group(1):
                        note(m.group(1), path)
    for path in scenes(PROP_LOOK_DIR):
        doc = Doc(path.read_text())
        sid = doc.ext_id(PROP_LOOK_SCRIPT)
        for head, body in doc.heads("node"):
            if sid and 'script = ExtResource("%s")' % sid in body:
                for line in body:
                    m = MODEL.match(line)
                    if m and m.group(1):
                        note(m.group(1), path)
    for path in scenes(SPECIES_DIR, suffix=".tres"):
        body = Doc(path.read_text()).heads("resource")[0][1]
        model = next((MODEL.match(l) for l in body if MODEL.match(l)), None)
        tag = next((re.match(r'^tag = "([^"]*)"', l) for l in body if l.startswith("tag = ")), None)
        prop = (model.group(1) if model and model.group(1) else (tag.group(1) if tag else ""))
        if prop:
            note(prop, path)
    for path in scenes(SHOTS_DIR, suffix=".tres"):
        body = Doc(path.read_text()).heads("resource")[0][1]
        model = next((MODEL.match(l) for l in body if MODEL.match(l)), None)
        if model and model.group(1):
            note(model.group(1), path)
    for tag, where in DEFAULT_TAGS.items():
        users.setdefault(tag, set()).add(where)
    out = {"tags": sorted(users, key=str.lower), "users": {t: sorted(u) for t, u in sorted(users.items(), key=lambda kv: kv[0].lower())}}
    TAGS.write_text(json.dumps(out, indent="\t") + "\n")
    print("props used: %d tags (%d uses) -> %s" % (len(out["tags"]), sum(len(u) for u in users.values()), TAGS.relative_to(ROOT)))


def apply(check):
    report = json.loads(REPORT.read_text())
    counts = {"visual parts": 0, "visual scenes": 0, "prop looks": 0, "species": 0, "shots": 0, "node edits": 0}

    def write(path, doc, key, n):
        if n == 0:
            return
        counts[key] += n
        if key in ("visual parts", "prop looks"):
            counts["visual scenes" if key == "visual parts" else "prop looks"] += 0
        doc.fix_steps()
        if not check:
            path.write_text(doc.text())

    for path in scenes(*VISUAL_DIRS):
        doc = Doc(path.read_text())
        n = convert_nodes(doc, VISUAL_SCRIPT, report)
        if n:
            counts["visual scenes"] += 1
        write(path, doc, "visual parts", n)
    for path in scenes(PROP_LOOK_DIR):
        doc = Doc(path.read_text())
        write(path, doc, "prop looks", convert_nodes(doc, PROP_LOOK_SCRIPT, report))
    for path in scenes(SPECIES_DIR, suffix=".tres"):
        doc = Doc(path.read_text())
        write(path, doc, "species", convert_resource(doc, report))
    for path in scenes(SHOTS_DIR, suffix=".tres"):
        doc = Doc(path.read_text())
        write(path, doc, "shots", convert_resource(doc, report))
    seen = {}
    for rel, header, drop, prop, tag in NODE_EDITS:
        path = ROOT / rel
        doc = seen.get(rel) or Doc(path.read_text())
        seen[rel] = doc
        counts["node edits"] += edit_node(doc, header, drop, prop, tag, report)
    for rel, doc in seen.items():
        doc.fix_steps()
        if not check:
            (ROOT / rel).write_text(doc.text())
    print("%s: %s" % ("check only" if check else "applied", ", ".join("%s=%d" % kv for kv in counts.items())))


def main():
    args = sys.argv[1:]
    if "--list" in args:
        list_tags()
    elif "--apply" in args:
        apply("--check" in args)
    else:
        print(__doc__)
        sys.exit(2)


if __name__ == "__main__":
    main()
