#!/usr/bin/env python3
"""F151 (RFC-030 030n-b): what sacengine would do with the Rhinok's Spikey Death (hrba) the log names.

Usage:
  python3 -I agent/tools/f151_expect.py <godot log of the f125/f151 bench case>
  python3 -I agent/tools/f151_expect.py --tabla [effect_range]     the rings alone (distance -> ring -> frame)

Needs the bench switches on (debug/ai_match.gd): GroundHug.log_flight and SpikeWave.log_spikes.

- Flight (updateRhinokProjectile, phase moving, state.d:24963-24974): every tick the shot is back on the land; the port
  flies `LIFT` m over it (declared): |y - (land + 0.05)| <= 0.06.
- Hit (24966-24983): the body its 5 m box meets takes the whole amount as splash ranged damage (dealRangedDamage,
  DamageMod.splash): 500 * splash ranged resistance. At the end of the range the shot's target, if alive, takes the same.
- Rings (24984-25003): frame 0 is the tick of the hit. Ring i (0-based) hurts on frame DAMAGE_FRAMES[i]; it goes from
  MIN_RADIUS + i * offset to that + STRIP, offset = (effectRange - STRIP - MIN_RADIUS) / (rings - 1). A body counts when
  its feet, seen from above, are between the two radii; it is on the land and at most MAX_HEIGHT over it; it is not the
  body hurt by the hit; it is not of the shooter's side unless it is the shot's target. Each takes the whole amount
  (splash ranged), once per ring: a body where two rings overlap takes both. The wave ends on frame LIFE (90).
The bodies come from the wave's own list (`anillos ... cuerpo ...`, where they stand on the tick of the hit); the pacifist
targets do not move. Resistances come from cache/data/creatures.json by the body's name without its number
(Druid2 -> Druid); a body without one (a building) is listed with its damage as `?`.
Port axes (x, y up, z): "seen from above" is (x, z).
"""
import json
import math
import os
import re
import sys

AMOUNT = 500.0
LIFT = 0.05
LIFT_TOLERANCE = 0.06
STRIP = 6.0
MIN_RADIUS = 1.0
MAX_HEIGHT = 10.0
DAMAGE_FRAMES = [14, 29, 44, 59, 89]
LIFE = 90
NUM = r"(-?\d+(?:\.\d+)?)"
VEC = r"\(" + NUM + r", " + NUM + r", " + NUM + r"\)"


def ring_bounds(effect_range):
    n = len(DAMAGE_FRAMES)
    offset = (effect_range - STRIP - MIN_RADIUS) / (n - 1)
    return [(MIN_RADIUS + i * offset, MIN_RADIUS + i * offset + STRIP) for i in range(n)]


def rings_of(distance, effect_range):
    """The rings (0-based) whose strip holds `distance`: the replica of distance -> ring -> frame."""
    return [i for i, (lo, hi) in enumerate(ring_bounds(effect_range)) if lo <= distance <= hi]


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
    """Druid12 -> Druid: the damage line (`dano`) names the body by its display name."""
    return re.sub(r"\d+$", "", name)


def expected_damage(res, name, amount):
    r = res.get(kind_of(name))
    if r is None:
        return None
    return round(amount * float(r.get("splash_ranged", 1.0)))


def table(effect_range):
    print("anillos con alcance %.1f m:" % effect_range)
    for i, (lo, hi) in enumerate(ring_bounds(effect_range)):
        print("  anillo %d/%d: de %.2f a %.2f m, cuadro +%d" % (i + 1, len(DAMAGE_FRAMES), lo, hi, DAMAGE_FRAMES[i]))
    print("  fin: cuadro +%d" % LIFE)


