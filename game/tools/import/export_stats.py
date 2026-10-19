#!/usr/bin/env python3
"""Creature, wizard, spell and ability stats from spells.wad (the installation; RFC-033).

Layouts follow sacengine `spells.d` (Cre8 528, Wizd 840, Spel 314+2, Strc 64).
Keys are SpellTags as in `nttData.d`: the raw record bytes, i.e. the WAD file name reversed.
Writes assets/original/data/{creatures,wizards,spells,abilities,books,buildings}.json (`--out DIR` writes somewhere else).
"""

import json
import math
import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from sac_formats.bldg import read_buildings  # noqa: E402
from sac_formats.install import INSTALL  # noqa: E402
NTT_DATA = ROOT.parent / "sacengine" / "source" / "nttData.d"
OUT = ROOT / "assets" / "original" / "data"

FPS = 60.0
CAST_FRAMES_PER_SECOND = 1.35 * FPS
GODS = ["persephone", "pyro", "james", "stratos", "charnel"]
GOD_NAMES = {0: "none", 1: "persephone", 2: "pyro", 3: "james", 4: "stratos", 5: "charnel"}
ATTACK_ANIMS_OFFSET = 176 + 11 * 4
SHOOT_ANIMS_OFFSET = 176 + 22 * 4
## stance1 is slot 0: the rest pose sacengine plays between gestures (state.d:7957-7992); idle0..3 are gestures.
STANCE1_ANIM_OFFSET = 176
IDLE0_ANIM_OFFSET = 176 + 1 * 4
RUN_ANIM_OFFSET = 176 + 6 * 4
WALK_ANIM_OFFSET = 176 + 24 * 4
## Animations slots (`animations.d`): death[0..2] 19, corpseRise 57, float2Stance 60 (wizards only).
DEATH_ANIMS_OFFSET = 176 + 19 * 4
CORPSE_RISE_OFFSET = 176 + 57 * 4
FLOAT_TO_STANCE_OFFSET = 176 + 60 * 4
## Peasant slots (`animations.d`: takeoff/fly/flyDamage/flyAttack are cower/pull/dig/talk-cower on peasants).
## Port role -> slot. A tag that starts with "00" means no clip (melee_animation drops it).
EXTRA_ANIM_SLOTS = {"cower": 32, "pull": 33, "work": 35, "talk_cower": 37}
## Peasants (nttData.d:133, same list as PeasantBehavior.TAGS): only they read those slots as peasant clips;
## on every other creature they are takeoff/fly/flyDamage/flyAttack.
PEASANT_TAGS = ("zepa", "zepd", "zepe", "zepf", "saep")
## F116 (RFC-030e): the flight slots of every other creature (`animations.d`: takeoff 32, fly 33, land 34).
FLIGHT_ANIM_SLOTS = {"takeoff": 32, "fly": 33, "land": 34}
## RFC-023f: death0 (slot 19), flyDeath (36, a peasant's pull-down) and hover (38) as clips of the skeleton.
DEATH_ANIM_SLOTS = {"death": 19, "fly_death": 36}
HOVER_ANIM_SLOT = 38
## F120 (RFC-030i-a): the stun slots (`animations.d`: knocked2Floor 9, getUp 10, flyDamage 35). sacengine stunned lasts
## (knocked2Floor + getUp)·updateAnimFactor ticks on the ground and flyDamage·updateAnimFactor in the air (state.d:8138-8150,
## 14170-14212). Only the timing is exported. Slot 35 is a peasant's dig: peasants have no fly_damage.
STUN_ANIM_SLOTS = {"knock": 9, "get_up": 10, "fly_damage": 35, "hit_floor": 8}
## F138 (RFC-030i-c): a wizard walks only, so only knock and get_up. The fasterStandupTimes fix (sacobject.d:844-874)
## swaps hitFloor (slot 8) for knocked2Floor on seven wizards; neither slot 9 nor 10 changes, so the stun length doesn't.
## F121 (RFC-030j): hitFloor (slot 8) too, only its length: a tumbling body that lands plays hitFloor then getUp
## (state.d:14175-14212). Timing only, like the rest (no mesh clip).
WIZARD_STUN_ANIM_SLOTS = {"knock": 9, "get_up": 10, "hit_floor": 8}
## RFC-023 023e: what a creature plays while a Sac Doctor holds it (CreatureMode.thrashing, state.d:8200-8223, 14329-14342):
## rise (slot 46) once, float2Thrash (49, the port's `held`) once, then thrash (25) on a loop. Same rule as the flight slots.
CAPTIVE_ANIM_SLOTS = {"rise": 46, "held": 49, "thrash": 25}
## RFC-023 023d: the spellcast loops of a wizard (`animations.d`: spellcast 27 standing, runSpellcast 30 running). The start and
## end clips (26/28, 29/31) are not exported: the port plays the loop while the Caster casts.
WIZARD_CAST_ANIM_SLOTS = {"cast": 27, "run_cast": 30}
## SKEL event tags (`sxsk.d` translateAnimEvent): attack, shoot.
ATTACK_EVENT = b"kcta"
SHOOT_EVENT = b"lrba"

