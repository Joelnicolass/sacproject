#!/usr/bin/env python3
"""F156 (RFC-030 030s-b): what sacengine would do with the Blight's Bilemites (liba) on lane M of debug/f156_mites, replicated from
state.d and the SPEL data, next to what the port logged. The terrain, the caches and the Terrain class are those of f128_expect.py
(loaded from the same folder).

Usage: python3 -I agent/tools/f156_expect.py [godot log of debug/f156_mites (rules debug/rules/f156_mites.tres)]
       python3 -I agent/tools/f156_expect.py --lanes     (only the lane check against the map files)
       python3 -I agent/tools/f156_expect.py --schedule  (the tick table, no log)

Lane N (B1 of the review: the `spent()` branch): Blight2 (slot 1) alone at (+45, +78) from the anchor, ordered at 6 s to use the ability on
the ground 38 m from it, with nobody within 15 m of that ground: every mite hops 5 times to nobody, the 5th touch stops it and it is
freed exactly 30 ticks later (the shot is gone: no more hops, no stick).

Needs the bench switches on (debug/ai/ai_match.gd): AbilityEffect.log_effects, Clinging.log_cling, PaceFactors.log_pace and MiteHop.log_hop.

sacengine:
- useAbility -> shoot!true (13463-13493): the body prepares (liba has no `lrba` in the export: the last frame of its clip, 94 ticks like
  the Sticky bomb) and at the shoot tick blightMitesShoot (13111-13119) throws 10 mites and drains the mana (Blight 200, liba 60: 200->140;
  cooldown 6 s = 360 ticks). Each: direction = getShotDirectionWithGravity + 0.2 * uniformDirection; v = direction * 30 (not normalized).
- updateBlightMite (25271-25340), once per tick from the next one: position += v / 60, then v.z -= 20 / 60. When the land is above it:
  it is put on the ground, numJumps += 1 and (before the 5th) v changes: toward the closest creature within 15 m (4.5 * dir + 0.5 *
  uniformDirection, v.z += 0.5 * 20 * |d| / |v|, v.z <= 10; the target it was thrown at goes first when it is in range) or, with nobody, 5 *
  uniformDirection and v.z = 10. The 5th touch stops it, and it is gone 30 ticks later.
- blightMiteCollisionTarget (25262-25269): the first creature (any side) that canBePoisoned whose box meets the mite's box (0.5 m) takes it
  (numBlightMites += 1, 8 s = 481 ticks: `++infectionTime <= 60 * duration` plus one), then numBlightMites -= 1. movementSpeed multiplies by
  0.8 ^ numBlightMites (stats.d:122). No damage. The shooter never takes one (declared divergence: sacengine allows it after 30 ticks).
- The replica takes each mite's origin and velocity from the `lob` line and, since Python does not reproduce Godot's RNG, restarts every
  segment from the post-hop state the port logs (`salto`): it integrates it with g = 20 (move, then gravity: RangedShot) against the real
  terrain (assets/original/maps/high_noon/terrain.res) and the bodies of lane M as still capsules, and says on which tick the ground is touched and which
  body is hit. It also checks that each hop's velocity is inside what the formulas allow and that the body it aims at is the closest one
  within 15 m (or the target it was thrown at, Druid1, when it is in range).
Lane M (anchor 1270, 1270): Blight1 -25/-20 (slot 1, looks to +x), Druid1 0/-20 (slot 2, 25 m, the target), Druid2 +3/-17 (slot 2),
Druid3 -3/-17 (slot 1, ally). The ability is used at 0.5 s (T = tick 30).
Log lines:
  bench: Blight1 usa la habilidad: rechazada, <motivo> (tick N)                                (BenchEvent)
  usando habilidad Bilemites Blight1 94 ticks (tick T)                                          (ActiveAbility)
  habilidad Bilemites mana 200->140 enfriamiento 360 ticks                                      (ActiveAbility)
  lob Blight1 liba tiro K/10 ShotN v (vx, vy, vz) origen (x, y, z) (tick F)                     (LobAbility)
  salto ShotN n=K en (x, y, z) v (vx, vy, vz) hacia <cuerpo|nadie> (tick N)                     (MiteHop; the 5th: `n=5 en (..) parado`)
  acaro ShotN suelto (tick N)                                                                   (MiteHop.spent)
  bomba mites ShotN pega a <cuerpo> en (x, y, z) (tick N) | se pierde en <cuerpo> (...)         (StickImpact)
  pegado <cuerpo> mites n=K factor xF hasta E (tick N) / suelto <cuerpo> mites n=A->B (tick N)  (Clinging)
  ritmo <cuerpo> xF [fuentes] (tick N)                                                          (PaceFactors)
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
BOX = 0.5
WINDUP_TICKS = 94
MANA = (200, 140)
COOLDOWN = 360
HOLD_TICKS = 481
FACTOR = 0.8
SHOTS = 10
SPREAD = 0.2
ACCURACY = 1000.0
RANGE = 100.0
REACH = 15.0
MAX_JUMPS = 5
REST_TICKS = 30
HOP_SPEED = 4.5
WOBBLE = 0.5
MAX_RISE = 10.0
IDLE_SPEED = 5.0
IDLE_RISE = 10.0
TOL_TICKS = 1
TOL_POS = 0.05
CLEAR_STRUCTURE_M = 11.0
CLEAR_WIDGET_M = 6.0
MAX_STEPS = 900
NUM = r"(-?\d+(?:\.\d+)?)"
VEC = r"\(" + NUM + r", " + NUM + r", " + NUM + r"\)"

# name -> (dx, dz, slot, creature model tag) from the anchor
LANES = {
    "Blight1": (-25.0, -20.0, 1, "kacd"),
    "Druid1": (0.0, -20.0, 2, "nmuh"),
    "Druid2": (3.0, -17.0, 2, "nmuh"),
    "Druid3": (-3.0, -17.0, 1, "nmuh"),
}
SHOOTER = "Blight1"
TARGET = "Druid1"
# lane N: dx, dz from the anchor, slot, model tag; the ground it is aimed at (x, z of the map) and the event second
LANE_N = {"Blight2": (45.0, 78.0, 1, "kacd")}
SHOOTER_N = "Blight2"
AIM_N = (ANCHOR[0] + 45.0, ANCHOR[1] + 116.0)
BODIES = dict(LANES, **LANE_N)
MAX_RANGE = 45.0  # speed^2 / g: the farthest a 30 m/s shot with g 20 can land
AWAY_N_M = 60.0
RANGES = {("Blight1", "Druid1"): 25.0}


def map_file(name):
    """A High Noon map file from assets/original/maps/high_noon/ (RFC-033, 033f)."""
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "original", "maps", "high_noon", name)


def data_file(name):
    """A game data file from assets/original/data/ (RFC-033, 033g)."""
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "original", "data", name)


def model_file(name):
    """A model measurement file from assets/original/models/ (RFC-033, 033c)."""
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "original", "models", name)



def world(name):
    dx, dz, _, _ = BODIES[name]
    return ANCHOR[0] + dx, ANCHOR[1] + dz


def flat(a, b):
    ax, az = world(a)
    bx, bz = world(b)
    return math.hypot(ax - bx, az - bz)


def capsule(tag):
    """(radius, height) of a creature's capsule on the ground (BodyCollider.refit): height >= 0.6, radius <= 0.45 * height."""
    try:
        creatures = json.load(open(data_file("creatures.json"), encoding="utf-8"))
        bodies = json.load(open(model_file("sizes.json"), encoding="utf-8"))["bodies"]
        info = bodies[creatures[tag]["model"]]
    except (OSError, KeyError, ValueError):
        return 0.35, 1.8
    height = max(float(info.get("height", 1.8)), 0.6)
    return min(float(info.get("radius", 0.35)), height * 0.45), height


