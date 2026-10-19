#!/usr/bin/env python3
"""F166 (RFC-030 030w-d): what sacengine would do with the Locust's instant ray (zbba) on debug/f166_locust_ray, replicated from
state.d and the SPEL data, next to what the port logged.

Usage: python3 -I agent/tools/f166_expect.py [godot log of debug/f166_locust_ray (rules debug/rules/f166_locust_ray.tres)]
       python3 -I agent/tools/f166_expect.py --lanes     (only the lane check against the map caches)

Needs the bench switches on (debug/ai/ai_match.gd): ShotStrike.log_strikes, LifeDrain.log_drain (F164).

sacengine:
- locustShoot (11527-11531) creates a LocustShoot; updateLocustShoot (22992-23005) acts in that same frame: collideRay from the
  shot origin up to `range` (zbba: 50 m) with the filter `id != attacker && isValidTarget`, so the first live body of any side
  stops it (buildings too). With a creature or a building it is dealRangedDamage(DamageMod.none) at once: no flight, no
  projectile. With nothing, the visual end is 0.5 * range (the port: RayStrike.miss_fraction, only the beam).
- LocustProjectile (23007-23022) is only visual (blood or rubble flowing back to the Locust at 36 m/s): not a damage.
- The damage is amount * the target's direct ranged resistance (Troll lort 0.9 -> 200 * 0.9 = 180). F164 adds the 0.875 drain (check_drain; Locust2 starts at 50 % for it).
Cast (anchor 1270, 1270; row z-80 and z-70; 0.3 min). Locust1 (slot 1, 50 % health, holds still) at -45/-80; Troll3 (slot 1, pacifist)
at -20/-80 in the line, 3 m before Troll1. A Troll and not a Druid: the Locust hovers 4 m over the ground and its ray goes down at 0.36-0.52
per meter, so it flies over a Druid (2.5 m) at 15 m and only a body of 4 m is still in its way; Troll1 (slot 2, pacifist) at -17/-80. Locust2 at -60/-70 and Troll2 at -35/-70 (free line; 15 m further west than the row of the plan because the jhut at -15/-56 is within 21 m of -20/-70). Both Locusts
get the order «attack» at 0.5 s (audit tick 30).
Log lines:
  bench: Locust1 ataca a Troll1 (tick 30)                                          (ai_match)
  dano Troll3 0 vida 800                                                           (ShotImpact.land -> RockProjectile.report)
  rayo zbba Locust1 → Troll3 (aliado) a 15.1 m: 0.0 (tick 120)                     (RayStrike)
Port axes: x, y up, z.
"""
import importlib.util
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("f131_expect", os.path.join(HERE, "f131_expect.py"))
f131 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(f131)

verdict = f131.verdict
NUM = r"(-?\d+(?:\.\d+)?)"
TOL = 0.01

# name -> (dx, dz, slot, kind) from the anchor
LANES = {
    "L1": (-45.0, -80.0, 1, "Locust"),
    "Y1": (-20.0, -80.0, 1, "Troll"),
    "T1": (-17.0, -80.0, 2, "Troll"),
    "L2": (-60.0, -70.0, 1, "Locust"),
    "T2": (-35.0, -70.0, 2, "Troll"),
}
HALF_BOX = {"Locust": 3.0, "Troll": 3.0}


def zbba():
    """amount and range of the SPEL, and the Troll's direct ranged resistance, from the data of the port."""
    root = os.path.join(HERE, "..", "..", "assets", "original", "data")
    spel = json.load(open(os.path.join(root, "abilities.json"), encoding="utf-8"))["zbba"]
    troll = json.load(open(os.path.join(root, "creatures.json"), encoding="utf-8"))["lort"]
    return float(spel["amount"]), float(spel["range"]), float(troll["resistances"]["direct_ranged"])


def check_lanes():
    return f131.lane_report(LANES, half_box=HALF_BOX, big_struct={"jhut": 16.0})


def read(lines):
    """Rays in order: dict(shooter, target, ally, dist, taken, tick, dano) where dano is the `dano` line printed just before."""
    rays, bench = [], {}
    last_dano = None
    for line in lines:
        m = re.match(r"bench: (\S+) ataca a (\S+) \(tick (\d+)\)", line)
        if m:
            bench[m.group(1)] = (m.group(2), int(m.group(3)))
            continue
        m = re.match(r"dano (\S+) " + NUM + r" vida " + NUM, line)
        if m:
            last_dano = (m.group(1), float(m.group(2)), float(m.group(3)))
            continue
        m = re.match(r"rayo zbba (\S+) → (\S+?)( \(aliado\))? a " + NUM + r" m: (?:sin daño \(aliado\) )?(?:" + NUM + r" )?\(tick (\d+)\)", line)
        if m:
            rays.append(dict(shooter=m.group(1), target=m.group(2), ally=bool(m.group(3)), dist=float(m.group(4)),
                             taken=float(m.group(5)) if m.group(5) else 0.0, tick=int(m.group(6)), dano=last_dano))
            last_dano = None
            continue
        m = re.match(r"rayo zbba (\S+) → (\S+) a " + NUM + r" m \(tick (\d+)\)", line)
        if m:
            rays.append(dict(shooter=m.group(1), target=None, ally=False, dist=float(m.group(3)), taken=0.0, tick=int(m.group(4)),
                             dano=None))
    return rays, bench