from sac_formats import wad as ex  # noqa: E402  (walk)


def tag(raw: bytes, offset: int) -> str:
    return raw[offset : offset + 4].decode("latin1").rstrip("\x00")


def human_tag(raw: bytes, offset: int) -> str:
    return raw[offset : offset + 4][::-1].decode("latin1").rstrip("\x00")


def u16(raw: bytes, offset: int) -> int:
    return struct.unpack_from("<H", raw, offset)[0]


def u32(raw: bytes, offset: int) -> int:
    return struct.unpack_from("<I", raw, offset)[0]


def f32(raw: bytes, offset: int) -> float:
    return round(struct.unpack_from("<f", raw, offset)[0], 4)


def cast_seconds(frames: int) -> float:
    return round(frames / CAST_FRAMES_PER_SECOND, 4)


def spell_header(raw: bytes) -> dict:
    """Fields shared by Cre8, Spel and Strc (bytes 0..44)."""
    return {
        "spell_type": u32(raw, 4),
        "name_tag": tag(raw, 8),
        "icon": tag(raw, 12),
        "cooldown_s": round(u32(raw, 20) / FPS, 4),
        "mana_cost": u32(raw, 24),
        "range": f32(raw, 28),
        "min_casting_time_s": cast_seconds(u16(raw, 36)),
        "casting_time_s": cast_seconds(u16(raw, 38)),
        "casting_frames": u16(raw, 38),
        "spell_order": u16(raw, 40),
    }


def resistances(raw: bytes) -> dict:
    keys = ["melee", "direct_spell", "splash_spell", "direct_ranged", "splash_ranged"]
    return {key: round(u16(raw, 62 + 2 * i) * 1e-3, 4) for i, key in enumerate(keys)}


def attack_animation_tags(raw: bytes) -> list[str]:
    """Cre8.animations.attack[0..2]: Animations starts at 176, attack is slot 11 (`animations.d`)."""
    return [raw[ATTACK_ANIMS_OFFSET + 4 * i : ATTACK_ANIMS_OFFSET + 4 * i + 4][::-1].decode("latin1") for i in range(3)]


def shoot_animation_tags(raw: bytes) -> list[str]:
    """Cre8.animations.shoot[0..1]: slot 22 (`animations.d`)."""
    return [raw[SHOOT_ANIMS_OFFSET + 4 * i : SHOOT_ANIMS_OFFSET + 4 * i + 4][::-1].decode("latin1") for i in range(2)]


def locomotion_animation_tags(raw: bytes) -> dict:
    """stance1/idle0/run/walk slots (`animations.d`) used by sacengine locomotion states."""
    return {
        "stance": human_tag(raw, STANCE1_ANIM_OFFSET),
        "idle": human_tag(raw, IDLE0_ANIM_OFFSET),
        "run": human_tag(raw, RUN_ANIM_OFFSET),
        "walk": human_tag(raw, WALK_ANIM_OFFSET),
    }


def index_saxs_animations() -> dict:
    """lower(file name) -> [(path, sxsk, skel)] over every saxs*.wad, like `makeSaxsAnimByTag`."""
    found: dict = {}
    for wad in sorted(INSTALL.glob("saxs*.wad")):
        skels: dict = {}
        anims: list = []
        for odir, name, ext, raw in ex.walk(wad.read_bytes()):
            if ext == "SKEL":
                skels[(odir, name)] = raw
            elif ext == "SXSK":
                anims.append((odir, name, raw))
        for odir, name, raw in anims:
            path = f"{wad.name}/{odir}/{name}.SXSK"
            found.setdefault(name.lower(), []).append((path, raw, skels.get((odir, name))))
    return found


