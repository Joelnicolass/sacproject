#!/usr/bin/env python3
"""F149 (RFC-030 030k-b): what sacengine would do with the Silverback's breath and the freezes the f149 log names.

Usage: python3 -I agent/tools/f149_expect.py <godot log of debug/f149_freeze or the f149 bench case>

- Breath (updateSilverbackProjectile, state.d:24758-24831): from the logged first position and direction, update n
  (frame n-1) is at p1 + (n-1)·step·dir with radius 7.5·(n-1)/(60·range/speed). It lives while remainingDistance > 0
  (float32: 40 - 0.6·n). A body is taken on the first update its logged hit box is within the radius: the target takes
  amount · direct ranged resistance, any other body amount · (1 - d/r) · splash ranged resistance.
- Freeze (freeze, 10693-10708): ceil(60 · (1000 / max health) · 20) ticks on a creature, in float32 as sacengine
  (a Trogg 1250, not 1251); a wizard ceil(60 · 0.25 · 20) = 300.
- Thaw (updateFreeze, 17579-17614): 150 · direct spell resistance (a Trogg 0). A broken ice shatters on the next tick
  (declared): `rompe el hielo` at tick c, `deshielo` at c + 1.
Resistances come from cache/data/creatures.json by the body's name without its number (Druid2 -> Druid).
Port axes (x, y up, z); the box distance is the same in any axis order.
"""
import json
import math
import os
import re
import struct
import sys

AMOUNT = 500.0
RANGE = 40.0
SPEED = 36.0
FPS = 60
FINAL = 7.5
THAW = 150.0
SPELL_S = 20.0
NUM = r"(-?\d+(?:\.\d+)?)"
VEC = r"\(" + NUM + r", " + NUM + r", " + NUM + r"\)"


def f32(x):
    return struct.unpack("f", struct.pack("f", x))[0]


def updates():
    """remainingDistance in float32, as sacengine counts it down; the update that takes it to <= 0 still deals damage."""
    remaining = f32(RANGE)
    step = f32(f32(SPEED) / FPS)
    n = 0
    while True:
        n += 1
        remaining = f32(remaining - step)
        if remaining <= 0.0:
            return n


def freeze_ticks(max_health, wizard):
    seconds = f32(0.25 * SPELL_S) if wizard else f32(f32(1000.0 / f32(max_health)) * f32(SPELL_S))
    return int(math.ceil(f32(FPS * seconds)))


def box_distance(point, center, half):
    out = [max(abs(point[i] - center[i]) - half[i], 0.0) for i in range(3)]
    return math.sqrt(sum(x * x for x in out))


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


def main():
    lines = open(sys.argv[1], encoding="utf-8", errors="replace").read().splitlines()
    res = resistances()
    waves = {}
    last_touch = None
    broken = {}
    for line in lines:
        m = re.search(r"onda (\S+) tick 1 en " + VEC + r" dir " + VEC + r" paso " + NUM + r" radio final " + NUM + r" en " + NUM + r" ticks a (\S+)", line)
        if m:
            p1 = [float(m.group(i)) for i in (2, 3, 4)]
            d = [float(m.group(i)) for i in (5, 6, 7)]
            waves[m.group(1)] = dict(p1=p1, dir=d, step=float(m.group(8)), final=float(m.group(9)), frames=float(m.group(10)), target=m.group(11))
            print("ONDA %s a %s: esperado %d actualizaciones" % (m.group(1), m.group(11), updates()))
            continue
        m = re.search(r"onda (\S+) (\d+) actualizaciones, (\d+) tocados", line)
        if m:
            print("  port %s %s actualizaciones, %s tocados" % (m.group(1), m.group(2), m.group(3)))
            continue
        m = re.search(r"onda (\S+) toca (\S+) tick (\d+) en " + VEC + r" a " + NUM + r" m radio " + NUM + r" caja " + VEC + r" ± " + VEC + r": (.+)$", line)
        if m and m.group(1) in waves:
            wave = waves[m.group(1)]
            who, tick, what = m.group(2), int(m.group(3)), m.group(15).strip()
            center = [float(m.group(i)) for i in (9, 10, 11)]
            half = [float(m.group(i)) for i in (12, 13, 14)]
            first = None
            for n in range(1, updates() + 1):
                point = [wave["p1"][i] + (n - 1) * wave["step"] * wave["dir"][i] for i in range(3)]
                radius = wave["final"] * (n - 1) / wave["frames"]
                dist = box_distance(point, center, half)
                if radius > 0.0 and dist <= radius:
                    first = (n, dist, radius)
                    break
            r = res.get(kind_of(who), {})
            if first is None:
                print("TOCA %s: esperado ninguno (port tick %d, %s)" % (who, tick, what))
                continue
            n, dist, radius = first
            if what == "directo":
                expected = AMOUNT * float(r.get("direct_ranged", 1.0))
            elif what == "salpicadura":
                expected = AMOUNT * max(0.0, 1.0 - dist / radius) * float(r.get("splash_ranged", 1.0))
            else:
                expected = 0.0
            print("TOCA %s esperado tick %d a %.3f m radio %.3f: %s %.1f" % (who, n, dist, radius, what, expected))
            print("  port   tick %d a %s m radio %s" % (tick, m.group(7), m.group(8)))
            last_touch = (who, expected) if what != "mismo bando" else None
            continue
        m = re.search(r"dano (\S+) (\d+) vida (\d+)", line)
        if m and last_touch and kind_of(m.group(1)) == kind_of(last_touch[0]):
            got, expected = float(m.group(2)), last_touch[1]
            ratio = 100.0 * got / expected if expected else (100.0 if got == 0 else float("inf"))
            print("  port   daño %s (%.1f %%)%s" % (m.group(2), ratio, "" if abs(ratio - 100.0) <= 5.0 else "  FUERA ±5 %"))
            last_touch = None
            continue
        m = re.search(r"congelado (\S+) durante (\d+) \(vida máx (\d+)(, mago)?\)", line)
        if m:
            expected = freeze_ticks(float(m.group(3)), bool(m.group(4)))
            got = int(m.group(2))
            print("CONGELADO %s esperado %d, port %d%s" % (m.group(1), expected, got, "" if expected == got else "  DISTINTO"))
            continue
        m = re.search(r"(\S+) rompe el hielo con " + NUM + r" de daño \(cuadro (\d+)\)", line)
        if m:
            broken[m.group(1)] = int(m.group(3))
            print("ROTURA %s por %s de daño en el cuadro %s" % (m.group(1), m.group(2), m.group(3)))
            continue
        m = re.search(r"deshielo (\S+) (\d+) de hechizo vida (\d+).*\(cuadro (\d+)\)", line)
        if m:
            who, got, tick = m.group(1), int(m.group(2)), int(m.group(4))
            expected = THAW * float(res.get(kind_of(who), {}).get("direct_spell", 1.0))
            note = ""
            if who in broken:
                note = ", %d cuadro(s) tras la rotura%s" % (tick - broken[who], "" if tick - broken[who] == 1 else "  DISTINTO")
            print("DESHIELO %s esperado %.0f, port %d%s" % (who, expected, got, note))


if __name__ == "__main__":
    main()
