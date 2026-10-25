#!/usr/bin/env python3
"""Step 2 of 2 of the 055s materials bake (step 1: tools/bake/bake_materials_055s.gd, which writes the json).

Saves the material of every surface inside the 74 model scenes (scenes/bodies/models/<tag>.tscn) as a
`surface_material_override/<i>` on the mesh of the instanced .glb, and drops the `surface_parts` line the scenes carried.

Run from game/:  python3 tools/bake/bake_materials_055s.py [--check]
--check changes nothing and prints what it would do. Running it twice is safe: a scene that already has the overrides is skipped.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "tools/bake/bake_materials_055s.json"
MODELS = ROOT / "scenes/bodies/models"
ID_PREFIX = "mat_"


def res_id(path):
    return ID_PREFIX + Path(path).stem


def node_block_end(lines, start):
    """Index of the first line after the [node ...] block that starts at `start`."""
    for i in range(start + 1, len(lines)):
        if lines[i].startswith("["):
            return i
    return len(lines)


def edit(text, entry, materials):
    lines = text.split("\n")
    if any(l.startswith("[ext_resource") and ('id="%s' % ID_PREFIX) in l for l in lines):
        return None  # already baked
    by_mesh = {}
    for o in entry["overrides"]:
        by_mesh.setdefault((o["node"], o["index"]), []).append(o)
    used = sorted({o["material"] for o in entry["overrides"]})
    # ext_resource goes after the last ext_resource and before any sub_resource.
    last_ext = max((i for i, l in enumerate(lines) if l.startswith("[ext_resource")), default=0)
    new_ext = []
    for path in used:
        uid = materials.get(path, "")
        new_ext.append('[ext_resource type="Material" %spath="%s" id="%s"]' % ('uid="%s" ' % uid if uid else "", path, res_id(path)))
    lines[last_ext + 1:last_ext + 1] = new_ext
    # The override nodes go right after the `Model` instance, before the Ragdoll and the rest.
    model_at = next((i for i, l in enumerate(lines) if l.startswith('[node name="Model" parent="."')), -1)
    if model_at < 0:
        raise ValueError("no Model node")
    at = node_block_end(lines, model_at)
    block = []
    for (node, index), overrides in sorted(by_mesh.items(), key=lambda kv: (kv[0][0], kv[0][1])):
        parent, _, name = node.rpartition("/")
        parent_path = "Model/" + parent if parent else "Model"
        block.append('[node name="%s" parent="%s" index="%d"]' % (name, parent_path, index))
        for o in sorted(overrides, key=lambda o: o["surface"]):
            block.append('surface_material_override/%d = ExtResource("%s")' % (o["surface"], res_id(o["material"])))
        block.append("")
    lines[at:at] = block
    out = [l for l in lines if not re.match(r"^surface_parts = ", l)]
    return "\n".join(out)


def main():
    check = "--check" in sys.argv
    report = json.loads(REPORT.read_text())
    materials = report["materials"]
    done = skipped = 0
    for name, entry in sorted(report["models"].items()):
        path = MODELS / (name + ".tscn")
        if not entry["overrides"]:
            print("%s: no textured surface, only surface_parts removed" % name)
            if not check:
                path.write_text(re.sub(r"(?m)^surface_parts = .*\n", "", path.read_text()))
            continue
        new_text = edit(path.read_text(), entry, materials)
        if new_text is None:
            skipped += 1
            continue
        if not check:
            path.write_text(new_text)
        done += 1
    print("models edited=%d already_baked=%d materials=%d%s" % (done, skipped, len(materials), " (check only)" if check else ""))


if __name__ == "__main__":
    main()
