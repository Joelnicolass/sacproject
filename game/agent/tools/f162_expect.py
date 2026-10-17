#!/usr/bin/env python3
"""F162 (RFC-030 030w-c): what sacengine would do with the Spitfire's fire wave (fhba) and the Gargoyle's wave (ehba) on the lanes of
debug/f162_waves, replicated from state.d and the SPEL data, next to what the port logged. The geometry helpers are f149_expect.py's
(the same walk as the Silverback's breath), the lane helpers f131_expect.py's.

Usage: python3 -I agent/tools/f162_expect.py [godot log of debug/f162_waves (rules debug/rules/f162_waves.tres)]
       python3 -I agent/tools/f162_expect.py --lanes     (only the lane check against the map caches)
       python3 -I agent/tools/f162_expect.py --numbers   (the figures of the replica, no log)

Needs the bench switch on (debug/ai_match.gd): GrowingWave.log_touches. Lines read:
  onda ShotN tick 1 en (x, y, z) dir (…) paso … radio final R en F ticks a <blanco> (cuadro N)
  onda ShotN toca <cuerpo> tick N en (…) a D m radio r caja (cx, cy, cz) ± (hx, hy, hz): directo|salpicadura|mismo bando
  dano <cuerpo> <daño> vida <vida>
  fuego <cuerpo> total T en U actualizaciones vida V

sacengine:
- updateSpitfireProjectile (23025-23069), updateGargoyleProjectile (23079-23113): the wave flies its whole range without hitting
  (remainingDistance counts down in float32) and on update n (frame n - 1) has the radius final · (n - 1) / (60 · range / speed):
  7,5 m for the Spitfire (range 34, amount 150) and 6 m for the Gargoyle (range 40, amount 125), both at 36 m/s. Every update it walks
  dealDamageAt (9075-9089); each body is taken once in the flight (damagedTargets).
- Callback: the shot's target takes dealRangedDamage whole (the Spitfire's with DamageMod.ignite) and then setAblaze(30, 0); a body
  of the shooter's side nothing; any other body setAblaze(30, 0) and then the splash amount · (1 - d / r) as ranged|splash|ignite.
  The fire is of 0 damage (setAblaze(id, updateFPS / 2, true, 0.0f)): 30 frames last 31 updates (lifetime + 1), total 0.
- The Gargoyle's wave has neither fire nor ignite.
Lane rows (anchor 1270, 1270): z-80 P1 Spitfire1 (slot 1) -45, W1 Trogg1 -20 (target), W2 Trogg2 -24/-77 (splash), A1 Druid1 (slot 1) -30/-78;
z-36 G1 Gargoyle1 (slot 1) -45, W3 Trogg3 -20 (target), W4 Trogg4 -24/-33 (splash). P1 attacks W1 and G1 attacks W3 at 0,5 s.
Port axes: x, y up, z. The resistances come from assets/original/data/creatures.json.
"""
import importlib.util
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
# Real body, not the centre: the half width of a Trogg/Druid is small; the fliers are in the air and do not matter for the ground.
HALF_BOX = {"Spitfire": 1.5, "Gargoyle": 1.5, "Trogg": 1.0, "Druid": 0.5}
BIG_STRUCT = {"jhut": 16.0}
BODY = {"Trogg1": "W1", "Trogg2": "W2", "Druid1": "A1", "Trogg3": "W3", "Trogg4": "W4"}
FIRST_SHOT = {"Spitfire": "Trogg1", "Gargoyle": "Trogg3"}


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
    ok &= verdict(len(waves) == 2, "0. dos ondas (Spitfire y Gargoyle) con su línea de inicio: %s" % names)
    by_target = {w["target"]: s for s, w in waves.items()}
    kinds = {}
    for shot, w in waves.items():
        kinds["Spitfire" if w["target"] == FIRST_SHOT["Spitfire"] else "Gargoyle"] = shot
    for kind, (amount, reach, final) in WAVES.items():
        shot = kinds.get(kind)
        if shot is None:
            ok &= verdict(False, "0. onda del %s: sin línea de inicio" % kind)
            continue
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
        ok &= verdict(len(direct) == 1 and direct[0]["who"] == FIRST_SHOT[kind], "3. %s: un solo directo, el blanco %s: %s" % (kind, FIRST_SHOT[kind], [t["who"] for t in direct]))
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
    spit = kinds.get("Spitfire")
    burned = sorted(f for f, _, _ in fires)
    ok &= verdict(burned == ["Trogg1", "Trogg2"], "4. fuego del Spitfire solo en W1 y W2 (ni el aliado ni la fila del Gargoyle): %s" % burned)
    ok &= verdict(all(total == 0.0 and updates == FIRE_UPDATES for _, total, updates in fires),
                  "4. cada fuego: 0 de daño en %d actualizaciones: %s" % (FIRE_UPDATES, fires))
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
