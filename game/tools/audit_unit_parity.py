#!/usr/bin/env python3
import json
import re
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT.parent / "sacengine" / "source" / "nttData.d"
CREATURES = ROOT / "cache" / "data" / "creatures.json"
BOOKS = ROOT / "cache" / "data" / "books.json"
CLIPS = ROOT / "cache" / "data" / "anim_mesh_clips_f37.json"
ANIM_DIR = ROOT / "cache" / "look" / "anim_f37"


def parse_spell_tags(ntt_text: str) -> dict[str, str]:
    m = re.search(r"enum SpellTag:char\[4\]\{(.*?)\n\}", ntt_text, re.S)
    tags = {}
    if not m:
        return tags
    for name, tag in re.findall(r"(\w+)=\"(.{4})\"", m.group(1)):
        tags[name] = tag
    return tags


def parse_lists(ntt_text: str) -> dict[str, list[str]]:
    tags = parse_spell_tags(ntt_text)
    lists = {}
    for name, body in re.findall(r"immutable ST\[\] (\w+)=\[([^\]]*)\];", ntt_text):
        out = []
        for raw in body.split(","):
            raw = raw.strip()
            if not raw or not raw.startswith("ST."):
                continue
            key = raw[3:]
            if key in tags:
                out.append(tags[key])
        lists[name] = out
    return lists


GODS = ("james", "persephone", "pyro", "stratos", "charnel")


def summonable_tags(lists: dict[str, list[str]]) -> list[str]:
    """Every creature of every book (F112): Manahoar and the 10 of each god."""
    result = set(lists.get("neutralCreatures", []))
    for god in GODS:
        result.update(lists.get(f"{god}Creatures", []))
    return sorted(result)


def creature_levels(books: dict) -> dict[str, int]:
    """Wizard level of each creature, from books.json "levels" (computeDefaultSpells)."""
    levels: dict[str, int] = {}
    for book in books.values():
        for tag, level in book.get("levels", {}).items():
            levels[tag] = min(int(level), levels.get(tag, 99))
    return levels


def sxsk_frames(model: str, tag: str) -> int:
    """Frame count in the clip's SXSK header (u16 at byte 2, sacengine sxsk.d:56); 0 if it is missing."""
    path = ANIM_DIR / model.lower() / tag / f"{tag}.SXSK"
    try:
        return struct.unpack_from("<H", path.read_bytes(), 2)[0]
    except (OSError, struct.error):
        return 0


def bool_clip_ok(entry: dict, model: str) -> bool:
    """The clip has more than one frame and as many frame OBJs as its SXSK says (no partial export)."""
    if not isinstance(entry, dict) or int(entry.get("frames", 0)) <= 1:
        return False
    expected = sxsk_frames(model, str(entry.get("tag", "")))
    return expected == int(entry.get("frames", 0)) == len(entry.get("frame_objs", []))


def main() -> None:
    ntt = SOURCE.read_text(encoding="latin1")
    lists = parse_lists(ntt)
    creatures = json.loads(CREATURES.read_text())
    books = json.loads(BOOKS.read_text())
    clips = json.loads(CLIPS.read_text()) if CLIPS.exists() else {}
    playable = summonable_tags(lists)
    levels = creature_levels(books)
    report = {
        "playable_count": len(playable),
        "states_implemented": ["idle", "move", "chase", "attack", "shoot", "summoning", "rock_form", "dead"],
        "units": [],
    }
    for tag in playable:
        row = creatures.get(tag, {})
        model = str(row.get("model", ""))
        ## The clip cache is keyed by the model tag as written (AArc, ABRX), like ClipPosePlayer reads it.
        by_model = clips.get(model, clips.get(model.lower(), {}))
        idle = row.get("idle_animation", {})
        walk = row.get("walk_animation", {}) or row.get("run_animation", {})
        melee = row.get("melee_animations", [{}])[0] if row.get("melee_animations") else {}
        shoot = row.get("shoot_animations", [{}])[0] if row.get("shoot_animations") else {}
        ranged = bool(row.get("ranged", False))
        abilities = [a for a in row.get("abilities", []) if a]
        report["units"].append({
            "tag": tag,
            "name": row.get("name", tag),
            "model": model,
            "level": levels.get(tag, -1),
            "ranged": ranged,
            "book_member": any(tag in b.get("creatures", []) for b in books.values()),
            "idle_tag": idle.get("tag", ""),
            "walk_tag": walk.get("tag", ""),
            "attack_tag": melee.get("tag", ""),
            "idle_clip_ok": bool_clip_ok(by_model.get(idle.get("tag", ""), {}), model),
            "walk_clip_ok": bool_clip_ok(by_model.get(walk.get("tag", ""), {}), model),
            "attack_clip_ok": bool_clip_ok(by_model.get(melee.get("tag", ""), {}), model),
            "shoot_tag": shoot.get("tag", "") if ranged else "",
            ## shoot0 is required only for ranged creatures (sacobject.d:425 rangedAttack).
            "shoot_clip_ok": (not ranged) or bool_clip_ok(by_model.get(shoot.get("tag", ""), {}), model),
            "abilities": abilities,
            "active_ability": row.get("active_ability", ""),
            "manahoar_support": tag == "oham" and ("hmba" in abilities),
        })
    out = ROOT / "agent" / "out" / "f41"
    out.mkdir(parents=True, exist_ok=True)
    target = out / "unit_parity_report.json"
    target.write_text(json.dumps(report, indent=2, ensure_ascii=False))
    missing = [
        u for u in report["units"]
        if not (u["idle_clip_ok"] and u["walk_clip_ok"] and u["attack_clip_ok"] and u["shoot_clip_ok"])
    ]
    report["missing_by_level"] = {}
    for u in missing:
        report["missing_by_level"].setdefault(str(u["level"]), []).append(u["tag"])
    target.write_text(json.dumps(report, indent=2, ensure_ascii=False))
    print("playable:", report["playable_count"])
    print("missing_clip_parity:", ",".join(u["tag"] for u in missing) if missing else "none")
    for level in sorted(report["missing_by_level"], key=int):
        print("  level %s missing: %s" % (level, ",".join(report["missing_by_level"][level])))
    print("report:", target)


if __name__ == "__main__":
    main()
