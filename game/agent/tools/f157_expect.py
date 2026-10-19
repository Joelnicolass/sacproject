#!/usr/bin/env python3
"""F157 (RFC-030 030t-b): what sacengine would do with the Styx's Rend Soul (dner) on lane R of debug/f131_devour_rend,
replicated from state.d and the SPEL data, next to what the port logged. PHASE 0: written from the plan, not yet run
against a real log (the port has no Rend Soul yet). The lanes and the shared helpers are f131_expect.py's.

Usage: python3 -I agent/tools/f157_expect.py [godot log of debug/f131_devour_rend (rules debug/rules/f131_devour_rend.tres)]
       python3 -I agent/tools/f157_expect.py --lanes     (only the lane check against the map files)
       python3 -I agent/tools/f157_expect.py --numbers   (the figures of the replica and the tick table, no log)

Needs the bench switches on (debug/ai/ai_match.gd): AbilityEffect.log_effects, plus the splash lines of SplashImpact.

sacengine:
- rendShoot (13226-13230) adds the effect only if canRend (13219-13225); mana (100) and the cooldown (10 s = 600) are paid whether or
  not the soul is still there; range 90 in 3D. The Styx prepares shoot0 (GUs1 c50): 100 ticks, not shoot1 (R2 of the plan).
- updateRendShoot (25867-25890), the tick after the shot: it checks the soul again, the soul bursts and severSoul dissolves the
  corpse; StyxBolt, 2 StyxExplosion and 192 sparks; dealSplashRangedDamageAt(0, …, 40): 2500 · (1 − d/40) by the distance to the
  hit box (9075-9089), no direct hit; buildings too (R5). The side is Health's rule: an ally takes 0 (friendly fire off).
Lane R (anchor 1270, 1270; row z+15): S1 Styx1 -45/+15 (slot 1, pacifist), R0 Trogg -20/+15 (slot 1), R6 Trogg +50/+15 (slot 1, 95 m),
R7 Trogg -30/+5 (slot 2), J1..J5 Jabberocky (slot 2, pacifist) at -14, -5, +5, +15 and +26 on z+15, A1 Druid -20/+20 (slot 1).
R0, R6 and R7 die at 0.3 s. S1 orders Rend on R6 at 2.0 s (120), on R7 at 2.1 s (126) and on R0 at 2.2 s (T = 132).
Log lines:
  bench: Styx1 usa la habilidad: rechazada, Fuera de alcance (tick 120)                              (ai_match)
  usando habilidad Rend Soul Styx1 100 ticks (tick 132)                                               (ActiveAbility)
  habilidad Rend Soul mana 500->400 enfriamiento 600 ticks                                            (ActiveAbility)
  alma Trogg1 reventada (tick 233) / cadáver Trogg1 disuelto (tick 233)                               (new, Soul.burst)
  salpicadura dner en (x, y, z) radio 40.0 m de 2500                                                  (SplashImpact)
    Jabberocky a 2.32 m                                                                               (SplashImpact, one per body of the walk)
  dano Jabberocky 1766 vida V                                                                         (SplashDamage.report, the same order)
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
TOL_TICKS = 1
TOL_D = 0.5
AMOUNT = 2500.0
RADIUS = 40.0
RANGE = 90.0
WINDUP = 100
MANA = (500, 400)
COOLDOWN = 600
RESISTANCE = 0.75
ORDER_T = 132
CLOCK = f131.CLOCK  # the bench labels an event with its nominal tick; the clock reads CLOCK more when it fires

# name -> (dx, dz, slot, kind) from the anchor
LANES = {
    "S1": (-45.0, 15.0, 1, "Styx"),
    "R0": (-20.0, 15.0, 1, "Trogg"),
    "R6": (50.0, 15.0, 1, "Trogg"),
    "R7": (-30.0, 5.0, 2, "Trogg"),
    "J1": (-14.0, 15.0, 2, "Jabberocky"),
    "J2": (-5.0, 15.0, 2, "Jabberocky"),
    "J3": (5.0, 15.0, 2, "Jabberocky"),
    "J4": (15.0, 15.0, 2, "Jabberocky"),
    "J5": (26.0, 15.0, 2, "Jabberocky"),
    "A1": (-20.0, 20.0, 1, "Druid"),
}


def falloff(d):
    """2500 · (1 − d/40) · resistance, d the distance to the hit box; 0 past the radius."""
    return AMOUNT * max(0.0, 1.0 - d / RADIUS) * RESISTANCE if d <= RADIUS else 0.0


def numbers():
    print("S1 -> R6: %.2f m (alcance %.0f: fuera), S1 -> R0: %.2f m (dentro), R7 es del bando 2 (inválido)" % (
        f131.flat(LANES, "S1", "R6"), RANGE, f131.flat(LANES, "S1", "R0")))
    print("orden en T=%d: usando 100 ticks, T+100=%d mana %d->%d enfriamiento %d, T+101=%d alma, cadáver, beam, salpicadura" % (
        ORDER_T, ORDER_T + WINDUP, MANA[0], MANA[1], COOLDOWN, ORDER_T + WINDUP + 1))
    for j in ("J1", "J2", "J3", "J4", "J5"):
        c = f131.flat(LANES, "R0", j)
        print("%s: centro a %.1f m; con media caja h: daño %.0f (h=3.7), %.0f (h=0)" % (j, c, falloff(max(0.0, c - 3.7)), falloff(c)))
    print("A1 (aliado, 0) y S1 (aliado, 0) están dentro del radio: reciben 0 por la regla de bando")


def check_lanes():
    ok = f131.lane_report(LANES)
    d6, d7, d0 = f131.flat(LANES, "S1", "R6"), f131.flat(LANES, "S1", "R7"), f131.flat(LANES, "S1", "R0")
    for name, d, inside in (("R6", d6, False), ("R0", d0, True)):
        good = (d <= RANGE) == inside
        ok = ok and good
        print("S1 -> %s: %.2f m (alcance %.0f, %s) %s" % (name, d, RANGE, "dentro" if inside else "fuera", "ok" if good else "MAL"))
    good = abs(d6 - 95.0) < 0.01
    ok = ok and good
    print("S1 -> R6 a 95 m %s; S1 -> R7 %.2f m (inválido por bando)" % ("ok" if good else "MAL", d7))
    for j, want in (("J1", 6.0), ("J2", 15.0), ("J3", 25.0), ("J4", 35.0), ("J5", 46.0)):
        d = f131.flat(LANES, "R0", j)
        good = abs(d - want) < 0.01
        ok = ok and good
        print("R0 -> %s: %.2f m al centro %s" % (j, d, "ok" if good else "MAL"))
    return ok


def check_log(path):
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    ok = True
    bench = f131.read_bench(lines, "Styx1")
    for tick, text in ((120, "out_of_range"), (126, "bad_target")):
        got = [t for t, tk in bench if tk == tick]
        ok &= verdict(bool(got) and got[0] == text, "1. rechazo a los %d: %s (esperado «%s»)" % (tick, got, text))
    using = [(int(m.group(1)), int(m.group(2))) for m in (re.search(r"usando habilidad Rend Soul Styx1 (\d+) ticks \(tick (\d+)\)", l) for l in lines) if m]
    ok &= verdict(bool(using) and using[0] == (WINDUP, ORDER_T + CLOCK), "2. usando habilidad Rend Soul 100 ticks en T=%d (+%d del reloj): %s" % (ORDER_T, CLOCK, using))
    manas = [(int(m.group(1)), int(m.group(2)), int(m.group(3))) for m in (re.search(r"habilidad Rend Soul mana (\d+)->(\d+) enfriamiento (\d+) ticks", l) for l in lines) if m]
    ok &= verdict(manas[:1] == [(MANA[0], MANA[1], COOLDOWN)], "2. mana 500->400 enfriamiento 600 (los rechazos no gastan): %s" % manas[:3])
    # splash: the walk lines then the damage lines, in the same order
    splash = None
    names = []
    hits = []
    for i, l in enumerate(lines):
        if re.search(r"salpicadura dner en \(.*\) radio 40\.0 m de 2500", l):
            splash = i
            j = i + 1
            while j < len(lines) and lines[j].startswith("  "):
                m = re.match(r"\s+(\S+) a " + NUM + r" m$", lines[j])
                if m:
                    names.append((m.group(1), float(m.group(2))))
                j += 1
            while j < len(lines) and (lines[j].startswith("dano ") or lines[j].startswith("  ")):
                m = re.match(r"dano (\S+) (-?\d+) vida (\d+)", lines[j])
                if m:
                    hits.append((m.group(1), int(m.group(2))))
                j += 1
            break
    ok &= verdict(splash is not None, "3. aparece la salpicadura dner de radio 40.0 m de 2500")
    if splash is None:
        return False
    burst = [int(m.group(1)) for m in (re.search(r"(?:alma Trogg6 reventada|cadáver Trogg6 disuelto) \(tick (\d+)\)", l) for l in lines) if m]
    want_tick = ORDER_T + CLOCK + WINDUP + 1
    ok &= verdict(len(burst) >= 2 and all(abs(t - want_tick) <= TOL_TICKS for t in burst[:2]),
                  "3. el alma se borra y el cadáver se disuelve en T+101=%d (±%d): %s" % (want_tick, TOL_TICKS, burst[:3]))
    jabs = [(n, d) for n, d in names if n.startswith("Jabberocky")]
    ok &= verdict(len(jabs) == 4, "4. cuatro Jabberocky en el radio de 40 m (J5 está fuera): %s" % jabs)
    # pair by walk order (SplashImpact prints the walk, SplashDamage.deal hurts in the same order, skipping maximum <= 0)
    pairs = list(zip([x for x in names], hits))
    bad = []
    for (n, d), (hn, amount) in pairs:
        ## A building (Bld…) takes the falloff whole (resistance 1, R5); the allies (Styx, Druid) take 0 by the side rule.
        want = falloff(d) if n.startswith("Jabberocky") else (AMOUNT * (1.0 - d / RADIUS) if n.startswith("Bld") else 0.0)
        tol = TOL_D * AMOUNT * (RESISTANCE if n.startswith("Jabberocky") else 1.0) / RADIUS if n.startswith(("Jabberocky", "Bld")) else 0.5
        if abs(amount - want) > max(tol, 1.0):
            bad.append((n, round(d, 2), amount, round(want)))
    ok &= verdict(not bad and len(pairs) >= 4, "4. daño 2500·(1−d/40)·0,75 con la d del log (±%.1f m): %d cuerpos, fallan %s" % (TOL_D, len(pairs), bad))
    others = [(n, a) for (n, _), (_, a) in pairs if not n.startswith(("Jabberocky", "Bld"))]
    ok &= verdict(all(a == 0 for _, a in others), "4. A1, S1 y los demás de su bando reciben 0: %s" % others)
    print("(el beam styx, las chispas y el cadáver que se disuelve: capturas del playtester; J4 del plan dice ≈271 pero, con la misma media caja"
          " que J1..J3 (≈3,7 m), 35 − 3,7 da ≈408: manda la d del log)")
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
