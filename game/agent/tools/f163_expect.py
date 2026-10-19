#!/usr/bin/env python3
"""F163 (RFC-030 030w-f): what sacengine would do with the Phoenix's Shield (rifl) on the lane of debug/f163_phoenix_shield,
replicated from state.d and the SPEL data, next to what the port logged. The lane helpers are f131_expect.py's.

Usage: python3 -I agent/tools/f163_expect.py [godot log of debug/f163_phoenix_shield (rules debug/rules/f163_phoenix_shield.tres)]
       python3 -I agent/tools/f163_expect.py --lanes     (only the lane check against the map caches)
       python3 -I agent/tools/f163_expect.py --numbers   (the figures of the replica, no log)

Needs the bench switch on (debug/ai/ai_match.gd): FireShield.log_shield. Lines read:
  escudo <fuente> quema <cuerpo> <daño> vida <vida> (tick N) maná M caja (cx, cy, cz) ± (hx, hy, hz) otro (x, y, z) ± (half, height)
  escudo <fuente> toca <cuerpo> aliado, no quema (tick N)

sacengine:
- runPhoenixPassive (state.d:13899-13919), every frame from updateCreatureStats (runPassive, 13921-13931): a body in a mode that
  canShield (218-225) with mana >= the SPEL's cost (rifl: 0) takes every moving body whose hitbox meets its own hitbox scaled ×1.5
  (scaleBox, about the center) except itself. A body that is not an ally (getStance) burns: ignite(fireform.amount / updateFPS) =
  dealFireDamage(0, 250 / 60, …, peirceShield) = dealSpellDamage(direct spell, peirceShield skips Life Shield / Rockform / petrified)
  = 250/60 · side · direct_spell resistance. If anyone burned it drains the cost (0) and puffs the particles. No buildings.
Lane (anchor 1270, 1270; 0,2 min; pacifists that hold still): P1 Phoenix1 (slot 1) -30/-80; P2 Phoenix2 (slot 2) -30/-75 (inside P1's
box ×1,5, and P1 in his); P3 Phoenix3 (slot 1, ally of P1) -36/-90,5 (inside P1's box, outside P2's); P4 Phoenix4 (slot 2) +10/-80 (far);
D1 Druid1 (slot 2, ally of P2) -22/-80 (on the ground at the edge of the boxes ×1,5: R6, a Phoenix reaches a body on the ground).
The plan's P3 (-33/-80) was inside P2's box too and so burned (it is P2's enemy); moved out of it. The bodies push each other a few
metres apart (BodySeparation, the boxes overlap): the check reads the positions of each line, not the start ones.
Port axes: x, y up, z. The resistances come from assets/original/data/creatures.json.
"""
import importlib.util
import json
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
AMOUNT = 250.0
SCALE = 1.5
DAMAGE_TOL = 0.001
# name -> (dx, dz, slot, kind) from the anchor
LANES = {
    "P1": (-30.0, -80.0, 1, "Phoenix"),
    "P2": (-30.0, -75.0, 2, "Phoenix"),
    "P3": (-36.0, -90.5, 1, "Phoenix"),
    "P4": (10.0, -80.0, 2, "Phoenix"),
    "D1": (-22.0, -80.0, 2, "Druid"),
}
BODY = {"Phoenix1": "P1", "Phoenix2": "P2", "Phoenix3": "P3", "Phoenix4": "P4", "Druid1": "D1"}
# Real body, not the centre (the Phoenix's box is wide: half 5,67 m).
HALF_BOX = {"Phoenix": 5.7, "Druid": 0.6}
BIG_STRUCT = {"jhut": 16.0}


def numbers():
    print("monto %.0f / %d = %.4f por cuadro; caja ×%.1f desde el centro; costo de maná de rifl 0" % (AMOUNT, FPS, AMOUNT / FPS, SCALE))
    res = f149.resistances()
    for who in ("Phoenix", "Druid"):
        r = float(res.get(who, {}).get("direct_spell", 1.0))
        print("%s: resistencia de hechizo directo %.3f -> %.4f por cuadro" % (who, r, AMOUNT / FPS * r))


def check_lanes():
    ok = f131.lane_report(LANES, half_box=HALF_BOX, big_struct=BIG_STRUCT)
    for a, b in (("P1", "P2"), ("P1", "P3"), ("P2", "P3"), ("P1", "P4"), ("P1", "D1"), ("P2", "D1")):
        print("%s -> %s: %.2f m en planta" % (a, b, f131.flat(LANES, a, b)))
    return ok


