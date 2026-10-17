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
Prints A1's death (updates of its first dose), each dose's total and A2's health when its last dose ends, and the port's
`veneno <body> total … en … actualizaciones vida …` lines when a log is given.
"""
import re
import sys

T = 60
AMOUNT, DURATION, NERF = 200.0, 10.0, 1.3
IRES, FREG = 1000, 0.0
RESIST = 0.9  # Druid directRangedResistance
COOLDOWN_EXTRA = 3 * T
HEALTH = 800.0


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


if __name__ == "__main__":
    main(sys.argv[1:])
