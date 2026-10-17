#!/usr/bin/env python3
"""F126 (RFC-030 030o-a): what sacengine would do with the Ent's Protector (HSba) and the Druid's Life Shield (hsba) on
lane A of debug/f126_protector_firewalk, replicated from state.d and the SPEL data, next to what the port logged.

Usage: python3 -I agent/tools/f126_expect.py [godot log of debug/f126_protector_firewalk or the f126 bench case]
       python3 -I agent/tools/f126_expect.py --lanes   (only the lane check against the map caches)

sacengine:
- useAbility (13463-13561): protector / lifeShield; when it returns true, apply() drains manaCost and sets the cooldown
  (cooldown * 60) in the same frame. Ent mana 500, HSba 300 -> 500->200; Druid mana 100, hsba 50 -> 100->50.
- protector (13196-13202): refused while the Ent has a shield; else lifeShield(hsba) on itself + a Protector effect.
- updateProtector (25698-25713): once, on the next frame: eachInRange(center, effectRange 30) of the Ent's side, not
  itself, a valid creature, not a wizard -> lifeShield, refused when it already has one (13092-13100).
- updateLifeShield (25122-25155): the shield is gone at frame hsba.duration * 60 = 1200 after it started.
- dealDamage (8962-8963): x0.5 with a shield. The Gnome's plfa: 600 * direct ranged 0.9 = 540 -> 270 shielded.
Lane A (anchor 1270, 1270): E Ent +25/-45; A1 Druid +25/-35; A2 Druid +25/-17.5 (its own Life Shield at T);
A3 Druid +25/-10; A4 enemy Druid +35/-45; G1 Gnome (slot 2) -10/-33, killed at 6 s.
The protector's distances are 3D center to center: the replica checks the verdicts and that each distance is the
horizontal one plus the ground and center heights within DIST_TOL_M (the box heights are the port's baked models).
"""
import json
import math
import os
import re
import struct
import sys

T = 60
ANCHOR = (1270.0, 1270.0)
RADIUS = 30.0
SHIELD_TICKS = 20 * T
DAMAGE = 600.0 * 0.9
SHIELD = 0.5
DRUID_HEALTH = 800.0
TOL_TICKS = 1
DIST_TOL_M = 1.5
HEALTH_TOL = 0.5
LANES = {
    "Ent1": (25.0, -45.0, 1),
    "Druid1": (25.0, -35.0, 1),
    "Druid2": (25.0, -17.5, 1),
    "Druid3": (25.0, -10.0, 1),
    "Druid4": (35.0, -45.0, 2),
    "Gnome1": (-10.0, -33.0, 2),
}
EXPECTED_VERDICT = {"Druid1": "sí", "Druid2": "ya tenía", "Druid3": "fuera"}
NUM = r"(-?\d+(?:\.\d+)?)"


def cache(name):
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "cache", name)


def load_terrain():
    """HNTR v1 (tools/export_high_noon_terrain.py, scenes/world/terrain.gd): vertices, normals, indices."""
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


def horizontal(a, b):
    ax, az = world(a)
    bx, bz = world(b)
    return math.hypot(ax - bx, az - bz)


def check_lanes():
    """Ground under every body, no structure within 15 m, no widget within 3 m, and the Gnome's closest foe is Druid1."""
    ok = True
    terrain = load_terrain()
    try:
        ntts = json.load(open(cache("high_noon_ntts.json"), encoding="utf-8"))
        widgets = json.load(open(cache("high_noon_widgets.json"), encoding="utf-8"))
    except OSError:
        ntts, widgets = {"structures": []}, {}
    for name in LANES:
        x, z = world(name)
        y = ground(terrain, x, z) if terrain else None
        near = [(s["tag"], round(math.hypot(s["x"] - x, s["z"] - z), 1)) for s in ntts.get("structures", [])
                if math.hypot(s["x"] - x, s["z"] - z) < 15.0]
        props = [k for k, ps in widgets.items() for p in ps if math.hypot(p[0] - x, p[1] - z) < 3.0]
        bad = (terrain is not None and y is None) or near or props
        ok = ok and not bad
        print("carril %-7s (%.1f, %.1f) suelo %s estructuras<15 %s widgets<3 %s %s" % (
            name, x, z, "?" if y is None else "%.2f" % y, near, props, "MAL" if bad else "ok"))
    foes = sorted((horizontal("Gnome1", n), n) for n, (_, _, slot) in LANES.items() if slot == 1)
    print("blanco del Gnome1: %s a %.2f m (siguiente %s a %.2f m) %s" % (
        foes[0][1], foes[0][0], foes[1][1], foes[1][0], "ok" if foes[0][1] == "Druid1" else "MAL"))
    ok = ok and foes[0][1] == "Druid1"
    for name in EXPECTED_VERDICT:
        d = horizontal("Ent1", name)
        print("Ent1 -> %s: %.2f m en planta (radio %.0f)" % (name, d, RADIUS))
    return ok


