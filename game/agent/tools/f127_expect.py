#!/usr/bin/env python3
"""F127 (RFC-030 030p-a): what sacengine would do with the Rhinok's Halo of Earth (HRba) on lane C of
debug/f127_halo_breath, replicated from state.d and the SPEL data, next to what the port logged.

Usage: python3 -I agent/tools/f127_expect.py [godot log of debug/f127_halo_breath or the f127 bench case]
       python3 -I agent/tools/f127_expect.py --lanes     (only the lane check against the map caches)
       python3 -I agent/tools/f127_expect.py --chase px py pz cx cy cz [hx hy hz]
                                                         (one rock's chase from a point to a still center, with the target's half box)

Needs the bench switch on (debug/ai_match.gd): HaloOfEarth.log_halo (and AbilityEffect.log_effects is not needed).

sacengine:
- useAbility → haloOfEarth (13232-13236): applies at once; apply() drains the mana (Rhinok 750, HRba 650: 750->100) and
  sets the cooldown (40 s = 2400 ticks) in the same frame.
- updateHaloOfEarth (19284-19321), from the next tick (T+1): while the Rhinok can carry it, all 6 rocks are made at once
  (makeHaloRock, 19128-19148: a point of the Rhinok's box x1.25 (isAbility), z = land − 0.25). In that same tick each
  free rock, in order, updates and then looks for a target (closestNonAllyInRange, 28825): the closest non-ally
  creature within effectRange 50 m, valid, in sight, that no other rock chases.
- updateHaloRock, with a target (19229-19251): distance = target center − position (before the step); velocity +=
  distance.normalized * 3 (SPEL acceleration), cap 30 (SPEL speed), cap 60 * distance; position += velocity / 60; if
  that distance was under 0.25 it blows up on the target. Then (19253-19269) the 0.7 box meets a body not of its side
  → it blows up on that body; from frame 35 on the land; at frame 2100 (duration 35 s).
- haloRockExplosion (19076-19100): dealSpellDamage(target, 600) = direct spell damage: 600 * direct_spell resistance,
  capped at the body's life. Druid (800, 1.0): 600, then 200 (it dies). Trogg (960, 0.0): 0.
Lane C (anchor 1270, 1270): R Rhinok1 -45/+15 (slot 1, uses the ability at T); C4 Trogg1 -37/+15 (ally); C1 Druid1 -25/+15
(enemy); C2 Trogg2 -20/+10 (enemy, immune to spells); C3 Druid2 +20/+15 (enemy, 65 m: out of the 50 m).
Expected: rocks 0 -> Druid1 and 1 -> Trogg2 on T+1; 2 hits on Druid1 (600, 200), 4 on Trogg2 (0); Trogg1 and Druid2 never
a target; all 6 blow up and the node frees itself before T+600.
Log lines (HaloOfEarth.log_halo):
  habilidad Halo Of Earth mana 750->100                                            (ActiveAbility)
  halo Rhinok1 usa tick N nacen 6 en tick M caja (x, y, z) a (x, y, z) x1.25 centro (x, y, z)
  halo Rhinok1 roca K nace en (x, y, z) (tick M)
  halo Rhinok1 roca K blanco Druid1 a D m desde (x, y, z) hacia (x, y, z) caja (hx, hy, hz) (tick N)
  halo Rhinok1 roca K explota por choque|llegada|suelo|vida|despawn en (x, y, z) con Druid1 (tick N)
  dano Druid1 600 vida 200
  halo Rhinok1 fin (tick N)
The chase is replayed from the point and the center the target line logs (a pacifist target does not move): the tick of
each blow-up is the line's tick + n, within TOL_TICKS (the port's box is a capsule, the replica's an AABB).
Port axes: x, y up, z; the original's z is the port's y.
"""
import json
import math
import os
import re
import struct
import sys

T = 60
ANCHOR = (1270.0, 1270.0)
ACCEL = 3.0
SPEED = 30.0
ARRIVE = 0.25
ROCK_HALF = 0.35
DAMAGE = 600.0
RANGE = 50.0
LIFE_TICKS = 2100
GROUND_GRACE = 35
NUM_ROCKS = 6
BURY = 0.25
MANA = (750, 100)
COOLDOWN_TICKS = 40 * T
END_BEFORE = 600
TOL_TICKS = 1
BOX_TOL_M = 0.05
GROUND_TOL_M = 0.35
CLEAR_STRUCTURE_M = 15.0
CLEAR_WIDGET_M = 6.0
LANES = {
    "Rhinok1": (-45.0, 15.0, 1),
    "Trogg1": (-37.0, 15.0, 1),
    "Druid1": (-25.0, 15.0, 2),
    "Trogg2": (-20.0, 10.0, 2),
    "Druid2": (20.0, 15.0, 2),
}
EXPECTED_TARGETS = {0: "Druid1", 1: "Trogg2"}
NEVER_TARGET = ("Trogg1", "Druid2")
REGEN_SLACK = 60
EXPECTED_HITS = {"Druid1": [600, 200], "Trogg2": [0, 0, 0, 0]}
NUM = r"(-?\d+(?:\.\d+)?)"
VEC = r"\(" + NUM + r", " + NUM + r", " + NUM + r"\)"


