#!/usr/bin/env python3
"""Melee approach check (MeleeAttack.close_in, sacengine `attack`, state.d:12857-12862) on the numbers the port logged.

Usage: python3 -I agent/tools/melee_gap_expect.py LOG [LOG...]     (the Godot log of the final_spit_melee flow, the log of
       the s7 bench case: agent/out/det/s7_fixed.log). Needs MeleeAttack.log_gap on (debug/ai_match.gd and debug/ability_spit.gd).
       python3 -I agent/tools/melee_gap_expect.py --table LOG...  also prints the per-creature table.

Log line (one per tick an attacker in ATTACK has its target in reach):
  melee_gap A->B d=<centre-centre> gap=<d - radius A - radius B> vx=.. vz=.. tick=T reach=rA foe_reach=rB radius=hA foe_radius=hB
radius is BodySeparation.half_size (the box the bodies push each other out of), reach the melee size (BodyLibrary reach).

A contact window is one attacker and target on consecutive ticks (a gap of more than GAP_TICKS ticks starts a new one). Checks:
  1. Overlap:    the box gap (axis_gap: the wider axis of the two BodySeparation boxes, which is what pushes them apart) never
                 below -0.05 m: the bodies do not sink into each other. (gap, the centre distance minus both radii, is shown in
                 the log; on a diagonal it is smaller than the box gap and is not an overlap.)
  2. Approach:   a settled window (>= SETTLE ticks) ends at close_in's goal, within 0.02 m: the sacengine distance 0.8 * forward *
                 reach from the target's edge (d = foe_reach + 0.8 * 1.3 * reach), or, when that lies inside what BodySeparation
                 allows, the box gap 0.1 it rests two bodies at (half of blockSlack; counted as «held at the BodySeparation floor»).
                 Past both is a failure, and so is a body that settles at neither.
  3. Tremor:     the approach speed (d[t-1] - d[t]) changes sign at most once per window (a settled window has none).
Exit 0 when every check passes, 1 otherwise (the failing creature and the cause are printed).
"""
import re
import sys
from collections import defaultdict

FORWARD = 1.3
FACTOR = 0.8
OVERLAP_MIN = -0.05
GOAL_TOL = 0.02
GAP_TICKS = 3
SETTLE = 6
REST_GAP = 0.1  # BodySeparation.rest_distance: half of blockSlack between the boxes
MOVE_EPS = 0.005  # m per tick (0.3 m/s) under which d is not moving: the alternate pushes of two settling bodies

LINE = re.compile(r"melee_gap (\S+?)->(\S+) d=(-?[\d.]+) gap=(-?[\d.]+) vx=(-?[\d.]+) vz=(-?[\d.]+) tick=(\d+) "
                  r"reach=([\d.]+) foe_reach=([\d.]+) radius=([\d.]+) foe_radius=([\d.]+) axis_gap=(-?[\d.]+)")


def parse(path):
    rows = []
    for line in open(path, errors="replace"):
        m = LINE.search(line)
        if m:
            a, b, d, gap, vx, vz, tick, reach, foe_reach, radius, foe_radius, axis = m.groups()
            rows.append(dict(a=a, b=b, d=float(d), gap=float(gap), vx=float(vx), vz=float(vz), tick=int(tick),
                             reach=float(reach), foe_reach=float(foe_reach), radius=float(radius), foe_radius=float(foe_radius), axis=float(axis)))
    return rows


def windows(rows):
    by_pair = defaultdict(list)
    for r in rows:
        by_pair[(r["a"], r["b"])].append(r)
    out = []
    for pair, seq in by_pair.items():
        cur = [seq[0]]
        for r in seq[1:]:
            if r["tick"] - cur[-1]["tick"] > GAP_TICKS:
                out.append(cur)
                cur = []
            cur.append(r)
        out.append(cur)
    return out


