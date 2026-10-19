#!/usr/bin/env python3
"""F152 (RFC-030 030o-b): what sacengine would do with the Warmonger's Firewalk (wfhg) on lane B of
debug/f126_protector_firewalk, replicated from state.d, next to what the port logged.

Usage: python3 -I agent/tools/f152_expect.py [godot log of debug/f126_protector_firewalk or the f126 bench case]
       python3 -I agent/tools/f152_expect.py --lanes   (the lane check and the expected trajectories, no log)

sacengine:
- useAbility → shoot!false (13470-13493): startUsingAbility with shoot1; at the shoot tick (GFs2: tick 75 at 30 fps,
  frame = 2 * tick = 150 ticks) shootOnTick calls firewalk (13213-13217) and drains the mana (12746-12748), even if it
  fails; the cooldown is set to 10 s = 600 ticks if it was 0. Warmonger mana 500, wfhg 250: 500->250.
- range = SPEL range 200 * 0.75 = 150 (sacspell.d:208), 3D from the body to the target.
- updateFirewalk (25802-25846): 60 frames, animatedDistance 20. d <= 20 straight line; else start -> start + 10 * dir
  until p = 0.5, then end - 10 * dir -> end. start/end/each position take the land's height. d is the 3D distance.
Lane B (anchor 1270, 1270): W1 -50/+20 -> +10/+20 (60 m, split); W2 -35/+8 -> -20/+8 (15 m, straight);
W3 -50/+40 -> +88.6/-40 (160 m, refused: out of range).
Log lines (Firewalking.log_walk and AbilityEffect.log_effects on):
  usando habilidad Firewalk Warmonger1 150 ticks (tick N)      (ActiveAbility, phase 2)
  firewalk Warmonger1 inicio de (x, y, z) a (x, y, z) d 60.00 m (tick N)
  firewalk Warmonger1 cuadro F (x, y, z) (tick N)
  firewalk Warmonger1 fin (tick N)
  habilidad Firewalk mana 500->250
  Warmonger3 Fuera de alcance
The check compares each logged frame with the model horizontally (HORIZ_TOL_M), with the land's height from
assets/original/maps/high_noon/terrain.res (flat when it is missing).
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
FRAMES = 60
ANIMATED = 20.0
RANGE = 200.0 * 0.75
WINDUP_TICKS = 150
MANA = (500, 250)
COOLDOWN_TICKS = 600
TOL_TICKS = 1
HORIZ_TOL_M = 0.05
LANES = {
    "Warmonger1": ((-50.0, 20.0), (10.0, 20.0)),
    "Warmonger2": ((-35.0, 8.0), (-20.0, 8.0)),
    "Warmonger3": ((-50.0, 40.0), (88.6, -40.0)),
}
NUM = r"(-?\d+(?:\.\d+)?)"


def map_file(name):
    """A High Noon map file from assets/original/maps/high_noon/ (RFC-033, 033f)."""
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "original", "maps", "high_noon", name)



def load_terrain():
    """Vertices and indices of the ground (assets/original/maps/high_noon/terrain.res, RFC-033): (verts, idx), None without the file."""
    return terrain_asset.load()


def ground(terrain, x, z):
    if terrain is None:
        return 0.0
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


def world(point):
    return ANCHOR[0] + point[0], ANCHOR[1] + point[1]


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def trajectory(terrain, start_xz, end_xz):
    """Frames 1..FRAMES of updateFirewalk: [(x, y, z)], y = the land's height (z of sacengine)."""
    def lift(xz):
        h = ground(terrain, xz[0], xz[1])
        return (xz[0], 0.0 if h is None else h, xz[1])
    start, end = lift(start_xz), lift(end_xz)
    direction = tuple(end[i] - start[i] for i in range(3))
    distance = math.sqrt(sum(c * c for c in direction))
    if distance != 0.0:
        direction = tuple(c / distance for c in direction)
    out = []
    for frame in range(1, FRAMES + 1):
        p = frame / FRAMES
        if frame >= FRAMES:
            at = end
        elif distance <= ANIMATED:
            at = lerp(start, end, p)
        elif p <= 0.5:
            mid = tuple(start[i] + 0.5 * ANIMATED * direction[i] for i in range(3))
            at = lerp(start, mid, 2.0 * p)
        else:
            mid = tuple(end[i] - 0.5 * ANIMATED * direction[i] for i in range(3))
            at = lerp(mid, end, 2.0 * (p - 0.5))
        h = ground(terrain, at[0], at[2])
        out.append((at[0], at[1] if h is None else h, at[2]))
    return start, end, distance, out


def horizontal(a, b):
    return math.hypot(a[0] - b[0], a[2] - b[2])


def distance3(a, b):
    return math.sqrt(sum((a[i] - b[i]) ** 2 for i in range(3)))


