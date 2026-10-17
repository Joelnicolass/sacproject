#!/usr/bin/env python3
"""F131 (RFC-030 030t-a): what sacengine would do with the Netherfiend's and the Hellmouth's Devour (ifna) on lane D of
debug/f131_devour_rend, replicated from state.d and the SPEL data, next to what the port logged. F157 (Rend Soul, lane R of
the same scene) is f157_expect.py; both load this module for the lane check. PHASE 0: written from the plan, not yet run
against a real log (the port has no Devour yet). The log lines marked (new) are the ones phase 2 must print.

Usage: python3 -I agent/tools/f131_expect.py [godot log of debug/f131_devour_rend (rules debug/rules/f131_devour_rend.tres)]
       python3 -I agent/tools/f131_expect.py --lanes     (only the lane check against the map caches)
       python3 -I agent/tools/f131_expect.py --numbers   (the figures of the replica and the tick table, no log)

Needs the bench switches on (debug/ai_match.gd): AbilityEffect.log_effects and MeleeAttack.log_melee.

sacengine:
- useAbility → shoot (13463-13561): Devour takes shoot1 (PCes c36 Netherfiend: 72 ticks; DMes c46 Hellmouth: 92). Mana cost 0 and
  no cooldown (flags 4098): nothing is spent, `mana 500->500 enfriamiento 0` (the old max(1) of ActiveAbility is gone, R1).
- Range: the length of the creature's box, measured in 2D (12474, 12526-12529): Netherfiend 7.11 m, Hellmouth 17.9 m.
- Valid soul (isApplicable, summarize 30820-30825): blue, free or its own, not severed; devourSoul (13138-13163) wants it normal or
  emerging. The slot-2 soul of V2 is «Blanco inválido»; V3 is «Fuera de alcance».
- devourSoul per soul.number: health += 500, maxHealth += 500, increment = 0.25 · max the first time, then 0.75 · inc + 125,
  regeneration += inc / 60 per second, the five resistances × 0.9, numBulks += 1; at the end heal(rainbow wobr): 600 in 150 ticks,
  4 per tick, only while not full. The soul (DEVOURING) shrinks 3/60 a tick toward the shot position (20 ticks) and severSoul
  dissolves the corpse.
Lane D (anchor 1270, 1270; 0.15 min): N1 Netherfiend1 +20/-35 (slot 1, pacifist, 50 % health), V1 Trogg +24/-35 (slot 1), V1b Trogg
+20/-31 (slot 1), V2 Trogg +16/-35 (slot 2), V3 Trogg +20/-50 (slot 1), V5 Trogg +20/-42 (slot 2), H1 Hellmouth -5/-35 (slot 1),
V4 Druid +5/-35 (slot 1). V1, V1b, V2, V3 and V4 die at 0.3 s. N1 orders Devour on V2 at 2.0 s, V3 at 2.1 s, V1 at 2.2 s (T1 =
tick 132), V1b at 3.6 s (T2 = tick 216); H1 on V4 at 2.4 s (T3 = tick 144); V5 attacks N1 at 5.0 s.
Log lines:
  bench: Netherfiend1 usa la habilidad: rechazada, Blanco inválido (tick 120)                       (ai_match)
  usando habilidad Devour Netherfiend1 72 ticks (tick 132)                                          (ActiveAbility)
  habilidad Devour mana 500->500 enfriamiento 0 ticks                                               (ActiveAbility)
  devora Netherfiend1 alma Trogg1 n 1 vida 900->1400 máx 1800->2300 incremento 575.000 regeneración +9.583/s resistencia 0.9000 (tick 204)   (new, DevourAbility)
  alma Trogg1 devorando (tick 204) / alma Trogg1 devorada (tick 224) / cadáver Trogg1 disuelto (tick 204)                                   (new, Soul)
  cura Netherfiend1 +4.000 vida 1404.0 (tick 205)                                                   (new, HealEffect log)
  golpe Trogg5 → Netherfiend1 ... resistencia 0.6075 ... (tick 300)                                  (MeleeAttack.log_melee)
Port axes: x, y up, z; the original's z is the port's y.
"""
import importlib.util
import json
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("f128_expect", os.path.join(HERE, "f128_expect.py"))
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)

