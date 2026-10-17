#!/usr/bin/env python3
"""F158 (RFC-030 030u-b): what sacengine would do with the Yeti's Freeze on hit (zerf, passive of ycrp) on lane Y of
debug/f132_quake_onhit, replicated from state.d and the SPEL data, next to what the port logged. PHASE 0: written from the plan,
not yet run against a real log (the port has no MeleeOnHit yet). The lane helpers are f131_expect.py's.

Usage: python3 -I agent/tools/f158_expect.py [godot log of debug/f132_quake_onhit (rules debug/rules/f132_quake_onhit.tres)]
       python3 -I agent/tools/f158_expect.py --lanes     (only the lane check against the map caches)
       python3 -I agent/tools/f158_expect.py --numbers   (the figures of the replica, no log)

Needs the bench switches on (debug/ai_match.gd): MeleeAttack.log_melee and the freeze line of Affliction.inflict (new).

sacengine:
- updateCreatureAttack (14411-14438): on every attack tick with a target, even when the damage roll fails, canFreeze = !frozen before
  && valid after; then zerf.isApplicable and tryFreezeWithCooldown. ccProtected includes shielded (Life Shield, stats.d:86-90): a body
  under the shield is not frozen.
- tryFreezeWithCooldown (10710-10725): while the body's own freeze cooldown runs it freezes only when cooldown <= uniform(600); once
  the roll lets it try, frozen or not, the cooldown is left at 600 and counts down every tick. freeze lasts
  ceil(60 · 1000 / max health · 20 s) ticks on a creature, in float32 (1600 hp: 750).
- A blow on a frozen body breaks the ice (dealRawDamage, even 0) and the next tick it shatters: «deshielo» with the SPEL amount (150).
- R3: the Yeti and the Netherfiend share clip tags (PCst, PCa1, PCa2): the replica reads the blows (golpe) from the log.
Lane Y (anchor 1270, 1270; rows z-35 and z-45): Y1 Yeti1 -30/-15 (slot 1), T1 Troll1 -25/-15 (slot 2, pacifist, 1600 hp), Y2 Yeti2 -38/-25
(slot 1), T2 Druid2 -30/-25 (slot 2, Life Shield at 0.3 s = tick 18). Both Yeti attack at 0.5 s (tick 30).
Log lines:
  golpe Yeti1 → Troll1 precisión … tirada … (tick N)                                                  (MeleeAttack.log_melee)
  congelar Troll1 enfriamiento C tirada R congela|rechaza (tick N)                                    (new, Frozen.inflict)
  congelado Troll1 durante 750 (vida máx 1600) (cuadro N)                                             (Frozen)
  Troll1 rompe el hielo con X de daño (cuadro N) / deshielo Troll1 150 de hechizo vida V (cuadro N+1) (Frozen)
Port axes: x, y up, z; the original's z is the port's y.
"""
import importlib.util
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("f131_expect", os.path.join(HERE, "f131_expect.py"))
f131 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(f131)

verdict = f131.verdict
NUM = f131.NUM
f32 = f131.f32
TOL_TICKS = 1
MAX_COOLDOWN = 600
DURATION_S = 20.0
CREATURE_K = 1000.0
THAW_DAMAGE = 150

# name -> (dx, dz, slot, kind) from the anchor
# Moved to x -30..-38, z -15/-25 (the plan's x 0/z -35/-45 is under the Quake lane: J2 at -5/-34, wave 10 m + box). Verified with --lanes against f132's real boxes.
LANES = {
    "Y1": (-30.0, -15.0, 1, "Yeti"),
    "T1": (-25.0, -15.0, 2, "Troll"),
    "Y2": (-38.0, -25.0, 1, "Yeti"),
    "T2": (-30.0, -25.0, 2, "Druid"),
}
# Real body, not the centre: half width per species (estimated from the captures) and the cabin radius, as f132_expect's.
HALF_BOX = {"Yeti": 4.0, "Troll": 3.0, "Druid": 2.5}
BIG_STRUCT = {"jhut": 16.0}
# The Quake lane of the same scene (f132): its bodies and how far its wave reaches (10 m + the box).
QUAKE_LANE = {"J1": (20.0, -55.0, 1, "Jabberocky"), "J2": (-5.0, -34.0, 1, "Jabberocky")}
QUAKE_REACH_M = 10.0 + 6.0


def freeze_ticks(max_health):
    """ceil(60 · (1000 / max health) · 20) in float32 (Frozen.lifetime_ticks)."""
    seconds = f32(f32(f32(CREATURE_K) / f32(max_health)) * f32(DURATION_S))
    n = f32(60.0 * seconds)
    return int(n) + (0 if n == int(n) else 1)


def numbers():
    print("Troll 1600 hp: congelado %d ticks, deshielo %d de hechizo" % (freeze_ticks(1600.0), THAW_DAMAGE))
    print("regla de cada intento: con el enfriamiento c > 0 congela si y solo si c <= r (r = uniform(600)); tras el intento c = %d" % MAX_COOLDOWN)
    for hp in (900, 1250, 1600, 3600):
        print("  vida máx %d: %d ticks" % (hp, freeze_ticks(float(hp))))


