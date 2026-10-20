#!/usr/bin/env python3
"""F130 (RFC-030 030s-a): what sacengine would do with the Storm Giant's Call lightning (gsba) and Lightning Charge (gcil) on
lanes L and K of debug/f130_lightning, replicated from state.d and the SPEL data, next to what the port logged.

Usage: python3 -I agent/tools/f130_expect.py [godot log of debug/f130_lightning (rules debug/rules/f130_lightning.tres), run with --log=pace]
       python3 -I agent/tools/f130_expect.py --lanes     (only the lane check against the map files)
       python3 -I agent/tools/f130_expect.py --numbers   (the figures of the replica, no log)

Needs the bench switches on (debug/ai/ai_match.gd): LightningStrike.log_bolt, LightningCharge.log_charge, PaceFactors.log_pace,
AbilityEffect.log_effects and MeleeAttack.log_melee (phase 2 of 030s-a).

sacengine:
- callLightning (13121-13129): always applies. The ability costs 50 (200 -> 150) and has no cooldown. It throws lightning() (10474-10491)
  with the SPEL ntil (750) from center + 100 * normalize(uniformDirection + (0, 0, 6)) to the Giant's own center. updateTargets cuts
  the ray at the first body it crosses (the Giant excepted): nobody here, so the bolt hurts the Giant.
- The damage lands at frame 12 (Lightning.travelDelay, 2831-2840, 16366-16386): dealSpellDamage with DamageMod.lightning. Friendly fire
  on: sideDamageMultiplier 0.5 (28892-28899) -> 375. dealRawDamage (9017-9022): charge int(4/60 * 375 * 60) = 1500 frames (4 = the
  attacker is an ally) and the Giant takes a quarter: 93.75 (its direct-spell resistance is 1.0).
- updateLightningCharge (25342-25386): frames -= 1 and ramp += 1/60 every tick; with frames >= 250 and uniform < ramp/60 a discharge:
  uniform(n + 4) among the n bodies within 30 m (centers) and the land (2D, 5 m to 30 m); itself = nothing; else frames -= 125,
  ramp = 0 and a gcil bolt (250) that lands 12 frames later. Charged: pace x1.5 (stats.d:122: 9.0 m/s -> 0.225 m per tick; the
  uncharged Giant 0.150), blow x1.5 (8885) and melee accuracy x1.5 (9237: 1500 -> 2250).
- The charge ends when frames reach 0: T + 12 + 1500 - 125 k (k = discharges), +-1.
Lane L (anchor 1270, 1270): SG1 StormGiant1 -40/+15 (slot 1, order ability at the start), L1 Trogg1 -10/+15 (slot 2, pacifist, immune to
spells: the discharges on it do 0). Lane K: SG2 StormGiant2 +28/-50 (slot 1), K1 Trogg2 +58/-50 (slot 2, pacifist).
Log lines:
  habilidad Call lightning mana 200->150 enfriamiento 0 ticks                                          (ActiveAbility)
  rayo gsba StormGiant1 sorteo (sx, sy, sz) origen (x, y, z) (tick T)                                  (CallLightning)
  rayo gsba StormGiant1 nace de (x, y, z) a StormGiant1 en (x, y, z) (tick T)                          (LightningStrike)
  rayo gsba StormGiant1 dano StormGiant1 93.75 vida V (tick T+12)
  carga StormGiant1 +1500 cuadros total 1500 (tick T+12)                                               (LightningCharge)
  carga StormGiant1 descarga a Trogg1 a D m | suelo (x, y, z) (candidatos n, tirada p) cuadros A->B (tick N)
  carga StormGiant1 fin (tick E)
  ritmo StormGiant1 ×1.5000 [...] (tick N)                                                             (PaceFactors)
  marcha StormGiant1 ×1.5000 (x, y, z) (tick N)                                                        (LightningCharge, every tick it moves)
  golpe StormGiant1 → Trogg1 precisión A evasión E facing F pendiente P p P tirada R fuerza S escala C resistencia X factor Y cantidad Z (tick N)
Port axes: x, y up, z; the original's z is the port's y.
"""
import importlib.util
import math
import os
import re
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("f128_expect", os.path.join(HERE, "f128_expect.py"))
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)

