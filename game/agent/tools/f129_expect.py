#!/usr/bin/env python3
"""F129 (RFC-030 030r-a): what sacengine would do with the Ikarus's Sticky bomb (acia) on lane S of debug/f129_lobs, replicated
from state.d and the SPEL data, next to what the port logged. The terrain, the caches and the Terrain class are those of
f128_expect.py (loaded from the same folder).

Usage: python3 -I agent/tools/f129_expect.py [godot log of debug/f129_lobs (rules debug/rules/f129_lobs.tres)]
       python3 -I agent/tools/f129_expect.py --lanes     (only the lane check against the map caches)
       python3 -I agent/tools/f129_expect.py --schedule  (the tick table, no log)

Needs the bench switches on (debug/ai_match.gd): AbilityEffect.log_effects, Clinging.log_cling and PaceFactors.log_pace.

sacengine:
- useAbility → shoot!true (13463-13493): startUsingAbility with shoot1 (CKa2, 48 frames at 30 fps, no `lrba`: the shoot tick is
  the last frame, 47): the body prepares 2 * 47 = 94 ticks. At that tick shootOnTick calls stickyBombShoot (13179-13187) and
  drains the mana (Ikarus 300, acia 60: 300->240); the cooldown (6 s = 360 ticks) is set if it was 0 (12746-12748).
- stickyBombShoot: 10 bombs, each direction = getShotDirectionWithGravity (11506-11510: offset.normalized, z += 0.5 * g * |offset| /
  speed^2, then applyRangedAccuracy 11491-11497) + 0.2 * uniformDirection; v = direction * 30, NOT normalized. g = 20 (sacspell.d:123).
- updateStickyBomb (25531-25578), once per tick from the next one: position += v / 60, then v.z -= 20 / 60. A bomb that is on the
  ground and below it vanishes (no stick). Else the first creature of another side that canBeStickyBombed whose box meets the bomb's
  box (0.25 m) takes it: numStickyBombs += 1 and it stays 601 ticks (`++infectionTime <= 60 * duration`, duration 10), then
  numStickyBombs -= 1. movementSpeed multiplies by 0.75 ^ numStickyBombs (stats.d:122). No damage.
- The replica integrates each of the 10 velocities the port logs with g = 20 from the origin it logs, in the port's order (move,
  then gravity: RangedShot._physics_process), against the bodies of lane S as still capsules on the real terrain (cache/high_noon_terrain.bin,
  capsule from cache/baked/bodies.json like BodyCollider: height, radius <= 0.45 * height), and says for each one the tick (the tick
  of the volley + steps) and the body it hits or that it touches the ground. The foe filter is the port's (RangedShot._can_hit):
  another side than the shooter's; the ally never receives one. The pick among bodies in the box is the nearest to its origin.
  Bombs that land after the tick Druid1 starts to walk (the `attack` event) are listed but not asserted: their target moves.
Lane S (anchor 1270, 1270): Ikarus1 -40/+15 (slot 1, looks to +x), Druid1 -15/+15 (slot 2, 25 m, the target), Trogg1 -13/+17
(slot 2), Druid2 -8/+19 (slot 1, ally). The ability is used at 0.7 s (T = tick 42; at 0.5 s with seed 7 no bomb hit Druid1, the walk could not be measured); Druid1 attacks the Ikarus at 3.5 s.
Log lines:
  bench: Ikarus1 usa la habilidad: rechazada, <motivo> (tick N)                              (BenchEvent)
  usando habilidad Sticky bomb Ikarus1 94 ticks (tick T)                                      (ActiveAbility)
  habilidad Sticky bomb mana 300->240 enfriamiento 360 ticks                                  (ActiveAbility)
  lob Ikarus1 acia tiro K/10 ShotN v (vx, vy, vz) origen (x, y, z) (tick F)                   (LobAbility)
  bomba sticky ShotN pega <cuerpo> en (x, y, z) (tick N) | toca suelo en (…) | se pierde en <cuerpo> (no se le puede pegar) en (…)   (StickImpact)
  pegado <cuerpo> sticky n=K factor ×F hasta E (tick N)  /  suelto <cuerpo> sticky n=A->B (tick N)   (Clinging)
  marcha <cuerpo> ×F (x, y, z) (tick N)       every tick while something is stuck                    (Clinging)
  ritmo <cuerpo> ×F [fuentes] (tick N)        each time speed_factor changes                         (PaceFactors)
Port axes: x, y up, z; the original's z is the port's y.
"""
import importlib.util
import json
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("f128_expect", os.path.join(HERE, "f128_expect.py"))
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)

