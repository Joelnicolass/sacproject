#!/usr/bin/env python3
"""055d-d2 (one-off), step 1 `buildings`: every MapBuilding of a layout.tscn becomes an instance of its building scene.
Step 2 `flatten` (below) moves Buildings and NpcSpawns into the map scene itself.

Run from game/: python3 tools/migrate/d2_layouts.py buildings|flatten
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAPS = ROOT / "scenes/map/maps"
LAYOUTS = ["high_noon", "peaks", "peasantville", "roads", "winter_wonder"]
DROP_PROPS = ("script =", "building =", "visuals =", "collision =", "sync =", "health_bar =", "collision_mask =",
              "max_health_override = 0.0", "owner_slot = 0")


def split_blocks(text: str) -> tuple[list[str], list[list[str]]]:
    header, blocks = [], []
    for line in text.split("\n"):
        if line.startswith("[ext_resource") or line.startswith("[gd_scene") or line.startswith("[sub_resource"):
            header.append(line)
        elif line.startswith("[node"):
            blocks.append([line])
        elif blocks:
            blocks[-1].append(line)
    return header, blocks


def ext_map(header: list[str]) -> dict[str, dict]:
    found = {}
    for line in header:
        m = re.match(r'\[ext_resource type="([^"]+)"(?: uid="[^"]*")? path="([^"]+)" id="([^"]+)"\]', line)
        if m:
            found[m.group(3)] = {"type": m.group(1), "path": m.group(2), "line": line}
    return found


def buildings_step() -> None:
    for tag in LAYOUTS:
        path = MAPS / tag / "layout.tscn"
        header, blocks = split_blocks(path.read_text())
        ext = ext_map(header)
        new_ids: dict[str, str] = {}
        new_ext: list[str] = []
        out_blocks = []
        for block in blocks:
            head = block[0]
            m = re.search(r'instance=ExtResource\("([^"]+)"\)', head)
            if m is None or ext[m.group(1)]["path"] != "res://scenes/map/map_building.tscn":
                out_blocks.append(block)
                continue
            tres = ext[re.search(r'^building = ExtResource\("([^"]+)"\)', "\n".join(block), re.M).group(1)]["path"]
            scene_path = "res://scenes/structures/buildings/%s.tscn" % Path(tres).stem
            if scene_path not in new_ids:
                new_ids[scene_path] = "b%d_%s" % (len(new_ids) + 1, Path(tres).stem)
                new_ext.append('[ext_resource type="PackedScene" path="%s" id="%s"]' % (scene_path, new_ids[scene_path]))
            name = re.search(r'name="([^"]*)"', head).group(1)
            parent = re.search(r'parent="([^"]*)"', head).group(1)
            uid = re.search(r"unique_id=(\d+)", head)
            new_head = '[node name="%s" parent="%s"%s instance=ExtResource("%s")]' % (
                name, parent, (" unique_id=" + uid.group(1)) if uid else "", new_ids[scene_path])
            body = [line for line in block[1:] if line and not line.startswith(DROP_PROPS)]
            for line in body:
                assert line.startswith("transform"), (tag, name, line)
            out_blocks.append([new_head] + body + [""])
        body_text = "\n".join("\n".join(b) for b in out_blocks)
        keep = [ext[i]["line"] for i in ext
                if 'ExtResource("%s")' % i in body_text and ext[i]["path"] not in ("res://scenes/map/map_building.tscn",)]
        text = "[gd_scene format=3]\n\n" + "\n".join(keep + new_ext) + "\n\n" + body_text.rstrip("\n") + "\n"
        text = re.sub(r"\n{3,}", "\n\n", text)
        path.write_text(text)
        print(tag, "buildings:", len(new_ids), "scenes")


def pascal(stem: str) -> str:
    return "".join(part.capitalize() for part in stem.strip("_").split("_"))


def creature_name(path: str) -> str:
    text = (ROOT / path.replace("res://", "")).read_text()
    return re.search(r'^display_name = "([^"]*)"', text, re.M).group(1).replace(" ", "")


def flatten_step() -> None:
    for tag in LAYOUTS:
        layout = (MAPS / tag / "layout.tscn").read_text()
        l_header, l_blocks = split_blocks(layout)
        l_ext = ext_map(l_header)
        map_path = MAPS / tag / "map.tscn"
        text = map_path.read_text()
        m_header = [line for line in text.split("\n") if line.startswith("[ext_resource")]
        m_ext = ext_map(m_header)
        used_ids = set(m_ext)
        added: list[str] = []
        remap: dict[str, str] = {}

        def ext_for(old_id: str) -> str:
            if old_id in remap:
                return remap[old_id]
            info = l_ext[old_id]
            new_id = "d2_%s" % re.sub(r"\W", "_", Path(info["path"]).stem)
            while new_id in used_ids:
                new_id += "x"
            used_ids.add(new_id)
            remap[old_id] = new_id
            added.append('[ext_resource type="%s" path="%s" id="%s"]' % (info["type"], info["path"], new_id))
            return new_id

        counters: dict[str, int] = {}
        buildings, npcs = [], []
        for block in l_blocks:
            head = block[0]
            parent = re.search(r'parent="([^"]*)"', head)
            if parent is None:
                continue
            name = re.search(r'name="([^"]*)"', head).group(1)
            inst = re.search(r'instance=ExtResource\("([^"]+)"\)', head)
            if inst is None:
                continue
            body = [line for line in block[1:] if line]
            if parent.group(1) == "Buildings":
                stem = Path(l_ext[inst.group(1)]["path"]).stem
                counters[stem] = counters.get(stem, 0) + 1
                new_name = "%s_%02d" % (pascal(stem), counters[stem])
                buildings.append(['[node name="%s" parent="Buildings" instance=ExtResource("%s")]' % (new_name, ext_for(inst.group(1)))] + body + [""])
            elif parent.group(1) == "NpcSpawns":
                keep = []
                creature = ""
                for line in body:
                    if line.startswith(("script =", "gizmo_extents", "ntts_id")):
                        continue
                    if line.startswith("creature ="):
                        old = re.search(r'ExtResource\("([^"]+)"\)', line).group(1)
                        creature = creature_name(l_ext[old]["path"])
                        line = 'creature = ExtResource("%s")' % ext_for(old)
                    keep.append(line)
                counters[creature] = counters.get(creature, 0) + 1
                npcs.append(['[node name="%s_%02d" parent="Npcs" instance=ExtResource("%s")]' % (creature, counters[creature], ext_for(inst.group(1)))] + keep + [""])
            else:
                sys.exit("unexpected parent %s in %s" % (parent.group(1), tag))
        layout_id = next(i for i, info in m_ext.items() if info["path"].endswith("/layout.tscn"))
        m = re.search(r'\[node name="(\w+Layout)" parent="\." (?:unique_id=\d+ )?instance=ExtResource\("%s"\)\]\n' % layout_id, text)
        assert m, tag
        folder = ['[node name="Buildings" type="Node3D" parent="."]', ""] + [l for b in buildings for l in b] \
            + ['[node name="Npcs" type="Node3D" parent="."]', ""] + [l for b in npcs for l in b]
        text = text.replace(m.group(0), "\n".join(folder) + "\n")
        text = text.replace(m_ext[layout_id]["line"] + "\n", "")
        # the sockets
        layout_name = m.group(1)
        text = text.replace('"buildings_root", "npc_spawns_root"', '"buildings", "npcs"')
        text = text.replace('buildings_root = NodePath("%s/Buildings")' % layout_name, 'buildings = NodePath("Buildings")')
        text = text.replace('npc_spawns_root = NodePath("%s/NpcSpawns")' % layout_name, 'npcs = NodePath("Npcs")')
        # new external resources go after the last existing one
        last = max(text.rfind(line) for line in m_header if line in text and line != m_ext[layout_id]["line"])
        end = text.index("\n", last) + 1
        text = text[:end] + "\n".join(added) + "\n" + text[end:]
        map_path.write_text(re.sub(r"\n{3,}", "\n\n", text))
        print(tag, "buildings", len(buildings), "npcs", len(npcs))


if __name__ == "__main__":
    if sys.argv[1:] == ["buildings"]:
        buildings_step()
    elif sys.argv[1:] == ["flatten"]:
        flatten_step()
    else:
        sys.exit("usage: d2_layouts.py buildings|flatten")
