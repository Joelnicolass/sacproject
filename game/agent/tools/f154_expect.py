#!/usr/bin/env python3
"""F154 (RFC-030 030q-b): what sacengine would do with the Seraph's Cage pull (psaa) on lane C of debug/f128_pull, replicated
from state.d and the SPEL data, next to what the port logged. The mechanic is Web pull's (pull!(PullType.cagePull)):
f128_expect.py holds the rules and this script calls them with the cage numbers, then adds the flight of the target after the
last pull.

Usage: python3 -I agent/tools/f154_expect.py [godot log of debug/f128_pull (rules debug/rules/f128_pull.tres)]
       python3 -I agent/tools/f154_expect.py --lanes     (the lane check, both lanes)
       python3 -I agent/tools/f154_expect.py --schedule  (the tick table of the cage pull)
       python3 -I agent/tools/f154_expect.py --flight x y z vx vy vz   (a ballistic body thrown from the land at (x, y, z))

Needs the bench switch on (debug/ai_match.gd): Pulling.log_pull.

sacengine:
- SPs1 has 102 frames and its load tick `liba` is frame 27: the user prepares 54 ticks (mana 300->240, no cooldown), the clip loops
  every 204 ticks and pulls at its last frame (101): T+202, T+406, T+610 and T+814 (T = the tick of the order).
- The cage is the web with another look: the thread is a lightning bolt with a cage shape that changes every 6 frames
  (changeShape, state.d:5126-5136) and when it breaks 64 sparks fly (animateCagePullBreaking, 25417-25432).
- numPulls >= 4 and the clip at its last frame (frame + 1 >= 204) ends it: T+815. Lane C (anchor 1270, 1270): Seraph1 at -170/+240
  (slot 1, looking to -x), Druid5 at -212/+240 (slot 2, 42 m). The ability is used at 0.5 s (T = tick 30). The four windows move
  the target about 6.4 m each, so the box never gets within 3 m of the Seraph's center before the fourth pull and the end is by
  the pulls; the fourth pull throws Druid5 and nothing drives it after: it flies on its own until it lands.
- That flight is Tumbling's (the port; sacengine updateCreature, 14781-14797): each tick, on the land (y <= ground + 0.02) and going
  down vy = 0, else vy -= 9.81 / 60; then vx, vz *= 0.99 and vy *= 0.998; position += v / 60; with vy <= 0 and y + vy / 60 <=
  ground + 0.02 it lands. The ground is the map's (cache/high_noon_terrain.bin), which climbs 4 cm per m on this lane. The
  replica takes the position and velocity the port logs when it starts the tumble («tumbo … desde … v …») and says where and
  when it lands: ±1 tick and ±0.05 m. While the body rises faster than the land under it the replica is only approximate
  (the real body slides on the floor): it says so and widens the margin to ±3 ticks and ±0.15 m.
Log lines: those of f128_expect.py, and Tumbling's own:
  tumbo Druid5 desde (x, y, z) suelo G v (vx, vy, vz) caja (hx, hy, hz) centro +c (cuadro N)
  aterriza Druid5 sobre suelo en (x, y, z) a D m (dx D, dz D) tras N ticks, ápice A m, vz V, caída F (cuadro N)
Port axes: x, y up, z; the original's z is the port's y.
"""
import importlib.util
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("f128_expect", os.path.join(HERE, "f128_expect.py"))
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)

T = base.T
TOL_TICKS = base.TOL_TICKS
TOL_M = base.TOL_M
LOOSE_TICKS = 3
LOOSE_M = 0.15
DAMP_XZ = 0.99
DAMP_Y = 0.998
REST = base.REST_M


def flight(terrain, pos, vel, accel=base.FALL_ACCEL, max_ticks=2000, drive=None):
    """Tumbling after a catapult at tick 0 (the body steps first, then Tumbling checks): (steps, (x, y, z), approximate).
    `steps` is the number of body steps done when it lands, so it lands at the catapult tick + steps - 1.
    `drive`: the velocity the pull sets on the tick after the catapult (updatePull runs before the body: `else if(--pullFrames>0)`
    fallingVelocity = velocity, with no lift), when the pull is still alive then (the 4th pull ends one tick later, after it)."""
    x, y, z = pos
    vx, vy, vz = vel
    approximate = False
    for k in range(1, max_ticks + 1):
        if k == 2 and drive is not None:
            vx, vy, vz = drive
        ground = terrain.ground(x, z) if terrain else None
        on_land = ground is not None and y <= ground + REST
        if on_land:
            if vy < 0.0:
                vy = 0.0
        else:
            vy -= accel / T
        vx *= DAMP_XZ
        vz *= DAMP_XZ
        vy *= DAMP_Y
        x += vx / T
        y += vy / T
        z += vz / T
        ground = terrain.ground(x, z) if terrain else None
        if ground is not None and y < ground - 0.002:
            approximate = True
        if vy > 0.0:
            continue
        if ground is not None and y + vy / T <= ground + REST:
            return k, (x, y, z), approximate
    return None, (x, y, z), approximate


