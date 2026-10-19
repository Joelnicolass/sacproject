#!/usr/bin/env python3
"""F153 (RFC-030 030p-b): what sacengine would do with the Dragon's Breath of life (filb) on lane D of the f127 / f153
bench, replicated from state.d and the SPEL data, next to what the port logged.

Usage: python3 -I agent/tools/f153_expect.py [godot log of the lane D scene (debug/rules/f153_breath.tres) or its bench case]
       python3 -I agent/tools/f153_expect.py --lanes     (only the lane check against the map files)
       python3 -I agent/tools/f153_expect.py --model D   (the flight and the revival of a breath that flies D meters)

Needs the bench switch on (debug/ai/ai_match.gd): BreathOfLife.log_breath and FastRevive.log_revive.

sacengine:
- useAbility → shoot (13470-13493): startUsingAbility with shoot2 (DGs2, tick 26 at 30 fps → 52 ticks); at the shoot tick
  shootOnTick drains the mana (12746-12748) and calls breathOfLifeShoot (13238-13248); the cooldown (4 s = 240 ticks) is set
  if it was 0. Dragon mana 750, filb 50: 750->700. A soul target is resolved to its corpse.
- abilityStatus (29582-29604): applicable (flags 4106: soul | corpse | onlyAlly) → «Blanco inválido»; then 3D distance
  obj.position to target.position over the SPEL range 40 → «Fuera de alcance». A rejection spends nothing.
- updateBreathOfLife (25943-25975), from the tick after the shoot tick: velocity = 60 (target − position), capped at 60;
  position += velocity / 60; when velocity < 0.01 (the breath sits on the target) fastRevive. So it lands after ceil(d)
  ticks and fastRevive is the next one: ceil(d) + 1 from the shoot tick.
- revive (8651-8664): dead, soul NORMAL or EMERGING → soul REVIVING, health = max health, mode fastReviving.
- updateCreature fastReviving (14101-14131): reviveTime 5 s · 60 / 2 = 150 ticks; timer < 75: z += 2 / 75 per tick (74 ticks:
  1.9733 m); facing += 2π / 150 per tick; at timer 150 the soul is removed and the creature idles.
Lane D (anchor 1270, 1270): D Dragon1 -10/-45 (slot 1); D1 Druid1 +15/-45 (slot 1, 25 m); D2 Druid2 +38/-45 (slot 1, 48 m);
D3 Druid3 -10/-35 (slot 2, 10 m). The three Druids die at 0.3 s. The Dragon uses the ability on D3 at 1.4 s, on D2 at 1.5 s and
on D1 at 1.6 s.
Log lines:
  bench: Dragon1 usa la habilidad: rechazada, Blanco inválido (tick 84)        (ordered by the tick: 84, 90, 96)
  bench: Dragon1 usa la habilidad: rechazada, Fuera de alcance (tick 90)
  bench: Dragon1 usa la habilidad: ok (tick 96)
  usando habilidad Breath of life Dragon1 52 ticks (tick 96)                    (ActiveAbility)
  habilidad Breath of life mana 750->700 enfriamiento 240 ticks                 (ActiveAbility)
  aliento Dragon1 sale de (x, y, z) hacia Druid1 d D m (tick T)                 (BreathOfLife)
  aliento Dragon1 llega a Druid1 (tick A)
  revive Druid1 inicio vida 800 (tick R)                                        (FastRevive)
  revive Druid1 sube 1.9733 m (tick U)
  revive Druid1 fin idle vida 800 (tick F)
What a log cannot say (criterion 4: selectable again, target again, its soul gone) goes to the playtester's capture / probe.
Port axes: x, y up, z; the original's z is the port's y.
"""
import json
import math
import os
import sys as _sys

_sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import terrain_asset  # noqa: E402  (agent/tools/terrain_asset.py: reads assets/original/maps/high_noon/terrain.res)
import re
import struct
import sys