def center(terrain, name):
    x, z = world(name)
    gy = (terrain.ground(x, z) if terrain else None) or 0.0
    return (x, gy + capsule(BODIES[name][3])[1] / 2.0, z)


def check_lanes():
    """Land under every body and around the lane (no hole), no structure within 11 m of a body, no widget within 6 m, the range
    (Druid1 inside the SPEL's 100 m, 25 m from the Blight) and the ally off the foes' side."""
    ok = True
    terrain = base.Terrain.load()
    try:
        ntts = json.load(open(map_file("ntts.json"), encoding="utf-8"))
        widgets = json.load(open(map_file("widgets.json"), encoding="utf-8"))
    except OSError:
        ntts, widgets = {"structures": []}, {}
    structures = ntts.get("structures", [])
    for name in BODIES:
        x, z = world(name)
        y = terrain.ground(x, z) if terrain else None
        near = [(s["tag"], round(math.hypot(s["x"] - x, s["z"] - z), 1)) for s in structures
                if math.hypot(s["x"] - x, s["z"] - z) < CLEAR_STRUCTURE_M]
        props = [k for k, ps in widgets.items() for p in ps if math.hypot(p[0] - x, p[1] - z) < CLEAR_WIDGET_M]
        bad = (terrain is not None and y is None) or near or props
        ok = ok and not bad
        print("carril %-8s (%.1f, %.1f) suelo %s estructuras<%d %s widgets<%d %s %s" % (
            name, x, z, "?" if y is None else "%.2f" % y, CLEAR_STRUCTURE_M, near, CLEAR_WIDGET_M, props, "MAL" if bad else "ok"))
    holes = 0
    cells = 0
    ys = []
    if terrain:
        xs = [world(n)[0] for n in LANES] + [world(n)[0] for n in LANE_N] + [AIM_N[0]]
        zs = [world(n)[1] for n in LANES] + [world(n)[1] for n in LANE_N] + [AIM_N[1]]
        x = min(xs) - 15.0
        while x <= max(xs) + 15.0:
            z = min(zs) - 15.0
            while z <= max(zs) + 15.0:
                cells += 1
                y = terrain.ground(x, z)
                if y is None:
                    holes += 1
                else:
                    ys.append(y)
                z += 2.5
            x += 2.5
    ok = ok and holes == 0
    print("huecos en el carril y 15 m alrededor (%d puntos cada 2,5 m): %d %s" % (cells, holes, "ok" if holes == 0 else "MAL"))
    if ys:
        print("suelo del carril M: %.2f a %.2f m (desnivel %.2f m; la réplica usa el suelo real)" % (min(ys), max(ys), max(ys) - min(ys)))
    for (user, name), want in RANGES.items():
        d = flat(user, name)
        good = abs(d - want) < 0.01 and d <= RANGE
        ok = ok and good
        print("%s -> %s: %.2f m en planta (alcance %.0f) %s" % (user, name, d, RANGE, "ok" if good else "MAL"))
    for a, b in (("Druid1", "Druid2"), ("Druid1", "Druid3")):
        print("%s - %s: %.2f m (dentro de los %.0f m de búsqueda de un ácaro)" % (a, b, flat(a, b), REACH))
    # lane N: the ground it is aimed at is land, clear of structures and widgets, in range, and nobody (lane M included) within reach
    ax, az = AIM_N
    ay = terrain.ground(ax, az) if terrain else None
    near = [(t["tag"], round(math.hypot(t["x"] - ax, t["z"] - az), 1)) for t in structures if math.hypot(t["x"] - ax, t["z"] - az) < CLEAR_STRUCTURE_M]
    props = [k for k, ps in widgets.items() for p in ps if math.hypot(p[0] - ax, p[1] - az) < CLEAR_WIDGET_M]
    bad = (terrain is not None and ay is None) or near or props
    ok = ok and not bad
    print("blanco del carril N (%.1f, %.1f) suelo %s estructuras %s widgets %s %s" % (ax, az, "?" if ay is None else "%.2f" % ay, near, props, "MAL" if bad else "ok"))
    sx, sz = world(SHOOTER_N)
    d_aim = math.hypot(ax - sx, az - sz)
    good = 0.0 < d_aim <= MAX_RANGE
    ok = ok and good
    print("%s -> suelo: %.2f m en planta (alcance del tiro %.0f) %s" % (SHOOTER_N, d_aim, MAX_RANGE, "ok" if good else "MAL"))
    lanes_m = [math.hypot(ax - world(n)[0], az - world(n)[1]) for n in LANES]
    good = min(lanes_m) >= AWAY_N_M
    ok = ok and good
    print("suelo del carril N a %.1f m del cuerpo más cercano del carril M (>= %.0f: ni un salto de 4 llega) %s" % (min(lanes_m), AWAY_N_M, "ok" if good else "MAL"))
    good = d_aim - 20.0 > REACH
    ok = ok and good
    print("%s a %.1f m del suelo: 5 saltos de <= 5 m dejan al Blight a >= %.1f m (> %.0f) %s" % (SHOOTER_N, d_aim, d_aim - 20.0, REACH, "ok" if good else "MAL"))
    foes = [n for n in LANES if LANES[n][2] != LANES[SHOOTER][2]]
    allies = [n for n in LANES if LANES[n][2] == LANES[SHOOTER][2] and n != SHOOTER]
    print("enemigos del Blight: %s; aliado (lo pueden alcanzar): %s ok" % (foes, allies))
    return ok