def check_lanes():
    """Ground under every start and end, no structure within 15 m of the start, and the expected trajectories."""
    ok = True
    terrain = load_terrain()
    try:
        ntts = json.load(open(map_file("ntts.json"), encoding="utf-8"))
        widgets = json.load(open(map_file("widgets.json"), encoding="utf-8"))
    except OSError:
        ntts, widgets = {"structures": []}, {}
    for name, (a, b) in LANES.items():
        for label, point in (("origen", a), ("destino", b)):
            x, z = world(point)
            y = ground(terrain, x, z) if terrain else None
            near = [(s["tag"], round(math.hypot(s["x"] - x, s["z"] - z), 1)) for s in ntts.get("structures", [])
                    if math.hypot(s["x"] - x, s["z"] - z) < 15.0]
            props = [k for k, ps in widgets.items() for p in ps if math.hypot(p[0] - x, p[1] - z) < 3.0]
            bad = (terrain is not None and y is None) or near or props
            ok = ok and not bad
            print("carril %-10s %-7s (%.1f, %.1f) suelo %s estructuras<15 %s widgets<3 %s %s" % (
                name, label, x, z, "?" if y is None else "%.2f" % y, near, props, "MAL" if bad else "ok"))
        sx, sz = world(a)
        ex, ez = world(b)
        flat = math.hypot(ex - sx, ez - sz)
        print("carril %-10s %.2f m en planta (alcance %.0f): %s" % (name, flat, RANGE, "dentro" if flat <= RANGE else "FUERA"))
    for name in ("Warmonger1", "Warmonger2"):
        start, end, distance, path = trajectory(terrain, world(LANES[name][0]), world(LANES[name][1]))
        print("%s d %.2f m (%s)" % (name, distance, "recto" if distance <= ANIMATED else "partido"))
        for frame in (1, 30, 31, 60):
            at = path[frame - 1]
            print("  cuadro %2d (%.3f, %.3f, %.3f) a %.2f m del origen, %.2f m del destino, salto %.2f m" % (
                frame, at[0], at[1], at[2], distance3(start, at), distance3(end, at),
                distance3(path[frame - 2], at) if frame > 1 else distance3(start, at)))
    return ok


def verdict(ok, text):
    print("%s  %s" % ("PASS" if ok else "FAIL", text))
    return ok


def read_log(path):
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    log = {"using": {}, "start": {}, "frames": {}, "end": {}, "ability": [], "refused": set(), "cut": set(), "hidden": {}}
    for line in lines:
        m = re.search(r"usando habilidad (.+?) (\S+) (\d+) ticks(?: \(tick (\d+)\))?", line)
        if m:
            log["using"].setdefault(m.group(2), (m.group(1), int(m.group(3)), int(m.group(4) or -1)))
        m = re.search(r"firewalk (\S+) inicio de \(" + NUM + ", " + NUM + ", " + NUM + r"\) a \(" + NUM + ", " + NUM + ", " + NUM
                      + r"\) d " + NUM + r" m \(tick (\d+)\)", line)
        if m:
            log["start"].setdefault(m.group(1), (tuple(float(m.group(i)) for i in (2, 3, 4)),
                                                  tuple(float(m.group(i)) for i in (5, 6, 7)), float(m.group(8)), int(m.group(9))))
        m = re.search(r"firewalk (\S+) cuadro (\d+) \(" + NUM + ", " + NUM + ", " + NUM + r"\) \(tick (\d+)\)", line)
        if m:
            log["frames"].setdefault(m.group(1), {}).setdefault(int(m.group(2)), (
                (float(m.group(3)), float(m.group(4)), float(m.group(5))), int(m.group(6))))
        m = re.search(r"firewalk (\S+) fin \(tick (\d+)\)", line)
        if m:
            log["end"].setdefault(m.group(1), int(m.group(2)))
        m = re.search(r"habilidad (.+?) mana (\d+)->(\d+)(?: enfriamiento (\d+) ticks)?", line)
        if m:
            log["ability"].append((m.group(1), int(m.group(2)), int(m.group(3)), int(m.group(4) or -1)))
        m = re.search(r"firewalk (\S+) oculto: is_targetable (\w+) is_obstacle (\w+)", line)
        if m:
            log["hidden"].setdefault(m.group(1), (m.group(2), m.group(3)))
        m = re.search(r"(Warmonger\d+).*out_of_range|out_of_range.*(Warmonger\d+)", line)
        if m:
            log["refused"].add(m.group(1) or m.group(2))
        m = re.search(r"preparaci[oó]n cortada.*?(Warmonger\d+)|(Warmonger\d+).*preparaci[oó]n cortada", line)
        if m:
            log["cut"].add(m.group(1) or m.group(2))
    return log