T = 60
ANCHOR = (1270.0, 1270.0)
WINDUP_TICKS = 52
MANA = (750, 700)
COOLDOWN_TICKS = 240
RANGE = 40.0
SPEED = 60.0
ARRIVE = 0.01
REVIVE_TICKS = 150
RISE_TICKS = 75
RISE_HEIGHT = 2.0
RISE_AT_74 = RISE_HEIGHT * 74 / RISE_TICKS
HEALTH = 800
TOL_TICKS = 1
TOL_RISE_M = 0.05
CLEAR_STRUCTURE_M = 11.0
CLEAR_WIDGET_M = 6.0
BENCH_TICKS = {"Blanco inválido": 84, "Fuera de alcance": 90, "ok": 96}
LANES = {
    "Dragon1": (-10.0, -45.0, 1),
    "Druid1": (15.0, -45.0, 1),
    "Druid2": (38.0, -45.0, 1),
    "Druid3": (-10.0, -35.0, 2),
}
FLAT_RANGE = {"Druid1": 25.0, "Druid2": 48.0, "Druid3": 10.0}
NUM = r"(-?\d+(?:\.\d+)?)"
VEC = r"\(" + NUM + r", " + NUM + r", " + NUM + r"\)"


def map_file(name):
    """A High Noon map file from assets/original/maps/high_noon/ (RFC-033, 033f)."""
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "original", "maps", "high_noon", name)



def load_terrain():
    """Vertices and indices of the ground (assets/original/maps/high_noon/terrain.res, RFC-033): (verts, idx), None without the file."""
    return terrain_asset.load()


def ground(terrain, x, z):
    verts, idx = terrain
    best = None
    for t in range(0, len(idx), 3):
        a, b, c = verts[idx[t]], verts[idx[t + 1]], verts[idx[t + 2]]
        if max(a[0], b[0], c[0]) < x or min(a[0], b[0], c[0]) > x or max(a[2], b[2], c[2]) < z or min(a[2], b[2], c[2]) > z:
            continue
        d = (b[0] - a[0]) * (c[2] - a[2]) - (c[0] - a[0]) * (b[2] - a[2])
        if abs(d) < 1e-2:
            continue
        l1 = ((b[0] - x) * (c[2] - z) - (c[0] - x) * (b[2] - z)) / d
        l2 = ((c[0] - x) * (a[2] - z) - (a[0] - x) * (c[2] - z)) / d
        l3 = 1.0 - l1 - l2
        if min(l1, l2, l3) >= -1e-6:
            y = l1 * a[1] + l2 * b[1] + l3 * c[1]
            best = y if best is None else max(best, y)
    return best


def world(name):
    dx, dz, _ = LANES[name]
    return ANCHOR[0] + dx, ANCHOR[1] + dz


def flat(a, b):
    ax, az = world(a)
    bx, bz = world(b)
    return math.hypot(ax - bx, az - bz)


def check_lanes():
    """Land under every body and along the lane (no hole), no structure within 11 m of a body (the huts of the map stand at
    12 to 22 m; the breath flies over buildings, collides off), no widget within 6 m, and the ranges: D1 and D3 inside the
    SPEL's 40 m, D2 outside (the Dragon's hover height only adds to the 3D distance)."""
    ok = True
    terrain = load_terrain()
    try:
        ntts = json.load(open(map_file("ntts.json"), encoding="utf-8"))
        widgets = json.load(open(map_file("widgets.json"), encoding="utf-8"))
    except OSError:
        ntts, widgets = {"structures": []}, {}
    structures = ntts.get("structures", [])
    for name in LANES:
        x, z = world(name)
        y = ground(terrain, x, z) if terrain else None
        near = [(s["tag"], round(math.hypot(s["x"] - x, s["z"] - z), 1)) for s in structures
                if math.hypot(s["x"] - x, s["z"] - z) < CLEAR_STRUCTURE_M]
        props = [k for k, ps in widgets.items() for p in ps if math.hypot(p[0] - x, p[1] - z) < CLEAR_WIDGET_M]
        bad = (terrain is not None and y is None) or near or props
        ok = ok and not bad
        print("carril %-7s (%.1f, %.1f) suelo %s estructuras<%d %s widgets<%d %s %s" % (
            name, x, z, "?" if y is None else "%.2f" % y, CLEAR_STRUCTURE_M, near, CLEAR_WIDGET_M, props, "MAL" if bad else "ok"))
    holes = 0
    cells = 0
    if terrain:
        x0, x1 = min(world(n)[0] for n in LANES) - 5.0, max(world(n)[0] for n in LANES) + 5.0
        z0, z1 = min(world(n)[1] for n in LANES) - 5.0, max(world(n)[1] for n in LANES) + 5.0
        x = x0
        while x <= x1:
            z = z0
            while z <= z1:
                cells += 1
                if ground(terrain, x, z) is None:
                    holes += 1
                z += 2.5
            x += 2.5
    ok = ok and holes == 0
    print("huecos en el carril (%d puntos cada 2,5 m): %d %s" % (cells, holes, "ok" if holes == 0 else "MAL"))
    for name, want_in in (("Druid1", True), ("Druid2", False), ("Druid3", True)):
        d = flat("Dragon1", name)
        good = abs(d - FLAT_RANGE[name]) < 0.01 and ((d <= RANGE) == want_in)
        ok = ok and good
        print("Dragon1 -> %s: %.2f m en planta (alcance %.0f, %s) %s" % (name, d, RANGE, "dentro" if want_in else "fuera", "ok" if good else "MAL"))
    return ok