def verdict(ok, text):
    print("%s  %s" % ("PASS" if ok else "FAIL", text))
    return ok


def box_hits(terrain, pos, name):
    """The still capsule of `name` against the mite's 0.5 m box at `pos`: the distance of the box to the capsule's axis <= radius."""
    x, z = world(name)
    gy = (terrain.ground(x, z) if terrain else None) or 0.0
    radius, height = capsule(BODIES[name][3])
    y0, y1 = gy + radius, gy + height - radius
    half = BOX / 2.0
    dx = max(abs(pos[0] - x) - half, 0.0)
    dz = max(abs(pos[2] - z) - half, 0.0)
    gap = max(y0 - (pos[1] + half), (pos[1] - half) - y1, 0.0)
    return dx * dx + dz * dz + gap * gap <= radius * radius


def segment(terrain, origin, velocity, bodies):
    """RangedShot._physics_process + MiteHop, step by step from a state: (steps to touch, steps to hit, body, position of each).
    A hit is looked for after the touch put the mite on the ground, in the same step."""
    p = list(origin)
    v = list(velocity)
    touch = hit = None
    for step in range(1, MAX_STEPS + 1):
        for i in range(3):
            p[i] += v[i] / T
        v[1] -= G / T
        ground = terrain.ground(p[0], p[2]) if terrain else None
        touched = ground is not None and ground > p[1]
        if touched:
            p[1] = ground
            if touch is None:
                touch = (step, tuple(p))
        best, best_d = None, float("inf")
        for name in bodies:
            if box_hits(terrain, p, name):
                cx, cy, cz = center(terrain, name)
                d = (p[0] - cx) ** 2 + (p[1] - cy) ** 2 + (p[2] - cz) ** 2
                if d < best_d:
                    best, best_d = name, d
        if best is not None:
            hit = (step, best, tuple(p))
            break
        if touched:
            break
    return touch, hit


