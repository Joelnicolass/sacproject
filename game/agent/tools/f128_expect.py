#!/usr/bin/env python3
"""F128 (RFC-030 030q-a): what sacengine would do with the Gremlin's Web pull (psla) on lane Q of debug/f128_pull,
replicated from state.d and the SPEL data, next to what the port logged. F154 (Cage pull) is the same mechanic with
other numbers: agent/tools/f154_expect.py loads this module and calls check_log(path, "cage").

Usage: python3 -I agent/tools/f128_expect.py [godot log of debug/f128_pull (rules debug/rules/f128_pull.tres)]
       python3 -I agent/tools/f128_expect.py --lanes     (only the lane check against the map files)
       python3 -I agent/tools/f128_expect.py --schedule  (the tick table of a pull, no log)

Needs the bench switch on (debug/ai_match.gd): Pulling.log_pull.

sacengine:
- useAbility → shoot (13470-13493): startUsingAbility with shoot1 (LSs1, 82 frames; the SPEL has no lrba, the load tick
  `liba` is frame 27, not exported): the body prepares 2 * 27 = 54 ticks. At the load tick loadOnTick (12592-12605) calls
  webPull and drains the mana (Gremlin 300, psla 60: 300->240). The case returns at 12738-12739 before the cooldown is
  set: Web pull has none (R2).
- abilityStatus / isApplicable (sacspell.d:43-66, 171): a creature or a wizard that is not an ally; crowdControl refuses
  it when it is shielded (Life Shield); out of the SPEL's 50 m it is «Fuera de alcance». A rejection spends nothing.
- pull (13166-13175): a ray from the shot position to the target's center; the first valid body on the way, of any side,
  is the target. startPulling (10108-10113): mode pulling, orders cleared.
- updatePull (25434-25519), one update per tick from the next one (frame 1, 2, …): nothing is checked while frame < 20.
  The clip loops (82 frames = 164 ticks) and has a pull at its last frame (81, tick 162 of the clip): T+162, T+326, T+490,
  T+654 (T = the tick of the order; the clip starts there). At each pull: stunWithCooldown(480) (only the first stuns:
  the cooldown runs), catapult(v) with v = -16.5 * thread/|thread| + (0, 0.8175, 0) (0.8175 = 5 * 9.81 / 60), pullFrames = 25.
  Next 24 ticks: a tumbling target takes v = -16.5 * threadDir; one on the ground is pushed by v / 60 (0.275 m per tick).
  An extra pull when a tumbling target goes away: dist > 1.05 * radius and dot(threadDir, fallingVelocity) > 1.5, or it
  goes backwards faster than 0.2 * vz.
- It ends (animateWebPullBreaking, 64 particles) when numPulls >= 1 and the box of the target is within 3 m of the user's
  center with pullFrames <= 0 or thread.y >= -1.5; or numPulls >= 4 and the clip is at its last frame (frame + 1 >= 164);
  or the user is no longer pulling; or the target is no longer valid.
Lane Q (anchor 1270, 1270): G Gremlin1 -40/+15 (slot 1, facing +x); Q1 Druid1 -9/+15 (slot 2, 31 m); Q2 Druid2 -50/+15
(slot 1, ally); Q3 Druid3 -40/+5 (slot 2, Life Shield at 0.1 s); Q4 Druid4 +20/+15 (slot 2, 60 m). The ability aims at Q2
at 0.3 s, Q3 at 0.35 s, Q4 at 0.4 s and Q1 at 0.5 s (T = tick 30).
Log lines (Pulling.log_pull):
  bench: Gremlin1 usa la habilidad: rechazada, Blanco inválido (tick 18)
  usando habilidad Web pull Gremlin1 54 ticks (tick T)                              (ActiveAbility)
  habilidad Web pull mana 300->240 enfriamiento 0 ticks                             (ActiveAbility)
  tirón Gremlin1 → Druid1 inicio blanco a D m (tick T+54)
  paso Gremlin1 → Druid1 centro (x, y, z) hilo y Y caja B ventana W accion nada|ventana|tirón (tick N)   (every tick from the
                                                                                    first pull)
  tirón K Gremlin1 → Druid1 v (vx, vy, vz) hilo (x, y, z) aturde sí|no (tick N)
  tirón fin Gremlin1 → Druid1 por <razón> tirones K caja B hilo y Y ventana W bit 0 centro (x, y, z) (tick N)
The checks work from the geometry the port logs (centers, box distance): the replica is the rule, not a copy of the
physics of the body. Port axes: x, y up, z; the original's z is the port's y.
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
WINDUP_TICKS = 54
FRAME_TICKS = 2
PULL_SPEED = 16.5
FALL_ACCEL = 9.81
LIFT_Y = 5.0 * FALL_ACCEL / T
PULL_WINDOW = 25
MIN_THREAD = 3.0
MAX_PULLS = 4
SHOOT_FRAMES = 20
MANA = (300, 240)
RANGE = 50.0
TOL_TICKS = 1
TOL_M = 0.05
TOL_V = 0.01
TOL_STEP = 0.01
CLEAR_STRUCTURE_M = 11.0
CLEAR_WIDGET_M = 6.0
REST_M = 0.02
FLAT_MIN, FLAT_MAX = 10.21, 10.55
NUM = r"(-?\d+(?:\.\d+)?)"
VEC = r"\(" + NUM + r", " + NUM + r", " + NUM + r"\)"

KINDS = {
    "web": {
        "ability": "Web pull", "user": "Gremlin1", "target": "Druid1", "frames": 82,
        "uses": 2, "ends_by": "cerca", "bench": {"Blanco inválido": [18, 21], "Fuera de alcance": [24], "ok": [30]},
    },
    "cage": {
        "ability": "Cage pull", "user": "Seraph1", "target": "Druid5", "frames": 102,
        "uses": 1, "ends_by": "4 tirones", "bench": {"ok": [30]},
    },
}

# name -> (dx, dz, slot, kind) from the anchor
LANES = {
    "Gremlin1": (-40.0, 15.0, 1, "web"),
    "Druid1": (-9.0, 15.0, 2, "web"),
    "Druid2": (-50.0, 15.0, 1, "web"),
    "Druid3": (-40.0, 5.0, 2, "web"),
    "Druid4": (20.0, 15.0, 2, "web"),
    "Seraph1": (-170.0, 240.0, 1, "cage"),
    "Druid5": (-212.0, 240.0, 2, "cage"),
    "Gremlin2": (200.0, 320.0, 1, "stone"),
    "Druid6": (218.0, 320.0, 2, "stone"),
    "Basilisk1": (218.0, 312.0, 1, "stone"),
}
RANGES = {("Gremlin1", "Druid1"): 31.0, ("Gremlin1", "Druid2"): 10.0, ("Gremlin1", "Druid3"): 10.0,
          ("Gremlin1", "Druid4"): 60.0, ("Seraph1", "Druid5"): 42.0, ("Gremlin2", "Druid6"): 18.0}


def map_file(name):
    """A High Noon map file from assets/original/maps/high_noon/ (RFC-033, 033f)."""
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "original", "maps", "high_noon", name)



class Terrain:
    """terrain.res: vertices, indices; a 10 m grid of triangles."""
    CELL = 10.0

    def __init__(self, verts, idx):
        self.verts = verts
        self.tris = [(verts[idx[i]], verts[idx[i + 1]], verts[idx[i + 2]]) for i in range(0, len(idx), 3)]
        self.grid = {}
        for n, (a, b, c) in enumerate(self.tris):
            x0, x1 = int(min(a[0], b[0], c[0]) // self.CELL), int(max(a[0], b[0], c[0]) // self.CELL)
            z0, z1 = int(min(a[2], b[2], c[2]) // self.CELL), int(max(a[2], b[2], c[2]) // self.CELL)
            for gx in range(x0, x1 + 1):
                for gz in range(z0, z1 + 1):
                    self.grid.setdefault((gx, gz), []).append(n)

    @staticmethod
    def load():
        loaded = terrain_asset.load()
        if loaded is None:
            return None
        return Terrain(*loaded)

    def ground(self, x, z):
        """Land height under (x, z), None over a hole."""
        best = None
        for n in self.grid.get((int(x // self.CELL), int(z // self.CELL)), ()):
            a, b, c = self.tris[n]
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
    dx, dz, _, _ = LANES[name]
    return ANCHOR[0] + dx, ANCHOR[1] + dz


def flat(a, b):
    ax, az = world(a)
    bx, bz = world(b)
    return math.hypot(ax - bx, az - bz)


def segment_distance(p, a, b):
    """Distance of the point p to the segment a-b (all (x, z))."""
    abx, abz = b[0] - a[0], b[1] - a[1]
    n = abx * abx + abz * abz
    t = 0.0 if n == 0 else max(0.0, min(1.0, ((p[0] - a[0]) * abx + (p[1] - a[1]) * abz) / n))
    return math.hypot(p[0] - (a[0] + t * abx), p[1] - (a[1] + t * abz))


def check_lanes():
    """Land under every body and along both lanes (no hole), flat ground (10.21-10.55 m), no structure within 11 m of a body
    (the huts of the map stand at 12 to 22 m), no widget within 6 m, the ranges (Druid1 and Druid3 inside the 50 m of the
    SPEL, Druid4 outside, Druid2 an ally) and no third body within 1 m of the ray of a pull (so the bounce ray keeps its
    target)."""
    ok = True
    terrain = Terrain.load()
    try:
        ntts = json.load(open(map_file("ntts.json"), encoding="utf-8"))
        widgets = json.load(open(map_file("widgets.json"), encoding="utf-8"))
    except OSError:
        ntts, widgets = {"structures": []}, {}
    structures = ntts.get("structures", [])
    heights = []
    for name in LANES:
        x, z = world(name)
        y = terrain.ground(x, z) if terrain else None
        near = [(s["tag"], round(math.hypot(s["x"] - x, s["z"] - z), 1)) for s in structures
                if math.hypot(s["x"] - x, s["z"] - z) < CLEAR_STRUCTURE_M]
        props = [k for k, ps in widgets.items() for p in ps if math.hypot(p[0] - x, p[1] - z) < CLEAR_WIDGET_M]
        bad = (terrain is not None and y is None) or near or props
        if y is not None:
            heights.append(y)
        ok = ok and not bad
        print("carril %-8s (%.1f, %.1f) suelo %s estructuras<%d %s widgets<%d %s %s" % (
            name, x, z, "?" if y is None else "%.2f" % y, CLEAR_STRUCTURE_M, near, CLEAR_WIDGET_M, props, "MAL" if bad else "ok"))
    holes = 0
    cells = 0
    if terrain:
        for lane, names in (("Q", [n for n in LANES if LANES[n][3] == "web"]), ("C", [n for n in LANES if LANES[n][3] == "cage"]),
                            ("R", [n for n in LANES if LANES[n][3] == "stone"])):
            xs = [world(n)[0] for n in names]
            zs = [world(n)[1] for n in names]
            x = min(xs) - 5.0
            while x <= max(xs) + 5.0:
                z = min(zs) - 5.0
                while z <= max(zs) + 5.0:
                    cells += 1
                    y = terrain.ground(x, z)
                    if y is None:
                        holes += 1
                    else:
                        heights.append(y)
                    z += 2.5
                x += 2.5
    ok = ok and holes == 0
    print("huecos en los carriles (%d puntos cada 2,5 m): %d %s" % (cells, holes, "ok" if holes == 0 else "MAL"))
    if terrain:
        q = [terrain.ground(x, ANCHOR[1] + 15.0) for x in range(1225, 1267)]
        c = [terrain.ground(x, ANCHOR[1] + 240.0) for x in range(1050, 1101)]
        good = None not in q and max(abs(q[i + 1] - q[i]) for i in range(len(q) - 1)) <= 0.1
        ok = ok and good
        print("camino del tirón Q (x 1225 a 1266, z %.0f): suelo %.2f a %.2f m (plano esperado %.2f a %.2f) %s" % (
            ANCHOR[1] + 15.0, min(q), max(q), FLAT_MIN, FLAT_MAX, "ok" if good else "MAL"))
        slope = max(abs(c[i + 1] - c[i]) for i in range(len(c) - 1)) if None not in c else float("nan")
        good = None not in c and slope <= 0.06
        ok = ok and good
        print("camino del tirón C (x 1050 a 1100, z %.0f): suelo %.2f a %.2f m, pendiente máxima %.3f m por m (f154_expect usa el suelo real) %s" % (
            ANCHOR[1] + 240.0, min(c), max(c), slope, "ok" if good else "MAL"))
    for (user, name), want in RANGES.items():
        d = flat(user, name)
        inside = d <= RANGE
        want_in = name != "Druid4"
        good = abs(d - want) < 0.01 and inside == want_in
        ok = ok and good
        print("%s -> %s: %.2f m en planta (alcance %.0f, %s) %s" % (
            user, name, d, RANGE, "dentro" if want_in else "fuera", "ok" if good else "MAL"))
    for user, name in (("Gremlin1", "Druid1"), ("Seraph1", "Druid5"), ("Gremlin2", "Druid6")):
        a, b = world(user), world(name)
        others = [(o, round(segment_distance(world(o), a, b), 1)) for o in LANES
                  if o not in (user, name) and segment_distance(world(o), a, b) < 1.0]
        good = not others
        ok = ok and good
        print("rayo %s -> %s sin terceros a menos de 1 m: %s %s" % (user, name, others, "ok" if good else "MAL"))
    return ok


def schedule(kind):
    """Ticks (relative to T, the tick of the order) of the load, the pulls and the end by 4 pulls."""
    k = KINDS[kind]
    loop = FRAME_TICKS * k["frames"]
    first = FRAME_TICKS * (k["frames"] - 1)
    pulls = [first + loop * i for i in range(MAX_PULLS)]
    return {"load": WINDUP_TICKS, "loop": loop, "pulls": pulls, "end_clip": pulls[-1] + 1}


def verdict(ok, text):
    print("%s  %s" % ("PASS" if ok else "FAIL", text))
    return ok


def read_log(path, kind):
    k = KINDS[kind]
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    log = {"bench": [], "using": None, "ability": [], "start": None, "pulls": [], "steps": [], "end": None, "bounce": None}
    who = re.escape(k["user"])
    for line in lines:
        m = re.search(r"bench: (\S+) usa la habilidad: (?:rechazada, )?(.+?) \(tick (\d+)\)", line)
        if m and m.group(1) == k["user"]:
            log["bench"].append((m.group(2), int(m.group(3))))
        m = re.search(re.escape(k["ability"]) + r" " + who + r" (\d+) ticks(?: \(tick (\d+)\))?", line)
        if m and line.startswith("usando habilidad") and log["using"] is None:
            log["using"] = (int(m.group(1)), int(m.group(2) or -1))
        m = re.search(r"habilidad " + re.escape(k["ability"]) + r" mana (\d+)->(\d+)(?: enfriamiento (\d+) ticks)?", line)
        if m:
            log["ability"].append((int(m.group(1)), int(m.group(2)), int(m.group(3) or -1)))
        m = re.search(r"tirón " + who + r" → (\S+) inicio blanco a " + NUM + r" m \(tick (\d+)\)", line)
        if m and log["start"] is None:
            log["start"] = (m.group(1), float(m.group(2)), int(m.group(3)))
        m = re.search(r"tirón " + who + r": el rayo para en (\S+) en vez de (\S+) \(tick (\d+)\)", line)
        if m:
            log["bounce"] = (m.group(1), m.group(2), int(m.group(3)))
        m = re.search(r"tirón (\d+) " + who + r" → (\S+) v " + VEC + r" hilo " + VEC + r" aturde (sí|no) \(tick (\d+)\)", line)
        if m:
            log["pulls"].append({
                "n": int(m.group(1)), "target": m.group(2), "v": tuple(float(m.group(i)) for i in (3, 4, 5)),
                "thread": tuple(float(m.group(i)) for i in (6, 7, 8)), "stun": m.group(9) == "sí", "tick": int(m.group(10))})
        m = re.search(r"paso " + who + r" → (\S+) centro " + VEC + r" hilo y " + NUM + r" caja " + NUM + r" ventana (-?\d+) accion (\S+) \(tick (\d+)\)", line)
        if m:
            log["steps"].append({
                "target": m.group(1), "pos": tuple(float(m.group(i)) for i in (2, 3, 4)), "thread_y": float(m.group(5)),
                "box": float(m.group(6)), "window": int(m.group(7)), "action": m.group(8), "tick": int(m.group(9))})
        m = re.search(r"tirón fin " + who + r" → (\S+) por (.+?) tirones (\d+) caja " + NUM + r" hilo y " + NUM + r" ventana (-?\d+) bit (\d) centro " + VEC + r" \(tick (\d+)\)", line)
        if m and log["end"] is None:
            log["end"] = {
                "target": m.group(1), "why": m.group(2), "pulls": int(m.group(3)), "box": float(m.group(4)),
                "thread_y": float(m.group(5)), "window": int(m.group(6)), "bit": int(m.group(7)),
                "pos": tuple(float(m.group(i)) for i in (8, 9, 10)), "tick": int(m.group(11))}
    return log


def check_log(path, kind="web"):
    k = KINDS[kind]
    sched = schedule(kind)
    log = read_log(path, kind)
    ok = True
    # 1. rejections spend nothing (the web lane only).
    if kind == "web":
        got = {}
        for reason, tick in log["bench"]:
            got.setdefault(reason, []).append(tick)
        for reason, ticks in k["bench"].items():
            if reason == "ok":
                continue
            have = got.get(reason, [])
            good = len(have) == len(ticks) and all(abs(a - b) <= TOL_TICKS for a, b in zip(have, ticks))
            ok &= verdict(good, "1. «%s» en los ticks %s (esperado %s ± %d)" % (reason, have, ticks, TOL_TICKS))
    ok &= verdict(len(log["ability"]) == k["uses"] and log["using"] is not None,
                  "1. %d uso(s) con maná (%d líneas de maná, preparación %s): los rechazos no gastan" % (k["uses"], len(log["ability"]), str(log["using"])))
    # 2. the preparation, the mana, no cooldown.
    use = log["using"]
    ok &= verdict(use is not None and use[0] == WINDUP_TICKS, "2. usando habilidad %s %d ticks: %s" % (k["ability"], WINDUP_TICKS, str(use)))
    mana = log["ability"][0] if log["ability"] else None
    ok &= verdict(mana is not None and mana[:2] == MANA, "2. mana %d->%d: %s" % (MANA[0], MANA[1], str(mana[:2] if mana else "nada")))
    ok &= verdict(mana is not None and mana[2] == 0, "2. sin enfriamiento: %s" % (str(mana[2]) if mana else "nada"))
    t0 = use[1] if use else None
    start = log["start"]
    want_start = None if t0 is None else t0 + sched["load"]
    ok &= verdict(start is not None and want_start is not None and abs(start[2] - want_start) <= TOL_TICKS,
                  "2. tirón %s → %s en el tick %s (esperado %s ± %d)" % (k["user"], start[0] if start else None, start[2] if start else None, want_start, TOL_TICKS))
    ok &= verdict(start is not None and start[0] == k["target"] and log["bounce"] is None,
                  "2. el blanco es %s y el rayo no lo cambia: %s" % (k["target"], str(log["bounce"])))
    # 3. the pulls: ticks, stun, velocity.
    pulls = log["pulls"]
    want = [] if t0 is None else [t0 + p for p in sched["pulls"]]
    n_want = MAX_PULLS if k["ends_by"] == "4 tirones" else 3
    ok &= verdict(len(pulls) >= n_want, "3. al menos %d tirones: %d" % (n_want, len(pulls)))
    for i, pull in enumerate(pulls[:len(want)]):
        ok &= verdict(abs(pull["tick"] - want[i]) <= TOL_TICKS,
                      "3. tirón %d en el tick %d (esperado %d = T + %d, ± %d)" % (pull["n"], pull["tick"], want[i], sched["pulls"][i], TOL_TICKS))
        ok &= verdict(pull["stun"] == (i == 0), "3. tirón %d %s aturde" % (pull["n"], "sí" if pull["stun"] else "no"))
        thread = pull["thread"]
        length = math.sqrt(sum(c * c for c in thread)) or 1.0
        expect = (-PULL_SPEED * thread[0] / length, -PULL_SPEED * thread[1] / length + LIFT_Y, -PULL_SPEED * thread[2] / length)
        diff = max(abs(a - b) for a, b in zip(pull["v"], expect))
        ok &= verdict(diff <= TOL_V, "3. tirón %d v %s = -16,5 * dirección del hilo + (0, %.4f, 0): diferencia %.4f (± %.2f)" % (
            pull["n"], tuple(round(c, 4) for c in pull["v"]), LIFT_Y, diff, TOL_V))
        speed = math.sqrt(pull["v"][0] ** 2 + (pull["v"][1] - LIFT_Y) ** 2 + pull["v"][2] ** 2)
        ok &= verdict(abs(speed - PULL_SPEED) <= TOL_V, "3. tirón %d rapidez del hilo %.3f (esperado %.2f ± %.2f)" % (pull["n"], speed, PULL_SPEED, TOL_V))
    # the window: 0.275 m per tick of the target while the 24 ticks last.
    steps = log["steps"]
    by_tick = {s["tick"]: s for s in steps}
    steps_ok = 0
    steps_bad = []
    for s in steps:
        nxt = by_tick.get(s["tick"] + 1)
        if s["action"] != "ventana" or nxt is None:
            continue
        step = math.hypot(nxt["pos"][0] - s["pos"][0], nxt["pos"][2] - s["pos"][2])
        if abs(step - PULL_SPEED / T) <= TOL_STEP:
            steps_ok += 1
        else:
            steps_bad.append((s["tick"], round(step, 4)))
    ok &= verdict(steps_ok > 0 and not steps_bad,
                  "3. en las ventanas avanza %.3f m por tick (± %.2f): %d pasos bien, mal %s" % (PULL_SPEED / T, TOL_STEP, steps_ok, steps_bad[:6]))
    windows = {}
    for s in steps:
        if s["action"] == "ventana":
            windows.setdefault(max([p["tick"] for p in pulls if p["tick"] <= s["tick"]] or [0]), []).append(s["tick"])
    full = [len(v) for v in windows.values()]
    ok &= verdict(bool(full) and all(n <= PULL_WINDOW - 1 for n in full),
                  "3. cada ventana empuja a lo más %d ticks: %s" % (PULL_WINDOW - 1, full))
    # 4. the end.
    end = log["end"]
    ok &= verdict(end is not None, "4. hay una línea «tirón fin»")
    if end is not None:
        ok &= verdict(end["why"] == k["ends_by"], "4. termina por «%s»: %s" % (k["ends_by"], end["why"]))
        ok &= verdict(end["bit"] == 0, "4. el bit del Pulling queda en 0: %d" % end["bit"])
        # no earlier tick satisfied the rule, and the end tick does (box < 3 with pullFrames <= 0 or thread.y >= -1.5).
        early = [s["tick"] for s in steps if s["tick"] < end["tick"] and pulls and s["tick"] > pulls[0]["tick"]
                 and s["box"] < MIN_THREAD and (s["window"] <= 0 or s["thread_y"] >= -0.5 * MIN_THREAD)]
        if k["ends_by"] == "cerca":
            satisfied = end["box"] < MIN_THREAD and (end["window"] <= 0 or end["thread_y"] >= -0.5 * MIN_THREAD)
            ok &= verdict(satisfied and not early, "4. la regla de cierre vale en el tick %d (caja %.3f < 3, ventana %d, hilo y %.3f) y en ninguno antes %s" % (
                end["tick"], end["box"], end["window"], end["thread_y"], early[:4]))
            third = t0 + sched["pulls"][2] if t0 is not None else None
            ok &= verdict(third is not None and third <= end["tick"] <= third + PULL_WINDOW + TOL_TICKS,
                          "4. termina en la 3.ª ventana: tick %d en [%s, %s]" % (end["tick"], third, None if third is None else third + PULL_WINDOW))
        else:
            want_end = t0 + sched["end_clip"] if t0 is not None else None
            ok &= verdict(want_end is not None and abs(end["tick"] - want_end) <= TOL_TICKS and end["pulls"] == MAX_PULLS,
                          "4. termina por los %d tirones en el tick %d (esperado %s = T + %d, ± %d)" % (MAX_PULLS, end["tick"], want_end, sched["end_clip"], TOL_TICKS))
            ok &= verdict(not early, "4. la distancia no cerró antes (caja al final %.3f >= 3): %s" % (end["box"], early[:4]))
        ok &= verdict(bool(steps) and end["tick"] - steps[-1]["tick"] <= TOL_TICKS,
                      "4. el último paso (%s) está a lo más a %d tick del fin (%d)" % (steps[-1]["tick"] if steps else None, TOL_TICKS, end["tick"]))
    print("(Gremlin de vuelta en idle, hilo y telaraña / jaula en pantalla: capturas del playtester)")
    return ok


def check_stone(path):
    """Lane R (F128 B1 of REVIEW-RFC-030q): the Web pull of Gremlin2 on Druid6 while the Basilisk's gaze keeps it stone
    (petrify: sacengine effects.fixed, push and catapult do nothing, state.d:8588-8590). Druid6 must not move at all
    while the state lasts, whatever the pulls do: no catapult (no tumble, no lift), no slide."""
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    stone = None
    pulls = []
    steps = []
    tumbles = []
    for line in lines:
        m = re.search(r"petrificado Druid durante (\d+) \(cuadro (\d+)\)", line)
        if m and stone is None:
            stone = (int(m.group(2)), int(m.group(1)))
        m = re.search(r"tirón (\d+) Gremlin2 → Druid6 v .* \(tick (\d+)\)", line)
        if m:
            pulls.append(int(m.group(2)))
        m = re.search(r"paso Gremlin2 → Druid6 centro " + VEC + r" .* accion (\S+) \(tick (\d+)\)", line)
        if m:
            steps.append((int(m.group(5)), tuple(float(m.group(i)) for i in (1, 2, 3)), m.group(4)))
        m = re.search(r"tumbo Druid desde " + VEC + r".* \(cuadro (\d+)\)", line)
        if m and abs(float(m.group(1)) - (ANCHOR[0] + 218.0)) < 1.0 and abs(float(m.group(3)) - (ANCHOR[1] + 320.0)) < 1.0:
            tumbles.append(int(m.group(4)))
    ok = verdict(stone is not None, "R1. el Basilisk petrifica a Druid6: %s" % str(stone))
    if stone is None:
        return False
    end = stone[0] + stone[1]
    inside = [p for p in pulls if stone[0] <= p < end]
    ok &= verdict(len(inside) >= 2, "R2. al menos 2 tirones con Druid6 de piedra (ticks %s, piedra %d a %d)" % (inside, stone[0], end))
    during = [(t, pos, a) for t, pos, a in steps if stone[0] <= t < end]
    acts = {a for _, _, a in during}
    ok &= verdict(bool(during) and "tirón" in acts and "ventana" in acts,
                  "R3. hay pasos de tirón y de ventana mientras es piedra: %s" % sorted(acts))
    moved = max((max(abs(pos[i] - during[0][1][i]) for i in range(3)) for _, pos, _ in during), default=1.0)
    ok &= verdict(moved <= 0.001, "R4. Druid6 no se mueve mientras es piedra: %.4f m de desvío en %d pasos (± 0.001)" % (moved, len(during)))
    ok &= verdict(not [t for t in tumbles if stone[0] <= t < end], "R5. ningún tumbo de Druid6 durante la piedra: %s" % tumbles)
    return ok


def main():
    args = sys.argv[1:]
    if args and args[0] == "--schedule":
        for kind in KINDS:
            s = schedule(kind)
            print("%s: carga T+%d, vuelta %d ticks, tirones T+%s, fin por los %d tirones T+%d" % (
                kind, s["load"], s["loop"], ", T+".join(str(p) for p in s["pulls"]), MAX_PULLS, s["end_clip"]))
        return
    ok = check_lanes()
    if args and args[0] != "--lanes":
        ok = check_log(args[0], "web") and ok
        ok = check_stone(args[0]) and ok
    print("RESULTADO %s" % ("PASS" if ok else "FAIL"))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
