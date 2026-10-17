"""The bodies (84 wizards and creatures) of the SAXS WADs: the model's limb records (SAXS) and its textures (SXTX = TGA)."""

from . import wad
from .install import INSTALL


def model_names() -> list:
    """The 3D model tag of every CRE8 and WIZD of spells.wad (the tag at 148, stored reversed), in file order, once each."""
    found, seen = [], set()
    for _odir, name, ext, raw in wad.walk((INSTALL / "spells.wad").read_bytes()):
        if ext not in ("CRE8", "WIZD") or len(raw) < 152:
            continue
        model = raw[148:152][::-1].decode("latin1").rstrip("\x00")
        if model and model not in seen:
            seen.add(model)
            found.append(model)
    return found


def read_bodies(models: list) -> dict:
    """{model: {"<name>.<ext>": bytes}} from the SAXC folder of each model.

    The same SAXC can sit in several WADs and only some copies carry the textures: the WADs are read in name order, a later
    file of the same name replaces an earlier one, and it stops at the first WAD after which the model is complete
    (SXMD, SAXS and at least one SXTX).
    """
    wanted = set(models)
    per_wad = {m: [] for m in models}       # model -> [files of wad 1, files of wad 2, ...]
    for path in sorted(INSTALL.glob("saxs*.wad")):
        got = {}
        for odir, name, ext, raw in wad.walk(path.read_bytes()):
            if not odir.endswith(".SAXC"):
                continue
            model = odir.rsplit("/", 1)[-1][:-len(".SAXC")]
            if model in wanted:
                got.setdefault(model, {})[f"{name}.{ext}"] = raw
        for model in models:
            per_wad[model].append(got.get(model, {}))
    out = {}
    for model in models:
        files = {}
        for one in per_wad[model]:
            files.update(one)
            if f"{model}.SXMD" in files and f"{model}.SAXS" in files and any(k.endswith(".SXTX") and k.startswith(".") for k in files):
                break
        if f"{model}.SXMD" in files:
            out[model] = files
    return out