def check_lanes():
    ok = f131.lane_report(LANES, half_box=HALF_BOX, big_struct=BIG_STRUCT)
    both = dict(LANES)
    both.update(QUAKE_LANE)
    for q in QUAKE_LANE:
        for y in LANES:
            d = f131.flat(both, q, y)
            good = d > QUAKE_REACH_M + HALF_BOX[LANES[y][3]]
            ok = ok and good
            print("%s -> %s: %.2f m (fuera de la onda del Quake) %s" % (q, y, d, "ok" if good else "MAL"))
    for a, b in (("Y1", "T1"), ("Y2", "T2")):
        d = f131.flat(LANES, a, b)
        print("%s -> %s: %.2f m en planta (el Yeti se acerca solo)" % (a, b, d))
    d = f131.flat(LANES, "Y1", "Y2")
    print("Y1 -> Y2: %.2f m (los Yeti son del mismo bando: no se pegan entre sí)" % d)
    return ok


def check_log(path):
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    ok = True
    hits = []
    for l in lines:
        m = re.search(r"golpe Yeti1 → Troll1 .*\(tick (\d+)\)", l)
        if m:
            hits.append(int(m.group(1)))
    ok &= verdict(bool(hits), "0. Yeti1 golpea a Troll1: %d golpes, el primero en %s" % (len(hits), hits[:1]))
    frozen = [(int(m.group(1)), int(m.group(2))) for m in (re.search(r"congelado Troll1 durante (\d+) .*\(cuadro (\d+)\)", l) for l in lines) if m]
    want = freeze_ticks(1600.0)
    ok &= verdict(bool(frozen) and frozen[0][0] == want and bool(hits) and abs(frozen[0][1] - hits[0]) <= TOL_TICKS,
                  "1. el primer golpe congela a Troll1 durante %d en el tick del golpe: %s (primer golpe %s)" % (want, frozen[:1], hits[:1]))
    breaks = [int(m.group(1)) for m in (re.search(r"Troll1 rompe el hielo con .* \(cuadro (\d+)\)", l) for l in lines) if m]
    thaws = [(int(m.group(1)), int(m.group(2))) for m in (re.search(r"deshielo Troll1 (\d+) de hechizo .*\(cuadro (\d+)\)", l) for l in lines) if m]
    if breaks:
        ok &= verdict(any(t == b + 1 for b in breaks[:1] for _, t in thaws[:1]) and thaws[0][0] == THAW_DAMAGE,
                      "2. un golpe sobre el hielo lo rompe (%d) y en el tick siguiente aparece deshielo Troll1 150: %s" % (breaks[0], thaws[:1]))
        mid = [t for t, _ in frozen[1:] if breaks[0] <= t <= breaks[0] + 1]
        ok &= verdict(not mid, "2. ese golpe no vuelve a congelar a Troll1 en el mismo tick: %s" % mid)
    else:
        ok &= verdict(False, "2. no hay «rompe el hielo»: ningún golpe cayó sobre el Troll congelado")
    attempts = []
    for l in lines:
        m = re.search(r"congelar Troll1 enfriamiento " + NUM + r" tirada " + NUM + r" (congela|rechaza) \(tick (\d+)\)", l)
        if m:
            attempts.append((int(m.group(4)), float(m.group(1)), float(m.group(2)), m.group(3)))
    bad = [(t, c, r, v) for t, c, r, v in attempts if (v == "congela") != (c <= r)]
    ok &= verdict(not bad, "3. cada intento con enfriamiento: congela si y solo si c <= r (%d intentos), fallan %s" % (len(attempts), bad[:3]))
    freezes = [t for t, _, _, v in attempts if v == "congela"]
    ok &= verdict(len(frozen) >= 1 + len(freezes), "3. cada «congela» tiene su «congelado»: %d congelados, %d congela" % (len(frozen), len(freezes)))
    druid = [l for l in lines if re.search(r"congelado Druid2", l)]
    ok &= verdict(not druid, "4. T2 con Life Shield no se congela: %s" % druid[:1])
    y2 = [l for l in lines if re.search(r"golpe Yeti2 → Druid2", l)]
    ok &= verdict(bool(y2), "4. Yeti2 sí golpeó a T2 (el escudo es lo que lo salva): %d golpes" % len(y2))
    print("(el hielo en pantalla, capturas cercanas del playtester; f149 no cambia, f132 igual en los 3 modos: corridas del orquestador)")
    return ok


def main():
    args = sys.argv[1:]
    if args and args[0] == "--numbers":
        numbers()
        return
    ok = check_lanes()
    if args and args[0] != "--lanes":
        ok = check_log(args[0]) and ok
    print("RESULTADO %s" % ("PASS" if ok else "FAIL"))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
