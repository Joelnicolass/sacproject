#!/usr/bin/env python3
"""F161 (RFC-030 030w-b): what sacengine would do with the Brainiac's bsba and the Shrike's absh on debug/f161_stun_shots,
replicated from state.d and the SPEL / creature data, next to what the port logged.

Usage: python3 -I agent/tools/f161_expect.py [godot log of debug/f161_stun_shots (rules debug/rules/f161_stun_shots.tres)]
       python3 -I agent/tools/f161_expect.py --lanes     (only the lane check against the map caches)
       python3 -I agent/tools/f161_expect.py --numbers   (the figures of the replica, no log)

sacengine:
- brainiacShoot / shrikeShoot (11513-11525): a straight shot of the SPEL's range and speed (bsba 200, range 90, speed 36;
  absh 150, range 35, speed 36).
- updateBrainiacProjectile (22886-22936) and updateShrikeProjectile (22952-22989): the shot meets the target or any body
  that is not of the shooter's side; on a creature or a wizard it calls stunWithCooldown(stunCooldownFrames) and then, by the
  `goto case`, dealRangedDamage(DamageMod.none): the stun first, the damage after. 480 is the stun COOLDOWN
  (stunCooldownFrames = 8·updateFPS, 8561-8568), not how long it lies: that is the Stunned clip length (72 ticks for a Troll).
- stunWithCooldown refuses while the body's own cooldown runs; the cooldown counts from the stun.
Log lines (the bench switches are the ones ai_match always turns on):
  aturdido Troll durante 72 (cuadro T)            StunImpact -> Stunned.stun_with_cooldown
  aturdir: Troll en enfriamiento (c) (cuadro T)   the stun was refused, c = 480 - (T - the tick of the last stun)
  directo Troll 180.0                              DirectImpact: monto · resistencia a distancia directa, right after
Both Trolls are called «Troll» in the log: the Brainiac's hits are told from the Shrike's by the amount (bsba 200 · 0.9 = 180,
absh 150 · 0.9 = 135).
Port axes: x, y up, z; the original's z is the port's y.
"""
import importlib.util
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("f131_expect", os.path.join(HERE, "f131_expect.py"))
f131 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(f131)

verdict = f131.verdict
NUM = f131.NUM
TOL = 1
COOLDOWN = 480
DAMAGE_TOL = 0.01
TROLL_DIRECT_RANGED = 0.9

# name -> (dx, dz, slot, kind) from the anchor
LANES = {
    "B1": (-45.0, -80.0, 1, "Brainiac"),
    "S1": (-45.0, -72.0, 1, "Shrike"),
    "T1": (-20.0, -80.0, 2, "Troll"),
    "T2": (-20.0, -72.0, 2, "Troll"),
}
RANGE = {"B1": 90.0, "S1": 35.0}
AMOUNT = {"B1": 200.0, "S1": 150.0}
# the shot that hits each Troll
SHOOTER = {"T1": "B1", "T2": "S1"}


def expected_damage(shooter):
    return AMOUNT[shooter] * TROLL_DIRECT_RANGED


def numbers():
    for troll, shooter in SHOOTER.items():
        print("%s -> %s: monto %g · %.1f = %.1f, aturde con enfriamiento %d" % (
            shooter, troll, AMOUNT[shooter], TROLL_DIRECT_RANGED, expected_damage(shooter), COOLDOWN))


def check_lanes():
    ok = f131.lane_report(LANES)
    for troll, shooter in SHOOTER.items():
        d = f131.flat(LANES, shooter, troll)
        good = d <= RANGE[shooter] and abs(d - 25.0) < 0.01
        ok = ok and good
        print("%s -> %s: %.2f m en planta (alcance %g) %s" % (shooter, troll, d, RANGE[shooter], "ok" if good else "MAL"))
    rows = f131.flat(LANES, "B1", "S1")
    good = rows >= 8.0 - 0.01
    ok = ok and good
    print("fila B a fila S: %.2f m (>= 8, sin contacto) %s" % (rows, "ok" if good else "MAL"))
    return ok


