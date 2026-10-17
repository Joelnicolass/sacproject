#!/usr/bin/env python3
"""F121 (RFC-030j): what sacengine would do with the bodies the f121 log names, replicated from state.d.

Usage: python3 -I agent/tools/f121_expect.py <godot log of debug/f121_push or the f121 bench case>

- Squall push (updatePushback, state.d:24017-24031): 40 ticks of 22.5 m/s along the shot, sliding on the land: 15·|dir_xz| m.
- Vortick vortex (updateVortexEffect 23922-23960, catapult 8582-8599, tumbling 14781-14797, landing 14175-14197): from
  the logged start relative to the vortex center, on flat ground at the logged ground height. Apex over the start
  ground, distance at landing, vz and fall damage max(0, -vz - 3)*20.
- Flurry implosion (updateFlurryImplosion 24619-24672): the pull of a body on flat ground from where it was touched.
Port axes (x, y up, z) = sacengine (x, z, y up). Prints the port's line next to the expected one and the ratio.
"""
import math
import re
import sys

T = 60.0
G = 9.81
DXY = math.exp(60 * math.log(0.99) / T)
DZ = math.exp(60 * math.log(0.998) / T)
NUM = r"(-?\d+(?:\.\d+)?)"
VEC = r"\(" + NUM + r", " + NUM + r", " + NUM + r"\)"


def vortex_flight(center, feet, ground, half, offset, radius=2.0, height=4.0):
    """sacengine order per frame: effects (the vortex), creature state (landing), creature position (tumbling)."""
    pos = list(feet)
    vel = [0.0, 0.0, 0.0]
    tumbling = False
    apex = pos[1]
    diag = math.sqrt(2.0) * radius
    for frame in range(0, 2000):
        lifted = False
        if frame < 0.75 * 2.0 * T:
            c = [pos[0], pos[1] + offset, pos[2]]
            inside = (abs(c[0] - center[0]) <= diag + half[0] and abs(c[2] - center[2]) <= diag + half[2]
                      and c[1] + half[1] >= center[1] - 0.25 * height and c[1] - half[1] <= center[1] + height)
            if inside:
                if frame < 0.75 * T and not tumbling:
                    dx, dz = center[0] - c[0], center[2] - c[2]
                    n = math.hypot(dx, dz) or 1.0
                    dx, dz = dx / n * 1.5, dz / n * 1.5
                    vel = [dz, 2.5, -dx]
                    tumbling = True
                if tumbling:
                    rx, ry, rz = c[0] - center[0], c[1] - center[1], c[2] - center[2]
                    if ry <= height:
                        vel[0] += 5.5 * (-rz - rx) / T
                        vel[2] += 5.5 * (rx - rz) / T
                        vel[1] += 5.5 / T
                    vel[1] = max(vel[1], 1.0)
                    lifted = True
        if not tumbling:
            continue
        if vel[1] <= 0.0 and pos[1] + vel[1] / T <= ground:
            dist = math.hypot(pos[0] - feet[0], pos[2] - feet[2])
            return apex - ground, dist, vel[1], max(0.0, -vel[1] - 3.0) * 20.0, frame
        if pos[1] <= ground:
            if vel[1] < 0.0:
                vel[1] = 0.0
        elif not lifted:
            vel[1] -= G / T
        vel[0] *= DXY
        vel[2] *= DXY
        vel[1] *= DZ
        pos = [pos[i] + vel[i] / T for i in range(3)]
        pos[1] = max(pos[1], ground)
        apex = max(apex, pos[1])
    return None


def implosion_pull(center, feet, ground, offset, scale, effect_range=20.0, duration=1.5, speed_k=15.0):
    pos = list(feet)
    s = scale
    while True:
        c = [pos[0], pos[1] + offset, pos[2]]
        rel = [center[i] - c[i] for i in range(3)]
        d = math.sqrt(sum(x * x for x in rel))
        if d <= 0.0 or d > effect_range or max(abs(x) for x in rel) > s:
            pass
        else:
            direction = [x / d for x in rel]
            speed = math.sqrt(max(10.0, d) * max(10.0, s)) / effect_range * speed_k / T
            step = [speed * x for x in direction]
            new = [pos[i] + step[i] for i in range(3)]
            if new[1] - ground <= speed_k / (2 * T):
                pos = [new[0], ground, new[2]]
            else:
                return None  # thrown: not replicated (port and sacengine both make it a tiny hop)
        s -= effect_range / duration / T
        if s <= 0.0:
            break
    before = math.hypot(center[0] - feet[0], center[2] - feet[2])
    after = math.hypot(center[0] - pos[0], center[2] - pos[2])
    return before, after