def read_log(path):
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    log = {"bench": [], "bench_n": [], "using": None, "using_n": None, "ability": [], "lobs": [], "lobs_n": [], "suelto_lines": [], "hops": {}, "free": {}, "stick": {}, "stuck": {}, "released": {}, "pace": {}}
    for line in lines:
        m = re.search(r"bench: (\S+) usa la habilidad: (?:rechazada, )?(.+?) \(tick (\d+)\)", line)
        if m and m.group(1) == SHOOTER:
            log["bench"].append((m.group(2), int(m.group(3))))
        m = re.search(r"bench: (\S+) usa la habilidad: (?:rechazada, )?(.+?) \(tick (\d+)\)", line)
        if m and m.group(1) == SHOOTER_N:
            log["bench_n"].append((m.group(2), int(m.group(3))))
        m = re.search(r"Bilemites " + SHOOTER_N + r" (\d+) ticks(?: \(tick (\d+)\))?", line)
        if m and line.startswith("usando habilidad") and log["using_n"] is None:
            log["using_n"] = (int(m.group(1)), int(m.group(2) or -1))
        m = re.search(r"Bilemites " + SHOOTER + r" (\d+) ticks(?: \(tick (\d+)\))?", line)
        if m and line.startswith("usando habilidad") and log["using"] is None:
            log["using"] = (int(m.group(1)), int(m.group(2) or -1))
        m = re.search(r"habilidad Bilemites mana (\d+)->(\d+)(?: enfriamiento (\d+) ticks)?", line)
        if m:
            log["ability"].append((int(m.group(1)), int(m.group(2)), int(m.group(3) or -1)))
        m = re.search(r"lob " + SHOOTER_N + r" (\S+) tiro (\d+)/(\d+) (\S+) v " + VEC + r" origen " + VEC + r" \(tick (\d+)\)", line)
        if m:
            log["lobs_n"].append({
                "tag": m.group(1), "k": int(m.group(2)), "of": int(m.group(3)), "shot": m.group(4),
                "v": tuple(float(m.group(i)) for i in (5, 6, 7)), "origin": tuple(float(m.group(i)) for i in (8, 9, 10)),
                "tick": int(m.group(11))})
        m = re.search(r"lob " + SHOOTER + r" (\S+) tiro (\d+)/(\d+) (\S+) v " + VEC + r" origen " + VEC + r" \(tick (\d+)\)", line)
        if m:
            log["lobs"].append({
                "tag": m.group(1), "k": int(m.group(2)), "of": int(m.group(3)), "shot": m.group(4),
                "v": tuple(float(m.group(i)) for i in (5, 6, 7)), "origin": tuple(float(m.group(i)) for i in (8, 9, 10)),
                "tick": int(m.group(11))})
        m = re.search(r"^salto (\S+) n=(\d+) en " + VEC + r" v " + VEC + r" hacia (\S+) \(tick (\d+)\)", line)
        if m:
            log["hops"].setdefault(m.group(1), []).append({
                "n": int(m.group(2)), "pos": tuple(float(m.group(i)) for i in (3, 4, 5)),
                "v": tuple(float(m.group(i)) for i in (6, 7, 8)), "aim": m.group(9), "tick": int(m.group(10)), "stop": False})
        m = re.search(r"^salto (\S+) n=(\d+) en " + VEC + r" parado \(tick (\d+)\)", line)
        if m:
            log["hops"].setdefault(m.group(1), []).append({
                "n": int(m.group(2)), "pos": tuple(float(m.group(i)) for i in (3, 4, 5)), "v": (0.0, 0.0, 0.0),
                "aim": None, "tick": int(m.group(6)), "stop": True})
        m = re.search(r"acaro (\S+) suelto \(tick (\d+)\)", line)
        if m:
            log["free"][m.group(1)] = int(m.group(2))
            log["suelto_lines"].append(m.group(1))
        m = re.search(r"bomba mites (\S+) (pega a|se pierde en|toca suelo) (\S*)", line)
        if m:
            tick = re.search(r"\(tick (\d+)\)\s*$", line)
            log["stick"][m.group(1)] = {"what": m.group(2), "body": m.group(3), "tick": int(tick.group(1)) if tick else -1}
        m = re.search(r"pegado (\S+) mites n=(\d+) factor ×" + NUM + r" hasta (\d+) \(tick (\d+)\)", line)
        if m:
            log["stuck"].setdefault(m.group(1), []).append({"n": int(m.group(2)), "factor": float(m.group(3)),
                                                            "until": int(m.group(4)), "tick": int(m.group(5))})
        m = re.search(r"suelto (\S+) mites n=(\d+)->(\d+) \(tick (\d+)\)", line)
        if m:
            log["released"].setdefault(m.group(1), []).append({"from": int(m.group(2)), "to": int(m.group(3)), "tick": int(m.group(4))})
        m = re.search(r"ritmo (\S+) ×" + NUM + r" \[(.*?)\] \(tick (\d+)\)", line)
        if m:
            log["pace"].setdefault(m.group(1), []).append({"factor": float(m.group(2)), "tick": int(m.group(4))})
    return log