def index_saxs_models() -> dict:
    models: dict = {}
    for wad in sorted(INSTALL.glob("saxs*.wad")):
        for odir, name, ext, _raw in ex.walk(wad.read_bytes()):
            if ext == "SXMD":
                models.setdefault(name.lower(), f"{wad.name}/{odir}/{name}.SXMD")
    return models


def melee_animation(anim_index: dict, model_path: str, anim_tag: str, event: bytes = ATTACK_EVENT, key: str = "attack_ticks") -> dict:
    """`getSaxsAnim` (nttData.d:232): the file with that tag sharing the longest path prefix with the model.
    numFrames from the SXSK header (`sxsk.d:56`), framerate and `event` frames (attack 'kcta', shoot 'lrba')
    from the SKEL (`skel.d`)."""
    best, best_len = None, -1
    for path, raw, skel in anim_index.get(anim_tag.lower(), []):
        common = 0
        for a, b in zip(path, model_path):
            if a != b:
                break
            common += 1
        if common >= best_len:
            best, best_len = (raw, skel), common
    if best is None or anim_tag.startswith("00"):
        return {}
    raw, skel = best
    frames = u16(raw, 2)
    framerate, ticks = 30, []
    if skel and len(skel) >= 140:
        framerate = u32(skel, 4)
        for i in range(min(u32(skel, 8), 8)):
            if skel[16 + 12 * i : 20 + 12 * i] == event:
                ticks.append(min(u32(skel, 12 + 12 * i), frames - 1))
    return {"tag": anim_tag, "frames": frames, "framerate": framerate, key: sorted(ticks)}


def clip_animation(anim_index: dict, model_path: str, anim_tag: str) -> dict:
    """Animation clip timing only (frames/framerate), with no event ticks."""
    clip = melee_animation(anim_index, model_path, anim_tag, b"----", "events")
    clip.pop("events", None)
    return clip


def _from_sxmd(v: tuple[float, float, float]) -> tuple[float, float, float]:
    return -v[0], -v[2], v[1]


def _quat_to_euler(qx: float, qy: float, qz: float, qw: float) -> tuple[float, float, float]:
    length = math.sqrt(qx * qx + qy * qy + qz * qz + qw * qw)
    if length <= 0.0:
        return 0.0, 0.0, 0.0
    qx, qy, qz, qw = qx / length, qy / length, qz / length, qw / length
    sinr_cosp = 2.0 * (qw * qx + qy * qz)
    cosr_cosp = 1.0 - 2.0 * (qx * qx + qy * qy)
    roll = math.atan2(sinr_cosp, cosr_cosp)
    sinp = 2.0 * (qw * qy - qz * qx)
    pitch = math.copysign(math.pi / 2.0, sinp) if abs(sinp) >= 1.0 else math.asin(sinp)
    siny_cosp = 2.0 * (qw * qz + qx * qy)
    cosy_cosp = 1.0 - 2.0 * (qy * qy + qz * qz)
    yaw = math.atan2(siny_cosp, cosy_cosp)
    return roll, pitch, yaw


def clip_pose_animation(anim_index: dict, model_path: str, anim_tag: str) -> dict:
    """Per-frame pose offsets from SXSK root displacement and root-bone tilt.
    Cached only for F36 MVP clips (jnwr/eorc)."""
    best, best_len = None, -1
    for path, raw, skel in anim_index.get(anim_tag.lower(), []):
        common = 0
        for a, b in zip(path, model_path):
            if a != b:
                break
            common += 1
        if common >= best_len:
            best, best_len = (raw, skel), common
    if best is None or anim_tag.startswith("00"):
        return {}
    raw, skel = best
    if len(raw) < 12:
        return {}
    frames = u16(raw, 2)
    bones = u16(raw, 8)
    if frames <= 1 or bones <= 0:
        return {}
    poses: list[list[float]] = []
    ys: list[float] = []
    zs: list[float] = []
    rxs: list[float] = []
    rzs: list[float] = []
    for i in range(frames):
        base = 12 + i * 12
        if base + 12 > len(raw):
            return {}
        _unknown, dx, dy, dz, offset = struct.unpack_from("<hhhhI", raw, base)
        px, py, pz = _from_sxmd((float(dx), float(dy), float(dz)))
        py *= 0.1
        pz *= 0.1
        ys.append(py)
        zs.append(pz)
        rx = 0.0
        rz = 0.0
        if offset + 8 <= len(raw):
            qx, qy, qz, qw = struct.unpack_from("<hhhh", raw, offset)
            fx, fy, fz = _from_sxmd((float(qx), float(qy), float(qz)))
            roll, pitch, _yaw = _quat_to_euler(fx, fy, fz, float(qw))
            rx = pitch
            rz = roll
        rxs.append(rx)
        rzs.append(rz)
    y0 = sum(ys) / len(ys)
    z0 = sum(zs) / len(zs)
    rx0 = sum(rxs) / len(rxs)
    rz0 = sum(rzs) / len(rzs)
    for i in range(frames):
        poses.append([
            round((ys[i] - y0) * 0.01, 5),
            round((zs[i] - z0) * 0.01, 5),
            round((rxs[i] - rx0) * 0.4, 5),
            round((rzs[i] - rz0) * 0.4, 5),
        ])
    framerate = 30
    impact_frames: list[int] = []
    if skel and len(skel) >= 140:
        framerate = max(1, u32(skel, 4))
        for i in range(min(u32(skel, 8), 8)):
            if skel[16 + 12 * i : 20 + 12 * i] == ATTACK_EVENT:
                impact_frames.append(min(u32(skel, 12 + 12 * i), frames - 1))
    return {
        "tag": anim_tag,
        "frames": frames,
        "framerate": framerate,
        "impact_frames": sorted(set(impact_frames)),
        "poses": poses,
    }