T = 60
ANCHOR = base.ANCHOR
G = 20.0
SPEED = 30.0
BOX = 0.25
WINDUP_TICKS = 94
MANA = (300, 240)
COOLDOWN = 360
HOLD_TICKS = 601
FACTOR = 0.75
SHOTS = 10
SPREAD = 0.2
ACCURACY = 1000.0
RANGE = 100.0
ATTACK_S = 3.5
TOL_TICKS = 1
TOL_PACE = 0.02
CLEAR_STRUCTURE_M = 11.0
CLEAR_WIDGET_M = 6.0
MAX_STEPS = 600
NUM = r"(-?\d+(?:\.\d+)?)"
VEC = r"\(" + NUM + r", " + NUM + r", " + NUM + r"\)"

# name -> (dx, dz, slot, creature model tag) from the anchor
LANES = {
    "Ikarus1": (-40.0, 15.0, 1, "kace"),
    "Druid1": (-15.0, 15.0, 2, "nmuh"),
    "Trogg1": (-13.0, 17.0, 2, "ycro"),
    "Druid2": (-8.0, 19.0, 1, "nmuh"),
}
SHOOTER = "Ikarus1"
TARGET = "Druid1"
RANGES = {("Ikarus1", "Druid1"): 25.0}


def cache(name):
    return base.cache(name)


def world(name):
    dx, dz, _, _ = LANES[name]
    return ANCHOR[0] + dx, ANCHOR[1] + dz


def flat(a, b):
    ax, az = world(a)
    bx, bz = world(b)
    return math.hypot(ax - bx, az - bz)


def capsule(tag):
    """(radius, height) of a creature's capsule on the ground (BodyCollider.refit): height >= 0.6, radius <= 0.45 * height."""
    try:
        creatures = json.load(open(cache(os.path.join("data", "creatures.json")), encoding="utf-8"))
        bodies = json.load(open(cache(os.path.join("baked", "bodies.json")), encoding="utf-8"))
        info = bodies[creatures[tag]["model"]]
    except (OSError, KeyError, ValueError):
        return 0.35, 1.8
    height = max(float(info.get("height", 1.8)), 0.6)
    return min(float(info.get("radius", 0.35)), height * 0.45), height