def hop_allowed(terrain, hop, bodies_all):
    """Is the logged velocity one the formulas allow, and is the body it aims at the right one? (text, ok)"""
    v = hop["v"]
    if hop["stop"]:
        return "parado", True
    if hop["aim"] == "nadie":
        horizontal = math.hypot(v[0], v[2])
        good = abs(v[1] - IDLE_RISE) < 1e-3 and horizontal <= IDLE_SPEED + 1e-3
        return "al azar: vy %.3f (%.0f), horizontal %.3f (<= %.0f)" % (v[1], IDLE_RISE, horizontal, IDLE_SPEED), good
    if hop["aim"] not in LANES:
        return "hacia un cuerpo desconocido %s" % hop["aim"], False
    pos = hop["pos"]
    near = {n: math.dist(pos, center(terrain, n)) for n in bodies_all}
    in_range = {n: d for n, d in near.items() if d <= REACH}
    closest = min(in_range, key=in_range.get) if in_range else None
    # the target goes first when it is in range
    expect = TARGET if closest is not None and TARGET in in_range else closest
    aim_center = center(terrain, hop["aim"])
    d = [aim_center[i] - pos[i] for i in range(3)]
    dist = math.sqrt(sum(c * c for c in d))
    horizontal_err = math.hypot(v[0] - HOP_SPEED * d[0] / dist, v[2] - HOP_SPEED * d[2] / dist)
    # vy: 4.5 * dy/|d| + [-0.5, 0.5] * the arc lift 0.5 * g * |d| / |v|, |v| in [4, 5], capped at 10
    low = HOP_SPEED * d[1] / dist - WOBBLE + 0.5 * G * dist / (HOP_SPEED + WOBBLE)
    high = HOP_SPEED * d[1] / dist + WOBBLE + 0.5 * G * dist / (HOP_SPEED - WOBBLE)
    low, high = min(low, MAX_RISE), min(high, MAX_RISE)
    good = expect == hop["aim"] and horizontal_err <= WOBBLE + 0.02 and low - 0.02 <= v[1] <= high + 0.02
    return "hacia %s (esperado %s), a %.2f m: error horizontal %.3f (<= %.2f), vy %.3f en [%.3f, %.3f]" % (
        hop["aim"], expect, dist, horizontal_err, WOBBLE, v[1], low, high), good