def parse_ranged_creatures(text: str) -> set:
    """CreatureData with `ranged: RangedType.ranged|friendlyRanged` (nttData.d); `isRanged` (sacobject.d:424)."""
    ranged = set()
    for body in re.findall(r"CreatureData \w+=\{(.*?)\n\};", text, re.S):
        found = re.search(r"tag: \"(.{4})\"", body)
        if found and re.search(r"ranged: RangedType\.(ranged|friendlyRanged)", body):
            ranged.add(found.group(1))
    return ranged


def extra_animation_tags(raw: bytes) -> dict:
    """Peasant clips (cower, pull, dig, talk-cower) from their `animations.d` slots; "" when the slot is empty."""
    return {role: human_tag(raw, 176 + slot * 4) for role, slot in EXTRA_ANIM_SLOTS.items()}


def flight_animations(anim_index: dict, model_path: str, tags: dict, stance_tag: str, peasant: bool) -> dict:
    """F116: takeoff/fly/land clips the way sacengine loads them (sacobject.d:675-689): a slot whose id starts with "00"
    (the human tag ends with it, e.g. Phoenix DF00) or repeats stance1 (Rhinok Eds1 in every flight slot) has no clip.
    canFly = there is a fly clip (sacobject.d:113-115). Peasants use those slots for other clips (sacobject.d:690-697).
    F120: the stun slots go through the same rule (peasant False, fly_damage already dropped for peasants)."""
    if peasant:
        return {}
    clips: dict = {}
    for role, anim_tag in tags.items():
        if not anim_tag or anim_tag.endswith("00") or anim_tag == stance_tag:
            continue
        clip = clip_animation(anim_index, model_path, anim_tag)
        if clip:
            clips[role] = clip
    return clips


def decode_cre8(raw: bytes) -> dict:
    entry = spell_header(raw)
    entry.update({
        "god": GOD_NAMES.get(u16(raw, 80), str(u16(raw, 80))),
        "model": human_tag(raw, 148),
        "health": u16(raw, 54),
        "regeneration_per_s": round(u16(raw, 56) / FPS, 4),
        "drain": round(u16(raw, 58) * 1e-3, 4),
        "running_speed": round(u16(raw, 50) * 1e-2, 4),
        "flying_speed": round(u16(raw, 52) * 1e-2, 4),
        "melee_strength": u32(raw, 132),
        "melee_accuracy": u16(raw, 44),
        "melee_evasion": u16(raw, 46),
        "ranged_accuracy": u16(raw, 60),
        "aggressiveness": u16(raw, 48),
        "sight_range": round(u16(raw, 76) * 0.1, 4),
        "resistances": resistances(raw),
        "mana": u32(raw, 136),
        "souls": u16(raw, 82),
        "abilities": [tag(raw, 92), tag(raw, 96), tag(raw, 124)],
        "passive_abilities": [tag(raw, 440), tag(raw, 452)],
        "behavior_flags": u32(raw, 152),
        "attack_animation_tags": attack_animation_tags(raw),
        "shoot_animation_tags": shoot_animation_tags(raw),
        "locomotion_animation_tags": locomotion_animation_tags(raw),
        "extra_animation_tags": extra_animation_tags(raw),
        "flight_animation_tags": {role: human_tag(raw, 176 + slot * 4) for role, slot in FLIGHT_ANIM_SLOTS.items()},
        "stun_animation_tags": {role: human_tag(raw, 176 + slot * 4) for role, slot in STUN_ANIM_SLOTS.items()},
        "death_animation_tags": {role: human_tag(raw, 176 + slot * 4) for role, slot in DEATH_ANIM_SLOTS.items()},
        "hover_animation_tag": human_tag(raw, 176 + HOVER_ANIM_SLOT * 4),
        "captive_animation_tags": {role: human_tag(raw, 176 + slot * 4) for role, slot in CAPTIVE_ANIM_SLOTS.items()},
    })
    return entry