def read_log(path):
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    ability = []
    shields = {}
    ends = {}
    protector = None
    rays = []
    for i, line in enumerate(lines):
        m = re.search(r"habilidad (.+?) mana (\d+)->(\d+)", line)
        if m:
            ability.append((i, m.group(1), int(m.group(2)), int(m.group(3))))
        m = re.search(r"escudo (\S+) (\d+) ticks \(tick (\d+)\)", line)
        if m:
            shields.setdefault(m.group(1), (int(m.group(2)), int(m.group(3)), i))
        m = re.search(r"escudo (\S+) (fin|muerte) \(tick (\d+)\)", line)
        if m:
            ends.setdefault(m.group(1), (m.group(2), int(m.group(3))))
        m = re.search(r"protector (\S+): (.*) \(tick (\d+)\)", line)
        if m and protector is None:
            entries = {}
            for part in m.group(2).split("; "):
                p = re.match(r"(\S+) " + NUM + r" m (.+)", part)
                if p:
                    entries[p.group(1)] = (float(p.group(2)), p.group(3))
            protector = (m.group(1), int(m.group(3)), entries)
        m = re.search(r"rayo (\S+) (\S+) → (\S+?)(?: \(aliado\))? a " + NUM + r" m: " + NUM + r" \(tick (\d+)\)", line)
        if m:
            rays.append((m.group(2), m.group(3), float(m.group(5)), int(m.group(6))))
    return ability, shields, ends, protector, rays


def verdict(ok, text):
    print("%s  %s" % ("PASS" if ok else "FAIL", text))
    return ok


def check_log(path):
    ability, shields, ends, protector, rays = read_log(path)
    ok = True
    ent = shields.get("Ent1")
    if ent is None:
        return verdict(False, "no hay `escudo Ent1 … ticks`: el Protector no se usó")
    t = ent[1]
    print("T = tick %d (escudo Ent1)" % t)
    # 1. mana and the ability line right after the shield it gave.
    prot = [a for a in ability if a[1] == "Protector"]
    ok &= verdict(bool(prot) and prot[0][2:] == (500, 200), "1. habilidad Protector mana 500->200: %s" % str(prot[0][2:] if prot else "nada"))
    ok &= verdict(ent[0] == SHIELD_TICKS, "2a. escudo Ent1 %d ticks (esperado %d)" % (ent[0], SHIELD_TICKS))
    # 2b. allies on T+1.
    if protector is None:
        ok &= verdict(False, "2b. no hay línea `protector Ent1: …`")
    else:
        who, tick, entries = protector
        ok &= verdict(who == "Ent1" and abs(tick - (t + 1)) <= TOL_TICKS, "2b. protector %s en tick %d (esperado T+1 = %d)" % (who, tick, t + 1))
        for name, want in EXPECTED_VERDICT.items():
            got = entries.get(name)
            flat = horizontal("Ent1", name)
            good = got is not None and got[1] == want and flat - 0.05 <= got[0] <= flat + DIST_TOL_M
            ok &= verdict(good, "2b. %s: %s (esperado %s, %.1f..%.1f m)" % (name, str(got), want, flat, flat + DIST_TOL_M))
        extra = [n for n in entries if n not in EXPECTED_VERDICT]
        ok &= verdict(not extra, "2c. no aparecen otros (Druid4 enemigo, magos): %s" % str(extra or "nadie"))
    # 3. Life Shield of Druid2 at T.
    life = [a for a in ability if a[1] == "Life Shield"]
    ok &= verdict(bool(life) and life[0][2:] == (100, 50), "3. habilidad Life Shield mana 100->50: %s" % str(life[0][2:] if life else "nada"))
    d2 = shields.get("Druid2")
    ok &= verdict(d2 is not None and d2[0] == SHIELD_TICKS and d2[1] == t, "3. escudo Druid2 %s (esperado %d ticks en T)" % (str(d2), SHIELD_TICKS))
    # 4. the Gnome's ray on Druid1, shielded.
    hit = [r for r in rays if r[1] == "Druid1"]
    want = DAMAGE * SHIELD
    if not hit:
        ok &= verdict(False, "4. el rayo del Gnome1 no tocó a Druid1")
    else:
        taken, tick = hit[0][2], hit[0][3]
        d1 = shields.get("Druid1")
        shielded = d1 is not None and d1[1] <= tick < d1[1] + SHIELD_TICKS
        ok &= verdict(shielded and abs(taken - want) <= HEALTH_TOL,
                      "4. Druid1 %.1f -> %.1f en tick %d (esperado %.1f -> %.1f; sin escudo %.1f)" % (
                          DRUID_HEALTH, DRUID_HEALTH - taken, tick, DRUID_HEALTH, DRUID_HEALTH - want, DRUID_HEALTH - DAMAGE))
    # 5. ends.
    for name, start in (("Ent1", t), ("Druid2", t), ("Druid1", t + 1)):
        end = ends.get(name)
        good = end is not None and end[0] == "fin" and abs(end[1] - (start + SHIELD_TICKS)) <= TOL_TICKS
        ok &= verdict(good, "5. escudo %s se apaga: %s (esperado fin en %d)" % (name, str(end), start + SHIELD_TICKS))
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
