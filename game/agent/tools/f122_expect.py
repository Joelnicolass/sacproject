#!/usr/bin/env python3
"""F122 (RFC-030k-a): what sacengine would do with the Necryl's Disease on lane A of debug/f122_poison, replicated from
state.d, next to what the port logged.

Usage: python3 -I agent/tools/f122_expect.py [godot log of debug/f122_poison or the f122 bench case] [--order port|sacengine]

Model (one dose of cena on A1, A2 within 2 m of A1's box, A3 out of reach):
- poison() (state.d:11601-11614): amount / duration / 1.3 per second for duration·60 frames; ires += 1000, freg ×0.
- updatePoison (23535-23590), per frame and per dose: an infectious dose first infects every body around whose
  infectionCooldown is 0 with a dose of the carrier's int Σ poisonDamage for `lifetime - frame` frames (cooldown
  lifetime + 180); then it deals per_s/60 · max(0, directRangedResistance + 1e-3·Σ ires) (dealDamage, 8950-8957) and ends
  after the update whose frame reached lifetime (lifetime + 1 updates). A dead body ends its doses (canBePoisoned).
- freg 0: no regeneration while poisoned (14403), so health only goes down.
--order port: the port's order (Poisoning of each body in tree order, A1 then A2; a dose given to a body whose turn has
passed this tick runs from the next one). --order sacengine: one global list, appended doses run the same frame, a removed
dose is swapped with the last (Effects.removePoison, 6569-6572).
F164b: every dose also feeds its thrower (dealPoisonDamage -> dealDamage with the attacker, 23585, 9415-9419, 8933-8947: healFromDrain
of what the tick really took, drain 0.5) and the burst feeds the whole SPEL amount (healFromDrain, 23523, 24360, 24879); the infection
passes the attacker on (infect), so the Necryl also feeds on Druid2. `check_drain` reads the port's `drena …` lines against that.
Prints A1's death (updates of its first dose), each dose's total and A2's health when its last dose ends, and the port's
`veneno <body> total … en … actualizaciones vida …` lines when a log is given.
"""
import json
import os
import re
import sys

T = 60
AMOUNT, DURATION, NERF = 200.0, 10.0, 1.3
IRES, FREG = 1000, 0.0
RESIST = 0.9  # Druid directRangedResistance
COOLDOWN_EXTRA = 3 * T
HEALTH = 800.0


HERE = os.path.dirname(os.path.abspath(__file__))
FEEDS = []  # (tick, body name, what the tick took): the Necryl's drain in simulate()


class Dose:
    def __init__(self, body, per_s, lifetime, label):
        self.body, self.per_s, self.lifetime, self.label = body, per_s, lifetime, label
        self.frame, self.updates, self.taken = 0, 0, 0.0


class Body:
    def __init__(self, name, health, reach):
        self.name, self.health, self.reach = name, health, reach
        self.doses, self.cool_until, self.dead_at = [], 0, None


def give(target, carrier, source, tick, log):
    if target.cool_until > tick:
        return None
    total = sum(int(d.per_s) for d in carrier.doses)
    left = source.lifetime - source.frame
    verb = "reinfectado" if target.doses else "infectado"
    dose = Dose(target, float(total), left, "%s<-%s" % (target.name, carrier.name))
    target.doses.append(dose)
    target.cool_until = tick + left + COOLDOWN_EXTRA
    log.append("tick %d: %s %s por %s: %d/s, %d cuadros" % (tick, target.name, verb, carrier.name, total, left))
    return dose


def step(dose, tick, log):
    body = dose.body
    dose.updates += 1
    bonus = 1e-3 * IRES * len(body.doses)
    dealt = min(body.health, dose.per_s / T * max(0.0, RESIST + bonus))
    body.health -= dealt
    if dealt > 0.0:
        FEEDS.append((tick, body.name, dealt))
    dose.taken += dealt
    if body.health <= 0.0 and body.dead_at is None:
        body.dead_at = (tick, dose.updates, dose.label)
    if dose.frame >= dose.lifetime:
        return False
    dose.frame += 1
    return True


def end(dose, log, ended):
    dose.body.doses.remove(dose)
    ended.append((dose, dose.body.health))
    log.append("veneno %s total %.1f en %d actualizaciones vida %d" % (dose.label, dose.taken, dose.updates, round(dose.body.health)))


def simulate(order):
    del FEEDS[:]
    a1 = Body("Druid1", HEALTH, True)
    a2 = Body("Druid2", HEALTH, True)
    bodies = [a1, a2]
    first = Dose(a1, AMOUNT / DURATION / NERF, int(DURATION * T), "Druid1 (cena)")
    a1.doses.append(first)
    log, ended = [], []
    effects = [first]
    for tick in range(0, 5000):
        if order == "port":
            for body in bodies:
                alive = body.health > 0.0
                for dose in list(body.doses):
                    if alive:
                        for other in bodies:
                            if other is not body and other.health > 0.0:
                                give(other, body, dose, tick, log)
                    if not alive or not step(dose, tick, log):
                        end(dose, log, ended)
        else:
            i = 0
            while i < len(effects):
                dose = effects[i]
                body = dose.body
                alive = body.health > 0.0
                if alive:
                    for other in bodies:
                        if other is not body and other.health > 0.0:
                            added = give(other, body, dose, tick, log)
                            if added:
                                effects.append(added)
                if not alive or not step(dose, tick, log):
                    end(dose, log, ended)
                    effects[i] = effects[-1]
                    effects.pop()
                    continue
                i += 1
        if not a1.doses and not a2.doses:
            break
    return a1, a2, log, ended