def map_file(name):
    """A High Noon map file from assets/original/maps/high_noon/ (RFC-033, 033f)."""
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "original", "maps", "high_noon", name)


def data_file(name):
    """A game data file from assets/original/data/ (RFC-033, 033g)."""
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "original", "data", name)


def cache(name):
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(here, "..", "..", "cache", name)


def load_terrain():
    """HNTR v1 (tools/export_high_noon_terrain.py, scenes/world/terrain.gd): vertices, indices."""
    try:
        raw = open(cache("high_noon_terrain.bin"), "rb").read()
    except OSError:
        return None
    if raw[:4] != b"HNTR":
        return None
    vc, ic = struct.unpack_from("<II", raw, 10)
    off = 18
    verts = [struct.unpack_from("<fff", raw, off + 12 * i) for i in range(vc)]
    off += 24 * vc
    return verts, struct.unpack_from("<%dI" % ic, raw, off)


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


def segment_distance(p, a, b):
    """Distance from the point p to the segment a-b, all (x, z)."""
    abx, abz = b[0] - a[0], b[1] - a[1]
    length2 = abx * abx + abz * abz
    t = 0.0 if length2 == 0 else max(0.0, min(1.0, ((p[0] - a[0]) * abx + (p[1] - a[1]) * abz) / length2))
    return math.hypot(p[0] - (a[0] + t * abx), p[1] - (a[1] + t * abz))


def check_lanes():
    """Land under every body and along the lane (no hole), no structure within 15 m of a body or of a flight, no widget
    (rocks and props of the map) within 6 m, and the radius: Druid1 and Trogg2 inside 50 m of the Rhinok, Druid2 outside."""
    ok = True
    terrain = load_terrain()
    try:
        ntts = json.load(open(map_file("ntts.json"), encoding="utf-8"))
        widgets = json.load(open(map_file("widgets.json"), encoding="utf-8"))
    except OSError:
        ntts, widgets = {"structures": []}, {}
    structures = ntts.get("structures", [])
    rhinok = world("Rhinok1")
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
    # The flights: the segments from the Rhinok to each body, and the strip they cover, over the land and clear of structures.
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
    for name in ("Druid1", "Trogg2"):
        dists = [(s["tag"], round(segment_distance((s["x"], s["z"]), rhinok, world(name)), 1)) for s in structures
                 if segment_distance((s["x"], s["z"]), rhinok, world(name)) < CLEAR_STRUCTURE_M]
        ok = ok and not dists
        print("vuelo Rhinok1 -> %s: estructuras a menos de %d m del trayecto %s %s" % (name, CLEAR_STRUCTURE_M, dists, "MAL" if dists else "ok"))
    for name, want_in in (("Druid1", True), ("Trogg2", True), ("Druid2", False)):
        d = flat("Rhinok1", name)
        good = (d <= RANGE) == want_in
        ok = ok and good
        print("Rhinok1 -> %s: %.2f m en planta (radio %.0f) %s" % (name, d, RANGE, "ok" if good else "MAL"))
    return ok


def chase(start, center, half=(0.0, 0.0, 0.0), accel=ACCEL, speed=SPEED, limit=LIFE_TICKS):
    """One rock chasing a still center from rest: (n, kind, position) of the first blow-up, n = ticks after the one
    that fixed the target. kind: llegada (distance under 0.25 before the step) or choque (its 0.7 box meets the target's)."""
    p = list(start)
    v = [0.0, 0.0, 0.0]
    for n in range(1, limit):
        d = [center[i] - p[i] for i in range(3)]
        dl = math.sqrt(sum(c * c for c in d))
        if dl > 0.0:
            v = [v[i] + d[i] / dl * accel for i in range(3)]
        vl = math.sqrt(sum(c * c for c in v))
        if vl > speed:
            v = [c / vl * speed for c in v]
            vl = speed
        if vl > T * dl:
            v = [c / vl * dl * T for c in v] if vl > 0 else v
        p = [p[i] + v[i] / T for i in range(3)]
        if dl < ARRIVE:
            return n, "llegada", tuple(p)
        if all(abs(p[i] - center[i]) <= ROCK_HALF + half[i] for i in range(3)):
            return n, "choque", tuple(p)
    return None


def resistances():
    try:
        data = json.load(open(data_file("creatures.json"), encoding="utf-8"))
    except OSError:
        return {}
    items = data if isinstance(data, list) else list(data.values())
    return {c.get("name", ""): c.get("resistances", {}) for c in items if isinstance(c, dict)}


