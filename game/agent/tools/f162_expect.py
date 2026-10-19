#!/usr/bin/env python3
"""F162 (RFC-030 030w-c): what sacengine would do with the Spitfire's fire wave (fhba) and the Gargoyle's wave (ehba) on the lanes of
debug/f162_waves, replicated from state.d and the SPEL data, next to what the port logged. The geometry helpers are f149_expect.py's
(the same walk as the Silverback's breath), the lane helpers f131_expect.py's.

Usage: python3 -I agent/tools/f162_expect.py [godot log of debug/f162_waves (rules debug/rules/f162_waves.tres)]
       python3 -I agent/tools/f162_expect.py --lanes     (only the lane check against the map caches)
       python3 -I agent/tools/f162_expect.py --numbers   (the figures of the replica, no log)

Needs the bench switch on (debug/ai/ai_match.gd): GrowingWave.log_touches. Lines read:
  onda ShotN tick 1 en (x, y, z) dir (…) paso … radio final R en F ticks a <blanco> (cuadro N)
  onda ShotN toca <cuerpo> tick N en (…) a D m radio r caja (cx, cy, cz) ± (hx, hy, hz): directo|salpicadura|mismo bando
  dano <cuerpo> <daño> vida <vida>
  fuego <cuerpo> total T en U actualizaciones vida V
  (F162b: la onda del Spitfire P3 pasa por la choza `jhut` de la aldea; el fuego de 0 de daño sobre un edificio termina en su primera
   actualización, `fuego <choza> total 0.0 en 1 actualizaciones`: updateFire 15117-15118 devuelve false sin daño ni partículas.)

sacengine:
- updateSpitfireProjectile (23025-23069), updateGargoyleProjectile (23079-23113): the wave flies its whole range without hitting
  (remainingDistance counts down in float32) and on update n (frame n - 1) has the radius final · (n - 1) / (60 · range / speed):
  7,5 m for the Spitfire (range 34, amount 150) and 6 m for the Gargoyle (range 40, amount 125), both at 36 m/s. Every update it walks
  dealDamageAt (9075-9089); each body is taken once in the flight (damagedTargets).
- Callback: the shot's target takes dealRangedDamage whole (the Spitfire's with DamageMod.ignite) and then setAblaze(30, 0); a body
  of the shooter's side nothing; any other body setAblaze(30, 0) and then the splash amount · (1 - d / r) as ranged|splash|ignite.
  The fire is of 0 damage (setAblaze(id, updateFPS / 2, true, 0.0f)): 30 frames last 31 updates (lifetime + 1), total 0.
- The Gargoyle's wave has neither fire nor ignite.
Lane rows (anchor 1270, 1270): z-56 P3 Spitfire2 (slot 1) -45 attacks W5 Trogg5 -24 (the wave flies on to the jhut at -14.7, -56.2, the
building the fire reaches), z-80 P1 Spitfire1 (slot 1) -45, W1 Trogg1 -20 (target), W2 Trogg2 -24/-77 (splash), A1 Druid1 (slot 1) -30/-78;
z-36 G1 Gargoyle1 (slot 1) -45, W3 Trogg3 -20 (target), W4 Trogg4 -24/-33 (splash). P1 attacks W1 and G1 attacks W3 at 0,5 s.
Port axes: x, y up, z. The resistances come from assets/original/data/creatures.json.
"""
import importlib.util
import json
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def _load(name):
    spec = importlib.util.spec_from_file_location(name, os.path.join(HERE, name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


f131 = _load("f131_expect")
f149 = _load("f149_expect")

verdict = f131.verdict
NUM = f131.NUM
VEC = f149.VEC
FPS = 60
SPEED = 36.0
FIRE_UPDATES = 31
RADIUS_TOL = 0.001
DAMAGE_TOL = 0.5

# shot -> (shooter, amount, range, final radius, target)
WAVES = {
    "Spitfire": (150.0, 34.0, 7.5),
    "Gargoyle": (125.0, 40.0, 6.0),
}
# name -> (dx, dz, slot, kind) from the anchor. The plan's row z-66 has the jhut of the village at the end of the wave's flight (it flies
# its whole range, 40 m, past the target and touched the building): moved to z-36, verified with --lanes along the whole flight.
LANES = {
    "P1": (-45.0, -80.0, 1, "Spitfire"),
    "W1": (-20.0, -80.0, 2, "Trogg"),
    "W2": (-24.0, -77.0, 2, "Trogg"),
    "A1": (-30.0, -78.0, 1, "Druid"),
    "G1": (-45.0, -36.0, 1, "Gargoyle"),
    "W3": (-20.0, -36.0, 2, "Trogg"),
    "W4": (-24.0, -33.0, 2, "Trogg"),
}
# The hut row: the Spitfire's wave must reach the jhut of the village, so it is not under the big-structure clearance of the others.
HUT_LANES = {
    "P3": (-45.0, -56.0, 1, "Spitfire"),
    "W5": (-24.0, -56.0, 2, "Trogg"),
}
# Real body, not the centre: the half width of a Trogg/Druid is small; the fliers are in the air and do not matter for the ground.
HALF_BOX = {"Spitfire": 1.5, "Gargoyle": 1.5, "Trogg": 1.0, "Druid": 0.5}
BIG_STRUCT = {"jhut": 16.0}
BODY = {"Trogg1": "W1", "Trogg2": "W2", "Druid1": "A1", "Trogg3": "W3", "Trogg4": "W4", "Trogg5": "W5"}
# target of each wave -> kind. The hut row (P3 -> W5) is checked apart: the jhut is the building the fire reaches.
WAVE_TARGETS = {"Trogg1": "Spitfire", "Trogg5": "Spitfire", "Trogg3": "Gargoyle"}
HUT = (-14.7, -56.2)  # jhut of the village, from the anchor (maps/high_noon/ntts.json)
HUT_ROW = ("P3", "W5")


def updates(reach):
    """remainingDistance in float32, as sacengine counts it down; the update that takes it to <= 0 still deals damage."""
    remaining = f149.f32(reach)
    step = f149.f32(f149.f32(SPEED) / FPS)
    n = 0
    while True:
        n += 1
        remaining = f149.f32(remaining - step)
        if remaining <= 0.0:
            return n


def numbers():
    for who, (amount, reach, final) in WAVES.items():
        print("%s: monto %.0f alcance %.0f radio final %.1f: %d actualizaciones, radio en la n-ésima = %.1f · (n-1) / %.4f" % (
            who, amount, reach, final, updates(reach), final, FPS * reach / SPEED))
    print("fuego del Spitfire: 0 de daño, %d actualizaciones" % FIRE_UPDATES)


def path_points():
    """The wave does not stop at its target: it flies its whole range along the row (y is the creature's, the lane check measures the
    ground), so the points of the flight every 10 m must be as free as the bodies' (a village at the end of it would be touched)."""
    points = {}
    for shooter, reach in (("P1", WAVES["Spitfire"][1]), ("G1", WAVES["Gargoyle"][1])):
        dx, dz, slot, _ = LANES[shooter]
        n = 1
        while n * 10.0 <= reach:
            points["%s+%d" % (shooter, n * 10)] = (dx + n * 10.0, dz, slot, "Spitfire")
            n += 1
        points["%s+end" % shooter] = (dx + reach, dz, slot, "Spitfire")
    return points


def check_lanes():
    lanes = dict(LANES)
    lanes.update(path_points())
    ok = f131.lane_report(lanes, half_box=HALF_BOX, big_struct=BIG_STRUCT)
    for a, b in (("P1", "W1"), ("P1", "W2"), ("P1", "A1"), ("G1", "W3"), ("G1", "W4")):
        print("%s -> %s: %.2f m en planta" % (a, b, f131.flat(LANES, a, b)))
    cross = min(f131.flat(LANES, a, b) for a in ("P1", "W1", "W2", "A1") for b in ("G1", "W3", "W4"))
    good = cross > WAVES["Spitfire"][2] + 3.0
    ok = ok and good
    print("fila z-80 a fila z-36: al menos %.2f m (más que el radio 7,5 de la onda del Spitfire y un margen) %s" % (cross, "ok" if good else "MAL"))
    return check_hut_row() and ok


def check_hut_row():
    """P3 -> W5 at z-56: ground and no holes, no other structure or prop near, the hut far from W5's box and inside the wave's radius when
    the wave passes it (the hut's box holds its centre, so the wave touches it whatever its size)."""
    ok = True
    terrain = f131.base.Terrain.load()
    try:
        ntts = json.load(open(f131.base.map_file("ntts.json"), encoding="utf-8"))
        widgets = json.load(open(f131.base.map_file("widgets.json"), encoding="utf-8"))
    except OSError:
        print("(sin assets/original/maps/high_noon/ntts.json: se omite la fila de la choza)")
        return True
    ax, az = f131.ANCHOR
    hut = (ax + HUT[0], az + HUT[1])
    found = [s for s in ntts.get("structures", []) if s["tag"] == "jhut" and math.hypot(s["x"] - hut[0], s["z"] - hut[1]) < 0.2]
    ok &= verdict(len(found) == 1, "5. la choza jhut de la aldea está en (%.1f, %.1f) del ancla: %s" % (HUT[0], HUT[1], len(found)))
    for name, (dx, dz, _, kind) in HUT_LANES.items():
        x, z = ax + dx, az + dz
        near = [(s["tag"], round(math.hypot(s["x"] - x, s["z"] - z), 1)) for s in ntts.get("structures", [])
                if s["tag"] != "jhut" and math.hypot(s["x"] - x, s["z"] - z) < 11.0]
        props = [k for k, ps in widgets.items() for p in ps if math.hypot(p[0] - x, p[1] - z) < HALF_BOX[kind] + 2.0]
        to_hut = math.hypot(hut[0] - x, hut[1] - z)
        ground = terrain.ground(x, z) if terrain else None
        bad = near or props or (terrain is not None and ground is None) or (name == "W5" and to_hut < 6.0)
        ok &= not bad
        print("carril %-3s (%.1f, %.1f) suelo %s otras estructuras<11 %s widgets %s choza a %.1f m %s" % (
            name, x, z, "?" if ground is None else "%.2f" % ground, near, props, to_hut, "MAL" if bad else "ok"))
    if terrain:
        holes = 0
        x = ax - 50.0
        while x <= ax - 8.0:
            for ddz in (-4.0, 0.0, 4.0):
                if terrain.ground(x, az + HUT_LANES["P3"][1] + ddz) is None:
                    holes += 1
            x += 2.5
        ok &= verdict(holes == 0, "5. sin huecos en el suelo a lo largo de la fila de la choza: %d" % holes)
    p, w = HUT_LANES["P3"], HUT_LANES["W5"]
    reach = WAVES["Spitfire"][1]
    flown = HUT[0] - p[0]
    radius = WAVES["Spitfire"][2] * flown / reach
    ok &= verdict(flown < reach and abs(HUT[1] - p[1]) < radius, "5. la onda de P3 llega a la choza (a %.1f m de 34, radio %.1f, desvío %.1f m)" % (flown, radius, abs(HUT[1] - p[1])))
    others = [LANES[k] for k in ("P1", "W1", "W2", "A1", "G1", "W3", "W4")]
    cross = [math.hypot(a[0] - b[0], a[1] - b[1]) for a in (p, w) for b in others]
    ok &= verdict(min(cross) > WAVES["Spitfire"][2] + 3.0, "5. la fila de la choza a las otras: al menos %.2f m (más que el radio 7,5 y un margen)" % min(cross))
    return ok


def check_log(path):
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    res = f149.resistances()
    ok = True
    waves = {}
    touches = []
    fires = []
    damage = {}
    last = None
    for line in lines:
        m = re.search(r"onda (\S+) tick 1 en " + VEC + r" dir " + VEC + r" paso " + NUM + r" radio final " + NUM + r" en " + NUM + r" ticks a (\S+)", line)
        if m:
            waves[m.group(1)] = dict(p1=[float(m.group(i)) for i in (2, 3, 4)], dir=[float(m.group(i)) for i in (5, 6, 7)],
                                     step=float(m.group(8)), final=float(m.group(9)), frames=float(m.group(10)), target=m.group(11))
            continue
        m = re.search(r"onda (\S+) toca (\S+) tick (\d+) en " + VEC + r" a " + NUM + r" m radio " + NUM + r" (caja \(.*\)|caja \?): (.+)$", line)
        if m:
            box = re.findall(NUM, m.group(9)) if m.group(9).startswith("caja (") else None
            last = dict(shot=m.group(1), who=m.group(2), tick=int(m.group(3)), dist=float(m.group(7)), radius=float(m.group(8)),
                        box=[float(x) for x in box] if box else None, what=m.group(10).strip(), damage=None)
            touches.append(last)
            continue
        m = re.search(r"^dano (\S+) (-?\d+) vida (\d+)", line)
        if m and last and last["who"] == m.group(1) and last["damage"] is None:
            last["damage"] = int(m.group(2))
            continue
        m = re.search(r"^fuego (\S+) total " + NUM + r" en (\d+) actualizaciones", line)
        if m:
            fires.append((m.group(1), float(m.group(2)), int(m.group(3))))
    names = sorted(waves)
    ok &= verdict(len(waves) >= 3, "0. al menos tres ondas (Spitfire P1, Spitfire P3, Gargoyle; P3 puede tirar una segunda antes de morir) con su línea de inicio: %s" % names)
    pairs = [(WAVE_TARGETS.get(w["target"]), shot) for shot, w in sorted(waves.items())]
    ok &= verdict(all(k for k, _ in pairs) and {w["target"] for w in waves.values()} == set(WAVE_TARGETS), "0. blancos de las ondas: %s" % [(k, waves[sh]["target"]) for k, sh in pairs])
    for kind, shot in pairs:
        if kind is None:
            continue
        amount, reach, final = WAVES[kind]
        w = waves[shot]
        ok &= verdict(abs(w["final"] - final) < 0.005 and abs(w["frames"] - FPS * reach / SPEED) < 0.001,
                      "0. %s (%s): radio final %.2f en %.4f ticks (esperado %.1f en %.4f)" % (kind, shot, w["final"], w["frames"], final, FPS * reach / SPEED))
        mine = [t for t in touches if t["shot"] == shot]
        names = [t["who"] for t in mine]
        ok &= verdict(len(names) == len(set(names)), "4. %s: cada cuerpo se toma una vez: %s" % (kind, names))
        bad_radius = []
        bad_first = []
        for t in mine:
            expected_r = final * (t["tick"] - 1) / w["frames"]
            if abs(expected_r - t["radius"]) > RADIUS_TOL:
                bad_radius.append((t["who"], t["tick"], t["radius"], round(expected_r, 3)))
            if t["box"]:
                center, half = t["box"][:3], t["box"][3:6]
                first = None
                for n in range(1, updates(reach) + 1):
                    point = [w["p1"][i] + (n - 1) * w["step"] * w["dir"][i] for i in range(3)]
                    radius = final * (n - 1) / w["frames"]
                    if radius > 0.0 and f149.box_distance(point, center, half) <= radius:
                        first = n
                        break
                if first != t["tick"]:
                    bad_first.append((t["who"], t["tick"], first))
        ok &= verdict(not bad_radius, "2. %s: el radio de cada toca es %.1f · (n-1) / %.3f (±%.3f): fallan %s" % (kind, final, w["frames"], RADIUS_TOL, bad_radius))
        ok &= verdict(not bad_first, "2. %s: cada cuerpo se toca en la primera actualización que su caja entra en el radio: fallan %s" % (kind, bad_first))
        direct = [t for t in mine if t["what"] == "directo"]
        ok &= verdict(len(direct) == 1 and direct[0]["who"] == w["target"], "3. %s %s: un solo directo, el blanco %s: %s" % (kind, shot, w["target"], [t["who"] for t in direct]))
        wrong = []
        for t in mine:
            r = res.get(f149.kind_of(t["who"]), {})
            if t["what"] == "directo":
                expected = amount * float(r.get("direct_ranged", 1.0))
            elif t["what"] == "salpicadura":
                expected = amount * max(0.0, 1.0 - t["dist"] / t["radius"]) * float(r.get("splash_ranged", 1.0))
            else:
                expected = 0.0
            if not r and t["what"] != "mismo bando":
                continue  # a structure: no resistances in creatures.json
            got = t["damage"] if t["damage"] is not None else 0
            if abs(got - expected) > DAMAGE_TOL + (0.5 if t["what"] != "mismo bando" else 0.0):
                wrong.append((t["who"], t["what"], got, round(expected, 2)))
        ok &= verdict(not wrong, "3. %s: directo = monto · resistencia, salpicadura = monto · (1 - d/r) · resistencia, aliado 0 (±%.1f): fallan %s" % (kind, DAMAGE_TOL, wrong))
    ally = [t for t in touches if t["who"] == "Druid1"]
    ok &= verdict(len(ally) == 1 and ally[0]["what"] == "mismo bando" and not ally[0]["damage"], "3. Druid1 (aliado) lo toca la onda y no recibe daño: %s" % [(t["what"], t["damage"]) for t in ally])
    burned = sorted(f for f, _, _ in fires if re.match(r"Trogg\d", f))
    ok &= verdict(sorted(set(burned)) == ["Trogg1", "Trogg2", "Trogg5"], "4. fuego del Spitfire solo en W1, W2 y W5 (ni el aliado ni la fila del Gargoyle): %s" % burned)
    ok &= verdict(all(total == 0.0 and updates == FIRE_UPDATES for who, total, updates in fires if re.match(r"Trogg\d", who)),
                  "4. cada fuego sobre una criatura: 0 de daño en %d actualizaciones: %s" % (FIRE_UPDATES, fires))
    # F162b: the building the wave of P3 crossed burns (setAblaze with no damage) and the fire ends on its first update (updateFire 15117-15118).
    huts = [f for f in fires if not re.match(r"Trogg\d", f[0])]
    p3_shots = [sh for sh, w in waves.items() if w["target"] == "Trogg5"]
    hut_touch = [t for t in touches if not re.match(r"Trogg\d|Druid", t["who"]) and t["shot"] in p3_shots]
    ok &= verdict(len(huts) >= 1 and len(huts) == len(hut_touch) and all(f[1] == 0.0 and f[2] == 1 for f in huts),
                  "4b. cada vez que una onda de P3 cruza la choza se prende un fuego, y termina en su primera actualización (0 de daño, 1): %s" % huts)
    ok &= verdict(len({t["shot"] for t in hut_touch}) == len(hut_touch) and len(hut_touch) == len(p3_shots) and all(t["what"] != "mismo bando" for t in hut_touch),
                  "4b. la choza la toca una vez cada onda de P3 y ninguna otra (ni la de P1 ni la del Gargoyle): %s" % [(t["shot"], t["what"]) for t in hut_touch])
    other = [t for t in touches if not re.match(r"Trogg\d|Druid", t["who"]) and t["shot"] not in p3_shots]
    ok &= verdict(not other, "4b. ninguna otra onda toca un edificio: %s" % [(t["shot"], t["who"]) for t in other])
    print("(la onda en pantalla, capturas cercanas del playtester; f149 igual y los 3 modos: corridas del orquestador)")
    return ok


def main():
    args = sys.argv[1:]
    if args and args[0] == "--numbers":
        numbers()
        return
    ok = check_lanes()
    if args and args[0] != "--lanes":
        ok = check_log(args[0]) and ok
    print("F162 %s" % ("PASS" if ok else "FAIL"))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
