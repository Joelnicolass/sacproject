"""The original's static models with their textures, read from the WADs: Persephone's buildings and plants, the spell models
and the BLDG components of the James WAD. One Prop per model; the textures are keyed by the OBJ material label.
"""

import re
from dataclasses import dataclass, field

from . import bldg, models, txtr, wad
from .install import INSTALL

## Spell models of models.wad (renderer.d loads them from MODL.WAD!/<tag>.MRMC/<tag>.MRMM).
SPELL_MODELS = ("rock",)


@dataclass
class Prop:
    name: str
    foliage: bool           # plants are drawn on both sides
    obj: str                # Wavefront OBJ text
    textures: dict = field(default_factory=dict)   # label -> (width, height, RGBA bytes)

    def labels(self) -> list:
        seen = []
        for label in re.findall(r"^usemtl (\S*)", self.obj, re.M):
            if label not in seen:
                seen.append(label)
        return seen


def _plants() -> list:
    prsc_files, _ = wad.index_wad(INSTALL / "prsc.wad")
    prsc_dirs = wad.index_folders(INSTALL / "prsc.wad")
    out, seen = [], set()
    for (name, ext), rows in prsc_files.items():
        if ext != "WIDG":
            continue
        for odir, raw in rows:
            if "LAND" not in odir or name in seen:
                continue
            seen.add(name)
            try:
                obj, tex = models.widg_obj(raw)
            except Exception as exc:     # noqa: BLE001
                print("widg fail", name, exc)
                continue
            found = txtr.folder_texture(prsc_dirs.get(odir, {}), tex)
            if found is not None:
                out.append(Prop(name, True, obj, {"plant": found}))
    return out


def _persephone_structures() -> list:
    prsc, prsc_pal = wad.index_wad(INSTALL / "prsc.wad")
    joby, joby_pal = wad.index_wad(INSTALL / "joby.wad")
    joby_dirs = wad.index_folders(INSTALL / "joby.wad")
    out, seen = [], set()
    for (name, ext), rows in joby.items():
        if ext != "MRMM":
            continue
        for odir, raw in rows:
            if "prsc" not in odir.lower() or name in seen:
                continue
            seen.add(name)
            try:
                obj, tags = models.mrmm_obj(raw)
            except Exception as exc:     # noqa: BLE001
                print("mrmm fail", name, exc)
                continue
            found = {}
            for tag in tags:
                image = (txtr.folder_texture(joby_dirs.get(odir, {}), tag)
                         or txtr.wad_texture(joby, joby_pal, tag)
                         or txtr.wad_texture(prsc, prsc_pal, tag))
                if image is not None:
                    found[tag] = image
            if found:
                out.append(Prop(name, False, obj, found))
    return out


def _spell_models() -> list:
    folders = wad.index_folders(INSTALL / "models.wad")
    out = []
    for name in SPELL_MODELS:
        files = folders.get(f"MODL.WAD!/{name}.MRMC", {})
        raw = files.get((name, "MRMM"))
        if raw is None:
            print("model missing", name)
            continue
        obj, tags = models.mrmm_obj(raw)
        found = {tag: txtr.folder_texture(files, tag) for tag in tags}
        if not all(found.values()):
            print("model texture missing", name, tags)
            continue
        out.append(Prop(name, False, obj, found))
    return out


def _bldg_components(known: set) -> list:
    buildings, mrmm = bldg.read_buildings()
    needed = set()
    for entry in buildings.values():
        if entry["folder"].split("!")[0] not in ("JMOD.WAD",):
            continue
        for component in entry["components"]:
            for key in ("tag", "destroyed"):
                if component[key]:
                    needed.add(component[key])
    out = []
    for name in sorted(needed):
        if name in known or name not in mrmm:
            continue
        _wad, _odir, files, raw = mrmm[name]
        try:
            obj, tags = models.mrmm_obj(raw)
        except Exception as exc:     # noqa: BLE001
            print("mrmm fail", name, exc)
            continue
        found = {tag: image for tag in tags if (image := txtr.folder_texture(files, tag)) is not None}
        if found:
            out.append(Prop(name, False, obj, found))
    return out


def all_props() -> list:
    """Every prop, sorted by name: Persephone's structures and the spell models, the plants, and the James BLDG components."""
    structures = _persephone_structures() + _spell_models()
    plants = _plants()
    components = _bldg_components({p.name for p in structures})
    return sorted(structures + plants + components, key=lambda p: p.name)
