"""Minimal glTF 2.0 binary (.glb) writer shared by the importers (RFC-033 033c; extracted from export_skeletal.py).

Written from the glTF 2.0 specification. No sacengine code. Deterministic: same input, same bytes.

    g = Gltf()
    acc = g.accessor(struct.pack(...), FLOAT, count, "VEC3", ARRAY_BUFFER, lo, hi)
    write_glb(path, doc_without_buffers, g)       # fills accessors / bufferViews / buffers and packs the file
"""

import json
import struct
from pathlib import Path

FLOAT, USHORT, UINT = 5126, 5123, 5125
ARRAY_BUFFER, ELEMENT_ARRAY_BUFFER = 34962, 34963


class Gltf:
    """One binary buffer with its bufferViews and accessors."""

    def __init__(self):
        self.blob = bytearray()
        self.views, self.accessors = [], []

    def view(self, raw: bytes, target=None):
        while len(self.blob) % 4:
            self.blob.append(0)
        v = {"buffer": 0, "byteOffset": len(self.blob), "byteLength": len(raw)}
        if target:
            v["target"] = target
        self.blob += raw
        self.views.append(v)
        return len(self.views) - 1

    def accessor(self, raw, ctype, count, atype, target=None, lo=None, hi=None):
        a = {"bufferView": self.view(raw, target), "componentType": ctype, "count": count, "type": atype}
        if lo is not None:
            a["min"], a["max"] = lo, hi
        self.accessors.append(a)
        return len(self.accessors) - 1


def write_glb(path: Path, doc: dict, g: Gltf) -> None:
    """Completes `doc` with the accessors, bufferViews and buffer of `g` and writes the .glb at `path`."""
    doc["accessors"] = g.accessors
    doc["bufferViews"] = g.views
    doc["buffers"] = [{"byteLength": len(g.blob)}]
    js = json.dumps(doc, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    blob = bytes(g.blob) + b"\0" * (-len(g.blob) % 4)
    total = 12 + 8 + len(js) + 8 + len(blob)
    path.write_bytes(
        struct.pack("<III", 0x46546C67, 2, total)
        + struct.pack("<II", len(js), 0x4E4F534A) + js
        + struct.pack("<II", len(blob), 0x004E4942) + blob
    )


def import_params(animation: bool, exact: bool = False, tangents: bool = True, import_script: str = "") -> str:
    """The text of the .glb.import for a model: `animation` True for skeletal models (RFC-023), False for static props.
    `exact` keeps the vertices as float32: by default Godot stores positions in 16 bits over the mesh box (0.3 mm on a
    14 m building), which is more than the parity of RFC-033 allows. `tangents` is ensure_tangents: only a model with a normal
    map needs them. `import_script`: res:// path of an EditorScenePostImport script (skeletal models: the scene importer
    drops a third of the animation keys and ignores its own optimizer options, so tools/skeletal_post_import.gd puts the
    clips back as the .glb stores them)."""
    return (
        "[remap]\n\nimporter=\"scene\"\ntype=\"PackedScene\"\n\n[params]\n\n"
        "nodes/root_type=\"\"\nnodes/root_name=\"\"\nnodes/apply_root_scale=true\nnodes/root_scale=1.0\n"
        "meshes/ensure_tangents=%s\n%smeshes/generate_lods=false\nmeshes/create_shadow_meshes=false\n"
        "meshes/light_baking=0\nskins/use_named_skins=true\n"
        "animation/import=%s\nanimation/fps=30\nanimation/trimming=false\nanimation/remove_immutable_tracks=false\n"
        "animation/import_rest_as_RESET=false\n"
        "import_script/path=\"%s\"\n_subresources={}\ngltf/naming_version=2\ngltf/embedded_image_handling=1\n"
    ) % ("true" if tangents else "false", "meshes/force_disable_compression=true\n" if exact else "", "true" if animation else "false", import_script)
