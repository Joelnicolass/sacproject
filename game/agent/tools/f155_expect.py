#!/usr/bin/env python3
"""F155 (RFC-030 030r-b): what sacengine would do with the Pyrodactyl's Viscous oil (kcfa) and DamageMod.ignite on lane O of
debug/f155_oil, replicated from state.d and the SPEL data, next to what the port logged. The terrain, the caches and the Terrain
class are those of f128_expect.py (loaded from the same folder).

Usage: python3 -I agent/tools/f155_expect.py [godot log of debug/f155_oil (rules debug/rules/f155_oil.tres)]
       python3 -I agent/tools/f155_expect.py --lanes     (only the lane check against the map caches)
       python3 -I agent/tools/f155_expect.py --schedule  (the tick table, no log)

Needs the bench switches on (debug/ai_match.gd): AbilityEffect.log_effects (the `lob` line) and Oiled.log_oil.

sacengine:
- useAbility → shoot!true (13463-13493): startUsingAbility with shoot1 (CKa2, 48 frames at 30 fps, no `lrba`: the shoot tick is the
  last frame, 47): the body prepares 2 * 47 = 94 ticks. At that tick shootOnTick calls oilShoot (13189-13194), which fires ONE
  OilProjectile: direction = getShotDirectionWithGravity (11506-11510) with the ranged accuracy, v = direction * 30 (not normalized),
  and drains the mana (Pyrodactyl 300, kcfa 60: 300->240); the cooldown (6 s = 360 ticks) is set if it was 0 (12746-12748).
- updateOilProjectile (25614-25633), once per tick from the next one: position += v / 60, then v.z -= 20 / 60 (g = 20, sacspell.d:123).
  On the ground (or a building) and below it: oilExplosion at once. Else the first creature that is NOT the shooter, of ANY side and
  canBeOiled, whose box meets the 1 m box of the oil (oilProjectileCollisionTarget, 25580-25586): oilExplosion.
- oilExplosion (25588-25612): dealDamageAt(0, 0, effectRange 15) with a callback that gives an Oil (900 ticks) to every body, any
  side, that is not oiled and canBeOiled. No damage. 100 oil particles.
- updateOil (25653-25676): one update per tick from the next one. While frame <= 900 a non-wizard has its orders cleared (and the AI
  does not run, 13647-13649). At frame 901 the oil is gone ("limpio"): +901 ticks after the burst.
- dealRawDamage (9028-9031): a hit with DamageMod.ignite on an oiled body: igniteOil (status = ignited) and the damage x2. The
  carriers: Spit fire fkba (23247), fhba (23041, 23051), cfba (24521, 24528), Fireball (16670-16677), Steam Cloud (25218) and the oil's
  own blast. NOT Tickferno (23809) nor Phoenix (24241). An ally with friendly fire off takes 0 in dealDamage (8961) and does not ignite.
- The tick after the ignite updateOil sees `ignited`: igniteOil (25639-25651): dealSplashRangedDamageAt(0, …, damageRange 5) of the
  SPEL's amount (500) with DamageMod.ignite, from the center of the oiled body, in the name of whoever threw the oil; the callback
  setAblaze(target, 60 frames, no damage) lights a look-only fire on EVERY body in the radius (ally included) before it hurts it. Then
  the oil is removed. The oil of the body that blasts is already ignited, so its own blast is not doubled; an oiled neighbour of the
  other side is (x2) and ignites: it blasts one update later (the same tick if its Oil updates after, divergence declared).
- Damage of a blast on body b: 500 * (1 - d / 5) * splash_ranged resistance (Druid, Trogg: 0.9) * (2 if b is oiled and not ignited),
  d = distance from the blast to b's box; capped by the health b has left (regeneration moves what is left, not the damage).

Lane O (anchor 1270, 1270): Pyrodactyl1 -25/-35 (slot 1, pacifist, the thrower), Druid1 (O1) 0/-35, Druid2 (O2) +2/-35, Druid3 (O3, slot 1,
an ally) 0/-32, Druid4 (O4) +18/-35 (17.5 m of box from the burst: out of the 15), Trogg1 (O5) 0/-48 (walks towards FM at 2.5 s),
FlameMinion1 (FM, slot 1, NOT a pacifist: a pacifist refuses the order to attack, so it spits fire at Druid1 on its own). The oil is
thrown at the point (1270, 1235) at 0.5 s (T = tick 30).
Log lines:
  usando habilidad Viscous Oil Pyrodactyl1 94 ticks (tick T)                                  (ActiveAbility)
  habilidad Viscous Oil mana 300->240 enfriamiento 360 ticks                                  (ActiveAbility)
  lob Pyrodactyl1 kcfa tiro 1/1 ShotN v (vx, vy, vz) origen (x, y, z) (tick F)                (LobAbility)
  bola aceite ShotN toca a <cuerpo>|suelo en (x, y, z) radio 15.0 (tick N)                    (OilImpact)
  aceite <cuerpo> untado hasta E (tick N)                                                     (Oiled.start)
  aceite <cuerpo> paso (x, y, z) (tick N)                                                     (Oiled, every tick it lasts)
  aceite <cuerpo> arde (tick N)                                                               (Oiled.ignite, the first time)
  aceite <cuerpo> explota en (x, y, z) radio 5.0 (tick N)  ... dano <cuerpo> N vida M ...  aceite <cuerpo> explosión fin (tick N)
  aceite <cuerpo> limpio (<motivo>) (tick N)                                                  (Oiled._finish)
  dano <cuerpo> N vida M                                                                      (rock_projectile.report)
  fuego <cuerpo> total 0.0 en 61 actualizaciones vida M                                       (Burning, look-only)
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
BOX = 1.0
WINDUP_TICKS = 94
MANA = (300, 240)
COOLDOWN = 360
OIL_TICKS = 900
CLEAN_AT = OIL_TICKS + 1
EFFECT_RANGE = 15.0
BLAST_RANGE = 5.0
BLAST_AMOUNT = 500.0
FIRE_UPDATES = 61
SPIT_AMOUNT = 160.0
RESIST = 0.9
ACCURACY = 1000.0
RANGE = 100.0
TOL_TICKS = 1
TOL_M = 0.05
CLEAR_STRUCTURE_M = 11.0
CLEAR_WIDGET_M = 6.0
MAX_STEPS = 600
NUM = r"(-?\d+(?:\.\d+)?)"
VEC = r"\(" + NUM + r", " + NUM + r", " + NUM + r"\)"

# name -> (dx, dz, slot, creature model tag) from the anchor
LANES = {
    "Pyrodactyl1": (-25.0, -35.0, 1, "kacf"),
    "Druid1": (0.0, -35.0, 2, "nmuh"),
    "Druid2": (2.0, -35.0, 2, "nmuh"),
    "Druid3": (0.0, -32.0, 1, "nmuh"),
    "Druid4": (18.0, -35.0, 2, "nmuh"),
    "Trogg1": (0.0, -48.0, 2, "ycro"),
    "FlameMinion1": (-18.0, -20.0, 1, "fplk"),
}
SHOOTER = "Pyrodactyl1"
SLOT = 1
TARGET = "Druid1"
AIM = (1270.0, 1235.0)
# the plan's lane: who is smeared and who is not
OILED = ["Druid1", "Druid2", "Druid3", "Trogg1"]
CLEAN = ["Druid4", "FlameMinion1", "Pyrodactyl1"]


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


def aabb_distance(point, center, half):
    """sacengine boxPointDistance: from `point` to the box (center, half extents), 0 inside it."""
    d = [max(abs(point[i] - center[i]) - half[i], 0.0) for i in range(3)]
    return math.sqrt(sum(c * c for c in d))


def body_box(terrain, name, pos=None):
    """(center, half) of the still capsule of `name` standing on the land (at `pos` x, z when the port says where)."""
    x, z = (pos[0], pos[2]) if pos else world(name)
    gy = (terrain.ground(x, z) if terrain else None)
    gy = 0.0 if gy is None else gy
    if pos:
        gy = pos[1]
    radius, height = capsule(LANES[name][3])
    return (x, gy + height / 2.0, z), (radius, height / 2.0, radius)


def check_lanes():
    """Land under every body and along the lane (no hole), no structure within 11 m of a body, no widget within 6 m, the range (the
    aim point inside the SPEL's 100 m, 25 m from the Pyrodactyl), who is inside the 15 m of the burst and who is not (with the
    margin), and the 5 m of the first blast (O2 and O3 in, the others out)."""
    ok = True
    terrain = base.Terrain.load()
    try:
        ntts = json.load(open(cache("high_noon_ntts.json"), encoding="utf-8"))
        widgets = json.load(open(cache("high_noon_widgets.json"), encoding="utf-8"))
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
        print("carril %-12s (%.1f, %.1f) suelo %s estructuras<%d %s widgets<%d %s %s" % (
            name, x, z, "?" if y is None else "%.2f" % y, CLEAR_STRUCTURE_M, near, CLEAR_WIDGET_M, props, "MAL" if bad else "ok"))
    holes = 0
    cells = 0
    flat_ys = []
    if terrain:
        xs = [world(n)[0] for n in LANES] + [AIM[0]]
        zs = [world(n)[1] for n in LANES] + [AIM[1]]
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
        print("suelo del carril O: %.2f a %.2f m (desnivel %.2f m; la réplica usa el suelo real)" % (min(flat_ys), max(flat_ys), max(flat_ys) - min(flat_ys)))
    px, pz = world(SHOOTER)
    d = math.hypot(AIM[0] - px, AIM[1] - pz)
    good = abs(d - 25.0) < 0.01 and d <= RANGE
    ok = ok and good
    print("%s -> punto de tiro: %.2f m en planta (alcance %.0f) %s" % (SHOOTER, d, RANGE, "ok" if good else "MAL"))
    ground = (terrain.ground(AIM[0], AIM[1]) if terrain else None) or 0.0
    burst = (AIM[0], ground + 0.9, AIM[1])
    for name in LANES:
        gap_oil = aabb_distance(burst, *body_box(terrain, name))
        inside = gap_oil <= EFFECT_RANGE
        want = name in OILED
        margin = abs(gap_oil - EFFECT_RANGE)
        good = inside == want and (margin >= 0.4 or name == SHOOTER)
        ok = ok and good
        print("%-12s a %.2f m de caja del golpe (radio %.0f): %s, %s %s" % (
            name, gap_oil, EFFECT_RANGE, "dentro" if inside else "fuera", "debe estar dentro" if want else "debe estar fuera",
            "ok (margen %.2f)" % margin if good else "MAL (margen %.2f)" % margin))
    o1 = body_box(terrain, "Druid1")[0]
    for name in ("Druid2", "Druid3", "Druid4", "Trogg1"):
        gap = aabb_distance(o1, *body_box(terrain, name))
        print("explosión de Druid1 -> %-7s a %.2f m de caja (radio %.0f): %s" % (name, gap, BLAST_RANGE, "dentro" if gap <= BLAST_RANGE else "fuera"))
    foes = [n for n in LANES if LANES[n][2] != SLOT]
    allies = [n for n in LANES if LANES[n][2] == SLOT and n != SHOOTER]
    print("enemigos del Pyrodactyl: %s; aliados (reciben aceite, no daño): %s ok" % (foes, allies))
    return ok


def verdict(ok, text):
    print("%s  %s" % ("PASS" if ok else "FAIL", text))
    return ok


def box_hits(terrain, pos, name):
    """The still capsule of `name` against the oil's 1 m box at `pos`: the distance of the box to the capsule's axis <= radius."""
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


def tick_of(line):
    m = re.search(r"\(tick (\d+)\)\s*$", line)
    return int(m.group(1)) if m else -1


def read_log(path):
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    log = {"bench": [], "using": None, "ability": [], "lobs": [], "burst": None, "oiled": {}, "paso": {}, "arde": [], "blasts": [],
           "directs": [], "clean": {}, "fires": {}, "refused": []}
    blast = None
    pending = {}
    # Lane R (Pyrodactyl2 / Earthfling1 / Basilisk1) shares the log: its lines are checked by check_rockform, not here.
    lane_r_shots = set()
    owner = ""
    kept = []
    for line in lines:
        m = re.search(r"lob (Pyrodactyl\d) \S+ tiro \d+/\d+ (\S+) ", line)
        if m:
            owner = m.group(1)
            if owner != SHOOTER:
                lane_r_shots.add(m.group(2))
                continue
        if line.startswith("habilidad Rockform") or "Pyrodactyl2" in line or "Earthfling1" in line or "Basilisk1" in line or "Flummox1" in line:
            continue
        if line.startswith("habilidad Viscous Oil mana") and owner != SHOOTER:
            continue
        m = re.match(r"bola aceite (\S+) ", line)
        if m and m.group(1) in lane_r_shots:
            continue
        kept.append(line)
    lines = kept
    for line in lines:
        m = re.search(r"bench: (\S+) usa la habilidad: (?:rechazada, )?(.+?) \(tick (\d+)\)", line)
        if m and m.group(1) == SHOOTER:
            log["bench"].append((m.group(2), int(m.group(3))))
        m = re.match(r"usando habilidad (.+?) " + SHOOTER + r" (\d+) ticks(?: \(tick (\d+)\))?", line)
        if m and log["using"] is None:
            log["using"] = (int(m.group(2)), int(m.group(3) or -1))
        m = re.search(r"habilidad (.+?) mana (\d+)->(\d+)(?: enfriamiento (\d+) ticks)?", line)
        if m:
            log["ability"].append((int(m.group(2)), int(m.group(3)), int(m.group(4) or -1)))
        m = re.search(r"lob " + SHOOTER + r" (\S+) tiro (\d+)/(\d+) (\S+) v " + VEC + r" origen " + VEC + r" \(tick (\d+)\)", line)
        if m:
            log["lobs"].append({
                "tag": m.group(1), "k": int(m.group(2)), "of": int(m.group(3)), "shot": m.group(4),
                "v": tuple(float(m.group(i)) for i in (5, 6, 7)), "origin": tuple(float(m.group(i)) for i in (8, 9, 10)),
                "tick": int(m.group(11))})
        m = re.match(r"bola aceite (\S+) toca (?:a (\S+)|suelo) en " + VEC + r" radio " + NUM + r" \(tick (\d+)\)", line)
        if m:
            log["burst"] = {"shot": m.group(1), "body": m.group(2), "pos": tuple(float(m.group(i)) for i in (3, 4, 5)),
                            "radius": float(m.group(6)), "tick": int(m.group(7))}
        m = re.match(r"aceite (\S+) no se unta", line)
        if m:
            log["refused"].append(m.group(1))
        m = re.match(r"aceite (\S+) untado hasta (\d+) \(tick (\d+)\)", line)
        if m:
            log["oiled"].setdefault(m.group(1), []).append({"until": int(m.group(2)), "tick": int(m.group(3))})
        m = re.match(r"aceite (\S+) paso " + VEC + r" \(tick (\d+)\)", line)
        if m:
            log["paso"].setdefault(m.group(1), []).append({"pos": tuple(float(m.group(i)) for i in (2, 3, 4)), "tick": int(m.group(5))})
        m = re.match(r"aceite (\S+) arde \(tick (\d+)\)", line)
        if m:
            log["arde"].append((m.group(1), int(m.group(2))))
            pending[m.group(1)] = int(m.group(2))
        m = re.match(r"aceite (\S+) explota en " + VEC + r" radio " + NUM + r" \(tick (\d+)\)", line)
        if m:
            blast = {"body": m.group(1), "pos": tuple(float(m.group(i)) for i in (2, 3, 4)), "radius": float(m.group(5)),
                     "tick": int(m.group(6)), "hits": [], "lit": []}
            log["blasts"].append(blast)
            continue
        m = re.match(r"aceite (\S+) explosión fin", line)
        if m:
            blast = None
            continue
        m = re.match(r"aceite (\S+) limpio \((.+?)\) \(tick (\d+)\)", line)
        if m:
            log["clean"].setdefault(m.group(1), []).append({"why": m.group(2), "tick": int(m.group(3))})
        m = re.match(r"dano (\S+) (-?\d+) vida (-?\d+)", line)
        if m:
            name, taken, left = m.group(1), int(m.group(2)), int(m.group(3))
            lit = name in pending
            if blast is not None:
                blast["hits"].append({"body": name, "taken": taken, "left": left, "lit": lit})
            else:
                log["directs"].append({"body": name, "taken": taken, "left": left, "lit": lit, "tick": pending.get(name, -1)})
            pending.pop(name, None)
        m = re.match(r"fuego (\S+) total " + NUM + r" en (\d+) actualizaciones", line)
        if m:
            log["fires"].setdefault(m.group(1), []).append({"total": float(m.group(2)), "updates": int(m.group(3))})
    return log


def check_log(path):
    log = read_log(path)
    terrain = base.Terrain.load()
    ok = True
    # 1. the preparation, the mana, the cooldown, the burst.
    use = log["using"]
    ok &= verdict(use is not None and use[0] == WINDUP_TICKS, "1. usando habilidad %d ticks: %s" % (WINDUP_TICKS, str(use)))
    ok &= verdict(len(log["ability"]) == 1, "1. un solo uso (%d líneas de maná)" % len(log["ability"]))
    mana = log["ability"][0] if log["ability"] else None
    ok &= verdict(mana is not None and mana[:2] == MANA, "1. mana %d->%d: %s" % (MANA[0], MANA[1], str(mana[:2] if mana else "nada")))
    ok &= verdict(mana is not None and mana[2] == COOLDOWN, "1. enfriamiento %d ticks: %s" % (COOLDOWN, str(mana[2] if mana else "nada")))
    lobs = log["lobs"]
    t0 = use[1] if use else None
    fire = lobs[0]["tick"] if lobs else None
    ok &= verdict(len(lobs) == 1 and fire is not None and t0 is not None and abs(fire - (t0 + WINDUP_TICKS)) <= TOL_TICKS,
                  "1. un solo tiro en el tick %s (esperado %s = T + %d, ± %d)" % (fire, None if t0 is None else t0 + WINDUP_TICKS, WINDUP_TICKS, TOL_TICKS))
    burst = log["burst"]
    if lobs:
        shot = lobs[0]
        steps, fate, name, at = fly(terrain, shot["origin"], shot["v"], [n for n in LANES if n != SHOOTER])
        want_tick = shot["tick"] + steps
        speed = math.sqrt(sum(c * c for c in shot["v"]))
        ok &= verdict(0.5 * SPEED <= speed <= 1.5 * SPEED, "1. |v| %.2f cerca de %.0f" % (speed, SPEED))
        ok &= verdict(burst is not None and abs(burst["tick"] - want_tick) <= TOL_TICKS,
                      "1. explosión en el tick %s; réplica %s%s en el tick %d (%d pasos, ± %d)" % (
                          None if burst is None else burst["tick"], fate, "" if name is None else " " + name, want_tick, steps, TOL_TICKS))
        if burst is not None:
            gap = math.dist(burst["pos"], at)
            ok &= verdict(gap <= 0.5, "1. punto de la explosión a %.3f m de la réplica (≤ 0,5)" % gap)
            ok &= verdict(abs(burst["radius"] - EFFECT_RANGE) < 1e-6, "1. radio del aceite %.1f" % burst["radius"])
    else:
        burst = None
    # 2. who is smeared: the plan's set, and the replica's by the box distance to the burst.
    got = set(log["oiled"])
    ok &= verdict(got == set(OILED), "2. untados %s (esperado %s)" % (sorted(got), sorted(OILED)))
    ok &= verdict(not (got & set(CLEAN)), "2. sin aceite: %s" % CLEAN)
    if burst is not None:
        replica = set()
        for name in LANES:
            gap = aabb_distance(burst["pos"], *body_box(terrain, name))
            if gap <= EFFECT_RANGE:
                replica.add(name)
        ok &= verdict(replica == got, "2. réplica por caja a %.1f m del golpe: %s" % (EFFECT_RANGE, sorted(replica)))
    ok &= verdict(all(len(v) == 1 for v in log["oiled"].values()), "2. cada cuerpo se unta una sola vez")
    ok &= verdict(all(v[0]["tick"] >= (burst["tick"] if burst else 0) and abs(v[0]["tick"] - (burst["tick"] if burst else 0)) <= TOL_TICKS
                      for v in log["oiled"].values()), "2. todos se untan en el tick de la explosión")
    # 3. O5 stays where the oil caught it and has no order.
    paso = log["paso"].get("Trogg1", [])
    if paso:
        first = paso[0]["pos"]
        worst = max(math.dist(p["pos"], first) for p in paso)
        ok &= verdict(worst <= TOL_M, "3. Trogg1 quieto %d ticks: se aparta %.4f m del primer paso (≤ %.2f)" % (len(paso), worst, TOL_M))
        ## FM spits at whoever is left: once the Druids are dead it lights Trogg1 too, and the blast takes its oil (sacengine igniteOil).
        end = next((c["tick"] for c in log["clean"].get("Trogg1", []) if c["why"] == "explotó"), None)
        start = log["oiled"].get("Trogg1", [{}])[0].get("tick", 0)
        need = OIL_TICKS - 2 if end is None else min(OIL_TICKS - 2, end - start - 2)
        ok &= verdict(len(paso) >= need, "3. Trogg1 pasó %d ticks untado (≥ %d%s)" % (len(paso), need, "" if end is None else ", hasta que arde y explota"))
    else:
        ok &= verdict(False, "3. sin líneas «paso» de Trogg1")
    # 4. the first fkba that reaches an oiled body: x2 and the blast on the tick after.
    arde = log["arde"]
    ok &= verdict(bool(arde), "4. al menos un aceite arde: %s" % arde[:4])
    lit_directs = [d for d in log["directs"] if d["lit"]]
    ok &= verdict(bool(lit_directs), "4. al menos un golpe directo sobre un untado: %d" % len(lit_directs))
    for d in lit_directs[:1]:
        want = SPIT_AMOUNT * RESIST * 2.0
        before = d["taken"] + d["left"]
        want = min(before, want)
        ok &= verdict(abs(d["taken"] - want) <= TOL_TICKS,
                      "4. primer fkba sobre un untado: dano %s %d (esperado %.1f = 160 * 0.9 * 2, tope %d)" % (d["body"], d["taken"], want, before))
    plain = [d for d in log["directs"] if not d["lit"] and d["body"] in ("Druid1", "Druid2", "Druid3", "Druid4") and d["taken"] > 0]
    for d in plain[:2]:
        want = min(d["taken"] + d["left"], SPIT_AMOUNT * RESIST)
        ok &= verdict(abs(d["taken"] - want) <= TOL_TICKS,
                      "4. fkba sobre un no untado (o ya encendido): dano %s %d (esperado %.1f = 160 * 0.9)" % (d["body"], d["taken"], want))
    # 5. the blasts.
    blasts = log["blasts"]
    ok &= verdict(bool(blasts), "5. al menos una explosión: %d" % len(blasts))
    arde_ticks = {}
    for name, tick in arde:
        arde_ticks.setdefault(name, tick)
    for i, b in enumerate(blasts):
        lit_at = arde_ticks.get(b["body"])
        delay = None if lit_at is None else b["tick"] - lit_at
        want = (1,) if i == 0 else (0, 1)
        ok &= verdict(delay in want, "5. %s arde en el tick %s y explota en el tick %d (%s ticks después; esperado %s)" % (
            b["body"], lit_at, b["tick"], delay, " o ".join(str(w) for w in want)))
        ok &= verdict(abs(b["radius"] - BLAST_RANGE) < 1e-6, "5. radio de la explosión %.1f" % b["radius"])
        bodies = {}
        for name, steps_ in log["paso"].items():
            before = [p for p in steps_ if p["tick"] <= b["tick"]]
            if before:
                bodies[name] = before[-1]["pos"]
        for h in b["hits"]:
            name = h["body"]
            if name not in LANES or name not in bodies:
                continue
            gap = aabb_distance(b["pos"], *body_box(terrain, name, bodies[name]))
            ally = LANES[name][2] == SLOT
            if gap > BLAST_RANGE:
                ok &= verdict(False, "5. %s recibe dano a %.2f m de la explosión de %s (radio %.0f)" % (name, gap, b["body"], BLAST_RANGE))
                continue
            raw = BLAST_AMOUNT * max(0.0, 1.0 - gap / BLAST_RANGE) * RESIST
            doubled = (not ally) and name != b["body"] and h["lit"]
            if ally:
                raw = 0.0
            elif doubled:
                raw *= 2.0
            expect = min(h["taken"] + h["left"], raw)
            tol = max(1.5, 0.03 * raw)
            ok &= verdict(abs(h["taken"] - expect) <= tol,
                          "5. explosión de %s: dano %s %d (esperado %.1f; a %.2f m de caja%s%s)" % (
                              b["body"], name, h["taken"], expect, gap, ", x2" if doubled else "", ", aliado: 0" if ally else ""))
            if not ally and name != b["body"]:
                ok &= verdict(h["lit"], "5. %s (enemigo untado, a %.2f m) arde con la explosión de %s" % (name, gap, b["body"]))
    ok &= verdict("Druid3" not in {n for n, _ in arde}, "5. Druid3 (aliado) recibe 0 y no arde")
    # the fire of no damage: every body in the radius of a blast gets one, ally included.
    for b in blasts:
        for name in LANES:
            if name not in log["paso"]:
                continue
            seen = [p for p in log["paso"][name] if p["tick"] <= b["tick"]]
            gap = aabb_distance(b["pos"], *body_box(terrain, name, seen[-1]["pos"] if seen else None))
            if gap <= BLAST_RANGE:
                fires = log["fires"].get(name, [])
                good = any(f["updates"] == FIRE_UPDATES and f["total"] == 0.0 for f in fires)
                ok &= verdict(good, "5. fuego visual en %s (a %.2f m de la explosión de %s): %s" % (name, gap, b["body"], fires[:2]))
    # 6. the oil that was not lit lets go at +901.
    for name in ("Druid3", "Trogg1"):
        cleans = log["clean"].get(name, [])
        until = log["oiled"].get(name, [{}])[0].get("until")
        if not cleans or until is None:
            ok &= verdict(False, "6. %s sin línea de untado o de limpieza" % name)
            continue
        start = log["oiled"][name][0]["tick"]
        lit = [t for n, t in arde if n == name]
        if cleans[-1]["why"] == "explotó" and lit and 0 <= cleans[-1]["tick"] - lit[0] <= 1:
            ok &= verdict(True, "6. %s: encendido por FM en el tick %d, el aceite se quitó con su explosión en el %d (no llega a +%d)" % (name, lit[0], cleans[-1]["tick"], CLEAN_AT))
            continue
        ok &= verdict(until - start == CLEAN_AT, "6. %s: untado hasta %d = untado + %d" % (name, until, CLEAN_AT))
        ok &= verdict(abs(cleans[-1]["tick"] - (start + CLEAN_AT)) <= TOL_TICKS and cleans[-1]["why"] == "vencido",
                      "6. %s limpio por «%s» en el tick %d (esperado %d ± %d)" % (name, cleans[-1]["why"], cleans[-1]["tick"], start + CLEAN_AT, TOL_TICKS))
    ok &= check_rockform(log, path)
    print("(look del aceite y de la explosión, y que f129 / f123 / quick no cambien: capturas y bancos del playtester)")
    return ok


def check_rockform(log, path):
    """Lane R (REVIEW-030r-b B1): an Earthfling in Rockform that the oil already holds (holds on) and the Basilisk's gaze petrifies
    (its bolt toward the Flummox crosses it) closes Rockform on the same tick: Afflictions.held_changed also fires when
    breaks_special_modes changes. Lines: `rockform abierto|cerrado <cuerpo> (tick N)` (ActiveAbility)."""
    name = "Earthfling1"
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    opened = [tick_of(l) for l in lines if l.startswith("rockform abierto " + name)]
    closed = [tick_of(l) for l in lines if l.startswith("rockform cerrado " + name)]
    stone = [int(m.group(1)) for m in (re.match(r"petrificado " + name.rstrip("1") + r" durante \d+ \(cuadro (\d+)\)", l) for l in lines) if m]
    smeared = [int(m.group(1)) for m in (re.match(r"aceite " + name + r" untado hasta \d+ \(tick (\d+)\)", l) for l in lines) if m]
    cleaned = [tick_of(l) for l in lines if l.startswith("aceite " + name + " limpio")]
    ok = verdict(bool(smeared), "7. %s untado en Rockform en el tick %s" % (name, smeared[:1]))
    ok &= verdict(bool(opened) and bool(stone), "7. %s en Rockform (abierto en %s) y petrificado en el cuadro %s" % (name, opened[:1], stone[:1]))
    if not (opened and stone and smeared):
        return False
    ok &= verdict(smeared[0] < stone[0] and (not cleaned or cleaned[0] > stone[0]),
                  "7. el aceite sigue puesto al petrificarlo (holds ya en true: el caso del bloqueante)")
    ok &= verdict(any(0 <= c - stone[0] <= 1 for c in closed), "7. rockform cerrado %s en el tick %s (petrificado en %d)" % (name, closed[:2], stone[0]))
    return ok


def schedule():
    print("T = tick de la orden (0,5 s = 30). Preparación %d ticks; tiro en T+%d; enfriamiento %d; el aceite dura %d ticks y se limpia a los +%d." % (
        WINDUP_TICKS, WINDUP_TICKS, COOLDOWN, OIL_TICKS, CLEAN_AT))
    print("Spit fire: %d * %.1f = %.1f; sobre un untado x2 = %.1f. Explosión: %d en radio %d, x2 sobre un vecino untado enemigo." % (
        SPIT_AMOUNT, RESIST, SPIT_AMOUNT * RESIST, SPIT_AMOUNT * RESIST * 2, BLAST_AMOUNT, BLAST_RANGE))


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
