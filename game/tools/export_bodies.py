#!/usr/bin/env python3
"""Export every wizard and creature SAXS to OBJ. Cache only, not git."""

import importlib.util
import json
import os
import signal
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INSTALL = Path("/Users/joelsartori/Downloads/sacgame/Sacrifice/data")
OUT = ROOT / "cache" / "look" / "bodies"
MAP = "/Users/joelsartori/Downloads/sacgame/Sacrifice/maps/(2) High Noon.scp"
ENGINE = Path("/Users/joelsartori/Development/sacproject/sacengine/3d")
CATALOG = ROOT / "cache" / "look" / "persephone" / "catalog.json"

spec = importlib.util.spec_from_file_location(
    "ex", ROOT / "tools" / "export_persephone.py"
)
ex = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ex)


def model_names():
    files, _ = ex.index_wad(INSTALL / "spells.wad")
    found = []
    seen = set()
    for (name, ext), rows in files.items():
        if ext not in ("CRE8", "WIZD"):
            continue
        raw = rows[0][1]
        if len(raw) < 152:
            continue
        model = raw[148:152][::-1].decode("latin1").rstrip("\x00")
        if not model or model in seen:
            continue
        seen.add(model)
        found.append((name, ext, model))
    return found


def extract(model: str) -> Path | None:
    dest = OUT / model
    dest.mkdir(parents=True, exist_ok=True)
    def complete() -> bool:
        return (dest / f"{model}.SXMD").exists() and (dest / f"{model}.SAXS").exists() and any(dest.glob("*.tga"))

    if complete():
        return dest
    # The same SAXC can sit in several wads; only some copies carry the SXTX.
    for wad in sorted(INSTALL.glob("saxs*.wad")):
        for odir, name, ext, raw in ex.walk(wad.read_bytes()):
            if f"{model}.SAXC" not in odir:
                continue
            (dest / f"{name}.{ext}").write_bytes(raw)
            if ext == "SXTX" and name.startswith("."):
                (dest / f"{name[1:]}.tga").write_bytes(raw)
        if complete():
            return dest
    return dest if (dest / f"{model}.SXMD").exists() else None


def export_obj(folder: Path, model: str) -> bool:
    obj = folder / f"{model}.obj"
    if obj.exists() and obj.stat().st_size > 1000:
        return True
    sxmd = folder / f"{model}.SXMD"
    if not sxmd.exists():
        return False
    proc = subprocess.Popen(
        [str(ENGINE), "--ignore-settings", "--num-slots=2", MAP, str(sxmd), f"export:{obj}"],
        cwd=str(ENGINE.parent),
        env={**os.environ, "DYLD_LIBRARY_PATH": "/opt/homebrew/lib"},
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    try:
        for _ in range(20):
            time.sleep(0.5)
            if obj.exists() and obj.stat().st_size > 1000:
                return True
        return obj.exists() and obj.stat().st_size > 1000
    finally:
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    creatures = []
    names = model_names()
    print("models", len(names), flush=True)
    for name, ext, model in names:
        folder = extract(model)
        if folder is None:
            print("missing", model, flush=True)
            continue
        ok = export_obj(folder, model)
        print(("ok" if ok else "fail"), ext, name, model, flush=True)
        if ok:
            creatures.append({
                "name": model,
                "mesh": f"res://cache/look/bodies/{model}/{model}.obj",
                "texture": "",
            })
    catalog = {}
    if CATALOG.exists():
        catalog = json.loads(CATALOG.read_text())
    catalog["creatures"] = creatures
    CATALOG.write_text(json.dumps(catalog))
    print("catalog", len(creatures), flush=True)


if __name__ == "__main__":
    main()