def decode_wizd(raw: bytes) -> dict:
    return {
        "spell_tag": tag(raw, 8),
        "model": human_tag(raw, 148),
        "health": u16(raw, 54),
        "mana": u32(raw, 136),
        "running_speed": round(u16(raw, 50) * 1e-2, 4),
        "flying_speed": round(u16(raw, 52) * 1e-2, 4),
        "regeneration_per_s": round(u16(raw, 56) / FPS, 4),
        "melee_accuracy": u16(raw, 44),
        "melee_evasion": u16(raw, 46),
        "resistances": resistances(raw),
        "souls": u16(raw, 82),
        "abilities": [tag(raw, 92), tag(raw, 96), tag(raw, 124)],
        "death_animation_tags": [human_tag(raw, DEATH_ANIMS_OFFSET + 4 * i) for i in range(3)],
        "corpse_rise_tag": human_tag(raw, CORPSE_RISE_OFFSET),
        "float_to_stance_tag": human_tag(raw, FLOAT_TO_STANCE_OFFSET),
        "locomotion_animation_tags": locomotion_animation_tags(raw),
        "stun_animation_tags": {role: human_tag(raw, 176 + slot * 4) for role, slot in WIZARD_STUN_ANIM_SLOTS.items()},
        "cast_animation_tags": {role: human_tag(raw, 176 + slot * 4) for role, slot in WIZARD_CAST_ANIM_SLOTS.items()},
    }


def decode_spel(raw: bytes) -> dict:
    raw = raw.ljust(316, b"\x00")
    entry = spell_header(raw)
    entry.update({
        "flags": u32(raw, 32),
        "exclusion_tags": [t for t in (tag(raw, 44 + 4 * i) for i in range(4)) if t],
        "damage_range": f32(raw, 60),
        "amount": u16(raw, 68),
        "speed": round(FPS * f32(raw, 72), 4),
        "acceleration": round(FPS * f32(raw, 76), 4),
        "duration": f32(raw, 80),
        "effect_range": f32(raw, 84),
        "flags1": u16(raw, 90),
        "flags2": u32(raw, 92),
        "amount2": u32(raw, 96),
        "amount3": u32(raw, 100),
        "args": spel_args(raw),
    })
    return entry


## spells.d Spel.args (8 × {type, what} at byte 142): `ires`/`freg` of poison, `ttex` of a particle... as sacspell.d
## spellArgInt/spellArgFloat read them. Type read reversed; i = int, f = float, t = tag (reversed too).
SPEL_ARGS_OFFSET = 142


def spel_args(raw: bytes) -> dict:
    args = {}
    for i in range(8):
        at = SPEL_ARGS_OFFSET + 8 * i
        kind = raw[at : at + 4][::-1].decode("latin1").rstrip("\x00")
        what = raw[at + 4 : at + 8]
        if not kind or kind.startswith("-") or kind.endswith("-"):
            continue
        if kind[0] == "i":
            args[kind] = struct.unpack("<i", what)[0]
        elif kind[0] == "f":
            args[kind] = round(struct.unpack("<f", what)[0], 6)
        elif kind[0] == "t":
            args[kind] = what[::-1].decode("latin1").rstrip("\x00")
    return args


def decode_strc(raw: bytes) -> dict:
    entry = spell_header(raw)
    entry.update({
        "flags": u32(raw, 32),
        "structures": [human_tag(raw, 44 + 4 * i) for i in range(5)],
    })
    return entry