T60 = 60.0
ANCHOR = base.ANCHOR
verdict = base.verdict
NUM = base.NUM
VEC = base.VEC

SPELL_AMOUNT = 750.0
ALLY_FACTOR = 0.5
RESISTANCE = 1.0
PASSIVE_LEFT = 0.25
CHARGE_FACTOR = 4.0
CHARGE_EXPECT = 1500
HIT_EXPECT = 93.75
MANA = (200, 150)
TRAVEL = 12
DISCHARGE_MIN = 250
DISCHARGE_COST = 125
RANGE = 30.0
GROUND_MIN = 5.0
SKY = 100.0
RUN = 9.0
STEP_CHARGED = RUN * 1.5 / T60
STEP_PLAIN = RUN / T60
STEP_TOL = 0.005
ACC_BASE = 1500.0
ACC_CHARGED = 2250.0
MELEE_BOOST = 1.5
TOL_TICKS = 1
TOL_M = 0.01
SIGHT = 100.0

# name -> (dx, dz, slot, lane) from the anchor
LANES = {
    "StormGiant1": (-40.0, 15.0, 1, "L"),
    "Trogg1": (-10.0, 15.0, 2, "L"),
    "StormGiant2": (28.0, -50.0, 1, "K"),
    "Trogg2": (58.0, -50.0, 2, "K"),
}
CLEAR_STRUCTURE_M = 11.0
CLEAR_WIDGET_M = 6.0
MAX_GRADE = 0.06


def f32(x):
    """Round to a 32-bit float (sacengine's arithmetic)."""
    return struct.unpack("<f", struct.pack("<f", x))[0]


def charge_frames(damage, ally):
    """cast(int)(factor / 60.0f * actualDamage * updateFPS) in float arithmetic."""
    factor = f32(CHARGE_FACTOR if ally else 2.0)
    return int(f32(f32(f32(factor / f32(60.0)) * f32(damage)) * f32(60.0)))


def world(name):
    dx, dz, _, _ = LANES[name]
    return ANCHOR[0] + dx, ANCHOR[1] + dz


def flat(a, b):
    ax, az = world(a)
    bx, bz = world(b)
    return math.hypot(ax - bx, az - bz)


