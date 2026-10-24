#!/usr/bin/env python3
"""Requiere el juego original instalado (SAC_INSTALL). Ver tools/import/local.cfg.example.

Imports the animated models of the level-8 spells (RFC-061i) to assets/original/props/<tag>.glb, each frame of the original as a blend shape:
  rage  Blind Rage's fist  (models.wad, 12 frames)
  bovi  Bovine Intervention's cow (models.wad, 65 frames)
  deth  Death (charlie.wad Bloo.WAD!/Char.FLDR/modl.FLDR, 27 frames)

Same method as import_dragonfire.py (it reuses its frame reader and Blender script): the MRMM holds N frames of vertex positions, the mesh is frame 0
and frames 1..N-1 are shape keys f1..f<N-1>. The texture of the model (M000, 256x256) is written next to it as <tag>_M000.png. Blender (CLI, no UI)
only converts: nothing is modelled. The scene that uses a model (MorphModel) puts its own material on the surface and drives the weights.

  python3 tools/import/import_morph_models.py            # write
  BLENDER_BIN=/path/to/blender python3 tools/import/import_morph_models.py

Deterministic: the files are only rewritten when the bytes change. An existing .glb.import / .png.import is never touched.
"""

import json
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from import_dragonfire import BLENDER, OUT, put, read_frames  # noqa: E402
from sac_formats import txtr, wad  # noqa: E402
from sac_formats.install import INSTALL  # noqa: E402

# tag -> (wad, folder of the model)
MODELS = {
    "rage": ("models.wad", "MODL.WAD!/rage.MRMC"),
    "bovi": ("models.wad", "MODL.WAD!/bovi.MRMC"),
    "deth": ("charlie.wad", "Bloo.WAD!/Char.FLDR/modl.FLDR/deth.MRMC"),
}


def import_one(tag: str, wad_name: str, folder: str, written: list) -> str:
    files = wad.index_folders(Path(INSTALL) / wad_name).get(folder, {})
    raw = files.get((tag, "MRMM"))
    if raw is None:
        raise SystemExit("model missing: " + tag)
    frames, uvs, faces = read_frames(raw)
    labels = []
    for face in faces:
        if face[3] not in labels:
            labels.append(face[3])
    for label in labels:
        image = txtr.folder_texture(files, label)
        if image is None:
            raise SystemExit("texture missing: " + label)
        written.append(put(OUT / f"{tag}_{label}.png", txtr.png_bytes(*image)))
    with tempfile.TemporaryDirectory() as tmp:
        data = Path(tmp) / f"{tag}.json"
        data.write_text(json.dumps({"name": tag.capitalize(), "frames": frames, "uvs": uvs, "faces": faces, "labels": labels}))
        made = Path(tmp) / f"{tag}.glb"
        script = Path(__file__).resolve().parent / "blender_dfir.py"
        subprocess.run([BLENDER, "--background", "--factory-startup", "--python", str(script), "--", str(data), str(made)], check=True,
                       stdout=subprocess.DEVNULL)
        written.append(put(OUT / f"{tag}.glb", made.read_bytes()))
    return "%s: %d frames, %d vertices, %d faces, labels %s" % (tag, len(frames), len(uvs), len(faces), labels)


def main() -> None:
    written = []
    for tag, (wad_name, folder) in MODELS.items():
        print(import_one(tag, wad_name, folder, written))
    print("%d files written" % sum(written))


if __name__ == "__main__":
    main()