T60 = 60
ANCHOR = base.ANCHOR
NUM = base.NUM
verdict = base.verdict
TOL_TICKS = 1
# The lines the effects print carry MatchClock.now(), which runs 4 ticks ahead of the bench's audit tick in debug/ai_match (the
# `bench:` lines and the event times of the plan are audit ticks; f153 shows the same 96 -> 100).
CLOCK = 4
CLEAR_STRUCTURE_M = 11.0
CLEAR_WIDGET_M = 6.0

# name -> (dx, dz, slot, kind) from the anchor
LANES = {
    "N1": (20.0, -35.0, 1, "Netherfiend"),
    "V1": (24.0, -35.0, 1, "Trogg"),
    "V1b": (20.0, -31.0, 1, "Trogg"),
    "V2": (16.0, -35.0, 2, "Trogg"),
    "V3": (20.0, -50.0, 1, "Trogg"),
    "V5": (20.0, -42.0, 2, "Trogg"),
    "H1": (-5.0, -35.0, 1, "Hellmouth"),
    "V4": (5.0, -35.0, 1, "Druid"),
}
RANGE_NETHERFIEND = 7.11
RANGE_HELLMOUTH = 17.9
# (user, soul, planned flat distance, inside the user's range)
REACH = (("N1", "V1", 4.0, True), ("N1", "V1b", 4.0, True), ("N1", "V2", 4.0, True), ("N1", "V3", 15.0, False),
         ("H1", "V4", 10.0, True))
ORDERS = {"N1": [(120, "V2", "Blanco inválido"), (126, "V3", "Fuera de alcance"), (132, "V1", "ok"), (216, "V1b", "ok")],
          "H1": [(144, "V4", "ok")]}
ATTACK_V5 = 300
WINDUP = {"N1": 72, "H1": 92}
RAINBOW = 600.0
RAINBOW_STEP = 4.0
SOUL_TICKS = 20


# ---- the replica -----------------------------------------------------------------------------------------------------------

def f32(x):
    return base.struct.unpack("<f", base.struct.pack("<f", x))[0]


class Stats:
    def __init__(self, health, maximum, regen, melee_res):
        self.health, self.maximum, self.regen, self.melee_res = health, maximum, regen, melee_res
        self.inc = None
        self.res = 1.0
        self.bulks = 0

    def devour(self, number):
        for _ in range(number):
            self.health += 500.0
            self.maximum += 500.0
            self.inc = 0.25 * self.maximum if self.inc is None else 0.75 * self.inc + 125.0
            self.regen += self.inc / 60.0
            self.res *= 0.9
            self.bulks += 1
        return self

    def regen_per_s(self):
        return self.regen

    def melee_resistance(self):
        return self.melee_res * self.res


def netherfiend():
    return Stats(900.0, 1800.0, 0.0, 0.75)


def hellmouth():
    return Stats(5400.0, 5400.0, 0.0, 1.0)


def bulk(n):
    """The target of the render scale after n souls: 2 - 0.75^n (13943-13948; presentation)."""
    return 2.0 - 0.75 ** n


def numbers():
    n = netherfiend().devour(1)
    print("T1  Netherfiend: vida 900->%d máx 1800->%d incremento %.3f regeneración +%.3f/s resistencia %.4f" % (
        n.health, n.maximum, n.inc, n.regen, n.res))
    n.devour(1)
    print("T2  Netherfiend: máx %d incremento %.3f regeneración +%.3f/s resistencia %.4f golpe de V5 resistencia %.4f" % (
        n.maximum, n.inc, n.regen, n.res, n.melee_resistance()))
    h = hellmouth().devour(1)
    print("T3  Hellmouth: 5400->%d/%d regeneración +%.3f/s resistencia %.4f, sin cura (lleno)" % (h.health, h.maximum, h.regen, h.res))
    print("cura: +%g por tick, %d ticks (%g en total) desde T1+%d" % (RAINBOW_STEP, int(RAINBOW / RAINBOW_STEP), RAINBOW, WINDUP["N1"] + 1))
    print("bulto: n=1 %.4f, n=2 %.4f (escala de render, 1.25 y 1.4375 con el suavizado)" % (bulk(1), bulk(2)))
    for who, rows in ORDERS.items():
        for tick, soul, result in rows:
            if result == "ok":
                print("%s sobre %s: orden %d, devora %d, alma fuera %d, cura %d..%d" % (
                    who, soul, tick, tick + WINDUP[who], tick + WINDUP[who] + SOUL_TICKS, tick + WINDUP[who] + 1,
                    tick + WINDUP[who] + int(RAINBOW / RAINBOW_STEP)))
            else:
                print("%s sobre %s: orden %d rechazada, %s" % (who, soul, tick, result))


