"""The original's static models with their textures, read from the WADs: Persephone's buildings, the plants of every land
but James's, the spell models
and the BLDG components of every god WAD (joby, pyromod, jamesmod, stratmod). One Prop per model; the textures are keyed by the OBJ material label.
"""

import re
from dataclasses import dataclass, field

from . import bldg, models, txtr, wad
from .install import INSTALL

## Land WADs whose WIDG models are imported as plants: Persephone (prsc), Charnel (char), Pyro (pyro_a), Stratos (strato_a)
## and James (james_a, JAW1-5 since RFC-054 054d: High Noon and Peasantville draw their own plants, no longer Persephone's).
PLANT_WADS = ("prsc.wad", "char.wad", "pyro_a.wad", "strato_a.wad", "james_a.wad")

## Spell models of models.wad (renderer.d loads them from MODL.WAD!/<tag>.MRMC/<tag>.MRMM).
SPELL_MODELS = ("rock", "bold", "sbll")


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
    """The WIDG models of the LAND folders of PLANT_WADS (the plants a map's widgets.json places, by tag)."""
    out, seen = [], set()
    for wad_name in PLANT_WADS:
        files, _ = wad.index_wad(INSTALL / wad_name)
        dirs = wad.index_folders(INSTALL / wad_name)
        for (name, ext), rows in files.items():
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
                found = txtr.folder_texture(dirs.get(odir, {}), tex)
                if found is not None:
                    out.append(Prop(name, True, obj, {"plant": found}))
                else:
                    print("widg texture missing", name, tex)
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
    """The models of every component (and its destroyed model) of every BLDG of the god WADs: all lands and all gods,
    so any map can place any building. A model already in `known` (Persephone's structures, the plants) is not repeated.
    Textures come from the model's own folder, then from anywhere in its WAD (the palette by name)."""
    buildings, mrmm = bldg.read_buildings()
    needed = set()
    for entry in buildings.values():
        for component in entry["components"]:
            for key in ("tag", "destroyed"):
                if component[key]:
                    needed.add(component[key])
    wad_textures = {}
    out = []
    for name in sorted(needed):
        if name in known:
            continue
        if name not in mrmm:
            print("bldg model missing", name)
            continue
        wad_name, _odir, files, raw = mrmm[name]
        try:
            obj, tags = models.mrmm_obj(raw)
        except Exception as exc:     # noqa: BLE001
            print("mrmm fail", name, exc)
            continue
        found = {}
        for tag in tags:
            image = txtr.folder_texture(files, tag)
            if image is None:
                if wad_name not in wad_textures:
                    wad_textures[wad_name] = wad.index_wad(INSTALL / wad_name)
                image = txtr.wad_texture(*wad_textures[wad_name], tag)
            if image is not None:
                found[tag] = image
        if set(tags) - set(found):
            print("bldg texture missing", name, sorted(set(tags) - set(found)))
        if found:
            out.append(Prop(name, False, obj, found))
    return out


def all_props() -> list:
    """Every prop, sorted by name: Persephone's structures and the spell models, the plants, and the BLDG components."""
    structures = _persephone_structures() + _spell_models()
    plants = _plants()
    components = _bldg_components({p.name for p in structures + plants})
    return sorted(structures + plants + components, key=lambda p: p.name)