def check_lanes():
    """Land under every body and along the volley (no hole), no structure within 11 m of a body, no widget within 6 m, the range
    (Druid1 inside the SPEL's 100 m, 25 m from the Ikarus) and the ally off the foes' side."""
    ok = True
    terrain = base.Terrain.load()
    try:
        ntts = json.load(open(cache("high_noon_ntts.json"), encoding="utf-8"))
        widgets = json.load(open(cache("high_noon_widgets.json"), encoding="utf-8"))
    except OSError:
        ntts, widgets = {"structures": []}, {}
    structures = ntts.get("structures", [])
    heights = {}
    for name in LANES:
        x, z = world(name)
        y = terrain.ground(x, z) if terrain else None
        near = [(s["tag"], round(math.hypot(s["x"] - x, s["z"] - z), 1)) for s in structures
                if math.hypot(s["x"] - x, s["z"] - z) < CLEAR_STRUCTURE_M]
        props = [k for k, ps in widgets.items() for p in ps if math.hypot(p[0] - x, p[1] - z) < CLEAR_WIDGET_M]
        bad = (terrain is not None and y is None) or near or props
        if y is not None:
            heights[name] = y
        ok = ok and not bad
        print("carril %-8s (%.1f, %.1f) suelo %s estructuras<%d %s widgets<%d %s %s" % (
            name, x, z, "?" if y is None else "%.2f" % y, CLEAR_STRUCTURE_M, near, CLEAR_WIDGET_M, props, "MAL" if bad else "ok"))
    holes = 0
    cells = 0
    flat_ys = []
    if terrain:
        xs = [world(n)[0] for n in LANES]
        zs = [world(n)[1] for n in LANES]
        x = min(xs) - 5.0
        while x <= max(xs) + 5.0:
            z = min(zs) - 5.0
            while z <= max(zs) + 5.0:
                cells += 1
                y = terrain.ground(x, z)
                if y is None:
                    holes += 1
                else:
                    flat_ys.append(y)
                z += 2.5
            x += 2.5
    ok = ok and holes == 0
    print("huecos en el carril (%d puntos cada 2,5 m): %d %s" % (cells, holes, "ok" if holes == 0 else "MAL"))
    if flat_ys:
        spread = max(flat_ys) - min(flat_ys)
        print("suelo del carril S: %.2f a %.2f m (desnivel %.2f m; la réplica usa el suelo real)" % (min(flat_ys), max(flat_ys), spread))
    for (user, name), want in RANGES.items():
        d = flat(user, name)
        good = abs(d - want) < 0.01 and d <= RANGE
        ok = ok and good
        print("%s -> %s: %.2f m en planta (alcance %.0f) %s" % (user, name, d, RANGE, "ok" if good else "MAL"))
    foes = [n for n in LANES if LANES[n][2] != LANES[SHOOTER][2]]
    allies = [n for n in LANES if LANES[n][2] == LANES[SHOOTER][2] and n != SHOOTER]
    print("enemigos del Ikarus: %s; aliados (no reciben ninguna): %s ok" % (foes, allies))
    return ok


def verdict(ok, text):
    print("%s  %s" % ("PASS" if ok else "FAIL", text))
    return ok


def box_hits(terrain, pos, name):
    """The still capsule of `name` against the bomb's 0.25 m box at `pos`: the distance of the box to the capsule's axis <= radius."""
    x, z = world(name)
    gy = terrain.ground(x, z) if terrain else None
    gy = 0.0 if gy is None else gy
    radius, height = capsule(LANES[name][3])
    y0, y1 = gy + radius, gy + height - radius
    half = BOX / 2.0
    dx = max(abs(pos[0] - x) - half, 0.0)
    dz = max(abs(pos[2] - z) - half, 0.0)
    gap = max(y0 - (pos[1] + half), (pos[1] - half) - y1, 0.0)
    return dx * dx + dz * dz + gap * gap <= radius * radius


def fly(terrain, origin, velocity, bodies):
    """RangedShot._physics_process, step by step: (steps, 'cuerpo' | 'suelo' | None, name, position)."""
    p = list(origin)
    v = list(velocity)
    for step in range(1, MAX_STEPS + 1):
        for i in range(3):
            p[i] += v[i] / T
        v[1] -= G / T
        best = None
        best_d = float("inf")
        for name in bodies:
            if box_hits(terrain, p, name):
                bx, bz = world(name)
                by = terrain.ground(bx, bz) if terrain else 0.0
                d = (p[0] - bx) ** 2 + (p[1] - (by or 0.0)) ** 2 + (p[2] - bz) ** 2
                if d < best_d:
                    best, best_d = name, d
        if best is not None:
            return step, "cuerpo", best, tuple(p)
        ground = terrain.ground(p[0], p[2]) if terrain else None
        if ground is not None and p[1] < ground:
            return step, "suelo", None, tuple(p)
    return MAX_STEPS, None, None, tuple(p)