def kind_of(name):
    return re.sub(r"\d+$", "", name)


def vec(m, i):
    return tuple(float(m.group(i + k)) for k in range(3))


def read_log(path):
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    out = dict(ability=[], use=None, box=None, born={}, fixes={}, blows=[], hits=[], end=None)
    pending = None
    for line in lines:
        m = re.search(r"habilidad (.+?) mana (\d+)->(\d+)", line)
        if m:
            out["ability"].append((m.group(1), int(m.group(2)), int(m.group(3))))
            continue
        m = re.search(r"halo (\S+) usa tick (\d+) nacen (\d+) en tick (\d+) caja " + VEC + r" a " + VEC + r" x" + NUM + r" centro " + VEC, line)
        if m:
            out["use"] = dict(who=m.group(1), used=int(m.group(2)), count=int(m.group(3)), tick=int(m.group(4)),
                              low=vec(m, 5), high=vec(m, 8), scale=float(m.group(11)), center=vec(m, 12))
            continue
        m = re.search(r"halo (\S+) roca (\d+) nace en " + VEC + r" \(tick (\d+)\)", line)
        if m:
            out["born"][int(m.group(2))] = dict(at=vec(m, 3), tick=int(m.group(6)))
            continue
        m = re.search(r"halo (\S+) roca (\d+) blanco (\S+) a " + NUM + r" m desde " + VEC + r" hacia " + VEC + r" caja " + VEC + r" \(tick (\d+)\)", line)
        if m:
            out["fixes"][int(m.group(2))] = dict(target=m.group(3), distance=float(m.group(4)), start=vec(m, 5),
                                                  center=vec(m, 8), half=vec(m, 11), tick=int(m.group(14)))
            continue
        m = re.search(r"halo (\S+) roca (\d+) explota por (\S+) en " + VEC + r" con (.+) \(tick (\d+)\)", line)
        if m:
            blow = dict(rock=int(m.group(2)), why=m.group(3), at=vec(m, 4), who=m.group(7), tick=int(m.group(8)))
            out["blows"].append(blow)
            pending = blow
            continue
        m = re.search(r"dano (\S+) (\d+) vida (\d+)", line)
        if m and pending and pending["who"] == m.group(1):
            pending["damage"] = int(m.group(2))
            pending["life"] = int(m.group(3))
            pending = None
            continue
        m = re.search(r"halo (\S+) fin \(tick (\d+)\)", line)
        if m:
            out["end"] = int(m.group(2))
    return out


def verdict(ok, text):
    print("%s  %s" % ("PASS" if ok else "FAIL", text))
    return ok


