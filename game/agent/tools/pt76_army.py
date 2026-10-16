#!/usr/bin/env python3
"""pt76: creatures of each slot alive on the field at given minutes, by tag, from the ai_match event record
(--events=) : `summoned` lines add, `died` lines (slot > 0) subtract. Usage: pt76_army.py EVENTS [min,min]"""
import sys, re, collections
path = sys.argv[1]
mins = [float(m) for m in (sys.argv[2] if len(sys.argv) > 2 else "5,10").split(",")]
ev = []
for line in open(path):
    m = re.match(r"(\d+) summoned slot (\d+) (\S+)", line)
    if m:
        ev.append((int(m[1]), int(m[2]), m[3], +1)); continue
    m = re.match(r"(\d+) died \S+ (\S+) slot (\d+)", line)
    if m and int(m[3]) > 0:
        ev.append((int(m[1]), int(m[3]), m[2], -1))
for mn in mins:
    t = int(mn * 3600)
    alive = collections.defaultdict(collections.Counter)
    for tick, slot, tag, d in ev:
        if tick <= t:
            alive[slot][tag] += d
    print(f"min {mn:g} (tick {t}):", " | ".join(f"slot {s} total {sum(c.values())} {dict(+c)}" for s, c in sorted(alive.items())))