def read_log(path):
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    log = {"bench": [], "using": None, "ability": [], "lobs": [], "bombs": {}, "stuck": {}, "released": {}, "march": {}, "pace": {}}
    for line in lines:
        m = re.search(r"bench: (\S+) usa la habilidad: (?:rechazada, )?(.+?) \(tick (\d+)\)", line)
        if m and m.group(1) == SHOOTER:
            log["bench"].append((m.group(2), int(m.group(3))))
        m = re.search(r"Sticky bomb " + SHOOTER + r" (\d+) ticks(?: \(tick (\d+)\))?", line)
        if m and line.startswith("usando habilidad") and log["using"] is None:
            log["using"] = (int(m.group(1)), int(m.group(2) or -1))
        m = re.search(r"habilidad Sticky bomb mana (\d+)->(\d+)(?: enfriamiento (\d+) ticks)?", line)
        if m:
            log["ability"].append((int(m.group(1)), int(m.group(2)), int(m.group(3) or -1)))
        m = re.search(r"lob " + SHOOTER + r" (\S+) tiro (\d+)/(\d+) (\S+) v " + VEC + r" origen " + VEC + r" \(tick (\d+)\)", line)
        if m:
            log["lobs"].append({
                "tag": m.group(1), "k": int(m.group(2)), "of": int(m.group(3)), "shot": m.group(4),
                "v": tuple(float(m.group(i)) for i in (5, 6, 7)), "origin": tuple(float(m.group(i)) for i in (8, 9, 10)),
                "tick": int(m.group(11))})
        m = re.search(r"bomba sticky (\S+) (pega a|toca suelo|se pierde en) (\S*)", line)
        if m:
            tick = re.search(r"\(tick (\d+)\)\s*$", line)
            what = m.group(2)
            body = m.group(3) if what != "toca suelo" else None
            log["bombs"][m.group(1)] = {"fate": "suelo" if what == "toca suelo" else ("cuerpo" if what == "pega a" else "perdida"),
                                        "body": body, "tick": int(tick.group(1)) if tick else -1}
        m = re.search(r"pegado (\S+) sticky n=(\d+) factor ×" + NUM + r" hasta (\d+) \(tick (\d+)\)", line)
        if m:
            log["stuck"].setdefault(m.group(1), []).append({"n": int(m.group(2)), "factor": float(m.group(3)),
                                                            "until": int(m.group(4)), "tick": int(m.group(5))})
        m = re.search(r"suelto (\S+) sticky n=(\d+)->(\d+) \(tick (\d+)\)", line)
        if m:
            log["released"].setdefault(m.group(1), []).append({"from": int(m.group(2)), "to": int(m.group(3)), "tick": int(m.group(4))})
        m = re.search(r"marcha (\S+) ×" + NUM + r" " + VEC + r" \(tick (\d+)\)", line)
        if m:
            log["march"].setdefault(m.group(1), []).append({"factor": float(m.group(2)), "pos": tuple(float(m.group(i)) for i in (3, 4, 5)),
                                                            "tick": int(m.group(6))})
        m = re.search(r"ritmo (\S+) ×" + NUM + r" \[(.*?)\] \(tick (\d+)\)", line)
        if m:
            log["pace"].setdefault(m.group(1), []).append({"factor": float(m.group(2)), "tick": int(m.group(4))})
    return log