def check_log(path):
    log = read_log(path)
    ok = True
    use = log["use"]
    if use is None:
        return verdict(False, "no hay `halo … usa tick …`: el Halo of Earth no se usó")
    t = use["used"]
    print("T = tick %d (uso), rocas en el tick %d" % (t, use["tick"]))
    # 1. mana and cooldown.
    halo = [a for a in log["ability"] if a[0] == "Halo Of Earth"]
    ok &= verdict(bool(halo) and halo[0][1:] == MANA, "1. habilidad Halo Of Earth mana 750->100: %s" % str(halo[0][1:] if halo else "nada"))
    try:
        abilities = json.load(open(data_file("abilities.json"), encoding="utf-8"))
        cooldown = round(float(abilities["HRba"]["cooldown_s"]) * T)
        ok &= verdict(cooldown == COOLDOWN_TICKS, "1. enfriamiento HRba en abilities.json: %d ticks (esperado %d)" % (cooldown, COOLDOWN_TICKS))
    except (OSError, KeyError):
        ok &= verdict(False, "1. no se pudo leer HRba de assets/original/data/abilities.json")
    # 2. the 6 rocks on T+1, inside the box, buried; rock 0 -> Druid1 and 1 -> Trogg2 in that same tick.
    terrain = load_terrain()
    ok &= verdict(use["tick"] == t + 1 and use["count"] == NUM_ROCKS, "2a. nacen %d rocas en el tick %d (esperado %d en T+1 = %d)" % (
        use["count"], use["tick"], NUM_ROCKS, t + 1))
    ok &= verdict(abs(use["scale"] - 1.25) < 1e-6, "2b. caja x%.2f (esperado 1,25)" % use["scale"])
    ok &= verdict(sorted(log["born"]) == list(range(NUM_ROCKS)), "2c. rocas que nacen: %s" % sorted(log["born"]))
    for k, rock in sorted(log["born"].items()):
        x, y, z = rock["at"]
        inside = use["low"][0] - 1e-3 <= x <= use["high"][0] + 1e-3 and use["low"][2] - 1e-3 <= z <= use["high"][2] + 1e-3
        land = ground(terrain, x, z) if terrain else None
        buried = land is None or abs(y - (land - BURY)) <= GROUND_TOL_M
        ok &= verdict(inside and buried and rock["tick"] == use["tick"],
                      "2d. roca %d nace en (%.2f, %.2f, %.2f) tick %d: dentro de la caja %s, enterrada %s (suelo %s)" % (
                          k, x, y, z, rock["tick"], "sí" if inside else "NO", "sí" if buried else "NO", "?" if land is None else "%.2f" % land))
    for k, want in EXPECTED_TARGETS.items():
        fix = log["fixes"].get(k)
        ok &= verdict(fix is not None and fix["target"] == want and fix["tick"] == use["tick"],
                      "2e. roca %d -> %s en el tick %d: %s" % (k, want, use["tick"], "nada" if fix is None else "%s en el tick %d" % (fix["target"], fix["tick"])))
    never = [f["target"] for f in log["fixes"].values() if f["target"] in NEVER_TARGET]
    ok &= verdict(not never, "4c. %s nunca son blanco: %s" % (", ".join(NEVER_TARGET), never or "ninguno"))
    # 3. the tick of each blow-up against the replayed chase.
    for blow in sorted(log["blows"], key=lambda b: (b["tick"], b["rock"])):
        fix = log["fixes"].get(blow["rock"])
        if fix is None:
            ok &= verdict(blow["why"] in ("despawn", "vida"), "3. roca %d explota por %s sin blanco (tick %d)" % (blow["rock"], blow["why"], blow["tick"]))
            continue
        replay = chase(fix["start"], fix["center"], fix["half"])
        if replay is None:
            ok &= verdict(False, "3. roca %d: la réplica no llega al blanco" % blow["rock"])
            continue
        n, kind, _ = replay
        want_tick = fix["tick"] + n
        same = abs(blow["tick"] - want_tick) <= TOL_TICKS and blow["why"] == kind and blow["who"] == fix["target"]
        ok &= verdict(same, "3. roca %d -> %s: explota por %s con %s en el tick %d (réplica: %s en %d = tick del blanco %d + %d)" % (
            blow["rock"], fix["target"], blow["why"], blow["who"], blow["tick"], kind, want_tick, fix["tick"], n))
    # 4. damage per target, in order: Druid1 600 then 200 (dies), Trogg2 four of 0.
    res = resistances()
    for name, want in EXPECTED_HITS.items():
        got = [b for b in sorted(log["blows"], key=lambda b: (b["tick"], b["rock"])) if b["who"] == name and "damage" in b]
        resistance = float(res.get(kind_of(name), {}).get("direct_spell", 1.0))
        life = {"Druid1": 800, "Trogg2": 960}[name]
        derived = []
        for _ in want:
            take = min(life, round(DAMAGE * resistance))
            derived.append(take)
            life -= take
        # The killing hit takes the life left, and the body regenerates between rocks (Druid1: 52 ticks, +11 life): the replica
        # does not model regeneration, so a hit that kills (life 0) may take up to REGEN_SLACK more than the replica's cap.
        close = len(got) == len(want) == len(derived) and all(
            b["damage"] == w or (b.get("life") == 0 and w <= b["damage"] <= w + REGEN_SLACK) for b, w in zip(got, want))
        ok &= verdict(close and want == derived,
                      "4. %s recibe %s (réplica %s): port %s" % (name, want, derived, [(b["damage"], b["life"]) for b in got]))
    dead = [b for b in log["blows"] if b["who"] == "Druid1" and b.get("life") == 0]
    ok &= verdict(len(dead) == 1, "4b. Druid1 muere con la segunda roca: %s" % ("sí" if dead else "no"))
    # 5. everything blown up and the coordinator freed before T+600.
    ok &= verdict(len(log["blows"]) == NUM_ROCKS, "5a. explotan %d rocas (esperado %d)" % (len(log["blows"]), NUM_ROCKS))
    ok &= verdict(log["end"] is not None and log["end"] < t + END_BEFORE, "5b. fin del coordinador en el tick %s (antes de T+%d = %d)" % (
        log["end"], END_BEFORE, t + END_BEFORE))
    return ok


def main():
    args = sys.argv[1:]
    if args and args[0] == "--chase":
        v = [float(a) for a in args[1:]]
        if len(v) not in (6, 9):
            print(__doc__)
            sys.exit(2)
        result = chase(v[0:3], v[3:6], v[6:9] if len(v) == 9 else (0.0, 0.0, 0.0))
        print("ticks, causa, posición:", result)
        return
    ok = check_lanes()
    if args and args[0] != "--lanes":
        ok = check_log(args[0]) and ok
    print("RESULTADO %s" % ("PASS" if ok else "FAIL"))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