def fly(distance):
    """The breath from rest: ticks after the shoot tick at which it lands (position == target) and at which fastRevive is
    called, for a still target `distance` away. velocity = 60 (target − position), capped at SPEED."""
    remaining = distance
    n = 0
    while True:
        n += 1
        velocity = T * remaining
        if velocity > SPEED:
            velocity = SPEED
        remaining -= velocity / T
        if velocity < ARRIVE:
            return n - 1, n
        if n > 100000:
            return None


def verdict(ok, text):
    print("%s  %s" % ("PASS" if ok else "FAIL", text))
    return ok


def read_log(path):
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    log = {"bench": [], "using": None, "ability": [], "out": None, "arrive": None, "start": None, "rise": None, "end": None}
    for line in lines:
        m = re.search(r"bench: (\S+) usa la habilidad: (?:rechazada, )?(.+?) \(tick (\d+)\)", line)
        if m:
            log["bench"].append((m.group(1), m.group(2), int(m.group(3))))
        m = re.search(r"usando habilidad Breath of life (\S+) (\d+) ticks(?: \(tick (\d+)\))?", line)
        if m and log["using"] is None:
            log["using"] = (m.group(1), int(m.group(2)), int(m.group(3) or -1))
        m = re.search(r"habilidad Breath of life mana (\d+)->(\d+)(?: enfriamiento (\d+) ticks)?", line)
        if m:
            log["ability"].append((int(m.group(1)), int(m.group(2)), int(m.group(3) or -1)))
        m = re.search(r"aliento (\S+) sale de " + VEC + r" hacia (\S+) d " + NUM + r" m \(tick (\d+)\)", line)
        if m and log["out"] is None:
            log["out"] = (m.group(1), m.group(5), float(m.group(6)), int(m.group(7)))
        m = re.search(r"aliento (\S+) llega a (\S+) \(tick (\d+)\)", line)
        if m and log["arrive"] is None:
            log["arrive"] = (m.group(2), int(m.group(3)))
        m = re.search(r"revive (\S+) inicio vida (\d+) \(tick (\d+)\)", line)
        if m and log["start"] is None:
            log["start"] = (m.group(1), int(m.group(2)), int(m.group(3)))
        m = re.search(r"revive (\S+) sube " + NUM + r" m \(tick (\d+)\)", line)
        if m and log["rise"] is None:
            log["rise"] = (m.group(1), float(m.group(2)), int(m.group(3)))
        m = re.search(r"revive (\S+) fin idle vida (\d+) \(tick (\d+)\)", line)
        if m and log["end"] is None:
            log["end"] = (m.group(1), int(m.group(2)), int(m.group(3)))
    return log