def main():
    lines = open(sys.argv[1], encoding="utf-8", errors="replace").read().splitlines()
    vortex = None
    implosion = None
    pending = {}
    for line in lines:
        m = re.search(r"empuje a (\S+) dir " + VEC, line)
        if m:
            dx, dz = float(m.group(2)), float(m.group(4))
            print("EMPUJE %s esperado %.2f m (15·|dir_xz|)" % (m.group(1), 15.0 * math.hypot(dx, dz)))
            continue
        m = re.search(r"empuje (\S+) " + NUM + r" m en (\d+) ticks \(dx " + NUM + r", dz " + NUM + r", dy " + NUM, line)
        if m:
            moved = math.hypot(float(m.group(4)), float(m.group(5)))
            print("  port %s %.2f m plano en %s ticks (dy %s)" % (m.group(1), moved, m.group(3), m.group(6)))
            continue
        m = re.search(r"vórtice en " + VEC, line)
        if m:
            vortex = tuple(float(m.group(i)) for i in (1, 2, 3))
            continue
        m = re.search(r"implosión en " + VEC, line)
        if m:
            implosion = tuple(float(m.group(i)) for i in (1, 2, 3))
            continue
        m = re.search(r"tumbo (\S+) desde " + VEC + r" suelo " + NUM + r" v " + VEC + r" caja " + VEC + r" centro \+" + NUM, line)
        if m and vortex and abs(float(m.group(7)) - 2.5) < 1e-3:
            feet = tuple(float(m.group(i)) for i in (2, 3, 4))
            half = tuple(float(m.group(i)) for i in (9, 10, 11))
            got = vortex_flight(vortex, feet, float(m.group(5)), half, float(m.group(12)))
            if got:
                pending.setdefault(m.group(1), []).append((feet, got))
            continue
        m = re.search(r"aterriza (\S+)(?: sobre \S+)? en " + VEC + r" a " + NUM + r" m .* ápice " + NUM + r" m, vz " + NUM + r", caída " + NUM, line)
        landed = tuple(float(m.group(i)) for i in (2, 3, 4)) if m else None
        near = [e for e in pending.get(m.group(1), []) if math.dist(e[0], landed) < 40.0] if m else []
        if near:
            pending[m.group(1)].remove(near[0])
            apex, dist, vz, fall, frames = near[0][1]
            pa, pd, pv, pf = float(m.group(6)), float(m.group(5)), float(m.group(7)), float(m.group(8))
            print("VORTICE %s esperado ápice %.2f m, %.2f m, vz %.2f, caída %.1f (%d ticks)" % (m.group(1), apex, dist, vz, fall, frames))
            print("  port   ápice %.2f m (%.0f %%), %.2f m (%.0f %%), vz %.2f, caída %.1f" % (
                pa, 100 * pa / apex if apex else 0, pd, 100 * pd / dist if dist else 0, pv, pf))
            continue
        m = re.search(r"implosión toca (\S+) en " + VEC + r" suelo " + NUM + r" centro \+" + NUM + r" escala " + NUM, line)
        if m and implosion:
            feet = tuple(float(m.group(i)) for i in (2, 3, 4))
            got = implosion_pull(implosion, feet, float(m.group(5)), float(m.group(6)), float(m.group(7)))
            if got:
                print("IMPLOSION %s esperado de %.2f m a %.2f m (tirón %.2f m)" % (m.group(1), got[0], got[1], got[0] - got[1]))
            else:
                print("IMPLOSION %s esperado: arrojado (no replicado)" % m.group(1))
            continue
        m = re.search(r"implosión (\S+) de " + NUM + r" m a " + NUM + r" m del centro \(tirón " + NUM, line)
        if m:
            print("  port %s de %s m a %s m (tirón %s m)" % (m.group(1), m.group(2), m.group(3), m.group(4)))


if __name__ == "__main__":
    main()