def check_log(path):
    log = read_log(path)
    terrain = load_terrain()
    ok = True
    # 1. the preparation line, the walk 150 ticks later, the mana.
    use = log["using"].get("Warmonger1")
    start = log["start"].get("Warmonger1")
    ok &= verdict(use is not None and use[0] == "Firewalk" and use[1] == WINDUP_TICKS,
                  "1. usando habilidad Firewalk Warmonger1 %d ticks: %s" % (WINDUP_TICKS, str(use)))
    if use and start and use[2] >= 0:
        ok &= verdict(abs(start[3] - (use[2] + WINDUP_TICKS)) <= TOL_TICKS,
                      "1. el Firewalk empieza en el tick %d (esperado %d ± %d)" % (start[3], use[2] + WINDUP_TICKS, TOL_TICKS))
    mana = [a for a in log["ability"] if a[0] == "Firewalk"]
    ok &= verdict(bool(mana) and mana[0][1:3] == MANA, "1. habilidad Firewalk mana %d->%d: %s" % (MANA[0], MANA[1], str(mana[0][1:3] if mana else "nada")))
    ok &= verdict(bool(mana) and mana[0][3] == COOLDOWN_TICKS, "1. enfriamiento de %d ticks: %s" % (COOLDOWN_TICKS, str(mana[0][3] if mana else "nada")))
    # 2/3. the trajectories, frame by frame.
    for name, key in (("Warmonger1", "2"), ("Warmonger2", "3")):
        frames = log["frames"].get(name, {})
        a, b = LANES[name]
        s, e, d, path = trajectory(terrain, world(a), world(b))
        ok &= verdict(len(frames) == FRAMES, "%s. %s: %d cuadros logueados (esperado %d)" % (key, name, len(frames), FRAMES))
        worst = 0.0
        for frame, (at, _) in sorted(frames.items()):
            worst = max(worst, horizontal(at, path[frame - 1]))
        ok &= verdict(bool(frames) and worst <= HORIZ_TOL_M, "%s. %s: peor desvío horizontal %.3f m (tope %.2f)" % (key, name, worst, HORIZ_TOL_M))
        last = frames.get(FRAMES)
        ok &= verdict(last is not None and horizontal(last[0], e) <= HORIZ_TOL_M,
                      "%s. %s: cuadro %d en %s (esperado (%.2f, %.2f))" % (key, name, FRAMES, str(last[0] if last else None), e[0], e[2]))
        if name == "Warmonger1" and 30 in frames and 31 in frames:
            at30, at31 = frames[30][0], frames[31][0]
            ok &= verdict(abs(distance3(s, at30) - 10.0) <= HORIZ_TOL_M,
                          "2. cuadro 30 a %.2f m del origen (esperado 10,00 ± %.2f)" % (distance3(s, at30), HORIZ_TOL_M))
            ok &= verdict(abs(distance3(e, at31) - 9.67) <= 0.1,
                          "2. cuadro 31 a %.2f m del destino (esperado 9,67 ± 0.1)" % distance3(e, at31))
            ok &= verdict(abs(distance3(at30, at31) - 40.33) <= 0.2, "2. salto de %.2f m (esperado 40,33 ± 0.2)" % distance3(at30, at31))
        if name == "Warmonger2" and len(frames) == FRAMES:
            steps = [horizontal(frames[f][0], frames[f - 1][0]) for f in range(2, FRAMES + 1)]
            ok &= verdict(all(abs(step - 0.25) <= HORIZ_TOL_M for step in steps),
                          "3. W2 avanza %.3f..%.3f m por tick (esperado 0,25)" % (min(steps), max(steps)))
        end = log["end"].get(name)
        if end is not None and frames:
            ok &= verdict(FRAMES in frames and abs(end - frames[FRAMES][1]) <= TOL_TICKS, "%s. %s: fin en el tick %d" % (key, name, end))
    hidden = log["hidden"].get("Warmonger1")
    ok &= verdict(hidden == ("false", "false"), "2. a mitad de la caminata is_targetable false, is_obstacle false: %s" % str(hidden))
    # 4. W3 refused, no walk.
    ok &= verdict("Warmonger3" in log["refused"] and "Warmonger3" not in log["start"] and "Warmonger3" not in log["using"],
                  "4. Warmonger3: «Fuera de alcance», sin preparación ni caminata")
    ok &= verdict(len([a for a in log["ability"] if a[0] == "Firewalk"]) == 2,
                  "4. solo W1 y W2 gastaron maná (habilidad Firewalk: %d líneas)" % len([a for a in log["ability"] if a[0] == "Firewalk"]))
    if log["cut"]:
        for name in log["cut"]:
            ok &= verdict(name not in log["start"], "5. %s: preparación cortada, sin caminata" % name)
    return ok


def main():
    args = sys.argv[1:]
    ok = check_lanes()
    if args and args[0] != "--lanes":
        ok = check_log(args[0]) and ok
    print("RESULTADO %s" % ("PASS" if ok else "FAIL"))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