def check_log(path):
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    res = f149.resistances()
    burns = []
    allies = []
    for line in lines:
        m = re.search(r"^escudo (\S+) quema (\S+) " + NUM + r" vida " + NUM + r" \(tick (\d+)\) maná " + NUM + r" caja " + VEC + r" ± " + VEC
                      + r" otro " + VEC + r" ± \(" + NUM + r", " + NUM + r"\)", line)
        if m:
            g = [float(m.group(i)) for i in range(3, 5)]
            v = lambda a: [float(m.group(i)) for i in range(a, a + 3)]
            burns.append(dict(src=m.group(1), who=m.group(2), taken=g[0], life=g[1], tick=int(m.group(5)), mana=float(m.group(6)),
                              center=v(7), half=v(10), at=v(13), bhalf=float(m.group(16)), bheight=float(m.group(17))))
            continue
        m = re.search(r"^escudo (\S+) toca (\S+) aliado, no quema \(tick (\d+)\)", line)
        if m:
            allies.append((m.group(1), m.group(2), int(m.group(3))))
    ok = True
    ok &= verdict(len(burns) > 0, "0. el escudo quemó (%d líneas)" % len(burns))
    pairs = {}
    for b in burns:
        pairs.setdefault((b["src"], b["who"]), []).append(b)
    names = sorted("%s>%s" % p for p in pairs)
    # Each burner against each victim: the expected set follows from the sides (enemy, in the box) and from nobody else.
    expected = {("Phoenix1", "Phoenix2"), ("Phoenix2", "Phoenix1"), ("Phoenix1", "Druid1")}
    seen = set(pairs)
    ok &= verdict(seen == expected,
                  "1. quién quema a quién (enemigos con las cajas ×1,5 tocándose): %s" % names)
    # 1. Geometry of every line: the victim's box meets the shield's box (strict), and the box is the body's scaled ×1.5.
    phoenix = [b for b in burns if b["who"].startswith("Phoenix")]
    base_half = phoenix[0]["bhalf"] if phoenix else 0.0
    base_height = phoenix[0]["bheight"] if phoenix else 0.0
    bad_scale = [b["tick"] for b in burns if abs(b["half"][0] - SCALE * base_half) > 0.001 or abs(b["half"][1] - SCALE * base_height / 2) > 0.001]
    ok &= verdict(not bad_scale, "1. la caja es la del Phoenix ×%.1f desde el centro (±%.3f ancho, ±%.3f alto): fallan %s" % (
        SCALE, SCALE * base_half, SCALE * base_height / 2, bad_scale[:5]))
    bad_meet = []
    for b in burns:
        dx = abs(b["at"][0] - b["center"][0])
        dz = abs(b["at"][2] - b["center"][2])
        dy = abs(b["at"][1] + b["bheight"] / 2 - b["center"][1])
        if not (dx < b["half"][0] + b["bhalf"] and dz < b["half"][2] + b["bhalf"] and dy < b["half"][1] + b["bheight"] / 2):
            bad_meet.append((b["src"], b["who"], b["tick"]))
    ok &= verdict(not bad_meet, "1. cada quema ocurre con las cajas tocándose: fallan %s" % bad_meet[:5])
    # 2. Damage: 250/60 · direct_spell resistance of the victim, whatever the shields.
    wrong = []
    for b in burns:
        r = float(res.get(f149.kind_of(b["who"]), {}).get("direct_spell", 1.0))
        expected_hit = AMOUNT / FPS * r
        if abs(b["taken"] - expected_hit) > DAMAGE_TOL and b["life"] > 0.0:
            wrong.append((b["src"], b["who"], b["tick"], b["taken"], round(expected_hit, 4)))
    ok &= verdict(not wrong, "1. cada quema es 250/60 · resistencia de hechizo directo (±%.3f): fallan %s" % (DAMAGE_TOL, wrong[:5]))
    # Every tick of contact burns: the ticks of a pair are consecutive.
    gaps = []
    for pair, rows in pairs.items():
        ticks = [r["tick"] for r in rows]
        if ticks != list(range(ticks[0], ticks[0] + len(ticks))):
            gaps.append(pair)
    ok &= verdict(not gaps, "1. cada cuadro de contacto quema (ticks consecutivos por par): huecos en %s" % gaps)
    # 3. Allies and the far one lose nothing to the shield.
    ally_burns = [(b["src"], b["who"]) for b in burns if BODY.get(b["src"]) and BODY.get(b["who"])
                  and LANES[BODY[b["src"]]][2] == LANES[BODY[b["who"]]][2]]
    ok &= verdict(not ally_burns, "2. un aliado nunca quema a un aliado: %s" % ally_burns)
    far = [b for b in burns if "Phoenix4" in (b["src"], b["who"])]
    ok &= verdict(not [b for b in burns if "Phoenix3" in (b["src"], b["who"])], "2. Phoenix3 (aliado de P1, fuera de la caja de P2) no quema ni es quemado")
    ok &= verdict(not far, "2. Phoenix4 (lejos) ni quema ni es quemado: %d líneas" % len(far))
    ok &= verdict(len(allies) > 0 and all(
        LANES[BODY[a]][2] == LANES[BODY[b]][2] for a, b, _ in allies), "2. los aliados que se tocan se anotan sin quemar: %s" % allies)
    # 4. The mana does not go down because of the shield (it may regenerate).
    by_src = {}
    for b in burns:
        by_src.setdefault(b["src"], []).append(b["mana"])
    down = {s: v for s, v in by_src.items() if any(b < a - 1e-6 for a, b in zip(v, v[1:]))}
    ok &= verdict(not down, "3. el maná del que quema no baja (costo 0): bajó en %s" % list(down))
    print("(R6: Druid1, en el suelo, %s)" % ("quemado por Phoenix1 en %d cuadros" % len(pairs.get(("Phoenix1", "Druid1"), [])) if ("Phoenix1", "Druid1") in pairs else "NO quemado"))
    print("(el fuego en pantalla, capturas cercanas del orquestador; los 3 modos: corridas del orquestador)")
    return ok


def main():
    args = sys.argv[1:]
    if args and args[0] == "--numbers":
        numbers()
        return
    ok = check_lanes()
    if args and args[0] != "--lanes":
        ok = check_log(args[0]) and ok
    print("F163 %s" % ("PASS" if ok else "FAIL"))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