def check_lanes():
    """Land under every body and along both lanes (no hole, gentle slope), no structure within 11 m of a body, no widget within 6 m,
    the ranges (L1 at 30 m from SG1, K1 at 30 m from SG2) and who can see whom (sight 100 m): SG1 does not see K1, SG2 sees both
    Troggs but K1 is the nearer."""
    ok = True
    terrain = base.Terrain.load()
    try:
        import json
        ntts = json.load(open(base.map_file("ntts.json"), encoding="utf-8"))
        widgets = json.load(open(base.map_file("widgets.json"), encoding="utf-8"))
    except OSError:
        ntts, widgets = {"structures": []}, {}
    structures = ntts.get("structures", [])
    for name in LANES:
        x, z = world(name)
        y = terrain.ground(x, z) if terrain else None
        near = [(s["tag"], round(math.hypot(s["x"] - x, s["z"] - z), 1)) for s in structures
                if math.hypot(s["x"] - x, s["z"] - z) < CLEAR_STRUCTURE_M]
        props = [k for k, ps in widgets.items() for p in ps if math.hypot(p[0] - x, p[1] - z) < CLEAR_WIDGET_M]
        bad = (terrain is not None and y is None) or near or props
        ok = ok and not bad
        print("carril %-11s (%.1f, %.1f) suelo %s estructuras<%d %s widgets<%d %s %s" % (
            name, x, z, "?" if y is None else "%.2f" % y, CLEAR_STRUCTURE_M, near, CLEAR_WIDGET_M, props, "MAL" if bad else "ok"))
    if terrain:
        for lane, giant, trogg in (("L", "StormGiant1", "Trogg1"), ("K", "StormGiant2", "Trogg2")):
            gx, gz = world(giant)
            tx, tz = world(trogg)
            x0, x1 = min(gx, tx) - 5.0, max(gx, tx) + 5.0
            holes = 0
            cells = 0
            heights = []
            x = x0
            while x <= x1:
                for z in (gz - 5.0, gz, gz + 5.0):
                    cells += 1
                    y = terrain.ground(x, z)
                    if y is None:
                        holes += 1
                    else:
                        heights.append((x, y))
                x += 2.5
            walk = [terrain.ground(gx + i, gz) for i in range(0, int(tx - gx) + 1)]
            grade = max(abs(walk[i + 1] - walk[i]) for i in range(len(walk) - 1)) if None not in walk else float("nan")
            good = holes == 0 and grade <= MAX_GRADE
            ok = ok and good
            print("carril %s: %d puntos cada 2,5 m, huecos %d, pendiente máxima del camino %.3f m por m (<= %.2f), suelo %.2f a %.2f %s" % (
                lane, cells, holes, grade, MAX_GRADE, min(h for _, h in heights), max(h for _, h in heights), "ok" if good else "MAL"))
    for a, b, want in (("StormGiant1", "Trogg1", 30.0), ("StormGiant2", "Trogg2", 30.0)):
        d = flat(a, b)
        good = abs(d - want) < 0.01 and d <= SIGHT
        ok = ok and good
        print("%s -> %s: %.2f m en planta (visión %.0f) %s" % (a, b, d, SIGHT, "ok" if good else "MAL"))
    far = flat("StormGiant1", "Trogg2")
    good = far > SIGHT
    ok = ok and good
    print("StormGiant1 -> Trogg2: %.2f m en planta (fuera de la visión de %.0f) %s" % (far, SIGHT, "ok" if good else "MAL"))
    near_k = flat("StormGiant2", "Trogg2")
    other = flat("StormGiant2", "Trogg1")
    good = near_k < other
    ok = ok and good
    print("StormGiant2: Trogg2 a %.2f m es el más cercano que Trogg1 a %.2f m %s" % (near_k, other, "ok" if good else "MAL"))
    return ok


def numbers():
    print("daño de Call lightning sobre el propio Giant: %.2f * %.2f * %.2f = %.2f; con la pasiva x%.2f: %.2f (esperado %.2f)" % (
        SPELL_AMOUNT, ALLY_FACTOR, RESISTANCE, SPELL_AMOUNT * ALLY_FACTOR * RESISTANCE,
        PASSIVE_LEFT, SPELL_AMOUNT * ALLY_FACTOR * RESISTANCE * PASSIVE_LEFT, HIT_EXPECT))
    print("carga: int(4/60 * 375 * 60) en float32 = %d (esperado %d); sin aliado (f = 2): %d" % (
        charge_frames(SPELL_AMOUNT * ALLY_FACTOR, True), CHARGE_EXPECT, charge_frames(SPELL_AMOUNT * ALLY_FACTOR, False)))
    print("paso por tick: cargado %.3f, sin carga %.3f; precisión cuerpo a cuerpo: %.0f -> %.0f" % (
        STEP_CHARGED, STEP_PLAIN, ACC_BASE, ACC_CHARGED))
    for k in range(0, 11):
        print("  k = %2d descargas: la carga termina en T + %d" % (k, TRAVEL + CHARGE_EXPECT - DISCHARGE_COST * k))