def check_log(path):
    log = read_log(path)
    terrain = base.Terrain.load()
    ok = True
    # 1. the preparation, the mana, the cooldown.
    use = log["using"]
    ok &= verdict(use is not None and use[0] == WINDUP_TICKS, "1. usando habilidad Sticky bomb %d ticks: %s" % (WINDUP_TICKS, str(use)))
    ok &= verdict(len(log["ability"]) == 1, "1. un solo uso (%d líneas de maná)" % len(log["ability"]))
    mana = log["ability"][0] if log["ability"] else None
    ok &= verdict(mana is not None and mana[:2] == MANA, "1. mana %d->%d: %s" % (MANA[0], MANA[1], str(mana[:2] if mana else "nada")))
    ok &= verdict(mana is not None and mana[2] == COOLDOWN, "1. enfriamiento %d ticks: %s" % (COOLDOWN, str(mana[2] if mana else "nada")))
    lobs = log["lobs"]
    t0 = use[1] if use else None
    fire = lobs[0]["tick"] if lobs else None
    ok &= verdict(fire is not None and t0 is not None and abs(fire - (t0 + WINDUP_TICKS)) <= TOL_TICKS,
                  "1. las bombas salen en el tick %s (esperado %s = T + %d, ± %d)" % (fire, None if t0 is None else t0 + WINDUP_TICKS, WINDUP_TICKS, TOL_TICKS))
    # 2. the ten velocities and where each ends.
    ok &= verdict(len(lobs) == SHOTS and all(l["tick"] == fire for l in lobs), "2. %d velocidades en el mismo tick: %d" % (SHOTS, len(lobs)))
    bodies = [n for n in LANES if LANES[n][2] != LANES[SHOOTER][2]]
    target_center = None
    if lobs:
        tx, tz = world(TARGET)
        radius, height = capsule(LANES[TARGET][3])
        ty = (terrain.ground(tx, tz) if terrain else None) or 0.0
        target_center = (tx, ty + height / 2.0, tz)
    walk_tick = int(round(ATTACK_S * T))
    asserted = 0
    for l in lobs:
        off = [target_center[i] - l["origin"][i] for i in range(3)]
        dist = math.sqrt(sum(c * c for c in off))
        nominal = [c / dist for c in off]
        nominal[1] += 0.5 * G * dist / (SPEED * SPEED)
        speed = math.sqrt(sum(c * c for c in l["v"]))
        cos = sum(a * b for a, b in zip(nominal, l["v"])) / ((math.sqrt(sum(c * c for c in nominal)) or 1.0) * (speed or 1.0))
        angle = math.acos(max(-1.0, min(1.0, cos)))
        # accuracy angle atan(1000 * 0.001 * 0.14 + 0.03) ~ 0.168 and 0.2 * a unit vector: at most 0.168 + 0.2 + the small ones.
        bound = math.atan(ACCURACY * 0.001 * 0.14 + 0.03) + math.asin(min(1.0, SPREAD)) + 0.02
        ok &= verdict(angle <= bound and 0.5 * SPEED <= speed <= 1.5 * SPEED,
                      "2. tiro %d %s: |v| %.2f, a %.3f rad de la dirección con gravedad (máx %.3f)" % (l["k"], l["shot"], speed, angle, bound))
        steps, fate, name, at = fly(terrain, l["origin"], l["v"], bodies)
        got = log["bombs"].get(l["shot"])
        want_tick = l["tick"] + steps
        late = want_tick >= walk_tick
        if got is None:
            ok &= verdict(False, "2. %s: sin línea «bomba» (la réplica dice %s%s en el tick %d)" % (l["shot"], fate, "" if name is None else " " + name, want_tick))
            continue
        good_fate = got["fate"] == ("suelo" if fate == "suelo" else "cuerpo")
        good_body = fate != "cuerpo" or got["body"] == name
        good_tick = abs(got["tick"] - want_tick) <= TOL_TICKS
        if late:
            print("....  2. %s: %s %s en el tick %d, réplica %s %s en %d (después de que Druid1 camina, no se exige)" % (
                l["shot"], got["fate"], got["body"], got["tick"], fate, name, want_tick))
            continue
        asserted += 1
        ok &= verdict(good_fate and good_body and good_tick,
                      "2. %s: réplica %s%s en el tick %d (%d pasos); puerto %s%s en el tick %d" % (
                          l["shot"], fate, "" if name is None else " " + name, want_tick, steps, got["fate"],
                          "" if got["body"] is None else " " + got["body"], got["tick"]))
    ok &= verdict(not any(b["body"] == "Druid2" for b in log["bombs"].values()), "2. Druid2 (aliado) no recibe ninguna")
    ok &= verdict(asserted > 0, "2. al menos una pegada o un suelo comparado: %d" % asserted)
    # 3. speed_factor = 0.75 ^ n and the step of the walk.
    for body, stuck in log["stuck"].items():
        for s in stuck:
            ok &= verdict(abs(s["factor"] - FACTOR ** s["n"]) < 1e-3, "3. %s n=%d: factor %.4f = 0.75^%d" % (body, s["n"], s["factor"], s["n"]))
    pace = log["pace"].get(TARGET, [])
    for s in pace:
        n = round(math.log(s["factor"]) / math.log(FACTOR)) if s["factor"] > 0 else 0
        ok &= verdict(abs(s["factor"] - FACTOR ** n) < 1e-3, "3. ritmo %s ×%.4f en el tick %d = 0.75^%d" % (TARGET, s["factor"], s["tick"], n))
    march = log["march"].get(TARGET, [])
    groups = {}
    for a, b in zip(march, march[1:]):
        if b["tick"] != a["tick"] + 1:
            continue
        step = math.hypot(b["pos"][0] - a["pos"][0], b["pos"][2] - a["pos"][2])
        if step > 1e-4 and abs(b["factor"] - a["factor"]) < 1e-6:
            groups.setdefault(round(b["factor"], 4), []).append(step)
    bad = []
    for factor, steps_ in sorted(groups.items()):
        steps_ = sorted(steps_)
        if len(steps_) < 8:
            continue
        ## The cruise step: the 90th percentile (the arrival at the Ikarus and the slopes only slow the walk down).
        median = steps_[min(len(steps_) - 1, int(0.9 * len(steps_)))]
        want = 11.0 * factor / T
        if abs(median - want) > TOL_PACE * want:
            bad.append((factor, round(median, 5), round(want, 5)))
    ok &= verdict(bool(groups) and not bad, "3. paso de Druid1 por factor (paso de crucero p90, ± %d %%): %s; mal %s" % (
        round(TOL_PACE * 100), {f: len(s) for f, s in sorted(groups.items())}, bad))
    # 4. every piece lets go 601 ticks after it stuck; the factor goes back to 1.
    for body, stuck in log["stuck"].items():
        ok &= verdict(all(s["until"] - s["tick"] == HOLD_TICKS for s in stuck), "4. %s: cada bomba hasta +%d" % (body, HOLD_TICKS))
        wants = sorted(s["tick"] + HOLD_TICKS for s in stuck)
        gots = []
        for r in log["released"].get(body, []):
            gots.extend([r["tick"]] * (r["from"] - r["to"]))
        gots.sort()
        good = len(gots) == len(wants) and all(abs(a - b) <= TOL_TICKS for a, b in zip(gots, wants))
        ok &= verdict(good, "4. %s: sueltas en %s (esperado %s ± %d)" % (body, gots[:12], wants[:12], TOL_TICKS))
        last = log["pace"].get(body, [])
        ok &= verdict(bool(last) and abs(last[-1]["factor"] - 1.0) < 1e-6 and (not wants or abs(last[-1]["tick"] - max(wants)) <= TOL_TICKS),
                      "4. %s: el factor vuelve a 1,0 en el tick %s (esperado %s)" % (body, last[-1]["tick"] if last else None, max(wants) if wants else None))
    print("(look de las bombas pegadas y de las que vuelan: capturas del playtester)")
    return ok


def schedule():
    print("T = tick de la orden (0,7 s = 42). Preparación %d ticks; bombas en T+%d; enfriamiento %d; cada bomba se suelta a +%d de pegarse." % (
        WINDUP_TICKS, WINDUP_TICKS, COOLDOWN, HOLD_TICKS))
    print("Druid1 ataca en el tick %d; velocidad 11 * 0.75^n m/s: n=1..%d -> %s" % (
        int(round(ATTACK_S * T)), SHOTS, ", ".join("%.3f" % (11.0 * FACTOR ** n) for n in range(1, SHOTS + 1))))


def main():
    args = sys.argv[1:]
    if args and args[0] == "--schedule":
        schedule()
        return
    ok = check_lanes()
    if args and args[0] != "--lanes":
        ok = check_log(args[0]) and ok
    print("RESULTADO %s" % ("PASS" if ok else "FAIL"))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
