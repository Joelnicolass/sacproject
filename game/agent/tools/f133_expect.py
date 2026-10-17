#!/usr/bin/env python3
"""F133 (RFC-030 030v-a): the six old active abilities (Life Shield hsba, Run Away !nur, Rockform dihk, Play Dead dedp, Stealth ivni,
Divine Sight eesd) on debug/f133_legacy_abilities, next to what the port logged. It is a refactor: the log of this scene must be the same
before and after the abilities move to the AbilityCatalog (the digest in agent/det_baseline.txt was recorded first, with the code of
before; this script checks the result of each event and the mana and cooldown lines, which the digest does not see: it hashes positions).

Usage: python3 -I agent/tools/f133_expect.py [godot log of debug/f133_legacy_abilities (rules debug/rules/f133_legacy_abilities.tres)]
       python3 -I agent/tools/f133_expect.py --lanes     (only the lane check against the map files)

Needs the bench switches on (debug/ai_match.gd): ActiveAbility.log_ability and AbilityEffect.log_effects.

Cast (anchor 1270, 1270; row z-80, away from the jhut at 1239/1300): slot 1 holds still: Druid1 -45, Ranger1 -40, FlameMinion1 -35,
Earthfling1 -30, Fallen1 -25; slot 2: Sylph1 -10 (pacifist). Mana and cooldown are the SPELs' (cooldown_s · 60, mana_cost).
Events (audit tick = seconds · 60) and what each gives:
  18 Druid1 Life Shield: ok, mana 100->50, cooldown 1200        48 Druid1: Enfriando
  24 FlameMinion1 Run Away: ok, mana 200->150, cooldown 600     144 FlameMinion1: Enfriando
  30 Earthfling1 Rockform: ok, mana 200->187, cooldown 60       72 Earthfling1: Enfriando; 120: Blanco inválido (already a rock)
  36 Fallen1 Play Dead: ok, mana 200->200, cooldown 0           132 Fallen1: Blanco inválido (already playing dead)
  42 Sylph1 Stealth: ok, mana 200->150, cooldown 300
  60 Ranger1 Divine Sight: ok, mana 200->150, cooldown 1500 (F165: no target, like the UI button; it throws the eye, log «ojo Eye1 de Ranger1»)
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

# name -> (dx, dz, slot, kind) from the anchor
LANES = {
    "D1": (-45.0, -80.0, 1, "Druid"),
    "R1": (-40.0, -80.0, 1, "Ranger"),
    "F1": (-35.0, -80.0, 1, "FlameMinion"),
    "E1": (-30.0, -80.0, 1, "Earthfling"),
    "A1": (-25.0, -80.0, 1, "Fallen"),
    "S1": (-10.0, -80.0, 2, "Sylph"),
}
HALF_BOX = {"Druid": 2.5, "Ranger": 2.5, "FlameMinion": 2.5, "Earthfling": 3.0, "Fallen": 2.5, "Sylph": 3.0}
BIG_STRUCT = {"jhut": 16.0}

# (user, tick) -> result of the bench line
RESULTS = [
    ("Druid1", 18, "ok"), ("FlameMinion1", 24, "ok"), ("Earthfling1", 30, "ok"), ("Fallen1", 36, "ok"), ("Sylph1", 42, "ok"),
    ("Druid1", 48, "Enfriando"), ("Ranger1", 60, "ok"), ("Earthfling1", 72, "Enfriando"), ("Earthfling1", 120, "Blanco inválido"),
    ("Fallen1", 132, "Blanco inválido"), ("FlameMinion1", 144, "Enfriando"),
]
# ability -> (mana before, mana after, cooldown ticks), in the order they are applied
SPENT = [("Life Shield", 100, 50, 1200), ("Run Away", 200, 150, 600), ("Rockform", 200, 187, 60), ("Play Dead", 200, 200, 0),
         ("Stealth", 200, 150, 300), ("Divine Sight", 200, 150, 1500)]


def check_lanes():
    ok = f131.lane_report(LANES, half_box=HALF_BOX, big_struct=BIG_STRUCT)
    d = f131.flat(LANES, "R1", "S1")
    print("R1 -> S1: %.2f m en planta (Divine Sight llega a 250 m) %s" % (d, "ok" if d < 250.0 else "MAL"))
    return ok and d < 250.0


def check_log(path):
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    ok = True
    for user, tick, want in RESULTS:
        got = [t for t, tk in f131.read_bench(lines, user) if tk == tick]
        ok &= verdict(bool(got) and got[0] == want, "%s a los %d: %s (esperado «%s»)" % (user, tick, got, want))
    spent = [(m.group(1), int(m.group(2)), int(m.group(3)), int(m.group(4))) for m in
             (re.match(r"habilidad (.+?) mana (\d+)->(\d+) enfriamiento (\d+) ticks", l) for l in lines) if m]
    ok &= verdict(spent == SPENT, "mana y enfriamiento de las seis, en orden: %s" % spent)
    ok &= verdict(any(re.match(r"escudo Druid1 1200 ticks", l) for l in lines), "Life Shield: escudo de 1200 ticks en Druid1")
    ok &= verdict(any(re.match(r"ritmo FlameMinion1 ×1\.7500", l) for l in lines), "Run Away: FlameMinion1 va a ×1,75")
    ok &= verdict(any(re.match(r"rockform abierto Earthfling1", l) for l in lines), "Rockform: Earthfling1 abre la roca")
    ok &= verdict(any(re.match(r"ojo Eye\d+ de Ranger1 \(tick \d+\)", l) for l in lines), "Divine Sight: el ojo sale del Ranger1")
    ok &= verdict(not any("SCRIPT ERROR" in l for l in lines), "sin SCRIPT ERROR")
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