def check_shots(log, terrain, lobs, bodies, others, rest_tol):
    """The per-mite checks (hops against the replica, the stick, the stop and the release). Returns (ok, compared)."""
    ok = True
    compared = 0
    for l in lobs:
        name = l["shot"]
        hops = sorted(log["hops"].get(name, []), key=lambda h: h["tick"])
        stick = log["stick"].get(name)
        ok &= verdict(len(hops) <= MAX_JUMPS and [h["n"] for h in hops] == list(range(1, len(hops) + 1)),
                      "3. %s: %d saltos (máx %d), numerados %s" % (name, len(hops), MAX_JUMPS, [h["n"] for h in hops]))
        state = (l["tick"], l["origin"], l["v"])
        for index in range(len(hops) + 1):
            tick0, pos0, vel0 = state
            touch, hit = segment(terrain, pos0, vel0, others)
            nxt = hops[index] if index < len(hops) else None
            sticks_here = stick is not None and stick["what"] == "pega a" and (nxt is None or stick["tick"] <= nxt["tick"])
            if hit is not None and (nxt is None or hit[0] <= (touch[0] if touch else 10 ** 9)) and (sticks_here or nxt is None):
                want = tick0 + hit[0]
                good = stick is not None and stick["what"] == "pega a" and stick["body"] == hit[1] and abs(stick["tick"] - want) <= TOL_TICKS
                ok &= verdict(good, "2. %s: réplica pega a %s en el tick %d (segmento %d); puerto %s" % (
                    name, hit[1], want, index + 1, "nada" if stick is None else "%s %s en %d" % (stick["what"], stick["body"], stick["tick"])))
                compared += 1
                break
            if nxt is None:
                if hit is None and nxt is None and index == len(hops) and (not hops or not hops[-1]["stop"]):
                    if touch is None and stick is None:
                        print("....  2. %s: sigue volando o cayó fuera del mapa (sin toque ni pegada en %d ticks)" % (name, MAX_STEPS))
                break
            if touch is None:
                ok &= verdict(False, "2. %s: salto %d en el tick %d y la réplica no toca el suelo" % (name, nxt["n"], nxt["tick"]))
                break
            want = tick0 + touch[0]
            dxz = math.hypot(nxt["pos"][0] - touch[1][0], nxt["pos"][2] - touch[1][2])
            good = abs(nxt["tick"] - want) <= TOL_TICKS and dxz <= TOL_POS
            ok &= verdict(good, "2. %s: salto %d, réplica en el tick %d (%d pasos) a %.3f m del puerto; puerto en el tick %d" % (
                name, nxt["n"], want, touch[0], dxz, nxt["tick"]))
            compared += 1
            text, allowed = hop_allowed(terrain, nxt, bodies)
            ok &= verdict(allowed, "2. %s: salto %d %s" % (name, nxt["n"], text))
            if nxt["stop"]:
                break
            state = (nxt["tick"], nxt["pos"], nxt["v"])
        # 3. the 5th touch stops it and it is freed 30 ticks later (a mite that stuck is freed with its shot instead)
        if hops and hops[-1]["stop"]:
            freed = log["free"].get(name)
            ok &= verdict(freed is not None and abs(freed - (hops[-1]["tick"] + REST_TICKS)) <= rest_tol,
                          "3. %s: parado en el tick %d y liberado en %s (esperado %d ± %d)" % (
                              name, hops[-1]["tick"], freed, hops[-1]["tick"] + REST_TICKS, rest_tol))
    return ok, compared


