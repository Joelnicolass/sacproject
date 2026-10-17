#!/usr/bin/env python3
"""F125 (RFC-030 030n-a): what sacengine would do with the Boulderdash's fan (emba) and the Phoenix's heat ray (rdra) of
debug/f125_big_shots, replicated from state.d, next to what the port logged.

Usage: python3 -I agent/tools/f125_expect.py [godot log of debug/f125_big_shots or the f125 bench case]

Boulderdash (boulderdashShoot 11793-11813, updateBoulderdashProjectile 24729-24755, hit box 24693):
- Three rocks (which = -1, 0, +1) with the same direction (one accuracy roll), straight, step speed/60 = 1 m a tick.
- distanceUntilSplit = max(0, |aim - origin| - 60), float32. Each tick: move, then if it is >= 0 it drops by 1 and, the
  tick it goes under 0, the side rocks turn which * 3.5 deg around the up axis (from the next move on).
- Then the 0.7 m box: the first body that is the intended target or not of the shooter's side (the shooter never); the
  port takes the nearest center among the boxes it touches. Hit: amount * direct ranged resistance (Druid 500 -> 450).
- remainingDistance = 2 * range = 400, float32, minus 1 a tick: at <= 0 it bursts with no damage. The ground is not
  replicated (the lanes keep ~0.8 m over it): a port rock that ends earlier, touching nobody, is reported as ground.
Port axes (x, y up, z); the turn uses Godot's Vector3.rotated(UP, a): x' = x cos a + z sin a, z' = z cos a - x sin a.
The start of each rock is the port's own first tick (`abanico ... tick 1 en ... dir ...`): the accuracy roll is the
port's, the replica checks what follows from it.

Phoenix (updatePhoenixProjectile 24208-24254): straight at 60 m/s for 80 m; on a creature setAblazeWithManaDrain(60
frames, 800, 0.5 * max mana): updateFire deals damage/lifetime * resistance per update for lifetime + 1 updates.
"""
import json
import math
import os
import re
import struct
import sys

T = 60
SPLIT_BEFORE = 60.0
ANGLE = 3.5
RANGE_FACTOR = 2.0
EMBA = {"amount": 500.0, "range": 200.0, "speed": 60.0}
RDRA = {"amount": 800.0, "frames": 60, "drain": 0.5, "range": 80.0, "speed": 60.0}
NUM = r"(-?\d+(?:\.\d+)?)"
VEC = r"\(" + NUM + r", " + NUM + r", " + NUM + r"\)"
TOL_M = 0.3
TOL_TICKS = 1


def f32(x):
    return struct.unpack("f", struct.pack("f", x))[0]


def resistances():
    here = os.path.dirname(os.path.abspath(__file__))
    path = os.path.join(here, "..", "..", "cache", "data", "creatures.json")
    try:
        data = json.load(open(path, encoding="utf-8"))
    except OSError:
        return {}
    items = data if isinstance(data, list) else list(data.values())
    return {c.get("name", ""): c.get("resistances", {}) for c in items if isinstance(c, dict)}


def kind_of(name):
    return re.sub(r"\d+$", "", name)


def split_tick(aim):
    """The tick the rocks turn on: distanceUntilSplit counted down in float32 from max(0, aim - 60)."""
    until = f32(max(0.0, f32(aim) - SPLIT_BEFORE))
    step = f32(EMBA["speed"] / T)
    n = 0
    while until >= 0.0:
        n += 1
        until = f32(until - step)
    return n


def range_ticks():
    remaining = f32(RANGE_FACTOR * EMBA["range"])
    step = f32(EMBA["speed"] / T)
    n = 0
    while True:
        n += 1
        remaining = f32(remaining - step)
        if remaining <= 0.0:
            return n


def turn(v, degrees):
    a = math.radians(degrees)
    c, s = math.cos(a), math.sin(a)
    return [v[0] * c + v[2] * s, v[1], v[2] * c - v[0] * s]


def touches(point, half_shot, center, half):
    return all(abs(point[i] - center[i]) <= half_shot + half[i] for i in range(3))


def fly(rock, bodies):
    """Ticks of one rock from its logged first tick: (tick, point, body or None, split tick)."""
    turn_at = split_tick(rock["aim"]) if rock["aim"] >= 0.0 else 0
    last = range_ticks()
    point = list(rock["p1"])
    step = [rock["step"] * d for d in rock["dir"]]
    half_shot = rock["box"] * 0.5
    for n in range(1, last + 1):
        if n > 1:
            point = [point[i] + step[i] for i in range(3)]
        if n == turn_at and rock["index"] != 0:
            step = turn(step, rock["index"] * ANGLE)
        best, best_d = None, math.inf
        for body in bodies:
            if body["name"] == rock["shooter"]:
                continue
            if body["name"] != rock["target"] and rock["slot"] > 0 and body["slot"] == rock["slot"]:
                continue
            if not touches(point, half_shot, body["center"], body["half"]):
                continue
            d = sum((point[i] - body["center"][i]) ** 2 for i in range(3))
            if d < best_d:
                best, best_d = body, d
        if best:
            return n, point, best["name"], turn_at
    return last, point, None, turn_at


def fire(amount, frames, resist, mana_max, drain):
    updates = frames + 1
    taken = amount / frames * resist * updates
    mana = max(0.0, mana_max - drain * mana_max / frames * updates)
    return taken, updates, mana


