#!/usr/bin/env python3
"""F164 (RFC-030 030w-e): what sacengine would do with the life drain on debug/f164_drain, replicated from state.d and the
creature / SPEL data, next to what the port logged.

Usage: python3 -I agent/tools/f164_expect.py [godot log of debug/f164_drain (rules debug/rules/f164_drain.tres)]
       python3 -I agent/tools/f164_expect.py --lanes     (only the lane check against the map caches)

Needs the bench switches on (debug/ai_match.gd): MeleeAttack.log_melee, LifeDrain.log_drain.

sacengine:
- dealDamage (state.d:8933-8946) works out the damage the target really takes (actualDamage, capped at the health it has left)
  and calls healFromDrain (8834-8840): a live attacker that is a creature heals actualDamage · its CRE8 `drain` at once, and
  heal (8815-8817) stops at its maximum health. Only mobile bodies feed it (a building never does, 9193-9207).
- The Scythe dzid and the Fallen dplk have drain 0.5; the Locust pazb 0.875 (measured in f166_expect.py). sacengine drains
  the whole damage of the creature, also from a distance (the Fallen's dkba is a direct ranged hit). Splash and poison:
  F164b, not here.
Cast (anchor 1270, 1270; 0.3 min; all attack at 0.5 s, audit tick 30):
  z-80  Scythe1 (slot 1, 50 % health = 270 of 540, holds still) at -30 hits Troll1 (slot 2, pacifist) at -27.
  z-70  Scythe2 (slot 1, full health) at -45 hits Troll2 at -42 (15 m west of the plan: the jhut at -15/-56): it is at its maximum, so no feeding.
  z-90  Fallen1 (slot 1, 50 % health = 360 of 720, holds still) at -60 shoots dkba (125) at Troll3 at -40 (the plan's -25 is 2.8 m from a jcc2): 125 · 0.9 = 112.5.
Log lines:
  golpe Scythe1 → Troll1 ... cantidad 136.0023 (tick 94)                               (MeleeAttack.log_melee)
  drena Scythe1 de Troll1 136.0023 (escala 0.500) -> vida 338.0012 ganada 68.0012 (tick 94)   (LifeDrain.log_drain, only if it gained)
Port axes: x, y up, z.
"""
import importlib.util
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("f131_expect", os.path.join(HERE, "f131_expect.py"))
f131 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(f131)

verdict = f131.verdict
NUM = r"(-?\d+(?:\.\d+)?)"
TOL = 0.01

# name -> (dx, dz, slot, kind) from the anchor
LANES = {
    "K1": (-30.0, -80.0, 1, "Scythe"),
    "T1": (-27.0, -80.0, 2, "Troll"),
    "K2": (-45.0, -70.0, 1, "Scythe"),
    "T2": (-42.0, -70.0, 2, "Troll"),
    "F1": (-60.0, -90.0, 1, "Fallen"),
    "T3": (-40.0, -90.0, 2, "Troll"),
}
HALF_BOX = {"Scythe": 3.0, "Troll": 3.0, "Fallen": 3.0}


def data():
    """Drain, health of the attackers, the Troll's direct ranged resistance and dkba's amount, from the data of the port."""
    root = os.path.join(HERE, "..", "..", "assets", "original", "data")
    creatures = json.load(open(os.path.join(root, "creatures.json"), encoding="utf-8"))
    spel = json.load(open(os.path.join(root, "abilities.json"), encoding="utf-8"))
    return creatures["dzid"], creatures["dplk"], creatures["lort"], spel["dkba"]


def check_lanes():
    return f131.lane_report(LANES, half_box=HALF_BOX, big_struct={"jhut": 16.0})


def read(lines):
    """blows: (attacker, target, amount, tick); feeds: (attacker, target, taken, scale, hp, gained, tick)."""
    blows, feeds = [], []
    for line in lines:
        m = re.match(r"golpe (\S+) → (\S+) .* cantidad " + NUM + r" \(tick (\d+)\)", line)
        if m:
            blows.append((m.group(1), m.group(2), float(m.group(3)), int(m.group(4))))
            continue
        m = re.match(r"drena (\S+) de (\S+) " + NUM + r" \(escala " + NUM + r"\) -> vida " + NUM + r" ganada " + NUM + r" \(tick (\d+)\)", line)
        if m:
            feeds.append((m.group(1), m.group(2), float(m.group(3)), float(m.group(4)), float(m.group(5)), float(m.group(6)), int(m.group(7))))
    return blows, feeds


