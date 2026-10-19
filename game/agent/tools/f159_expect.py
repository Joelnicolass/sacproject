#!/usr/bin/env python3
"""F159 (RFC-030 030u-c): what sacengine would do with the Dragon's Grasping Vines on hit (eniv, passive of grdg) on lane V of
debug/f132_quake_onhit, replicated from state.d and the SPEL data, next to what the port logged. PHASE 0: written from the plan,
not yet run against a real log (the port has no Vined yet). The lane helpers are f131_expect.py's.

Usage: python3 -I agent/tools/f159_expect.py [godot log of debug/f132_quake_onhit (rules debug/rules/f132_quake_onhit.tres)]
       python3 -I agent/tools/f159_expect.py LOG --watch   (the log of agent/harness/run_pt159.sh: also the «vigila» lines of the watcher)
       python3 -I agent/tools/f159_expect.py --lanes     (only the lane check against the map files)
       python3 -I agent/tools/f159_expect.py --numbers   (the figures of the replica, no log)

Needs the bench switches on (debug/ai/ai_match.gd): MeleeAttack.log_melee, the vine lines of Vined (new) and the watcher of
agent/harness/pt159_watch.gd (new, one line per tick of JV).

sacengine:
- graspingVines (10795-10812): refuses fliers; numVines += 1; lasts (wizard 0.25 : 1000 / max health) · 40 s, float32 steps through
  SacFloat.f32: a Jabberocky of 5600 hp is ceil(60 · (1000 / 5600) · 40) = 429 ticks. Each blow brings its own timer (3092-3104).
- updateGraspingVines (17852-17876): fixes the xy position; ends by time or when the body no longer admits control. While it lasts:
  no regeneration, ccProtected, fixed, healBlocked and shieldBlocked.
Lane V (anchor 1270, 1270; row z-58): D1 Dragon1 +55/-58 (slot 1), JV Jabberocky3 +67/-58 (slot 2, pacifist, 5600 hp). D1 attacks JV at
0.5 s (tick 30) and dies at 1.8 s (tick 108): one blow. JV is ordered to move to +80/-58 at 2.0 s (tick 120).
Log lines:
  golpe Dragon1 → Jabberocky3 precisión … (tick N)                                                    (MeleeAttack.log_melee)
  enredado Jabberocky3 durante 429 (n 1) (cuadro N)                                                   (new, Vined)
  enredado fin Jabberocky3 (n 0) (cuadro N)                                                           (new, Vined)
  vigila Jabberocky3 pos (x, y, z) vida V (tick N)                                                    (new, pt159_watch: every tick)
Port axes: x, y up, z; the original's z is the port's y.
"""
import importlib.util
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("f131_expect", os.path.join(HERE, "f131_expect.py"))
f131 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(f131)

verdict = f131.verdict
NUM = f131.NUM
VEC = f131.base.VEC
f32 = f131.f32
TOL_TICKS = 1
TOL_M = 0.05
DURATION_S = 40.0
CREATURE_K = 1000.0
WIZARD_FACTOR = 0.25
ORDER_MOVE = 120
D1_DIES = 108

# name -> (dx, dz, slot, kind) from the anchor
LANES = {
    "D1": (55.0, -58.0, 1, "Dragon"),
    "JV": (67.0, -58.0, 2, "Jabberocky"),
    "GO": (80.0, -58.0, 0, "Jabberocky"),
}
# Moved from the plan's +20/+32/+45: that row sits under the Quake lane of the same scene (J1 at +20/-55, wave 10 m + box). Verified with
# --lanes against f132's real boxes, like f158's.
HALF_BOX = {"Dragon": 5.0, "Jabberocky": 6.0}
BIG_STRUCT = {"jhut": 16.0}
QUAKE_LANE = {"J1": (20.0, -55.0, 1, "Jabberocky"), "Q1": (25.0, -55.0, 2, "Ycrp"), "Q2": (20.0, -61.0, 1, "Ycrp"),
              "Q3": (28.5, -55.0, 2, "Ycrp"), "Q4": (9.5, -55.0, 2, "Ycrp"), "Q5": (20.0, -67.0, 2, "Ycrp"), "J2": (-5.0, -34.0, 1, "Jabberocky")}
Y_LANE = {"Y1": (-30.0, -15.0, 1, "Yeti"), "T1": (-25.0, -15.0, 2, "Troll"), "Y2": (-38.0, -25.0, 1, "Yeti"), "T2": (-30.0, -25.0, 2, "Druid")}
QUAKE_REACH_M = 10.0 + 6.0
CLEAR_Y_M = 20.0


def vine_ticks(max_health, wizard=False):
    """ceil(60 · duration) in float32 (Vined.grasp via SacFloat.f32): (wizard ? 0.25 : 1000 / max health) · 40 s."""
    factor = f32(WIZARD_FACTOR) if wizard else f32(f32(CREATURE_K) / f32(max_health))
    seconds = f32(factor * f32(DURATION_S))
    n = f32(60.0 * seconds)
    return int(n) + (0 if n == int(n) else 1)


def numbers():
    print("Jabberocky 5600 hp: %d ticks (esperado 429)" % vine_ticks(5600.0))
    print("mago: %d ticks (0,25 · 40 s = 600)" % vine_ticks(1000.0, True))
    for hp in (900, 1250, 1600, 5600):
        print("  vida máx %d: %d ticks" % (hp, vine_ticks(float(hp))))
    print("JV queda quieto desde el golpe b1 hasta b1+429; la orden de marcha a los %d ticks espera al final de las lianas" % ORDER_MOVE)