def main():
    res = resistances()
    druid = res.get("Druid", {})
    hit = EMBA["amount"] * float(druid.get("direct_ranged", 0.9))
    taken, updates, mana = fire(RDRA["amount"], RDRA["frames"], float(druid.get("direct_ranged", 0.9)), 100.0, RDRA["drain"])
    print("A abanico: 3 piedras, giro ±%.1f° a los max(0, d - %.0f) m, alcance %d ticks, golpe a un Druid %.1f, suelo 0"
          % (ANGLE, SPLIT_BEFORE, range_ticks(), hit))
    print("B Phoenix -> Druid: fuego total %.1f en %d actualizaciones, maná 100 -> %.2f, sin daño directo; vuelo d/60 ±2"
          % (taken, updates, mana))
    if len(sys.argv) < 2:
        return
    lines = open(sys.argv[1], encoding="utf-8", errors="replace").read().splitlines()
    rocks, bodies, splits, ends = {}, {}, {}, {}
    order = []
    for line in lines:
        m = re.search(r"abanico (\S+) índice (-?\d+) tick 1 en " + VEC + r" dir " + VEC + r" paso " + NUM
                      + r" apuntado " + NUM + r" m giro a los " + NUM + r" m alcance " + NUM + r" caja " + NUM
                      + r" blanco (\S+) tirador (\S+) bando (-?\d+) \(cuadro (\d+)\)", line)
        if m:
            name = m.group(1)
            rocks[name] = dict(index=int(m.group(2)), p1=[float(m.group(i)) for i in (3, 4, 5)],
                               dir=[float(m.group(i)) for i in (6, 7, 8)], step=float(m.group(9)), aim=float(m.group(10)),
                               until=float(m.group(11)), reach=float(m.group(12)), box=float(m.group(13)),
                               target=m.group(14), shooter=m.group(15), slot=int(m.group(16)), frame=int(m.group(17)))
            order.append(name)
            continue
        m = re.search(r"abanico (\S+) cuerpo (\S+) caja " + VEC + r" ± " + VEC + r" bando (-?\d+)", line)
        if m:
            bodies.setdefault(int(rocks.get(m.group(1), {}).get("frame", -1)), []).append(
                dict(name=m.group(2), center=[float(m.group(i)) for i in (3, 4, 5)],
                     half=[float(m.group(i)) for i in (6, 7, 8)], slot=int(m.group(9))))
            continue
        m = re.search(r"abanico ±(\S+)° a los " + NUM + r" m: (\S+) índice (-?\d+) tick (\d+) ángulo " + NUM + r"°", line)
        if m:
            splits[m.group(3)] = dict(at=float(m.group(2)), tick=int(m.group(5)), angle=float(m.group(6)))
            continue
        m = re.search(r"abanico (\S+) índice (-?\d+) fin tick (\d+) en " + VEC + r" giro tick (\d+) toca (\S+)", line)
        if m:
            ends[m.group(1)] = dict(tick=int(m.group(3)), at=[float(m.group(i)) for i in (4, 5, 6)], touched=m.group(8))
            continue
    bad = 0
    for name in order:
        rock = rocks[name]
        walk = bodies.get(rock["frame"], [])
        tick, point, who, turn_at = fly(rock, walk)
        expected_at = max(0.0, rock["aim"] - SPLIT_BEFORE)
        print("\nPIEDRA %s índice %+d (cuadro %d), apuntado %.3f m, %d cuerpos" % (name, rock["index"], rock["frame"],
              rock["aim"], len(walk)))
        notes = []
        if abs(rock["until"] - expected_at) > 1.0:
            notes.append("giro a los %.3f m, esperado %.3f" % (rock["until"], expected_at))
        split = splits.get(name)
        if split:
            angle_ok = abs(abs(split["angle"]) - abs(rock["index"]) * ANGLE) <= 0.01
            tick_ok = abs(split["tick"] - turn_at) <= TOL_TICKS
            print("  giro esperado tick %d a los %.3f m, ±%.2f°; port tick %d a los %.3f m, %.4f°%s" % (turn_at, expected_at,
                  abs(rock["index"]) * ANGLE, split["tick"], split["at"], split["angle"],
                  "" if angle_ok and tick_ok else "  DISTINTO"))
            if not (angle_ok and tick_ok):
                notes.append("giro")
        else:
            notes.append("sin línea de giro")
        damage = EMBA["amount"] * float(res.get(kind_of(who), {}).get("direct_ranged", 1.0)) if who else 0.0
        print("  esperado fin tick %d en (%.3f, %.3f, %.3f) toca %s: %.1f" % (tick, point[0], point[1], point[2],
              who or "nadie (alcance)", damage))
        end = ends.get(name)
        if end:
            dist = math.sqrt(sum((end["at"][i] - point[i]) ** 2 for i in range(3)))
            same = (end["touched"] == (who or "nadie"))
            ground = end["touched"] == "nadie" and end["tick"] < tick
            ok = (same and abs(end["tick"] - tick) <= TOL_TICKS and dist <= TOL_M)
            print("  port    fin tick %d en (%.3f, %.3f, %.3f) toca %s, a %.3f m%s" % (end["tick"], end["at"][0], end["at"][1],
                  end["at"][2], end["touched"], dist, "" if ok else ("  SUELO (no replicado)" if ground else "  DISTINTO")))
            if who:
                print("  vuelo %d ticks, distancia/60 = %.1f" % (end["tick"], math.dist(rock["p1"], point) + 1.0))
            if not ok and not ground:
                notes.append("fin")
        else:
            notes.append("sin línea de fin")
        bad += 1 if notes else 0
    m_fire = [l for l in lines if re.search(r"^fuego rdra ", l) or re.search(r"^\S+ fuego ", l)]
    if m_fire:
        print("\n--- fuego del Phoenix (port) ---")
        for line in m_fire:
            print(line)
    if order:
        print("\n%d piedras, %d con diferencias" % (len(order), bad))


if __name__ == "__main__":
    main()