# ---- the lanes -------------------------------------------------------------------------------------------------------------

def world(lanes, name):
    dx, dz, _, _ = lanes[name]
    return ANCHOR[0] + dx, ANCHOR[1] + dz


def flat(lanes, a, b):
    ax, az = world(lanes, a)
    bx, bz = world(lanes, b)
    return math.hypot(ax - bx, az - bz)


def lane_report(lanes, margin=5.0, step=2.5, half_box=None, big_struct=None):
    """Land under every body and over the rectangle that holds them (no hole), no structure within 11 m of a body, no widget
    within 6 m. Shared by f131, f157, f132, f158 and f159 (each with its own lanes). Returns ok.
    half_box (kind -> m, optional): the body's real half width instead of its centre; then no widget within half_box + 2 m and no
    structure within CLEAR_STRUCTURE_M or, for a tag in big_struct (tag -> radius m), radius + half_box + 2 m. Without it the
    check is the old centre one."""
    ok = True
    terrain = base.Terrain.load()
    try:
        ntts = json.load(open(base.cache("high_noon_ntts.json"), encoding="utf-8"))
        widgets = json.load(open(base.cache("high_noon_widgets.json"), encoding="utf-8"))
    except OSError:
        ntts, widgets = {"structures": []}, {}
    if terrain is None:
        print("(sin cache/high_noon_terrain.bin: se omite el suelo)")
    structures = ntts.get("structures", [])
    for name in lanes:
        x, z = world(lanes, name)
        y = terrain.ground(x, z) if terrain else None
        hb = (half_box or {}).get(lanes[name][3]) if half_box else None
        wid_m = CLEAR_WIDGET_M if hb is None else max(CLEAR_WIDGET_M, hb + 2.0)
        st_m = lambda tag: CLEAR_STRUCTURE_M if hb is None else max(CLEAR_STRUCTURE_M, (big_struct or {}).get(tag, 0.0) + hb + 2.0)
        near = [(s["tag"], round(math.hypot(s["x"] - x, s["z"] - z), 1)) for s in structures
                if math.hypot(s["x"] - x, s["z"] - z) < st_m(s["tag"])]
        props = [k for k, ps in widgets.items() for p in ps if math.hypot(p[0] - x, p[1] - z) < wid_m]
        bad = (terrain is not None and y is None) or near or props
        ok = ok and not bad
        print("carril %-8s (%.1f, %.1f) suelo %s estructuras<%d %s widgets<%d %s %s" % (
            name, x, z, "?" if y is None else "%.2f" % y, CLEAR_STRUCTURE_M, near, wid_m, props, "MAL" if bad else "ok"))
    if terrain:
        xs = [world(lanes, n)[0] for n in lanes]
        zs = [world(lanes, n)[1] for n in lanes]
        holes = cells = 0
        heights = []
        x = min(xs) - margin
        while x <= max(xs) + margin:
            z = min(zs) - margin
            while z <= max(zs) + margin:
                cells += 1
                y = terrain.ground(x, z)
                if y is None:
                    holes += 1
                else:
                    heights.append(y)
                z += step
            x += step
        ok = ok and holes == 0
        print("huecos en el carril (%d puntos cada %.1f m): %d, suelo %.2f a %.2f m %s" % (
            cells, step, holes, min(heights) if heights else float("nan"), max(heights) if heights else float("nan"),
            "ok" if holes == 0 else "MAL"))
    return ok


