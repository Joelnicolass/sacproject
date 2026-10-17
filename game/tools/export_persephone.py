#!/usr/bin/env python3
"""Persephone sky, vegetation and structures from the local install.

Writes game/cache/look/persephone/. Does not copy the wads.
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

ROOT = Path(__file__).resolve().parents[1]
from sac_formats.install import INSTALL  # noqa: E402
OUT = ROOT / "cache" / "look" / "persephone"


# One reader for the WAD, TXTR and MRMM/WIDG formats: tools/sac_formats (RFC-033). These names stay for the exporters.
from sac_formats import models as _models  # noqa: E402
from sac_formats import txtr as _txtr  # noqa: E402
from sac_formats.wad import index_folders, index_wad, parse_le, walk  # noqa: E402,F401
from sac_formats.txtr import decode_txtr  # noqa: E402,F401


def write_png(path: Path, width: int, height: int, rgba: bytes) -> None:
    path.write_bytes(_txtr.png_bytes(width, height, rgba))


def _write_texture(path: Path, found) -> bool:
    if found is None:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    write_png(path, *found)
    return True


def txtr_png(files, palettes, name: str, dest: Path) -> bool:
    return _write_texture(dest, _txtr.wad_texture(files, palettes, name))


def folder_txtr_png(folder: dict, name: str, dest: Path) -> bool:
    """Texture and palette from the same WAD folder, like sacengine loadTXTR."""
    return _write_texture(dest, _txtr.folder_texture(folder, name))


def obj_widg(raw: bytes, dest: Path) -> str:
    text, tex = _models.widg_obj(raw)
    dest.write_text(text)
    return tex


def obj_mrmm(raw: bytes, dest: Path) -> list[str]:
    text, names = _models.mrmm_obj(raw)
    dest.write_text(text)
    return names


# Spell models of models.wad (renderer.d loads them from MODL.WAD!/<tag>.MRMC/<tag>.MRMM).
SPELL_MODELS = ("rock",)


def export_spell_models() -> list[dict]:
    folders = index_folders(INSTALL / "models.wad")
    (OUT / "models").mkdir(parents=True, exist_ok=True)
    (OUT / "models" / ".gdignore").write_text("")
    out = []
    for name in SPELL_MODELS:
        odir = f"MODL.WAD!/{name}.MRMC"
        files = folders.get(odir, {})
        raw = files.get((name, "MRMM"))
        if raw is None:
            print("model missing", name)
            continue
        folder = OUT / "models" / name
        folder.mkdir(parents=True, exist_ok=True)
        textures = obj_mrmm(raw, folder / f"{name}.obj")
        if not all(folder_txtr_png(files, tex, folder / f"{tex}.png") for tex in textures):
            print("model texture missing", name, textures)
            continue
        out.append({"name": name, "mesh": f"res://cache/look/persephone/models/{name}/{name}.obj", "texture": ""})
    print("spell models", [m["name"] for m in out])
    return out


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    prsc, prsc_pal = index_wad(INSTALL / "prsc.wad")
    for tag, filename in (("SKY_", "sky.png"), ("SKYT", "skyt.png"), ("SKYB", "skyb.png")):
        ok = txtr_png(prsc, prsc_pal, tag, OUT / filename)
        print("sky", tag, ok)

    plants = []
    plant_dir = OUT / "plants"
    plant_dir.mkdir(exist_ok=True)
    prsc_dirs = index_folders(INSTALL / "prsc.wad")
    seen = set()
    for (name, ext), rows in prsc.items():
        if ext != "WIDG":
            continue
        for odir, raw in rows:
            if "prsc.LAND" not in odir and "LAND" not in odir:
                continue
            if name in seen:
                continue
            seen.add(name)
            try:
                tex = obj_widg(raw, plant_dir / f"{name}.obj")
            except Exception as exc:
                print("widg fail", name, exc)
                continue
            png = plant_dir / f"{name}.png"
            if folder_txtr_png(prsc_dirs.get(odir, {}), tex, png):
                plants.append({
                    "name": name,
                    "mesh": f"res://cache/look/persephone/plants/{name}.obj",
                    "texture": f"res://cache/look/persephone/plants/{name}.png",
                })
    print("plants", len(plants))

    joby, joby_pal = index_wad(INSTALL / "joby.wad")
    joby_dirs = index_folders(INSTALL / "joby.wad")
    structures = []
    bldg_dir = OUT / "buildings"
    bldg_dir.mkdir(exist_ok=True)
    seen_b = set()
    for (name, ext), rows in joby.items():
        if ext != "MRMM":
            continue
        for odir, raw in rows:
            if "prsc" not in odir.lower():
                continue
            if name in seen_b:
                continue
            seen_b.add(name)
            folder = bldg_dir / name
            folder.mkdir(exist_ok=True)
            try:
                textures = obj_mrmm(raw, folder / f"{name}.obj")
            except Exception as exc:
                print("mrmm fail", name, exc)
                continue
            got = False
            for tex in textures:
                if folder_txtr_png(joby_dirs.get(odir, {}), tex, folder / f"{tex}.png"):
                    got = True
                elif txtr_png(joby, joby_pal, tex, folder / f"{tex}.png"):
                    got = True
                elif txtr_png(prsc, prsc_pal, tex, folder / f"{tex}.png"):
                    got = True
            if got:
                structures.append({
                    "name": name,
                    "mesh": f"res://cache/look/persephone/buildings/{name}/{name}.obj",
                    "texture": "",
                })
    print("structures", len(structures), [s["name"] for s in structures])
    structures.extend(export_spell_models())

    creatures = []
    if (OUT / "catalog.json").exists():
        creatures = json.loads((OUT / "catalog.json").read_text()).get("creatures", [])
    catalog = {"plants": plants, "structures": structures, "creatures": creatures}
    (OUT / "catalog.json").write_text(json.dumps(catalog, indent=2))


if __name__ == "__main__":
    main()