def check_log(path):
    log = read_log(path)
    ok = True
    # 1. the rejections leave the mana alone.
    reasons = {}
    for _, reason, tick in log["bench"]:
        reasons[reason] = tick
    for reason in ("Blanco inválido", "Fuera de alcance"):
        tick = reasons.get(reason)
        ok &= verdict(tick is not None and abs(tick - BENCH_TICKS[reason]) <= TOL_TICKS,
                      "1. «%s» en el tick %s (esperado %d ± %d)" % (reason, tick, BENCH_TICKS[reason], TOL_TICKS))
    ok &= verdict(len(log["ability"]) == 1 and log["using"] is not None,
                  "1. un solo uso (%d líneas de maná, preparación %s): los rechazos no gastan" % (len(log["ability"]), str(log["using"])))
    # 2. the preparation, the mana and the cooldown.
    use = log["using"]
    ok &= verdict(use is not None and use[1] == WINDUP_TICKS, "2. usando habilidad Breath of life %d ticks: %s" % (WINDUP_TICKS, str(use)))
    mana = log["ability"][0] if log["ability"] else None
    ok &= verdict(mana is not None and mana[:2] == MANA, "2. mana %d->%d: %s" % (MANA[0], MANA[1], str(mana[:2] if mana else "nada")))
    ok &= verdict(mana is not None and mana[2] == COOLDOWN_TICKS, "2. enfriamiento de %d ticks: %s" % (COOLDOWN_TICKS, str(mana[2] if mana else "nada")))
    out = log["out"]
    fire = use[2] + WINDUP_TICKS if use and use[2] >= 0 else None
    ok &= verdict(out is not None and fire is not None and abs(out[3] - fire) <= TOL_TICKS,
                  "2. el aliento sale en el tick %s (esperado %s ± %d)" % (out[3] if out else None, fire, TOL_TICKS))
    # 3. the flight: ceil(d) + 1 ticks.
    arrive = log["arrive"]
    if out and arrive:
        landed, called = fly(out[2])
        want = out[3] + called
        ok &= verdict(abs(arrive[1] - want) <= TOL_TICKS,
                      "3. d %.4f m: llega en el tick %d (esperado %d = %d + ceil(d) + 1, ± %d)" % (out[2], arrive[1], want, out[3], TOL_TICKS))
        ok &= verdict(called == math.ceil(out[2]) + 1 or abs(out[2] - round(out[2])) < 1e-3, "3. el modelo da %d ticks para d %.4f" % (called, out[2]))
    else:
        ok &= verdict(False, "3. faltan las líneas «aliento … sale» y «aliento … llega»")
    # 4. D1.
    start, rise, end = log["start"], log["rise"], log["end"]
    ok &= verdict(start is not None and start[1] == HEALTH, "4. vuelve con %d de vida: %s" % (HEALTH, str(start)))
    ok &= verdict(start is not None and arrive is not None and 0 <= start[2] - arrive[1] <= TOL_TICKS,
                  "4. la vida vuelve en el tick de la llegada o el siguiente: %s / %s" % (start[2] if start else None, arrive[1] if arrive else None))
    ok &= verdict(rise is not None and abs(rise[1] - RISE_AT_74) <= TOL_RISE_M,
                  "4. sube %s m a los 74 ticks (esperado %.4f ± %.2f)" % (rise[1] if rise else None, RISE_AT_74, TOL_RISE_M))
    if start and rise:
        ok &= verdict(abs(rise[2] - (start[2] + RISE_TICKS - 1)) <= TOL_TICKS,
                      "4. la altura de los 74 ticks en el tick %d (esperado %d ± %d)" % (rise[2], start[2] + RISE_TICKS - 1, TOL_TICKS))
    ok &= verdict(end is not None and end[1] == HEALTH, "4. al final sigue con %d de vida: %s" % (HEALTH, str(end)))
    if start and end:
        ok &= verdict(abs(end[2] - (start[2] + REVIVE_TICKS)) <= TOL_TICKS,
                      "4. IDLE en el tick %d (esperado %d ± %d)" % (end[2], start[2] + REVIVE_TICKS, TOL_TICKS))
    print("(selección, blanco y alma que desaparece: capturas / sonda del playtester)")
    return ok


def main():
    args = sys.argv[1:]
    if args and args[0] == "--model":
        if len(args) != 2:
            print(__doc__)
            sys.exit(2)
        d = float(args[1])
        landed, called = fly(d)
        print("d %.4f m: aterriza a los %d ticks, fastRevive a los %d; sube %.4f m a los 74, IDLE %d ticks después" % (
            d, landed, called, RISE_AT_74, REVIVE_TICKS))
        return
    ok = check_lanes()
    if args and args[0] != "--lanes":
        ok = check_log(args[0]) and ok
    print("RESULTADO %s" % ("PASS" if ok else "FAIL"))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