def check_lanes():
    ok = lane_report(LANES)
    for user, soul, want, inside in REACH:
        d = flat(LANES, user, soul)
        reach = RANGE_NETHERFIEND if user == "N1" else RANGE_HELLMOUTH
        good = abs(d - want) < 0.01 and (d <= reach) == inside
        ok = ok and good
        print("%s -> %s: %.2f m en planta (alcance %.2f, %s) %s" % (user, soul, d, reach, "dentro" if inside else "fuera", "ok" if good else "MAL"))
    # V5 reaches N1 and no one else stands at melee range of it before its turn.
    d = flat(LANES, "V5", "N1")
    print("V5 -> N1: %.2f m (V5 corre al Netherfiend a los 5,0 s)" % d)
    # H1 and N1 must not interfere: the nearest foreign body of each user.
    for user in ("N1", "H1"):
        others = sorted((round(flat(LANES, user, o), 1), o) for o in LANES if o != user)
        print("más cercanos a %s: %s" % (user, others[:4]))
    return ok


# ---- the log ---------------------------------------------------------------------------------------------------------------

def read_bench(lines, user):
    out = []
    for line in lines:
        m = re.search(r"bench: (\S+) usa la habilidad: (?:rechazada, )?(.+?) \(tick (\d+)\)", line)
        if m and m.group(1) == user:
            out.append((m.group(2), int(m.group(3))))
    return out