def check_log(path):
    amount, reach, resist = zbba()
    want = round(amount * resist, 2)
    print("zbba: %.0f de monto, alcance %.0f m, Troll directo %.2f -> %.1f por rayo; Troll3 aliado: 0 (fuego amigo apagado)" % (
        amount, reach, resist, want))
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    rays, bench = read(lines)
    ok = verdict(not any("SCRIPT ERROR" in l for l in lines), "sin SCRIPT ERROR")
    ok &= verdict(len(rays) > 0, "hay rayos de zbba en el log: %d" % len(rays))
    # A free line: every ray of Locust2 lands on Troll2 for amount * resistance, in the tick the ray is cast.
    free = [r for r in rays if r["shooter"] == "Locust2"]
    ok &= verdict(bool(free), "Locust2 dispara: %d rayos" % len(free))
    hits = [r for r in free if r["target"] is not None]
    for r in free:
        if r["target"] is None:
            # the accuracy (800) sent it past the Troll: it ends on the ground, nobody takes anything, no `dano` line before it
            ok &= verdict(r["dano"] is None and r["dist"] <= reach + 0.01,
                          "Locust2 -> suelo a %.1f m (tick %d): sin daño (la precisión lo desvió)" % (r["dist"], r["tick"]))
            continue
        good = (r["target"] == "Troll2" and abs(r["taken"] - want) <= TOL and r["dist"] <= reach + 0.01 and
                r["dano"] is not None and r["dano"][0] == "Troll2" and abs(r["dano"][1] - round(want)) <= 0.5)
        ok &= verdict(good, "Locust2 -> Troll2 a %.1f m: %.2f (esperado %.2f, mismo tick %d del disparo, sin vuelo)" % (
            r["dist"], r["taken"], want, r["tick"]))
    ok &= verdict(len(hits) >= 3, "al menos 3 rayos de Locust2 dan en Troll2: %d de %d" % (len(hits), len(free)))
    first = bench.get("Locust2")
    if first and free:
        ok &= verdict(free[0]["tick"] >= first[1], "primer rayo de Locust2 en el tick %d, después de la orden del tick %d" % (
            free[0]["tick"], first[1]))
    # The line with the friend: the ray stops at Troll3, which takes nothing, and Troll1 is never reached.
    blocked = [r for r in rays if r["shooter"] == "Locust1"]
    ok &= verdict(bool(blocked), "Locust1 dispara: %d rayos" % len(blocked))
    stops = [r for r in blocked if r["target"] == "Troll3" and r["ally"] and abs(r["taken"]) <= TOL]
    ok &= verdict(len(stops) > 0, "el rayo de Locust1 frena en Troll3 (aliado) sin daño: %d de %d" % (len(stops), len(blocked)))
    ok &= verdict(not any(r["target"] == "Troll1" for r in blocked), "ningún rayo de Locust1 llega a Troll1 (detrás de Troll3)")
    ok &= verdict(not any(re.match(r"dano Troll1 ", l) for l in lines), "Troll1 no recibe daño de ese rayo")
    ok &= verdict(all(r["dist"] <= reach + 0.01 for r in rays), "ningún rayo pasa del alcance de %.0f m" % reach)
    ok &= check_drain(lines, hits, free)
    return ok


def check_drain(lines, hits, free):
    """F164 (state.d:8834-8840): every ray of Locust2 that takes health heals 0.875 · the direct hit in its own tick, up to the
    maximum (450); Locust2 starts at 50 %. Locust1 hit nobody (Troll3 is an ally and takes 0) and never feeds."""
    pazb = json.load(open(os.path.join(HERE, "..", "..", "assets", "original", "data", "creatures.json"), encoding="utf-8"))["pazb"]
    full, scale = float(pazb["health"]), float(pazb["drain"])
    feeds = []
    for line in lines:
        m = re.match(r"drena (\S+) de (\S+) " + NUM + r" \(escala " + NUM + r"\) -> vida " + NUM + r" ganada " + NUM + r" \(tick (\d+)\)", line)
        if m:
            feeds.append((m.group(1), m.group(2), float(m.group(3)), float(m.group(4)), float(m.group(5)), float(m.group(6)), int(m.group(7))))
    ok = verdict(not any(f[0] == "Locust1" for f in feeds), "Locust1 (su rayo frena en el aliado, sin daño) no tiene líneas de cura")
    hp = full * 0.5
    capped = 0
    for r in hits:
        want = min(full, hp + scale * r["taken"])
        gained, hp = want - hp, want
        fed = [f for f in feeds if f[0] == "Locust2" and f[6] == r["tick"]]
        if gained <= TOL / 10:
            capped += 1
            ok &= verdict(not fed, "tick %d: rayo %.2f con la vida al tope de %.0f: sin línea de cura" % (r["tick"], r["taken"], full))
        else:
            good = len(fed) == 1 and abs(fed[0][2] - r["taken"]) <= TOL and abs(fed[0][5] - gained) <= TOL and abs(fed[0][4] - hp) <= TOL
            ok &= verdict(good, "tick %d: rayo %.2f -> Locust2 cura %.4f (esperado %.4f · %.3f), vida %.4f" % (
                r["tick"], r["taken"], fed[0][5] if fed else 0.0, gained, scale, hp))
    ok &= verdict(any(f[0] == "Locust2" for f in feeds), "Locust2 cura al menos una vez: %d líneas" % sum(1 for f in feeds if f[0] == "Locust2"))
    ok &= verdict(all(f[0] in ("Locust2",) for f in feeds), "solo Locust2 aparece en las líneas de cura")
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
