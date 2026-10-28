#!/usr/bin/env python3
"""Needs the original game installed (SAC_INSTALL). See tools/import/local.cfg.example.

Imports Dragonfire's dragon (`dfir`, models.wad) to assets/original/props/dfir.glb with its 5 animation frames as blend shapes.

The MRMM of `dfir` holds 97 vertices and 5 frames of vertex positions (the wing beats); import_props.py only reads the first
one. This script reads all five, writes the two textures (M000 the body, M001 the wings: 128x128 with alpha) next to the model as
props/dfir_M000.png and props/dfir_M001.png, and asks Blender (CLI, no UI) to build the mesh with 4 shape keys (frames 1..4 over frame
0) and export it as glTF morph targets. Nothing is modelled: the dragon is the original's. The mesh has two materials named after the
texture labels (M000, M001); the scene that uses it (scenes/spells/carrier/dragon_look.tscn) puts its own unshaded alpha material on
each and drives the weights with an AnimationPlayer.

  python3 tools/import/import_dragonfire.py            # write
  BLENDER_BIN=/path/to/blender python3 tools/import/import_dragonfire.py

Deterministic: the files are only rewritten when the bytes change. An existing .glb.import / .png.import is never touched.
"""

import json
import os
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sac_formats import txtr, wad  # noqa: E402
from sac_formats.install import INSTALL  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "original" / "props"
BLENDER = os.environ.get("BLENDER_BIN") or "/Applications/Blender.app/Contents/MacOS/Blender"
MODEL = "dfir"


def _le(raw: bytes, at: int) -> int:
    return int.from_bytes(raw[at:at + 4], "little")


def read_frames(raw: bytes):
    """(frames, uvs, faces): frames[k][i] = (x, y, z) in Godot's axes (x, z, y of the file); faces = (a, b, c, label) of the top LOD."""
    num_v, num_f, num_frames = _le(raw, 4), _le(raw, 12), _le(raw, 24)
    v_off, f_off = _le(raw, 184), _le(raw, 188)
    frames = []
    uvs = []
    for k in range(num_frames):
        frame = []
        for i in range(num_v):
            x, y, z, u, v = struct.unpack_from("<fffff", raw, v_off + (k * num_v + i) * 40)
            frame.append((round(x, 5), round(z, 5), round(y, 5)))
            if k == 0:
                uvs.append((round(u, 5), round(1.0 - v, 5)))
        frames.append(frame)
    lods = [_le(raw, f_off + i * 36 + 32) for i in range(num_f)]
    top = max(lods) if lods else 0
    faces = []
    for i in range(num_f):
        if lods[i] != top:
            continue
        a, b, c = struct.unpack_from("<III", raw, f_off + i * 36)
        label = raw[f_off + i * 36 + 16: f_off + i * 36 + 20][::-1].decode("latin1").rstrip("\x00")
        faces.append((a, c, b, label))      # the winding mrmm_obj writes
    return frames, uvs, faces


def put(path: Path, data: bytes) -> bool:
    if path.exists() and path.read_bytes() == data:
        return False
    path.write_bytes(data)
    return True


def main() -> None:
    folders = wad.index_folders(Path(INSTALL) / "models.wad")
    files = folders.get(f"MODL.WAD!/{MODEL}.MRMC", {})
    raw = files.get((MODEL, "MRMM"))
    if raw is None:
        raise SystemExit("model missing: " + MODEL)
    frames, uvs, faces = read_frames(raw)
    labels = []
    for face in faces:
        if face[3] not in labels:
            labels.append(face[3])
    written = 0
    for label in labels:
        image = txtr.folder_texture(files, label)
        if image is None:
            raise SystemExit("texture missing: " + label)
        written += put(OUT / f"{MODEL}_{label}.png", txtr.png_bytes(*image))
    glb = OUT / f"{MODEL}.glb"
    with tempfile.TemporaryDirectory() as tmp:
        data = Path(tmp) / "dfir.json"
        data.write_text(json.dumps({"frames": frames, "uvs": uvs, "faces": faces, "labels": labels}))
        made = Path(tmp) / "dfir.glb"
        script = Path(__file__).resolve().parent / "blender_dfir.py"
        subprocess.run([BLENDER, "--background", "--factory-startup", "--python", str(script), "--", str(data), str(made)], check=True,
                       stdout=subprocess.DEVNULL)
        written += put(glb, made.read_bytes())
    print("dfir: %d frames, %d vertices, %d faces, labels %s (%d files written)" % (len(frames), len(uvs), len(faces), labels, written))


if __name__ == "__main__":
    main()