def read_tumble(path, name, lane_z):
    """Every tumble on the lane at `lane_z` (±10 m): {start (x, y, z), v, tick, land (x, y, z) or None, land_tick or None}.
    Tumbling logs the creature's type name («Druid»), not the node's, so the lane is told by the position."""
    tumbles = []
    num = base.NUM
    vec = base.VEC
    kind = name.rstrip("0123456789")
    for line in open(path, encoding="utf-8", errors="replace").read().splitlines():
        m = re.search(r"tumbo " + re.escape(kind) + r" desde " + vec + r" suelo " + num + r" v " + vec + r" caja .*\(cuadro (\d+)\)", line)
        if m and abs(float(m.group(3)) - lane_z) <= 10.0:
            tumbles.append({"start": tuple(float(m.group(i)) for i in (1, 2, 3)), "v": tuple(float(m.group(i)) for i in (5, 6, 7)),
                            "tick": int(m.group(m.lastindex)), "land": None, "land_tick": None})
            continue
        m = re.search(r"aterriza " + re.escape(kind) + r" sobre \S+ en " + vec + r" .*\(cuadro (\d+)\)", line)
        if m and tumbles and tumbles[-1]["land"] is None and abs(float(m.group(3)) - lane_z) <= 10.0:
            tumbles[-1]["land"] = tuple(float(m.group(i)) for i in (1, 2, 3))
            tumbles[-1]["land_tick"] = int(m.group(m.lastindex))
    return tumbles


def check_log(path):
    ok = base.check_log(path, "cage")
    log = base.read_log(path, "cage")
    end = log["end"]
    tumbles = read_tumble(path, base.KINDS["cage"]["target"], base.ANCHOR[1] + base.LANES["Druid5"][1])
    terrain = base.Terrain.load()
    last = tumbles[-1] if tumbles else None
    pulls = log["pulls"]
    ok &= base.verdict(last is not None and len(pulls) >= base.MAX_PULLS and abs(last["tick"] - pulls[base.MAX_PULLS - 1]["tick"]) <= 0,
                       "3. el último tumbo de %s empieza en el cuarto tirón: %s / %s" % (
                           base.KINDS["cage"]["target"], last["tick"] if last else None,
                           pulls[base.MAX_PULLS - 1]["tick"] if len(pulls) >= base.MAX_PULLS else None))
    if last is None or end is None:
        return ok
    ok &= base.verdict(last["land_tick"] is not None and last["land_tick"] > end["tick"],
                       "3. al terminar (tick %d) %s sigue en el aire: aterriza en el tick %s" % (end["tick"], base.KINDS["cage"]["target"], last["land_tick"]))
    drive = None
    if end["tick"] == last["tick"] + 1 and end["window"] > 0:
        drive = (last["v"][0], last["v"][1] - base.LIFT_Y, last["v"][2])
    steps, where, approximate = flight(terrain, last["start"], last["v"], drive=drive)
    if steps is None:
        return base.verdict(False, "3. la réplica no aterriza")
    want_tick = last["tick"] + steps - 1
    tol_t, tol_m = (LOOSE_TICKS, LOOSE_M) if approximate else (TOL_TICKS, TOL_M)
    ok &= base.verdict(last["land_tick"] is not None and abs(last["land_tick"] - want_tick) <= tol_t,
                       "3. aterriza en el tick %s (réplica %d, ± %d%s)" % (last["land_tick"], want_tick, tol_t, ", aproximada: roza el suelo" if approximate else ""))
    if last["land"] is not None:
        dx = math.hypot(last["land"][0] - where[0], last["land"][2] - where[2])
        ok &= base.verdict(dx <= tol_m, "3. aterriza en (%.2f, %.2f) y la réplica en (%.2f, %.2f): %.3f m (± %.2f)" % (
            last["land"][0], last["land"][2], where[0], where[2], dx, tol_m))
    return ok


def main():
    args = sys.argv[1:]
    if args and args[0] == "--schedule":
        s = base.schedule("cage")
        print("cage: carga T+%d, vuelta %d ticks, tirones T+%s, fin por los %d tirones T+%d" % (
            s["load"], s["loop"], ", T+".join(str(p) for p in s["pulls"]), base.MAX_PULLS, s["end_clip"]))
        return
    if args and args[0] == "--flight":
        if len(args) != 7:
            print(__doc__)
            sys.exit(2)
        values = [float(a) for a in args[1:]]
        steps, where, approximate = flight(base.Terrain.load(), tuple(values[:3]), tuple(values[3:]))
        print("aterriza tras %s pasos en (%.3f, %.3f, %.3f)%s" % (steps, where[0], where[1], where[2], " (aproximado)" if approximate else ""))
        return
    ok = base.check_lanes()
    if args and args[0] != "--lanes":
        ok = check_log(args[0]) and ok
    print("RESULTADO %s" % ("PASS" if ok else "FAIL"))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