def port_lines(path):
    pattern = re.compile(r"veneno (\S+) total (-?\d+(?:\.\d+)?) en (\d+) actualizaciones vida (-?\d+)")
    found = []
    with open(path, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            match = pattern.search(line)
            if match:
                found.append((match.group(1), float(match.group(2)), int(match.group(3)), int(match.group(4))))
    return found


def data():
    root = os.path.join(HERE, "..", "..", "assets", "original", "data")
    creatures = json.load(open(os.path.join(root, "creatures.json"), encoding="utf-8"))
    spel = json.load(open(os.path.join(root, "abilities.json"), encoding="utf-8"))
    return creatures, spel


def check_drain(path):
    """The thrower's drain on lane A (Necryl1), B (Deadeye1) and C (Hellmouth1). Returns True when everything matches."""
    creatures, spel = data()
    line_re = re.compile(r"drena (\S+) de (\S+) (-?\d+(?:\.\d+)?) \(escala (-?\d+(?:\.\d+)?)\) -> vida (-?\d+(?:\.\d+)?) ganada (-?\d+(?:\.\d+)?) \(tick (\d+)\)")
    feeds = []
    for line in open(path, encoding="utf-8", errors="replace").read().splitlines():
        m = line_re.match(line)
        if m:
            feeds.append((m.group(1), m.group(2), float(m.group(3)), float(m.group(4)), float(m.group(5)), float(m.group(6)), int(m.group(7))))
    ok = True

    def verdict(good, text):
        print("%s  %s" % ("PASS" if good else "FAIL", text))
        return good

    cases = (("Deadeye1", "plfd", "lfda"), ("Hellmouth1", "nomd", "mhba"), ("Necryl1", "glsd", "cena"))
    for who, tag, shot in cases:
        drain, full = float(creatures[tag]["drain"]), float(creatures[tag]["health"])
        amount, duration = float(spel[shot]["amount"]), float(spel[shot]["duration"])
        mine = [f for f in feeds if f[0] == who]
        ok &= verdict(len(mine) >= 2, "%s: %d líneas de cura" % (who, len(mine)))
        burst = mine[0] if mine else None
        ok &= verdict(burst is not None and abs(burst[2] - amount) <= 1e-3 and abs(burst[3] - drain) <= 1e-3,
                      "%s: la ráfaga cura con el monto entero del SPEL %s (%.0f · %.2f)" % (who, shot, amount, drain))
        prev = None
        for f in mine:
            want = min(drain * f[2], full - prev) if prev is not None else None
            if prev is not None and abs(f[5] - want) > 1e-3 and f[4] < full - 1e-3:
                ok &= verdict(False, "%s: tick %d cura %.4f, esperado %.4f" % (who, f[6], f[5], want))
            prev = f[4]
        if who != "Necryl1":
            tick = amount / duration / NERF / T * RESIST
            ticks = [f for f in mine if abs(f[2] - amount) > 1e-3]  # a line with the whole amount is a burst (the Hellmouth fires again)
            bad = [f for f in ticks if abs(f[2] - tick) > 1e-3]
            ok &= verdict(not bad and len(mine) - len(ticks) >= 1, "%s: %d curas por tick de %.4f (el daño que toma el Druid), %d ráfagas%s" % (
                who, len(ticks), tick, len(mine) - len(ticks), "" if not bad else ", distinta: %s" % (bad[0],)))
        else:
            # The simulation's tick 0 is the update after the burst; the Necryl dies in the scenario (the Disease kills it), so
            # only the ticks up to its last line are compared.
            base, last = mine[0][6] + 1, mine[-1][6]
            for druid in ("Druid1", "Druid2"):
                got = sorted(f[2] for f in mine[1:] if f[1] == druid)
                want = sorted(d for t, n, d in FEEDS if n == druid and base + t <= last)
                same = len(got) == len(want) and all(abs(a - b) <= 1e-3 for a, b in zip(got, want))
                ok &= verdict(same, "Necryl1 de %s: %d curas por tick (simulación %d), sumas %.3f / %.3f" % (
                    druid, len(got), len(want), sum(got), sum(want)))
    return ok


def main(argv):
    order = "port"
    log_path = None
    args = list(argv)
    while args:
        arg = args.pop(0)
        if arg == "--order" and args:
            order = args.pop(0)
        else:
            log_path = arg
    per_s = AMOUNT / DURATION / NERF
    print("primer tick sobre Druid1: %.4f (esperado 0.4872)" % (per_s / T * (RESIST + 1e-3 * IRES)))
    print("Deadeye: total %.1f en %d actualizaciones" % (720.0 / 10.0 / NERF / T * RESIST * (10 * T + 1), 10 * T + 1))
    print("Hellmouth: 120 ticks %.1f" % (800.0 / 10.0 / NERF / T * 0.9 * 120))
    a1, a2, log, ended = simulate(order)
    print("orden %s" % order)
    for line in log:
        print("  " + line)
    if a1.dead_at:
        print("Druid1 muere en el tick %d (actualización %d de %s)" % a1.dead_at)
    last_a2 = [h for d, h in ended if d.body is a2]
    if last_a2:
        print("Druid2 vida al terminar su última dosis: %.1f" % last_a2[-1])
    if log_path:
        print("puerto (%s):" % log_path)
        for name, total, updates, health in port_lines(log_path):
            print("  veneno %s total %.1f en %d actualizaciones vida %d" % (name, total, updates, health))
        good = check_drain(log_path)
        print("RESULTADO %s" % ("PASS" if good else "FAIL"))
        sys.exit(0 if good else 1)


if __name__ == "__main__":
    main(sys.argv[1:])