def expected_rings(wave, res):
    """(ring 1-based, body) -> (reason, frame, distance, damage) for every body of the wave's list."""
    out = {}
    for name, body in wave["bodies"].items():
        if body["max"] <= 0:
            continue
        dx = body["feet"][0] - wave["center"][0]
        dz = body["feet"][2] - wave["center"][2]
        distance = math.hypot(dx, dz)
        for i in rings_of(distance, wave["range"]):
            if name == wave["touched"]:
                continue
            if not body["land"]:
                reason = "fuera de la tierra"
            elif body["feet"][1] > body["ground"] + MAX_HEIGHT:
                reason = "alto"
            elif wave["slot"] > 0 and body["side"] == wave["slot"] and name != wave["intended"]:
                reason = "aliado, sin daño"
            else:
                reason = "daño"
            damage = expected_damage(res, name, wave["amount"]) if reason == "daño" else 0
            out[(i + 1, name)] = (reason, DAMAGE_FRAMES[i], distance, damage)
    return out


def main():
    if len(sys.argv) >= 2 and sys.argv[1] == "--tabla":
        table(float(sys.argv[2]) if len(sys.argv) > 2 else 30.0)
        return
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    lines = open(sys.argv[1], encoding="utf-8", errors="replace").read().splitlines()
    res = resistances()
    waves = {}
    order = []
    hits = []
    got = {}
    pending = None
    current = None
    flight_worst = {}
    for line in lines:
        m = re.search(r"pegado (\S+) tick (\d+) en " + VEC + r" suelo " + NUM, line)
        if m:
            off = abs(float(m.group(4)) - (float(m.group(6)) + LIFT))
            flight_worst[m.group(1)] = max(flight_worst.get(m.group(1), (0.0, 0))[0], off), int(m.group(2))
            continue
        m = re.search(r"púas (\S+) (\S+) choca con (.+) en " + VEC + r" \(cuadro (\d+)\)", line)
        if m:
            hits.append(dict(shot=m.group(2), who=m.group(3), tick=int(m.group(7)), how="choca"))
            pending = (m.group(3), expected_damage(res, m.group(3), AMOUNT), "golpe")
            continue
        m = re.search(r"púas (\S+) (\S+) agota el alcance en " + VEC + r", pedido (.+?) \(cuadro (\d+)\)", line)
        if m:
            who = m.group(6)
            alive = who.endswith(" vivo")
            hits.append(dict(shot=m.group(2), who=who, tick=int(m.group(7)), how="alcance"))
            pending = (who[:-5], expected_damage(res, who[:-5], AMOUNT), "golpe") if alive else None
            continue
        m = re.search(r"anillos (\S+) (\S+) en " + VEC + r" alcance " + NUM + r" m daño (\d+) bando (-?\d+) pedido (.+) tocado (.+) anillos .* \(cuadro (\d+)\)", line)
        if m:
            key = m.group(2)
            waves[key] = dict(center=[float(m.group(i)) for i in (3, 4, 5)], range=float(m.group(6)), amount=float(m.group(7)),
                              slot=int(m.group(8)), intended=m.group(9), touched=m.group(10), born=int(m.group(11)), bodies={},
                              end=None)
            order.append(key)
            continue
        m = re.search(r"anillos (\S+) (\S+) cuerpo (.+) pies " + VEC + r" suelo " + NUM + r" tierra (sí|no) bando (-?\d+) vida máx (\d+)", line)
        if m and m.group(2) in waves:
            waves[m.group(2)]["bodies"][m.group(3)] = dict(feet=[float(m.group(i)) for i in (4, 5, 6)], ground=float(m.group(7)),
                                                         land=m.group(8) == "sí", side=int(m.group(9)), max=int(m.group(10)))
            continue
        m = re.search(r"anillo (\d+)/(\d+) (\S+) (\S+) \+(\d+) de " + NUM + r" a " + NUM + r" m \(cuadro (\d+)\)", line)
        if m:
            current = (m.group(4), int(m.group(1)), int(m.group(8)))
            continue
        m = re.search(r"^\s+anillo (\d+) (.+) a " + NUM + r" m: (.+)$", line)
        if m and current:
            wave, ring, tick = current
            name = m.group(2)
            got.setdefault(wave, {})[(ring, name)] = dict(reason=m.group(4).strip(), tick=tick, distance=float(m.group(3)), damage=None)
            pending = (name, (wave, ring), "anillo") if m.group(4).strip() == "daño" else pending
            continue
        m = re.search(r"dano (.+) (\d+) vida (\d+)", line)
        if m and pending and m.group(1) in (pending[0], kind_of(pending[0])):
            if pending[2] == "anillo":
                wave, ring = pending[1]
                got[wave][(ring, pending[0])]["damage"] = int(m.group(2))
            else:
                hits[-1]["damage"] = int(m.group(2))
                hits[-1]["expected"] = pending[1]
            pending = None
            continue
        m = re.search(r"anillos (\S+) (\S+) fin \+(\d+) \(cuadro (\d+)\)", line)
        if m and m.group(2) in waves:
            waves[m.group(2)]["end"] = (int(m.group(3)), int(m.group(4)))

    bad = 0
    for shot, (worst, ticks) in sorted(flight_worst.items()):
        ok = worst <= LIFT_TOLERANCE
        bad += 0 if ok else 1
        print("VUELO %s: %d ticks, peor |y - (suelo + %.2f)| = %.3f%s" % (shot, ticks, LIFT, worst, "" if ok else "  FUERA ±%.2f" % LIFT_TOLERANCE))
    for hit in hits:
        line = "GOLPE %s %s %s en el cuadro %d" % (hit["shot"], hit["how"], hit["who"], hit["tick"])
        if "damage" in hit:
            exp = hit.get("expected")
            same = exp is None or exp == hit["damage"]
            bad += 0 if same else 1
            line += ": daño %d, esperado %s%s" % (hit["damage"], "?" if exp is None else exp, "" if same else "  DISTINTO")
        print(line)
    for key in order:
        wave = waves[key]
        print("ANILLOS %s desde (%.2f, %.2f) cuadro %d, alcance %.1f m, bando %d, pedido %s, tocado %s" % (key, wave["center"][0],
              wave["center"][2], wave["born"], wave["range"], wave["slot"], wave["intended"], wave["touched"]))
        for i, (lo, hi) in enumerate(ring_bounds(wave["range"])):
            print("  anillo %d: %.2f-%.2f m en el cuadro %d" % (i + 1, lo, hi, wave["born"] + DAMAGE_FRAMES[i]))
        expected = expected_rings(wave, res)
        port = got.get(key, {})
        for (ring, name) in sorted(set(expected) | set(port)):
            exp = expected.get((ring, name))
            have = port.get((ring, name))
            if exp is None:
                bad += 1
                print("  %s anillo %d: esperado nada; port %s en el cuadro %d a %.3f m  DISTINTO" % (name, ring, have["reason"], have["tick"], have["distance"]))
                continue
            reason, frame, distance, damage = exp
            tick = wave["born"] + frame
            text = "  %s a %.3f m -> anillo %d -> cuadro %d: %s%s" % (name, distance, ring, tick, reason,
                                                                       " %s" % ("?" if damage is None else damage) if reason == "daño" else "")
            if have is None:
                bad += 1
                print(text + "; port nada  DISTINTO")
                continue
            same = have["reason"] == reason and abs(have["tick"] - tick) <= 1
            if reason == "daño" and damage is not None and have["damage"] is not None:
                same = same and have["damage"] == damage
            bad += 0 if same else 1
            print(text + "; port %s cuadro %d%s%s" % (have["reason"], have["tick"],
                  " daño %s" % have["damage"] if have["damage"] is not None else "", "" if same else "  DISTINTO"))
        end = wave["end"]
        if end is None:
            bad += 1
            print("  fin: no aparece  DISTINTO")
        else:
            same = end[0] == LIFE and end[1] == wave["born"] + LIFE
            bad += 0 if same else 1
            print("  fin +%d en el cuadro %d, esperado +%d en el %d%s" % (end[0], end[1], LIFE, wave["born"] + LIFE, "" if same else "  DISTINTO"))
    print("RESULTADO %s (%d diferencias)" % ("PASS" if bad == 0 and (order or hits) else "FAIL", bad))


if __name__ == "__main__":
    main()
