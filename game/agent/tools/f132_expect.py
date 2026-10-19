#!/usr/bin/env python3
"""F132 (RFC-030 030u-a): what sacengine would do with the Jabberocky's Quake (kauq) on lane Q of debug/f132_quake_onhit,
replicated from state.d and the SPEL data, next to what the port logged. PHASE 0: written from the plan, not yet run
against a real log (the port has no QuakeAbility yet). F158 (lane Y) and F159 (lane V) are f158_expect.py and f159_expect.py
and share this scene; the lane helpers are f131_expect.py's.

Usage: python3 -I agent/tools/f132_expect.py [godot log of debug/f132_quake_onhit (rules debug/rules/f132_quake_onhit.tres)]
       python3 -I agent/tools/f132_expect.py --lanes     (only the lane check against the map files)
       python3 -I agent/tools/f132_expect.py --numbers   (the wave table and the tick table, no log)

Needs the bench switches on (debug/ai/ai_match.gd): QuakeWave.log_quake and AbilityEffect.log_effects.

sacengine:
- useAbility → act() (13495-13510): shoot0 (ESsm c96: 192 ticks), the mana (300) is paid when it starts, so 500 -> 200 at T; at
  the shoot tick quake (13204-13207) adds the effect and the cooldown (10 s = 600) is set if it was 0. A body stunned before the
  shoot tick loses the mana and gets no cooldown.
- updateQuake (25737-25759): the effect updates before the creatures, so frame 1 is the tick after the shoot tick S. waveLoc =
  50 · (frame / 60) / 0.5 = 1.667 · frame (float32). While 0.5 < waveLoc < 10 (frames 1 to 5; frame 6 is 10.0 exactly, not under)
  every moving body, any side, with its box within waveLoc + 0.1, 0.5 < flat distance of the feet and |flat − waveLoc| < 2.5 takes
  stunWithCooldown(480). 30 frames, no damage; it ends when the frame goes past 30 (S + 31).
Lane Q (anchor 1270, 1270; row z-55, away from the jhut at 1239/1300): J1 Jabberocky1 20/-55 (slot 1, pacifist), Q1 Trogg 25/-55
(slot 2, 5 m), Q2 Druid 20/-61 (slot 1, 6 m), Q3 Trogg 28.5/-55 (slot 2, 8.5 m), Q4 Trogg 9.5/-55 (slot 2, 10.5 m), Q5 Trogg 20/-67
(slot 2, 12 m), J2 Jabberocky2 -5/-34 (slot 1). J1 orders Quake at 0.5 s (T = tick 30) and at 4.0 s; J2 at 0.5 s, is stunned at 1.0 s and orders it again at 3.3 s (after the stun of 132 ticks, before the regenerated mana reaches 300).
Log lines:
  usando habilidad Quake Jabberocky1 192 ticks (tick 30)                                              (ActiveAbility)
  habilidad Quake mana 500->200 enfriamiento 0 ticks                                                  (ActiveAbility, paid at the start)
  sacudida Jabberocky1 (tick 222)                                                                     (new, QuakeAbility.fire at the shoot tick)
  habilidad Quake enfriamiento 600 ticks (tick 222)                                                   (new, ActiveAbility, cooldown set at the shoot tick)
  onda kauq en (x, y, z) alcance 50.0 m 0.50 s aturde de 0.5 a 10.0 m banda 2.500 m por 480 (cuadro 222)   (QuakeWave.log_quake)
  onda kauq paso 3 radio 5.000 m (cuadro 225)
    onda kauq Trogg2 a 5.000 m en planta, caja 4.400 m: aturdido (cuadro 225)
  onda kauq fin paso 31 (cuadro 253)
  preparación cortada Quake Jabberocky2 (tick 64)                                                     (ActiveAbility)
  bench: Jabberocky2 usa la habilidad: rechazada, Sin maná (tick 198)                                 (ai_match)
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
TOL_TICKS = 1
T_ORDER = 30
CLOCK = f131.CLOCK  # the bench labels an event with its nominal tick; the effect logs read CLOCK more when it fires
BY_NAME = {"Trogg1": "Q1", "Druid1": "Q2", "Trogg2": "Q3", "Trogg3": "Q4", "Trogg4": "Q5", "Jabberocky1": "J1"}
WINDUP = 192
MANA = (500, 200)
COOLDOWN = 600
STUN = 480
WAVE_RANGE = 50.0
WAVE_S = 0.5
STUN_MIN, STUN_MAX = 0.5, 10.0
BAND = 1.5
TOTAL = 30

# name -> (dx, dz, slot, kind) from the anchor
LANES = {
    "J1": (20.0, -55.0, 1, "Jabberocky"),
    "Q1": (25.0, -55.0, 2, "Trogg"),
    "Q2": (20.0, -61.0, 1, "Druid"),
    "Q3": (28.5, -55.0, 2, "Trogg"),
    "Q4": (9.5, -55.0, 2, "Trogg"),
    "Q5": (20.0, -67.0, 2, "Trogg"),
    "J2": (-5.0, -34.0, 1, "Jabberocky"),
}
# Real body, not the centre (the first lane stood J1's leg on the tip of the jhut at 15.5 m and the centre check passed): half
# width of the body per species (estimated from the captures: the Jabberocky sprawls ~12 m), and the radius of the cabin.
HALF_BOX = {"Jabberocky": 6.0, "Trogg": 3.0, "Druid": 2.5}
BIG_STRUCT = {"jhut": 16.0}
PLANNED = {"Q1": 5.0, "Q2": 6.0, "Q3": 8.5, "Q4": 10.5, "Q5": 12.0}
# the plan: ticks after the shoot tick S at which each is stunned (±1), None = never
PLAN_AFTER_S = {"Q1": 3, "Q2": 4, "Q3": 5, "Q4": None, "Q5": None, "J1": None}


def f32(x):
    return f131.f32(x)


def wave_at(frame):
    return f32(f32(WAVE_RANGE * f32(float(frame) / 60.0)) / WAVE_S)


def band_m():
    return f32(f32(BAND * WAVE_RANGE) / f32(WAVE_S * 60.0))


def stunned_frame(flat, box):
    """The first frame (1..TOTAL) at which a body at `flat` m (feet, from above) and `box` m (hit box) is stunned, or None."""
    for frame in range(1, TOTAL + 1):
        loc = wave_at(frame)
        if not (STUN_MIN < loc < STUN_MAX):
            continue
        if box <= f32(loc + 0.1) and STUN_MIN < flat and abs(flat - loc) < band_m():
            return frame
    return None


def numbers():
    print("T=%d, shoot tick S=T+%d=%d, mana %d->%d desde T, enfriamiento %d desde S, la onda nace en S y se libera en S+%d=%d" % (
        T_ORDER, WINDUP, T_ORDER + WINDUP, MANA[0], MANA[1], COOLDOWN, TOTAL + 1, T_ORDER + WINDUP + TOTAL + 1))
    for frame in range(1, 8):
        loc = wave_at(frame)
        print("paso %d: onda %.4f m %s, alcance de caja %.4f, banda ±%.3f m" % (
            frame, loc, "(aturde)" if STUN_MIN < loc < STUN_MAX else "(no aturde)", f32(loc + 0.1), band_m()))
    for name, flat in PLANNED.items():
        for half in (0.3, 0.5, 0.8):
            f = stunned_frame(flat, flat - half)
            print("%s a %.1f m (media caja %.1f): aturdido en el paso %s" % (name, flat, half, f))


def check_lanes():
    ok = f131.lane_report(LANES, half_box=HALF_BOX, big_struct=BIG_STRUCT)
    for name, want in PLANNED.items():
        d = f131.flat(LANES, "J1", name)
        good = abs(d - want) < 0.01
        ok = ok and good
        print("J1 -> %s: %.2f m en planta %s" % (name, d, "ok" if good else "MAL"))
    d = f131.flat(LANES, "J1", "J2")
    print("J1 -> J2: %.2f m (la onda de 10 m no la alcanza) %s" % (d, "ok" if d > 20.0 else "MAL"))
    return ok and d > 20.0


def check_log(path):
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    ok = True
    using = [(int(m.group(1)), int(m.group(2))) for m in (re.search(r"usando habilidad Quake Jabberocky1 (\d+) ticks \(tick (\d+)\)", l) for l in lines) if m]
    ok &= verdict(bool(using) and using[0] == (WINDUP, T_ORDER + CLOCK), "1. usando habilidad Quake 192 ticks en T=%d (+%d del reloj): %s" % (T_ORDER, CLOCK, using))
    manas = [(int(m.group(1)), int(m.group(2))) for m in (re.search(r"habilidad Quake mana (\d+)->(\d+)", l) for l in lines) if m]
    ok &= verdict(manas[:1] == [MANA], "1. mana 500->200: %s" % manas[:2])
    shake = [int(m.group(1)) for m in (re.search(r"sacudida Jabberocky1 \(tick (\d+)\)", l) for l in lines) if m]
    cool = [(int(m.group(1)), int(m.group(2))) for m in (re.search(r"habilidad Quake enfriamiento (\d+) ticks \(tick (\d+)\)", l) for l in lines) if m]
    s_tick = T_ORDER + CLOCK + WINDUP
    ok &= verdict(bool(shake) and abs(shake[0] - s_tick) <= TOL_TICKS, "2. sacudida en T+192=%d: %s" % (s_tick, shake[:2]))
    ok &= verdict(bool(cool) and cool[0][0] == COOLDOWN and abs(cool[0][1] - s_tick) <= TOL_TICKS,
                  "2. el enfriamiento queda en 600 en el tick del disparo: %s" % cool[:2])
    born = None
    steps = {}
    rows = []
    end = None
    for l in lines:
        m = re.search(r"onda kauq en \(.*\) alcance " + NUM + r" m " + NUM + r" s aturde de " + NUM + r" a " + NUM + r" m banda " + NUM +
                      r" m por (\d+) \(cuadro (\d+)\)", l)
        if m and born is None:
            born = int(m.group(7))
            ok &= verdict(abs(float(m.group(5)) - band_m()) < 0.001 and int(m.group(6)) == STUN,
                          "3. banda %.3f m y aturdimiento %d: %s" % (band_m(), STUN, m.group(0)[:100]))
        m = re.search(r"onda kauq paso (\d+) radio " + NUM + r" m \(cuadro (\d+)\)", l)
        if m:
            steps[int(m.group(1))] = (float(m.group(2)), int(m.group(3)))
        m = re.match(r"\s+onda kauq (\S+) a " + NUM + r" m en planta, caja " + NUM + r" m: (.+?) \(cuadro (\d+)\)", l)
        if m:
            rows.append((m.group(1), float(m.group(2)), float(m.group(3)), m.group(4), int(m.group(5))))
        m = re.search(r"onda kauq fin paso (\d+) \(cuadro (\d+)\)", l)
        if m:
            end = (int(m.group(1)), int(m.group(2)))
    ok &= verdict(born is not None and abs(born - s_tick) <= TOL_TICKS, "4. la onda nace en S=%d: %s" % (s_tick, born))
    bad_loc = [(f, v) for f, (v, _) in steps.items() if abs(v - wave_at(f)) > 0.001]
    ok &= verdict(sorted(steps) == [1, 2, 3, 4, 5] and not bad_loc, "3. pasos 1 a 5 con la onda 1,667·f: %s" % sorted(steps.items())[:6])
    # who is who: by the name the bench gives each body (group order of the rules); the bodies settle a few dm off the planned spot
    by = {}
    for name, flat, box, result, tick in rows:
        if name in BY_NAME:
            by.setdefault(BY_NAME[name], []).append((tick, result, flat, box))
    for lane in ("Q1", "Q2", "Q3", "Q4", "Q5", "J1"):
        hits = [t for t, r, _, _ in by.get(lane, []) if r == "aturdido"]
        want = None if PLAN_AFTER_S[lane] is None else s_tick + PLAN_AFTER_S[lane]
        if want is None:
            ok &= verdict(not hits, "3. %s nunca aturdido: %s" % (lane, hits))
        else:
            ok &= verdict(len(hits) == 1 and abs(hits[0] - want) <= TOL_TICKS,
                          "3. %s aturdido en S+%d=%d (±%d): %s" % (lane, PLAN_AFTER_S[lane], want, TOL_TICKS, hits))
        # the rule per row: stun iff in the band (the box is already inside the walk)
        wrong = [(t, r) for t, r, fl, bx in by.get(lane, [])
                 if (r == "aturdido") != (stunned_frame_at(fl, bx, t - (born or s_tick)) and not any(h < t for h in hits))]
        ok &= verdict(not wrong, "3. %s: cada fila sigue la regla (banda, no repetir) sin excepciones: %s" % (lane, wrong[:3]))
    ok &= verdict(end is not None and abs(end[1] - (s_tick + TOTAL + 1)) <= TOL_TICKS and end[0] == TOTAL + 1,
                  "4. la onda se libera en T+223=%d (±%d): %s" % (s_tick + TOTAL + 1, TOL_TICKS, end))
    # J2: mana 500->200, cut at T2+30, no shake, no cooldown, «Sin maná» at 3.3 s (plan: stun at 1.5 s and 3.0 s; the stun lasts 132 ticks and holds the body: «Blanco inválido»; and the mana is back over 300 by 3.8 s); J1 «Enfriando» at 4.0 s
    j2 = [(int(m.group(1)), int(m.group(2))) for m in (re.search(r"usando habilidad Quake Jabberocky2 (\d+) ticks \(tick (\d+)\)", l) for l in lines) if m]
    ok &= verdict(bool(j2) and j2[0][1] == T_ORDER + CLOCK, "5. J2 empieza el Quake en T=%d (+%d del reloj): %s" % (T_ORDER, CLOCK, j2[:2]))
    cut = [int(m.group(1)) for m in (re.search(r"preparación cortada Quake Jabberocky2 \(tick (\d+)\)", l) for l in lines) if m]
    ok &= verdict(bool(cut) and abs(cut[0] - (T_ORDER + 30 + CLOCK)) <= TOL_TICKS, "5. preparación cortada en T2+30=%d (+%d del reloj): %s" % (T_ORDER + 30 + CLOCK, CLOCK, cut[:2]))
    j2_shake = [l for l in lines if re.search(r"sacudida Jabberocky2", l)]
    ok &= verdict(not j2_shake, "5. J2 no sacude ni queda en enfriamiento: %s" % j2_shake[:1])
    for user, tick, text in (("Jabberocky2", 198, "Sin maná"), ("Jabberocky1", 240, "Enfriando")):
        got = [t for t, tk in f131.read_bench(lines, user) if tk == tick]
        ok &= verdict(bool(got) and got[0] == text, "5. %s a los %d: %s (esperado «%s»)" % (user, tick, got, text))
    print("(el anillo de tierra y el polvo: capturas del playtester, cerca porque el pasto tapa)")
    return ok


def stunned_frame_at(flat, box, frame):
    """True when a body at `flat`/`box` is in the band of `frame`."""
    loc = wave_at(frame)
    return STUN_MIN < loc < STUN_MAX and box <= f32(loc + 0.1) and STUN_MIN < flat and abs(flat - loc) < band_m()


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