def check_log(path):
    scythe, fallen, troll, dkba = data()
    drain = float(scythe["drain"])
    full = float(scythe["health"])
    shot = float(dkba["amount"]) * float(troll["resistances"]["direct_ranged"])
    print("Scythe: %.0f de vida, drena %.3f; Fallen: %.0f de vida, drena %.3f; dkba %.0f · Troll directo %.2f = %.2f" % (
        full, drain, float(fallen["health"]), float(fallen["drain"]), float(dkba["amount"]),
        float(troll["resistances"]["direct_ranged"]), shot))
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    blows, feeds = read(lines)
    ok = verdict(not any("SCRIPT ERROR" in l for l in lines), "sin SCRIPT ERROR")

    # 1. Scythe1: every blow with amount > 0 heals 0.5 · amount in the same tick, up to the maximum.
    k1 = [b for b in blows if b[0] == "Scythe1" and b[1] == "Troll1" and b[2] > 0.0]
    ok &= verdict(len(k1) >= 5, "Scythe1 pega a Troll1 al menos 5 veces: %d" % len(k1))
    hp = full * 0.5
    capped = 0
    for att, tgt, amount, tick in k1:
        want = min(full, hp + drain * amount)
        gained = want - hp
        hp = want
        fed = [f for f in feeds if f[0] == "Scythe1" and f[6] == tick]
        if gained <= TOL / 10:
            good = not fed
            capped += 1
            what = "al tope de %.0f: sin línea de cura" % full
        else:
            good = len(fed) == 1 and abs(fed[0][2] - amount) <= TOL and abs(fed[0][5] - gained) <= TOL and abs(fed[0][4] - hp) <= TOL
            what = "cura %.4f (esperado %.4f), vida %.4f" % (fed[0][5] if fed else 0.0, gained, hp)
        ok &= verdict(good, "tick %d: golpe %.4f -> %s" % (tick, amount, what))
    ok &= verdict(capped >= 1, "al menos un golpe de Scythe1 llega con la vida al tope: %d" % capped)
    ok &= verdict(abs(hp - full) <= TOL, "Scythe1 termina en %.0f (el tope)" % hp)
    ok &= verdict(not any(f[0] == "Scythe1" and f[1] != "Troll1" for f in feeds), "Scythe1 solo drena de Troll1")

    # 2. Scythe2 is at 540 from the start: it hits, and never feeds.
    k2 = [b for b in blows if b[0] == "Scythe2" and b[2] > 0.0]
    ok &= verdict(len(k2) >= 3, "Scythe2 pega al menos 3 veces: %d" % len(k2))
    ok &= verdict(not any(f[0] == "Scythe2" for f in feeds), "Scythe2 (vida llena) no tiene líneas de cura")

    # 3. Fallen1: each shot heals 0.5 · the direct hit.
    f1 = [f for f in feeds if f[0] == "Fallen1"]
    ok &= verdict(len(f1) >= 3, "Fallen1 cura con al menos 3 disparos: %d" % len(f1))
    hp = float(fallen["health"]) * 0.5
    for att, tgt, taken, scale, now, gained, tick in f1:
        hp = min(float(fallen["health"]), hp + float(fallen["drain"]) * shot)
        good = tgt == "Troll3" and abs(taken - shot) <= TOL and abs(scale - float(fallen["drain"])) <= 1e-3 and \
            abs(gained - float(fallen["drain"]) * shot) <= TOL and abs(now - hp) <= TOL
        ok &= verdict(good, "tick %d: disparo %.2f -> cura %.3f (esperado %.3f), vida %.3f" % (
            tick, taken, gained, float(fallen["drain"]) * shot, now))

    # 4. Nobody else drains here (the Trolls have no drain).
    ok &= verdict(all(f[0] in ("Scythe1", "Fallen1") for f in feeds), "solo Scythe1 y Fallen1 aparecen en las líneas de cura")
    return ok


def main():
    args = sys.argv[1:]
    ok = check_lanes()
    if args and args[0] != "--lanes":
        ok = check_log(args[0]) and ok
    print("RESULTADO %s" % ("PASS" if ok else "FAIL"))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