def check_lane_n(log, terrain):
    """B1 (spent()): Blight2 throws at bare ground; every mite hops 5 times to nobody, stops on the 5th touch and is freed exactly
    30 ticks later, and the shot is gone after that (no hop and no stick after the release, one release line per shot)."""
    ok = True
    use = log["using_n"]
    ok &= verdict(use is not None and use[0] == WINDUP_TICKS, "N1. %s: usando habilidad Bilemites %d ticks: %s" % (SHOOTER_N, WINDUP_TICKS, str(use)))
    mana = log["ability"][1] if len(log["ability"]) > 1 else None
    ok &= verdict(mana is not None and mana[:2] == MANA and mana[2] == COOLDOWN, "N1. mana %d->%d, enfriamiento %d: %s" % (MANA[0], MANA[1], COOLDOWN, str(mana)))
    lobs = log["lobs_n"]
    fire = lobs[0]["tick"] if lobs else None
    t0 = use[1] if use else None
    ok &= verdict(fire is not None and t0 is not None and abs(fire - (t0 + WINDUP_TICKS)) <= TOL_TICKS,
                  "N1. los ácaros salen en el tick %s (esperado %s)" % (fire, None if t0 is None else t0 + WINDUP_TICKS))
    ok &= verdict(len(lobs) == SHOTS and all(l["tick"] == fire for l in lobs), "N1. %d velocidades en el mismo tick: %d" % (SHOTS, len(lobs)))
    ok_n, compared = check_shots(log, terrain, lobs, [], [], 0)
    ok &= ok_n
    ok &= verdict(compared >= SHOTS * (MAX_JUMPS - 1), "N2. saltos comparados con la réplica: %d (>= %d)" % (compared, SHOTS * (MAX_JUMPS - 1)))
    for l in lobs:
        name = l["shot"]
        hops = sorted(log["hops"].get(name, []), key=lambda h: h["tick"])
        ok &= verdict(len(hops) == MAX_JUMPS and hops[-1]["stop"] and all(not h["stop"] and h["aim"] == "nadie" for h in hops[:-1]),
                      "N3. %s: %d toques, los %d primeros hacia nadie y el 5.º parado" % (name, len(hops), MAX_JUMPS - 1))
        stop = hops[-1]["tick"] if hops else None
        free = log["free"].get(name)
        ok &= verdict(stop is not None and free is not None and free - stop == REST_TICKS,
                      "N3. %s: parado en %s, suelto en %s (exactamente +%d)" % (name, stop, free, REST_TICKS))
        ok &= verdict(log["suelto_lines"].count(name) == 1 and name not in log["stick"],
                      "N3. %s: una sola liberación y no se pegó a nadie" % name)
        ok &= verdict(not any(h["tick"] > (free or 10 ** 9) for h in hops), "N3. %s: ningún salto después de la liberación (el disparo desapareció)" % name)
    ok &= verdict(not any(b[0] != "ok" for b in log["bench_n"]) and bool(log["bench_n"]), "N1. %s: el bench no la rechazó: %s" % (SHOOTER_N, str(log["bench_n"])))
    return ok


