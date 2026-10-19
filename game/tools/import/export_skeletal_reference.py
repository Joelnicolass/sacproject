#!/usr/bin/env python3
"""Parity reference for tools/audit/audit_skeletal.gd (RFC-023a): sacengine's own OBJ export of every clip of a model.

Runs the sacengine binary (read only, never modified) with `export-all-frames:` (app.d) for each clip of each
model, adds the displacement correction the game applies (referenceHeight, sxsk.d frameOffset; without the
skip threshold export_stats uses) and keeps only the frames the audit compares: 0, middle and last.
Output: <out>/<model>/<clip>/<frame>.obj, outside git (default agent/out/skeletal_ref/, ignored).
Usage: python3 tools/import/export_skeletal_reference.py [--out DIR] [--clips TAG,TAG | --unit-clips] [model ...]   (default eorc jnwr)
--unit-clips: only the clips the creature units play (UnitClipRoles: stance/idle, run/walk, melee[0], cower/work,
flight, stun) and writes <out>/unit_clips.json ({model: [tag]}), which `audit_skeletal.gd --clips=` reads.
"""

import json

import argparse
import shutil
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import export_skeletal as sk  # noqa: E402

stats = sk.stats
ROOT = sk.ROOT
DEFAULT_OUT = ROOT / "agent" / "out" / "skeletal_ref"


UNIT_ROLE_FIELDS = ("stance_animation", "idle_animation", "run_animation", "walk_animation")
UNIT_ROLE_DICTS = ("extra_animations", "flight_animations", "stun_animations")


def unit_clip_tags() -> dict:
    """model -> clip tags the units of that model play (the roles of scenes/bodies/unit_clip_roles.gd)."""
    creatures = json.loads((ROOT / "assets" / "original" / "data" / "creatures.json").read_text())
    found: dict = {}
    for entry in creatures.values():
        tags = found.setdefault(entry["model"], set())
        for field in UNIT_ROLE_FIELDS:
            tags.add((entry.get(field) or {}).get("tag", ""))
        for anim in entry.get("melee_animations", [])[:1]:
            tags.add(anim.get("tag", ""))
        for field in UNIT_ROLE_DICTS:
            for clip in (entry.get(field) or {}).values():
                if isinstance(clip, dict):
                    tags.add(clip.get("tag", ""))
    return {model: sorted(t for t in tags if t) for model, tags in found.items()}


def kept_frames(count: int) -> list:
    return sorted({0, count // 2, count - 1})


def fix_displacement(obj: Path, sxsk: bytes, frame: int, zfactor: float, scaling: float) -> None:
    """Adds (corrected - raw) displacement to every vertex of a sacengine frame (same maths as export_stats)."""
    reference = struct.unpack_from("<f", sxsk, 4)[0]
    if not (reference > 0.0 and zfactor > 0.0):
        return
    ratio = zfactor / reference
    _unknown, d0, d1, d2, _offset = struct.unpack_from("<hhhhI", sxsk, 12 + 12 * frame)
    dx = -scaling * d0 * (ratio - 1.0)
    dy = -scaling * d2 * (ratio - 1.0)
    dz = scaling * d1 * (ratio - zfactor)
    delta = (dx, dz, -dy)
    out = []
    for line in obj.read_text().splitlines():
        if line.startswith("v "):
            x, y, z = (float(c) for c in line.split()[1:4])
            line = "v %.10f %.10f %.10f" % (x + delta[0], y + delta[1], z + delta[2])
        out.append(line)
    obj.write_text("\n".join(out) + "\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--clips", default="", help="comma separated clip tags (default: all)")
    parser.add_argument("--unit-clips", action="store_true", help="only the clips creature units play")
    parser.add_argument("--write-clips-only", action="store_true", help="with --unit-clips: write unit_clips.json and stop")
    parser.add_argument("models", nargs="*", default=sk.DEFAULT_MODELS)
    args = parser.parse_args()
    out = args.out.resolve()
    wanted = {c for c in args.clips.split(",") if c}
    per_model = unit_clip_tags() if args.unit_clips else {}
    if args.unit_clips:
        out.mkdir(parents=True, exist_ok=True)
        merged = json.loads((out / "unit_clips.json").read_text()) if (out / "unit_clips.json").exists() else {}
        merged.update({m: per_model.get(m, []) for m in args.models})
        (out / "unit_clips.json").write_text(json.dumps(merged, indent=1, sort_keys=True))
        if args.write_clips_only:
            return
    model_paths = stats.index_saxs_models()
    anim_index = stats.index_saxs_animations()
    failed = []
    for tag in args.models:
        files, clips = sk.model_sources(tag, model_paths, anim_index)
        src = out / "_src" / tag
        src.mkdir(parents=True, exist_ok=True)
        for (name, ext), raw in files.items():
            (src / f"{name}.{ext}").write_bytes(raw)
        sxmd_path = src / f"{tag}.SXMD"
        zfactor = struct.unpack_from("<f", files[(tag, "SXMD")], 8)[0]
        scaling = struct.unpack_from("<f", files[(tag, "SAXS")], 0)[0]
        for clip_tag, sxsk, skel in clips:
            if wanted and clip_tag not in wanted:
                continue
            if args.unit_clips and clip_tag not in per_model.get(tag, []):
                continue
            clip_out = out / tag / clip_tag
            frames = struct.unpack_from("<H", sxsk, 2)[0]
            keep = kept_frames(frames)
            if all((clip_out / f"{f}.obj").exists() for f in keep):
                continue
            (src / "anim").mkdir(exist_ok=True)
            sxsk_path = src / "anim" / f"{clip_tag}.SXSK"
            sxsk_path.write_bytes(sxsk)
            if skel:
                (src / "anim" / f"{clip_tag}.SKEL").write_bytes(skel)
            shutil.rmtree(clip_out, ignore_errors=True)
            if not stats._export_all_frames(sxmd_path, sxsk_path, clip_out):
                failed.append(f"{tag}/{clip_tag}")
                print("FAILED", tag, clip_tag, flush=True)
                continue
            for obj in list(clip_out.glob("*.obj")):
                frame = int(obj.stem)
                if frame in keep:
                    fix_displacement(obj, sxsk, frame, zfactor, scaling)
                else:
                    obj.unlink()
            print("ok", tag, clip_tag, keep, flush=True)
    shutil.rmtree(out / "_src", ignore_errors=True)
    if failed:
        print("failed clips:", " ".join(failed))
        sys.exit(1)


if __name__ == "__main__":
    main()