def read_log(path):
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    log = {"ability": [], "origin": None, "born": [], "hits": [], "grounds": [], "stale": [], "adds": [], "discharges": [], "selfpick": [],
           "end": None, "pace": [], "walk": {}, "blows": []}
    for line in lines:
        m = re.search(r"habilidad Call lightning mana (\d+)->(\d+) enfriamiento (\d+) ticks", line)
        if m:
            log["ability"].append((int(m.group(1)), int(m.group(2)), int(m.group(3))))
        m = re.search(r"rayo gsba (\S+) sorteo \(" + NUM + r", " + NUM + r", " + NUM + r"\) origen " + VEC + r" \(tick (\d+)\)", line)
        if m:
            log["origin"] = {"draw": tuple(float(m.group(i)) for i in (2, 3, 4)), "origin": tuple(float(m.group(i)) for i in (5, 6, 7)),
                             "tick": int(m.group(8))}
        m = re.search(r"rayo (gsba|gcil) (\S+) nace de " + VEC + r" a (\S+) en " + VEC + r" \(tick (\d+)\)", line)
        if m:
            log["born"].append({"label": m.group(1), "who": m.group(2), "from": tuple(float(m.group(i)) for i in (3, 4, 5)),
                                "to": m.group(6), "at": tuple(float(m.group(i)) for i in (7, 8, 9)), "tick": int(m.group(10))})
        m = re.search(r"rayo (gsba|gcil) (\S+) dano (\S+) " + NUM + r" vida " + NUM + r" \(tick (\d+)\)", line)
        if m:
            log["hits"].append({"label": m.group(1), "who": m.group(2), "target": m.group(3), "taken": float(m.group(4)),
                                "health": float(m.group(5)), "tick": int(m.group(6))})
        m = re.search(r"rayo (gsba|gcil) (\S+) llega al suelo en " + VEC + r" \(tick (\d+)\)", line)
        if m:
            log["grounds"].append({"label": m.group(1), "who": m.group(2), "tick": int(m.group(6))})
        m = re.search(r"rayo (gsba|gcil) (\S+) llega a (\S+): ya no es blanco \(tick (\d+)\)", line)
        if m:
            log["stale"].append({"label": m.group(1), "who": m.group(2), "target": m.group(3), "tick": int(m.group(4))})
        m = re.search(r"carga (\S+) \+(\d+) cuadros total (\d+) \(tick (\d+)\)", line)
        if m:
            log["adds"].append({"who": m.group(1), "add": int(m.group(2)), "total": int(m.group(3)), "tick": int(m.group(4))})
        m = re.search(r"carga (\S+) descarga a (?:(\S+) a " + NUM + r" m|suelo " + VEC + r") \(candidatos (\d+), tirada (\d+)\) cuadros (\d+)->(\d+) \(tick (\d+)\)", line)
        if m:
            ground = m.group(2) is None
            log["discharges"].append({
                "who": m.group(1), "target": None if ground else m.group(2), "dist": None if ground else float(m.group(3)),
                "ground": tuple(float(m.group(i)) for i in (4, 5, 6)) if ground else None,
                "n": int(m.group(7)), "pick": int(m.group(8)), "before": int(m.group(9)), "after": int(m.group(10)), "tick": int(m.group(11))})
        m = re.search(r"carga (\S+) elige su propio cuerpo: nada \(candidatos (\d+), tirada (\d+), tick (\d+)\)", line)
        if m:
            log["selfpick"].append({"who": m.group(1), "tick": int(m.group(4))})
        m = re.search(r"carga (\S+) fin(?: por muerte)? \(tick (\d+)\)", line)
        if m and log["end"] is None:
            log["end"] = {"who": m.group(1), "tick": int(m.group(2)), "death": "por muerte" in line}
        m = re.search(r"ritmo (\S+) ×" + NUM + r" .* \(tick (\d+)\)", line)
        if m:
            log["pace"].append({"who": m.group(1), "factor": float(m.group(2)), "tick": int(m.group(3))})
        m = re.search(r"marcha (\S+) ×" + NUM + r" " + VEC + r" \(tick (\d+)\)", line)
        if m:
            log["walk"].setdefault(m.group(1), []).append({
                "factor": float(m.group(2)), "pos": tuple(float(m.group(i)) for i in (3, 4, 5)), "tick": int(m.group(6))})
        m = re.search(r"golpe (\S+) → (\S+) precisión " + NUM + r" evasión " + NUM + r" facing " + NUM + r" pendiente " + NUM + r" p " + NUM
                      + r" tirada " + NUM + r" fuerza (\d+) escala " + NUM + r" resistencia " + NUM + r" factor " + NUM + r" cantidad " + NUM
                      + r" \(tick (\d+)\)", line)
        if m:
            g = m.groups()
            log["blows"].append({"who": g[0], "foe": g[1], "acc": float(g[2]), "eva": float(g[3]), "facing": float(g[4]), "pending": float(g[5]),
                                 "p": float(g[6]), "roll": float(g[7]), "strength": int(g[8]), "scale": float(g[9]), "res": float(g[10]),
                                 "factor": float(g[11]), "amount": float(g[12]), "tick": int(g[13])})
    return log