def check_log(path):
    log = read_log(path)
    terrain = base.Terrain.load()
    ok = True
    use = log["using"]
    ok &= verdict(use is not None and use[0] == WINDUP_TICKS, "1. usando habilidad Bilemites %d ticks: %s" % (WINDUP_TICKS, str(use)))
    ok &= verdict(len(log["ability"]) == 2, "1. dos usos, uno por Blight (%d líneas de maná)" % len(log["ability"]))
    mana = log["ability"][0] if log["ability"] else None
    ok &= verdict(mana is not None and mana[:2] == MANA, "1. mana %d->%d: %s" % (MANA[0], MANA[1], str(mana[:2] if mana else "nada")))
    ok &= verdict(mana is not None and mana[2] == COOLDOWN, "1. enfriamiento %d ticks: %s" % (COOLDOWN, str(mana[2] if mana else "nada")))
    lobs = log["lobs"]
    t0 = use[1] if use else None
    fire = lobs[0]["tick"] if lobs else None
    ok &= verdict(fire is not None and t0 is not None and abs(fire - (t0 + WINDUP_TICKS)) <= TOL_TICKS,
                  "1. los ácaros salen en el tick %s (esperado %s = T + %d, ± %d)" % (fire, None if t0 is None else t0 + WINDUP_TICKS, WINDUP_TICKS, TOL_TICKS))
    ok &= verdict(len(lobs) == SHOTS and all(l["tick"] == fire for l in lobs), "1. %d velocidades en el mismo tick: %d" % (SHOTS, len(lobs)))
    ok_m, compared = check_shots(log, terrain, lobs, list(LANES), [n for n in LANES if n != SHOOTER], TOL_TICKS)  # the shooter is never hit (declared)
    ok &= ok_m
    ok &= check_lane_n(log, terrain)
    ok &= verdict(compared > 0, "2. al menos un salto o una pegada comparados: %d" % compared)
    ok &= verdict(not any(s["body"] == SHOOTER for s in log["stick"].values()), "2. el Blight no recibe ninguno")
    # 4. speed_factor = 0.8 ^ n for every body; the ally can be reached
    for body, stuck in log["stuck"].items():
        for s in stuck:
            ok &= verdict(abs(s["factor"] - FACTOR ** s["n"]) < 1e-3, "4. %s n=%d: factor %.4f = 0.8^%d" % (body, s["n"], s["factor"], s["n"]))
    for body, list_ in log["pace"].items():
        for s in list_:
            n = round(math.log(s["factor"]) / math.log(FACTOR)) if s["factor"] > 0 else 0
            ok &= verdict(abs(s["factor"] - FACTOR ** n) < 1e-3, "4. ritmo %s x%.4f en el tick %d = 0.8^%d" % (body, s["factor"], s["tick"], n))
    print("....  4. mites pegados por cuerpo: %s (Druid3 es el aliado: lo pueden alcanzar)" % {b: len(s) for b, s in sorted(log["stuck"].items())})
    # 5. every piece lets go 481 ticks after it stuck; the factor goes back to 1
    for body, stuck in log["stuck"].items():
        ok &= verdict(all(s["until"] - s["tick"] == HOLD_TICKS for s in stuck), "5. %s: cada ácaro hasta +%d" % (body, HOLD_TICKS))
        wants = sorted(s["tick"] + HOLD_TICKS for s in stuck)
        gots = []
        for r in log["released"].get(body, []):
            gots.extend([r["tick"]] * (r["from"] - r["to"]))
        gots.sort()
        good = len(gots) == len(wants) and all(abs(a - b) <= TOL_TICKS for a, b in zip(gots, wants))
        ok &= verdict(good, "5. %s: soltados en %s (esperado %s ± %d)" % (body, gots[:12], wants[:12], TOL_TICKS))
        last = log["pace"].get(body, [])
        ok &= verdict(bool(last) and abs(last[-1]["factor"] - 1.0) < 1e-6 and (not wants or abs(last[-1]["tick"] - max(wants)) <= TOL_TICKS),
                      "5. %s: el factor vuelve a 1,0 en el tick %s (esperado %s)" % (body, last[-1]["tick"] if last else None, max(wants) if wants else None))
    print("(look de los ácaros que saltan y de los pegados: capturas del playtester)")
    return ok


def schedule():
    print("T = tick de la orden (0,5 s = 30). Preparación %d ticks; ácaros en T+%d; enfriamiento %d; cada ácaro se suelta a +%d de pegarse." % (
        WINDUP_TICKS, WINDUP_TICKS, COOLDOWN, HOLD_TICKS))
    print("Un ácaro hace como mucho %d saltos; el %dº lo para y se libera a +%d. Velocidad x 0,8^n: n=1..%d -> %s" % (
        MAX_JUMPS, MAX_JUMPS, REST_TICKS, SHOTS, ", ".join("%.3f" % (FACTOR ** n) for n in range(1, SHOTS + 1))))


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