def check_lanes():
    ok = f131.lane_report(LANES, half_box=HALF_BOX, big_struct=BIG_STRUCT)
    both = dict(LANES)
    both.update(QUAKE_LANE)
    both.update(Y_LANE)
    for v in ("D1", "JV", "GO"):
        for q in QUAKE_LANE:
            d = f131.flat(both, q, v)
            good = d > QUAKE_REACH_M + HALF_BOX.get(LANES[v][3], 5.0)
            ok = ok and good
            if not good or q in ("J1", "Q3"):
                print("%s -> %s: %.2f m (fuera de la onda del Quake) %s" % (q, v, d, "ok" if good else "MAL"))
        for y in Y_LANE:
            d = f131.flat(both, y, v)
            good = d > CLEAR_Y_M
            ok = ok and good
            if not good:
                print("%s -> %s: %.2f m MAL (lejos del carril Y)" % (y, v, d))
    d = f131.flat(LANES, "D1", "JV")
    print("D1 -> JV: %.2f m en planta (el Dragon se acerca solo) y JV -> destino %.2f m" % (d, f131.flat(LANES, "JV", "GO")))
    good = abs(f131.flat(LANES, "JV", "GO") - 13.0) < 0.01
    return ok and good


def check_log(path, need_watch=False):
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    ok = True
    hits = [int(m.group(1)) for m in (re.search(r"golpe Dragon1 → Jabberocky3 .*\(tick (\d+)\)", l) for l in lines) if m]
    ok &= verdict(len(hits) == 1, "1. exactamente 1 golpe de D1 a JV antes de morir: %s" % hits)
    vines = [(int(m.group(1)), int(m.group(2)), int(m.group(3))) for m in (re.search(r"enredado Jabberocky3 durante (\d+) \(n (\d+)\) \(cuadro (\d+)\)", l) for l in lines) if m]
    want = vine_ticks(5600.0)
    ok &= verdict(len(vines) == 1 and vines[0][0] == want and vines[0][1] == 1,
                  "1. enredado Jabberocky3 durante %d (n 1), una sola vez: %s" % (want, vines))
    if not vines or not hits:
        return False
    b1 = vines[0][2]
    ok &= verdict(abs(b1 - hits[0]) <= TOL_TICKS, "1. el enredo nace en el golpe (%d): %s" % (hits[0], b1))
    watch = []
    for l in lines:
        m = re.search(r"vigila Jabberocky3 pos " + VEC + r" vida " + NUM + r" \(tick (\d+)\)", l)
        if m:
            watch.append((int(m.group(5)), (float(m.group(1)), float(m.group(2)), float(m.group(3))), float(m.group(4))))
    end = b1 + want
    if not watch and not need_watch:
        ends = [int(m.group(1)) for m in (re.search(r"enredado fin Jabberocky3 .*\(cuadro (\d+)\)", l) for l in lines) if m]
        ok &= verdict(bool(ends) and abs(ends[0] - end) <= TOL_TICKS, "2. fin de las lianas en b1+%d=%d (±%d): %s" % (want, end, TOL_TICKS, ends[:1]))
        print("(sin líneas «vigila»: un log de la corrida determinista no las trae; la quietud y la vida salen del log de pt159 con --watch)")
        return ok
    pinned = [(t, p, v) for t, p, v in watch if b1 + 1 <= t < end - TOL_TICKS]
    ok &= verdict(bool(pinned), "2. el vigía tiene %d líneas de JV con las lianas puestas" % len(pinned))
    if pinned:
        p0 = pinned[0][1]
        drift = max(math.hypot(p[0] - p0[0], p[2] - p0[2]) for _, p, _ in pinned)
        ok &= verdict(drift <= TOL_M, "2. JV queda quieto (±%.2f m) de b1 a b1+%d=%d: desvío %.4f m" % (TOL_M, want, end, drift))
        lives = {round(v, 3) for _, _, v in pinned}
        ok &= verdict(len(lives) == 1, "3. la vida de JV no cambia mientras está enredado: %s" % sorted(lives)[:4])
    after = [(t, p, v) for t, p, v in watch if t >= end + TOL_TICKS]
    if after:
        start = after[0]
        later = [x for x in after if x[0] >= start[0] + 60]
        moved = max((math.hypot(p[0] - start[1][0], p[2] - start[1][2]) for t, p, _ in later[:1]), default=0.0)
        ok &= verdict(moved > 1.0, "2. después avanza más de 1 m en 60 ticks: %.2f m" % moved)
        regen = [v for _, _, v in after if v > pinned[0][2] + 0.01] if pinned else []
        ok &= verdict(bool(regen), "3. después regenera: %d lecturas por encima de %.1f" % (len(regen), pinned[0][2] if pinned else 0.0))
    else:
        ok &= verdict(False, "2/3. el vigía no tiene lecturas después de b1+%d" % want)
    ends = [int(m.group(1)) for m in (re.search(r"enredado fin Jabberocky3 .*\(cuadro (\d+)\)", l) for l in lines) if m]
    ok &= verdict(bool(ends) and abs(ends[0] - end) <= TOL_TICKS, "2. fin de las lianas en b1+%d=%d (±%d): %s" % (want, end, TOL_TICKS, ends[:1]))
    print("(lianas de reserva en pantalla: captura del playtester; f132 igual en los 3 modos y quick sin cambios, f121 incluido: corridas del orquestador)")
    return ok


def main():
    args = sys.argv[1:]
    if args and args[0] == "--numbers":
        numbers()
        return
    ok = check_lanes()
    if args and args[0] != "--lanes":
        ok = check_log(args[0], "--watch" in args[1:]) and ok
    print("RESULTADO %s" % ("PASS" if ok else "FAIL"))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