def steps_of(points):
    """Flat distance between consecutive ticks of a walk: [(tick, factor, step)]."""
    out = []
    for a, b in zip(points, points[1:]):
        if b["tick"] == a["tick"] + 1:
            out.append((b["tick"], b["factor"], math.hypot(b["pos"][0] - a["pos"][0], b["pos"][2] - a["pos"][2])))
    return out


def median(values):
    values = sorted(values)
    return values[len(values) // 2] if values else float("nan")


def check_log(path):
    log = read_log(path)
    ok = True
    # 1. the ability, the bolt, the hit and the charge.
    ability = log["ability"][0] if log["ability"] else None
    ok &= verdict(ability is not None and ability == (MANA[0], MANA[1], 0),
                  "1. habilidad Call lightning mana %d->%d enfriamiento 0 ticks: %s" % (MANA[0], MANA[1], str(ability)))
    first = next((b for b in log["born"] if b["label"] == "gsba"), None)
    ok &= verdict(first is not None and first["who"] == "StormGiant1" and first["to"] == "StormGiant1",
                  "1. el rayo gsba de StormGiant1 nace sobre sí mismo (nadie en el camino): %s" % (str(first["to"]) if first else None))
    t0 = first["tick"] if first else None
    origin = log["origin"]
    if origin and first:
        sx, sy, sz = origin["draw"]
        u = (sx, sz, sy)
        un = math.sqrt(sum(c * c for c in u))
        v = (u[0] / un, u[1] / un + 6.0, u[2] / un)
        n = math.sqrt(sum(c * c for c in v))
        want = tuple(first["at"][i] + SKY * v[i] / n for i in range(3))
        diff = max(abs(a - b) for a, b in zip(want, origin["origin"]))
        ok &= verdict(diff <= TOL_M, "1. origen = centro + 100 * normalize(sorteo + (0, 6, 0)): diferencia %.4f m (± %.2f)" % (diff, TOL_M))
        ok &= verdict(all(-1.0 <= c <= 1.0 for c in origin["draw"]) and origin["tick"] == t0,
                      "1. el sorteo es de [-1, 1) y del tick del uso: %s (tick %s)" % (origin["draw"], origin["tick"]))
    hit = next((h for h in log["hits"] if h["label"] == "gsba"), None)
    ok &= verdict(hit is not None and t0 is not None and abs(hit["tick"] - (t0 + TRAVEL)) <= TOL_TICKS,
                  "1. el rayo pega en T+%d (± %d): T = %s, tick %s" % (TRAVEL, TOL_TICKS, t0, hit["tick"] if hit else None))
    ok &= verdict(hit is not None and hit["target"] == "StormGiant1" and abs(hit["taken"] - HIT_EXPECT) <= TOL_M,
                  "1. dano StormGiant1 %.2f (esperado %.2f = 750 * 0.5 * 0.25 ± %.2f): %s" % (
                      HIT_EXPECT, HIT_EXPECT, TOL_M, str(hit["taken"] if hit else None)))
    add = next((a for a in log["adds"] if a["who"] == "StormGiant1"), None)
    want_add = charge_frames(SPELL_AMOUNT * ALLY_FACTOR, True)
    ok &= verdict(add is not None and add["add"] == want_add and hit is not None and add["tick"] == hit["tick"],
                  "1. carga StormGiant1 +%d cuadros (réplica en float32 %d, ± 1) en el tick del daño: %s" % (
                      CHARGE_EXPECT, want_add, str((add["add"], add["tick"]) if add else None)))
    ok &= verdict(add is not None and abs(add["add"] - CHARGE_EXPECT) <= 1, "1. la carga es 1500 (± 1): %s" % (add["add"] if add else None))
    ok &= verdict(not [a for a in log["adds"] if a["who"] == "StormGiant2"] and "StormGiant2" not in {d["who"] for d in log["discharges"]},
                  "K. StormGiant2 nunca se carga ni descarga")
    # 2. the pace.
    charged = [p for p in log["pace"] if p["who"] == "StormGiant1"]
    on = next((p for p in charged if abs(p["factor"] - 1.5) < 1e-3), None)
    off = next((p for p in charged if on is not None and p["tick"] > on["tick"] and abs(p["factor"] - 1.0) < 1e-3), None)
    ok &= verdict(on is not None and add is not None and abs(on["tick"] - add["tick"]) <= TOL_TICKS,
                  "2. ritmo StormGiant1 x1.5 con la carga: tick %s (carga %s)" % (on["tick"] if on else None, add["tick"] if add else None))
    end = log["end"]
    window = (on["tick"], off["tick"] if off else (end["tick"] if end else 10 ** 9)) if on else (0, 0)
    one = steps_of(log["walk"].get("StormGiant1", []))
    moving = [s for t, f, s in one if window[0] < t < window[1] and f > 1.4 and s > 0.1]
    ok &= verdict(len(moving) >= 20 and abs(median(moving) - STEP_CHARGED) <= STEP_TOL,
                  "2. StormGiant1 cargado avanza %.3f m por tick (± %.3f): mediana %.4f en %d pasos" % (STEP_CHARGED, STEP_TOL, median(moving), len(moving)))
    two = steps_of(log["walk"].get("StormGiant2", []))
    plain = [s for t, f, s in two if abs(f - 1.0) < 1e-3 and s > 0.1]
    ok &= verdict(len(plain) >= 20 and abs(median(plain) - STEP_PLAIN) <= STEP_TOL,
                  "2. StormGiant2 avanza %.3f m por tick (± %.3f): mediana %.4f en %d pasos" % (STEP_PLAIN, STEP_TOL, median(plain), len(plain)))
    # 3. the accuracy and the blows.
    blows = log["blows"]
    sg1 = [b for b in blows if b["who"] == "StormGiant1"]
    sg2 = [b for b in blows if b["who"] == "StormGiant2"]
    end_tick = end["tick"] if end else 10 ** 9
    on_tick = on["tick"] if on else 10 ** 9
    live = [b for b in sg1 if on_tick <= b["tick"] < end_tick]
    ok &= verdict(bool(live) and all(abs(b["acc"] - ACC_CHARGED) < 0.05 and abs(b["factor"] - MELEE_BOOST) < 1e-3 for b in live),
                  "3. StormGiant1 cargado: precisión %.0f y factor %.1f en %d golpes: %s" % (
                      ACC_CHARGED, MELEE_BOOST, len(live), sorted({(b["acc"], b["factor"]) for b in live})))
    ok &= verdict(bool(sg2) and all(abs(b["acc"] - ACC_BASE) < 0.05 and abs(b["factor"] - 1.0) < 1e-3 for b in sg2),
                  "3. StormGiant2: precisión %.0f y factor 1.0 en %d golpes: %s" % (ACC_BASE, len(sg2), sorted({(b["acc"], b["factor"]) for b in sg2})))
    bad = []
    for b in blows:
        if not (b["acc"] + b["eva"] / b["facing"]) > 0:
            continue
        p = b["acc"] / (b["acc"] + b["eva"] / b["facing"])
        amount = b["facing"] * b["pending"]
        if b["roll"] >= p:
            amount *= (1.0 - b["roll"]) / (1.0 - p)
        amount *= b["strength"] * b["scale"] * b["res"] * b["factor"]
        if abs(p - b["p"]) > 5e-4 or abs(amount - b["amount"]) > TOL_M:
            bad.append((b["who"], b["tick"], round(p, 4), b["p"], round(amount, 3), b["amount"]))
    ok &= verdict(bool(blows) and not bad, "3. los montos coinciden con la tirada del log (± %.2f) en %d golpes; mal %s" % (TOL_M, len(blows), bad[:4]))
    # 4. the discharges.
    centers = {who: {p["tick"]: p["pos"] for p in points} for who, points in log["walk"].items()}
    problems = []
    for d in log["discharges"]:
        if d["before"] < DISCHARGE_MIN:
            problems.append(("antes de 250", d["tick"], d["before"]))
        if d["after"] != d["before"] - DISCHARGE_COST:
            problems.append(("costo", d["tick"], d["before"], d["after"]))
        if d["target"] is not None and not d["dist"] <= RANGE + 1e-3:
            problems.append(("lejos", d["tick"], d["dist"]))
        if d["ground"] is not None:
            pos = centers.get(d["who"], {}).get(d["tick"]) or centers.get(d["who"], {}).get(d["tick"] - 1)
            if pos is not None:
                dist = math.hypot(d["ground"][0] - pos[0], d["ground"][2] - pos[2])
                if not GROUND_MIN - 0.05 <= dist <= RANGE + 0.05:
                    problems.append(("suelo", d["tick"], round(dist, 2)))
        if d["pick"] < 0 or d["pick"] >= d["n"] + 4:
            problems.append(("tirada", d["tick"], d["pick"], d["n"]))
        arrival = [b for b in log["born"] if b["label"] == "gcil" and b["tick"] == d["tick"]]
        landed = [h["tick"] for h in log["hits"] + log["grounds"] + log["stale"] if h["label"] == "gcil" and h["tick"] >= d["tick"] + TRAVEL - TOL_TICKS
                  and h["tick"] <= d["tick"] + TRAVEL + TOL_TICKS]
        if not arrival or not landed:
            problems.append(("llegada", d["tick"], bool(arrival), landed))
    ok &= verdict(len(log["discharges"]) >= 3 and not problems,
                  "4. %d descargas: blanco a <= 30 m o suelo a 5-30 m, llegan a los +12 (± 1), cuestan 125 y salen con >= 250 cuadros; mal %s" % (
                      len(log["discharges"]), problems[:5]))
    ok &= verdict(all(h["target"] != "Trogg1" or h["taken"] == 0.0 for h in log["hits"] if h["label"] == "gcil"),
                  "4. las descargas sobre Trogg1 (inmune a los hechizos) hacen 0")
    # 5. the end.
    k = len(log["discharges"])
    want_end = None if t0 is None or add is None else add["tick"] + CHARGE_EXPECT - DISCHARGE_COST * k
    ok &= verdict(end is not None and want_end is not None and abs(end["tick"] - want_end) <= TOL_TICKS and not end["death"],
                  "5. la carga termina en T+12+1500-125k = %s (k = %d, ± %d): tick %s" % (want_end, k, TOL_TICKS, end["tick"] if end else None))
    ok &= verdict(off is not None and end is not None and abs(off["tick"] - end["tick"]) <= TOL_TICKS,
                  "5. ritmo StormGiant1 vuelve a x1.0 al terminar: tick %s (fin %s)" % (off["tick"] if off else None, end["tick"] if end else None))
    after = [s for t, f, s in one if end is not None and t > end["tick"] + 1 and f < 1.1 and s > 0.1]
    if after:
        ok &= verdict(abs(median(after) - STEP_PLAIN) <= STEP_TOL, "5. después avanza %.3f m por tick: mediana %.4f en %d pasos" % (STEP_PLAIN, median(after), len(after)))
    else:
        print("INFO  5. StormGiant1 no vuelve a caminar después de la carga (el ritmo x1.0 ya lo prueba)")
    print("(rayos, chispas y velocidad en pantalla: capturas del playtester)")
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