def parse_ntt_data() -> dict:
    """Names and per-god lists straight from sacengine `nttData.d`."""
    text = NTT_DATA.read_text()
    spell_enum = re.search(r"enum SpellTag:char\[4\]\{(.*?)\n\}", text, re.S).group(1)
    tags = dict(re.findall(r"(\w+)=\"(.{4})\"", spell_enum))
    wizard_enum = re.search(r"enum WizardTag:char\[4\]\{(.*?)\n\}", text, re.S).group(1)
    wizard_tags = dict(re.findall(r"(\w+)=\"(.{4})\"", wizard_enum))
    names = dict(re.findall(r"tag: \"(.{4})\",\s*name: \"([^\"]+)\"", text))
    lists = {}
    for name, body in re.findall(r"immutable ST\[\] (\w+)=\[([^\]]*)\];", text):
        lists[name] = [tags[item.strip()[3:]] for item in body.split(",") if item.strip()]
    enum_names = {value: key for key, value in tags.items()}
    return {
        "tags": tags, "wizard_tags": wizard_tags, "names": names, "lists": lists, "enum_names": enum_names,
        "ranged": parse_ranged_creatures(text),
    }


def title_from_identifier(identifier: str) -> str:
    words = re.sub(r"([a-z])([A-Z])", r"\1 \2", identifier)
    return words[:1].upper() + words[1:]


def english_texts() -> dict:
    texts = {}
    lang = INSTALL / "local" / "lang_english.wad"
    if not lang.exists():
        return texts
    for _odir, name, ext, raw in ex.walk(lang.read_bytes()):
        if ext == "TEXT":
            texts.setdefault(name[::-1], raw.rstrip(b"\x00").decode("latin1").strip())
    return texts


def display_name(spell_tag: str, ntt: dict) -> str:
    if spell_tag in ntt["names"]:
        return ntt["names"][spell_tag]
    if spell_tag in ntt["enum_names"]:
        return title_from_identifier(ntt["enum_names"][spell_tag])
    return spell_tag


## BLDG (RFC-024 addendum, cut 024b2). Layout follows sacengine `bldg.d`: header 128 bytes
## (flags, ground 8x8, maxHealth u32, 10 floats, tileset, numComponents u32 at 120) and 48 bytes per component.
## The BLDG reader (layout, wads) lives in tools/import/sac_formats/bldg.py, shared with the props importer.
def write_buildings_json(buildings: dict) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "buildings.json").write_text(json.dumps(buildings, indent=1, ensure_ascii=False))