def read_hits(lines):
    """Per shot (told by its amount) the impacts in order: {tick, stunned, cooldown, damage}."""
    stream = []
    for line in lines:
        m = re.search(r"aturdido (\S+) durante (\d+) \(cuadro (\d+)\)", line)
        if m:
            stream.append(("stun", int(m.group(3)), int(m.group(2)), None))
            continue
        m = re.search(r"aturdir: (\S+) en enfriamiento \((\d+)\) \(cuadro (\d+)\)", line)
        if m:
            stream.append(("cool", int(m.group(3)), None, int(m.group(2))))
            continue
        m = re.match(r"\s+directo (\S+) " + NUM + r"$", line)
        if m:
            stream.append(("direct", None, None, float(m.group(2))))
    hits = []
    pending = None
    for kind, tick, length, value in stream:
        if kind in ("stun", "cool"):
            pending = {"tick": tick, "stunned": kind == "stun", "length": length, "cooldown": value}
        elif kind == "direct":
            if pending is None:
                hits.append({"tick": None, "stunned": None, "length": None, "cooldown": None, "damage": value, "order_ok": False})
            else:
                pending["damage"] = value
                pending["order_ok"] = True
                hits.append(pending)
                pending = None
    return hits


def check_log(path):
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    hits = read_hits(lines)
    ok = True
    for troll, shooter in SHOOTER.items():
        want = expected_damage(shooter)
        mine = [h for h in hits if abs(h["damage"] - want) <= DAMAGE_TOL]
        ok &= verdict(len(mine) >= 3, "%s: %d impactos de %s con daño %.1f (>= 3)" % (troll, len(mine), shooter, want))
        if not mine:
            continue
        ok &= verdict(all(h["order_ok"] for h in mine), "1. %s: cada impacto da el aturdimiento y despues el directo" % troll)
        ok &= verdict(mine[0]["stunned"] and mine[0]["length"] is not None and mine[0]["length"] > 0,
                      "1. %s: el primer impacto aturde (durante %s, cuadro %s)" % (troll, mine[0]["length"], mine[0]["tick"]))
        # 2. the damage is the amount times the direct ranged resistance (by construction of the selection above; the
        # other amounts must not appear)
        # 3. the cooldown counts from the last stun
        last_stun = None
        refused = stunned_again = 0
        bad = []
        for h in mine:
            if last_stun is None or h["tick"] - last_stun >= COOLDOWN:
                if not h["stunned"]:
                    bad.append(("debia aturdir", h))
                else:
                    if last_stun is not None:
                        stunned_again += 1
                    last_stun = h["tick"]
            else:
                want_c = COOLDOWN - (h["tick"] - last_stun)
                if h["stunned"] or h["cooldown"] is None or abs(h["cooldown"] - want_c) > TOL:
                    bad.append(("enfriamiento esperado %d" % want_c, h))
                else:
                    refused += 1
        ok &= verdict(not bad, "3. %s: %d en enfriamiento con c = 480 - dt (±1), %d vez(ces) vuelve a aturdir tras 480%s" % (
            troll, refused, stunned_again, "" if not bad else " MAL: %s" % bad[:2]))
        ok &= verdict(refused >= 1 and stunned_again >= 1, "3. %s: hubo impactos dentro de 480 y uno despues de 480" % troll)
    other = [h for h in hits if all(abs(h["damage"] - expected_damage(s)) > DAMAGE_TOL for s in SHOOTER.values())]
    ok &= verdict(not other, "2. todo daño directo es monto · 0.9 (180.0 o 135.0): %s" % [h["damage"] for h in other][:3])
    return ok


def main():
    args = sys.argv[1:]
    if args and args[0] == "--numbers":
        numbers()
        return
    ok = check_lanes()
    if args and args[0] != "--lanes":
        ok = check_log(args[0]) and ok
    print("RESULTADO %s" % ("PASS" if ok else "FAIL"))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
