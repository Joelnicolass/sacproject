#!/usr/bin/env python3
"""F123 (RFC-030l): what sacengine would do with the fire shots of debug/f123_fire_shots, replicated from state.d, next to
what the port logged.

Usage: python3 -I agent/tools/f123_expect.py [godot log of debug/f123_fire_shots or the f123 bench case]

Model:
- setAblaze / setAblazeWithManaDrain (state.d:27670-27676): damage / lifetime per frame, manaDrain / lifetime per frame.
- updateFire (15112-15130): deal, drain (never under 0), `return lifetime-- > 0`: lifetime + 1 updates.
- dealDamage (8948-8972): × max(0, resistance) of the kind; peirceShield skips the shields (none on the lanes).
- Tickferno sfba (23797-23810): 237 over 60 frames, mana drain 0.5 · max mana, on a Druid (direct ranged 0.9, mana 100).
- Pyromaniac lffa (24314-24321): 960 over 300 frames, ranged, peirceShield, on a Trogg (direct ranged 0.9).
- Bombard cfba (24518-24528): 575 splash ranged on the body it hit, 575 · (1 - d/10) on the rest (splash ranged 0.9), and a
  fire of no damage for 60 frames (61 updates) on each.
- Flight: straight shots fly speed/60 a frame (sfba 48, lffa 60); cfba falls with g 30.
"""
import re
import sys

T = 60


def fire(damage, lifetime, resist, mana_max=0.0, drain_fraction=0.0):
    updates = lifetime + 1
    taken = damage / lifetime * resist * updates
    mana = max(0.0, mana_max - drain_fraction * mana_max / lifetime * updates) if drain_fraction else mana_max
    return taken, updates, mana


def expected():
    rows = []
    taken, updates, mana = fire(237.0, 60, 0.9, 100.0, 0.5)
    rows.append(("A Tickferno -> Druid", f"fuego total {taken:.1f} en {updates} actualizaciones, maná 100 -> {mana:.2f}"))
    taken, updates, _ = fire(960.0, 300, 0.9)
    rows.append(("B Pyromaniac -> Trogg", f"fuego total {taken:.1f} en {updates} actualizaciones, sin daño directo"))
    rows.append(("C Bombard -> tocado", f"salpicadura {575 * 0.9:.1f}, fuego total 0.0 en 61 actualizaciones"))
    for d in (1.0, 2.0, 3.0, 4.0):
        rows.append((f"C Bombard -> a {d:.0f} m de la caja", f"salpicadura {575 * (1 - d / 10) * 0.9:.2f}"))
    for name, dist, speed in (("A heat ray 40 m", 40.0, 48.0), ("B cohete 50 m", 50.0, 60.0)):
        rows.append((f"vuelo {name}", f"{dist / speed * T:.1f} ticks (±2)"))
    return rows


LINE = re.compile(r"^(fuego .*|salpicadura .*|  directo .*|  \S+ a [0-9.]+ m)$")


def main():
    for label, value in expected():
        print(f"{label:34s} {value}")
    if len(sys.argv) < 2:
        return
    print("\n--- log del port ---")
    drains = []
    with open(sys.argv[1], encoding="utf-8", errors="replace") as log:
        for line in log:
            line = line.rstrip("\n")
            if LINE.match(line) or re.match(r"^\S+ fuego ", line):
                print(line)
            m = re.match(r"^drena (\S+) de ", line)
            if m:
                drains.append(m.group(1))
    # F164c: the fire feeds LifeDrain with its attacker (dealFireDamage -> dealDamage, state.d:9421-9427, 8940), but the Tickferno,
    # the Pyromaniac and the Bombard have drain 0 (creatures.json: craf, plff, wlcf): healFromDrain gives nothing, so no "drena" line
    # may name them. (A fire with a drainer is covered by rules_suite guard_fire.)
    bad = [d for d in drains if re.match(r"(Tickferno|Pyromaniac|Bombard)\d", d)]
    print("F123 drenaje del fuego: %s (líneas drena de los lanzadores de fuego: %s)" % ("PASS" if not bad else "FAIL", bad))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