def book_levels(lists: dict, god: str) -> dict:
    """Wizard level of every entry of a god's book, as sacengine `computeDefaultSpells` (state.d:2138-2172).

    creatureSpells[god] = Manahoar + the 10 of the god; normalSpells[god] = Speedup, Heal + the 9 of the god.
    Level 0: neutral creatures and spells, structures but the Shrine. Level 1: creatures 1-3 and the first spell.
    Levels 2-7: one creature and one spell each. Level 8: the last two spells. Level 9: the last creature. Shrine: 3.
    """
    creatures = lists[f"{god}Creatures"]
    spells = lists[f"{god}Spells"]
    levels: dict = {}
    for tag_name in lists["neutralCreatures"] + lists["neutralSpells"] + lists["structureSpells"][:-1]:
        levels[tag_name] = 0
    levels[lists["structureSpells"][-1]] = 3
    for tag_name in creatures[0:3]:
        levels[tag_name] = 1
    levels[spells[0]] = 1
    for level in range(2, 8):
        levels[creatures[level + 1]] = level
        levels[spells[level - 1]] = level
    for tag_name in spells[7:9]:
        levels[tag_name] = 8
    levels[creatures[9]] = 9
    return levels


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    ntt = parse_ntt_data()
    texts = english_texts()
    creatures, wizards, spells, abilities, structures = {}, {}, {}, {}, {}
    ## F118 (RFC-030g): the @PRC SPELs (goc@ Steam Cloud, cen@ Poison Cloud, tum@ Healing Shower...). Only the ones a CRE8
    ## names in its passive slots (440/452, sacobject.d:607-610) go to abilities.json, below.
    procs = {}

    for odir, name, ext, raw in ex.walk((INSTALL / "spells.wad").read_bytes()):
        spell_tag = name[::-1]
        if ext == "CRE8":
            entry = decode_cre8(raw)
            target = creatures
        elif ext == "WIZD":
            entry = decode_wizd(raw)
            target = wizards
            spell_tag = name
        elif ext == "SPEL":
            entry = decode_spel(raw)
            target = abilities if "@ABI" in odir else spells
            if "@PRC" in odir:
                target = procs
            elif "@ABI" not in odir and "@SHR" in odir:
                continue
        elif ext == "STRC":
            entry = decode_strc(raw)
            target = structures
        else:
            continue
        lookup = entry.get("spell_tag", spell_tag)
        entry["tag"] = spell_tag
        entry["name"] = display_name(lookup, ntt)
        entry["game_name"] = texts.get(entry.get("name_tag", lookup), "")
        if target is abilities and entry["game_name"]:
            entry["name"] = entry["game_name"]
        entry["folder"] = odir.split("/")[-1]
        target[spell_tag] = entry

    spells.update(structures)
    for entry in creatures.values():
        for passive in entry["passive_abilities"]:
            if passive in procs:
                abilities[passive] = procs[passive]
    anim_index = index_saxs_animations()
    model_paths = index_saxs_models()
    for creature_tag, entry in creatures.items():
        slots = entry["abilities"]
        # sacobject.d:425 rangedAttack = abilities[0] if isRanged; :444 ability = abilities[1] if isRanged else abilities[0].
        entry["ranged"] = creature_tag in ntt["ranged"]
        entry["ranged_attack"] = slots[0] if entry["ranged"] else ""
        entry["active_ability"] = slots[1] if entry["ranged"] else slots[0]
        # sacobject.d:426 passiveOnDamage = abilities[2] (korq Taurock, ahtf Firefist, rifl Phoenix, gcil, hmba...).
        entry["passive_on_damage"] = slots[2]
        # Every non-null slot, the passive too: shiny.d:888-898 counts and rates all of sacObject.abilities.
        entry["abilities"] = [a for a in slots if a]
        entry["passive_abilities"] = [a for a in entry["passive_abilities"] if a]
        model_path = model_paths.get(entry["model"].lower(), "")
        locomotion: dict = entry.pop("locomotion_animation_tags", {})
        entry["stance_animation"] = clip_animation(anim_index, model_path, locomotion.get("stance", ""))
        entry["idle_animation"] = clip_animation(anim_index, model_path, locomotion.get("idle", ""))
        entry["run_animation"] = clip_animation(anim_index, model_path, locomotion.get("run", ""))
        entry["walk_animation"] = clip_animation(anim_index, model_path, locomotion.get("walk", ""))
        entry["melee_animations"] = [
            melee_animation(anim_index, model_path, anim_tag) for anim_tag in entry.pop("attack_animation_tags")
        ]
        entry["shoot_animations"] = [
            melee_animation(anim_index, model_path, anim_tag, SHOOT_EVENT, "shoot_ticks")
            for anim_tag in entry.pop("shoot_animation_tags")
        ]
        extra: dict = {}
        if creature_tag in PEASANT_TAGS:
            for role, anim_tag in entry.pop("extra_animation_tags").items():
                clip = clip_animation(anim_index, model_path, anim_tag) if anim_tag and not anim_tag.endswith("00") else {}
                if clip:
                    extra[role] = clip
        else:
            entry.pop("extra_animation_tags")
        entry["extra_animations"] = extra
        entry["flight_animations"] = flight_animations(
            anim_index, model_path, entry.pop("flight_animation_tags"), locomotion.get("stance", ""), creature_tag in PEASANT_TAGS)
        stun_tags: dict = entry.pop("stun_animation_tags")
        if creature_tag in PEASANT_TAGS:
            stun_tags.pop("fly_damage", None)
        entry["stun_animations"] = flight_animations(anim_index, model_path, stun_tags, locomotion.get("stance", ""), False)
        # RFC-023f: death0 (ground) and flyDeath (creatures that must fly) as clips; the hover pose joins the flight clips.
        death_tags: dict = entry.pop("death_animation_tags")
        if creature_tag in PEASANT_TAGS:
            death_tags.pop("fly_death", None)
        entry["death_animations"] = flight_animations(anim_index, model_path, death_tags, "", False)
        hover = flight_animations(anim_index, model_path, {"hover": entry.pop("hover_animation_tag")}, locomotion.get("stance", ""), creature_tag in PEASANT_TAGS)
        entry["flight_animations"].update(hover)
        entry["captive_animations"] = flight_animations(
            anim_index, model_path, entry.pop("captive_animation_tags"), locomotion.get("stance", ""), creature_tag in PEASANT_TAGS)
    for entry in wizards.values():
        entry["abilities"] = [a for a in entry["abilities"] if a]
        # Ghost timing (state.d:14000-14099): dying, deadToGhost and ghostToIdle last numFrames·updateAnimFactor ticks.
        model_path = model_paths.get(entry["model"].lower(), "")
        locomotion: dict = entry.pop("locomotion_animation_tags", {})
        entry["stance_animation"] = clip_animation(anim_index, model_path, locomotion.get("stance", ""))
        entry["idle_animation"] = clip_animation(anim_index, model_path, locomotion.get("idle", ""))
        entry["run_animation"] = clip_animation(anim_index, model_path, locomotion.get("run", ""))
        entry["walk_animation"] = clip_animation(anim_index, model_path, locomotion.get("walk", ""))
        entry["cast_animations"] = flight_animations(
            anim_index, model_path, entry.pop("cast_animation_tags"), locomotion.get("stance", ""), False)
        entry["death_frames"] = [
            melee_animation(anim_index, model_path, anim_tag).get("frames", 0) for anim_tag in entry.pop("death_animation_tags")
        ]
        entry["corpse_rise_frames"] = melee_animation(anim_index, model_path, entry.pop("corpse_rise_tag")).get("frames", 0)
        entry["float_to_stance_frames"] = melee_animation(anim_index, model_path, entry.pop("float_to_stance_tag")).get("frames", 0)
        entry["stun_animations"] = flight_animations(
            anim_index, model_path, entry.pop("stun_animation_tags"), locomotion.get("stance", ""), False)

    lists = ntt["lists"]
    books = {}
    for god in GODS:
        books[god] = {
            "creatures": lists["neutralCreatures"] + lists[f"{god}Creatures"],
            "spells": lists["neutralSpells"] + lists[f"{god}Spells"][:1],
            "structures": lists["structureSpells"][:-1],
            "levels": book_levels(lists, god),
        }

    ordered_wizards = {key: wizards[key] for key in sorted(wizards)}
    outputs = {
        "creatures.json": creatures,
        "wizards.json": ordered_wizards,
        "spells.json": spells,
        "abilities.json": abilities,
        "books.json": books,
    }
    for filename, payload in outputs.items():
        (OUT / filename).write_text(json.dumps(payload, indent=1, ensure_ascii=False))
    write_buildings_json(read_buildings()[0])

    print("creatures", len(creatures), "wizards", len(wizards), "spells", len(spells), "abilities", len(abilities))
    trogg = creatures["ycro"]
    print(
        "Trogg", trogg["health"], "vida", trogg["running_speed"], "m/s", trogg["souls"], "alma",
        "maná", trogg["mana_cost"], "modelo", trogg["model"], "cooldown", trogg["cooldown_s"], "s",
    )
    for creature_tag in ("ycro", "nmuh"):
        print(creature_tag, "ataques", [
            (a.get("tag"), a.get("frames"), a.get("framerate"), a.get("attack_ticks")) for a in creatures[creature_tag]["melee_animations"]
        ])
    fling = creatures["palk"]
    print(
        "Earthfling ranged", fling["ranged"], "disparo", fling["ranged_attack"], "habilidad", fling["active_ability"],
        "maná", fling["mana"], "disparos", [(a.get("tag"), a.get("frames"), a.get("framerate"), a.get("shoot_ticks")) for a in fling["shoot_animations"]],
    )
    rock = spells["kcor"]
    print(
        "Rock", rock["mana_cost"], "maná alcance", rock["range"], "cooldown", rock["cooldown_s"], "s",
        "lanzamiento", rock["casting_time_s"], "s", "velocidad", rock["speed"], "daño", rock["amount"],
    )
    for god, book in books.items():
        print(
            god,
            ", ".join(display_name(t, ntt) for t in book["creatures"]),
            "/",
            ", ".join(display_name(t, ntt) for t in book["spells"]),
        )
    print("magos", ", ".join(w["name"] for w in ordered_wizards.values()))
    james = ordered_wizards["cwa0"]
    print("cwa0 muerte", james["death_frames"], "fantasma", james["corpse_rise_frames"], "vuelta", james["float_to_stance_frames"])
    print("magos aturdidos", {t: {r: c.get("frames") for r, c in w["stun_animations"].items()} for t, w in ordered_wizards.items()})


if __name__ == "__main__":
    import sys

    args = sys.argv[1:]
    if "--out" in args:
        at = args.index("--out")
        OUT = Path(args[at + 1]).resolve()
        del args[at:at + 2]
    main()