def approach_signs(w):
    """Signs of the approach speed (d[t-1] - d[t]) over the window, ignoring moves under MOVE_EPS."""
    signs = []
    for prev, now in zip(w, w[1:]):
        v = prev["d"] - now["d"]
        if abs(v) >= MOVE_EPS:
            signs.append(1 if v > 0 else -1)
    return signs


def check(paths, table):
    failures = []
    stats = defaultdict(lambda: dict(min_gap=9e9, finals=[], flips=0, windows=0, overlap_at=None))
    for path in paths:
        rows = parse(path)
        if not rows:
            failures.append("%s: no melee_gap lines (is MeleeAttack.log_gap on?)" % path)
            continue
        for w in windows(rows):
            kind = w[0]["a"].rstrip("0123456789")
            s = stats[kind]
            s["windows"] += 1
            low = min(w, key=lambda r: r["axis"])
            if low["axis"] < s["min_gap"]:
                s["min_gap"] = low["axis"]
            if low["axis"] < OVERLAP_MIN:
                failures.append("%s: %s->%s tick %d box gap %.3f < %.2f (overlap)" % (path, low["a"], low["b"], low["tick"], low["axis"], OVERLAP_MIN))
            signs = approach_signs(w)
            flips = sum(1 for x, y in zip(signs, signs[1:]) if x != y)
            s["flips"] = max(s["flips"], flips)
            if flips > 1:
                failures.append("%s: %s->%s tick %d..%d: approach speed flips sign %d times (tremor)" % (path, w[0]["a"], w[0]["b"], w[0]["tick"], w[-1]["tick"], flips))
            if len(w) >= SETTLE:
                last = w[-1]
                goal_d = last["foe_reach"] + FACTOR * FORWARD * last["reach"]
                goal_gap = goal_d - last["radius"] - last["foe_radius"]  # centre to centre, as close_in's sacengine goal
                tail = w[-3:]
                still = max(abs(a["d"] - b["d"]) for a, b in zip(tail, tail[1:])) < MOVE_EPS
                # BodySeparation rests two bodies when the wider axis of their boxes, grown by half of blockSlack, stops overlapping.
                held = REST_GAP - GOAL_TOL <= last["axis"] <= REST_GAP + GOAL_TOL
                s["finals"].append((last["gap"], goal_gap, still, last["a"], last["b"], last["tick"]))
                if last["axis"] < REST_GAP - GOAL_TOL and last["gap"] < goal_gap - GOAL_TOL:
                    failures.append("%s: %s->%s tick %d final gap %.3f (axis %.3f) below the goal %.3f and the push floor (walked past the goal)" % (path, last["a"], last["b"], last["tick"], last["gap"], last["axis"], goal_gap))
                elif still and held and last["gap"] > goal_gap + GOAL_TOL:
                    s["push"] = s.get("push", 0) + 1
                elif still and not held and last["gap"] > goal_gap + GOAL_TOL:
                    failures.append("%s: %s->%s tick %d settled at gap %.3f (axis %.3f), neither the goal %.3f nor the push floor" % (path, last["a"], last["b"], last["tick"], last["gap"], last["axis"], goal_gap))
    if table or True:
        print("%-14s %7s %9s %9s %9s %6s" % ("creature", "windows", "min gap", "final(med)", "goal", "flips"))  # goal: sacengine, centre gap
        for kind, s in sorted(stats.items()):
            fin = sorted(f[0] for f in s["finals"])
            goals = sorted(f[1] for f in s["finals"])
            med = fin[len(fin) // 2] if fin else float("nan")
            goal = goals[len(goals) // 2] if goals else float("nan")
            print("%-14s %7d %9.3f %9.3f %9.3f %6d%s" % (kind, s["windows"], s["min_gap"], med, goal, s["flips"],
                  ("  (%d windows held at the BodySeparation floor)" % s["push"]) if s.get("push") else ""))
    return failures


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        print(__doc__)
        sys.exit(2)
    bad = check(args, "--table" in sys.argv)
    for f in bad:
        print("FAIL", f)
    print("MELEE GAP " + ("PASS" if not bad else "FAIL"))
    sys.exit(1 if bad else 0)