def check_log(path):
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    ok = True
    bench = read_bench(lines, "Netherfiend1")
    want = {120: "Blanco inválido", 126: "Fuera de alcance"}
    for tick, text in want.items():
        got = [t for t, tk in bench if tk == tick]
        ok &= verdict(bool(got) and got[0] == text, "1. rechazo a los %d: %s (esperado «%s»)" % (tick, got, text))
    using = [(int(m.group(1)), int(m.group(2))) for m in (re.search(r"usando habilidad Devour Netherfiend1 (\d+) ticks \(tick (\d+)\)", l) for l in lines) if m]
    ok &= verdict(len(using) >= 2 and using[0] == (72, 132 + CLOCK) and using[1][1] == 216 + CLOCK,
                  "2. usando habilidad Devour 72 ticks en T1=132 y T2=216: %s" % using)
    manas = [(int(m.group(1)), int(m.group(2)), int(m.group(3))) for m in (re.search(r"habilidad Devour mana (\d+)->(\d+) enfriamiento (\d+) ticks", l) for l in lines) if m]
    ok &= verdict(bool(manas) and all(a == b and c == 0 for a, b, c in manas) and manas[0][0] == 500,
                  "1/2. el Devour no gasta ni enfría: %s" % manas[:3])
    eats = []
    for l in lines:
        m = re.search(r"devora (\S+) alma (\S+) n (\d+) vida (\d+)->(\d+) máx (\d+)->(\d+) incremento " + NUM + r" regeneración \+" + NUM +
                      r"/s resistencia " + NUM + r" \(tick (\d+)\)", l)
        if m:
            eats.append({"by": m.group(1), "n": int(m.group(3)), "hp": (int(m.group(4)), int(m.group(5))),
                         "max": (int(m.group(6)), int(m.group(7))), "inc": float(m.group(8)), "regen": float(m.group(9)),
                         "res": float(m.group(10)), "tick": int(m.group(11))})
    nether = [e for e in eats if e["by"] == "Netherfiend1"]
    hell = [e for e in eats if e["by"] == "Hellmouth1"]
    exp1 = netherfiend().devour(1)
    ok &= verdict(len(nether) >= 1 and abs(nether[0]["tick"] - (132 + 72 + CLOCK)) <= TOL_TICKS and nether[0]["hp"] == (900, int(exp1.health))
                  and nether[0]["max"] == (1800, int(exp1.maximum)) and abs(nether[0]["regen"] - exp1.regen) < 0.001
                  and abs(nether[0]["res"] - 0.9) < 1e-4,
                  "2. T1+72: %s (esperado vida 900->%d máx 1800->%d +%.3f/s ×0.9000)" % (nether[:1], exp1.health, exp1.maximum, exp1.regen))
    exp2 = netherfiend().devour(1).devour(1)
    ok &= verdict(len(nether) >= 2 and abs(nether[1]["tick"] - (216 + 72 + CLOCK)) <= TOL_TICKS and nether[1]["max"][1] == int(exp2.maximum)
                  and abs(nether[1]["inc"] - exp2.inc) < 0.01 and abs(nether[1]["regen"] - exp2.regen) < 0.001
                  and abs(nether[1]["res"] - exp2.res) < 1e-4,
                  "5. T2+72: %s (esperado máx %d inc %.2f +%.3f/s ×%.4f)" % (nether[1:2], exp2.maximum, exp2.inc, exp2.regen, exp2.res))
    exp3 = hellmouth().devour(1)
    ok &= verdict(len(hell) >= 1 and abs(hell[0]["tick"] - (144 + 92 + CLOCK)) <= TOL_TICKS and hell[0]["hp"] == (5400, int(exp3.health))
                  and hell[0]["max"] == (5400, int(exp3.maximum)) and abs(hell[0]["regen"] - exp3.regen) < 0.001,
                  "6. T3+92: %s (esperado 5400->%d/%d +%.3f/s)" % (hell[:1], exp3.health, exp3.maximum, exp3.regen))
    cure = {}
    for l in lines:
        m = re.search(r"cura (\S+) \+" + NUM + r" vida " + NUM + r" \(tick (\d+)\)", l)
        if m:
            cure.setdefault(m.group(1), []).append((int(m.group(4)), float(m.group(2))))
    nc = cure.get("Netherfiend1", [])
    first = 132 + 72 + 1 + CLOCK
    ticks = [t for t, _ in nc if first - TOL_TICKS <= t <= first + 150 + TOL_TICKS]
    ok &= verdict(len(ticks) >= 150 - TOL_TICKS and all(abs(a - RAINBOW_STEP) < 0.01 for t, a in nc[:150]),
                  "4. la cura da +4 por tick durante 150 ticks desde T1+73=%d: %d ticks, de %s a %s" % (
                      first, len(ticks), ticks[0] if ticks else None, ticks[-1] if ticks else None))
    ok &= verdict(not cure.get("Hellmouth1"), "6. el Hellmouth lleno no recibe cura: %s" % cure.get("Hellmouth1", [])[:2])
    souls = {}
    for l in lines:
        m = re.search(r"alma (\S+) (devorando|devorada) \(tick (\d+)\)", l)
        if m:
            souls.setdefault(m.group(1), {})[m.group(2)] = int(m.group(3))
        m = re.search(r"cadáver (\S+) disuelto \(tick (\d+)\)", l)
        if m:
            souls.setdefault(m.group(1), {})["disuelto"] = int(m.group(2))
    good = [s for s in souls.values() if "devorando" in s and "devorada" in s and 0 < s["devorada"] - s["devorando"] <= SOUL_TICKS + TOL_TICKS and "disuelto" in s]
    ok &= verdict(len(good) >= 3, "3. el alma pasa a DEVOURING y se va en ≤ %d ticks, el cadáver se disuelve (%d de 3 devorados): %s" % (
        SOUL_TICKS, len(good), souls))
    hits = []
    for l in lines:
        m = re.search(r"golpe \S+ → Netherfiend1 .* resistencia " + NUM + r" .*\(tick (\d+)\)", l)
        if m:
            hits.append((int(m.group(2)), float(m.group(1))))
    after = [r for t, r in hits if t >= ATTACK_V5 + CLOCK]
    ok &= verdict(bool(after) and abs(after[0] - exp2.melee_resistance()) < 1e-3,
                  "5. el golpe de V5 sale con resistencia %.4f: %s" % (exp2.melee_resistance(), after[:2]))
    print("(escala del bulto 1.25 y 1.4375, :shown en 1 y 2, cadáver que se disuelve en pantalla: capturas del playtester)")
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
