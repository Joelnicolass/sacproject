#!/usr/bin/env python3
"""072 1d: render-frame jitter of the bodies a client sees vs the host, from the CSVs of agent/harness/jitter_watch.gd.

  python3 agent/tools/jitter_stats.py --host host.csv --client A.csv [--step2]

CSV columns: t_usec,frame,who,name,x,z,rtt_ms,last_correction. who = own | rival | creature | mark (walk_start / walk_end in `name`).
Per body and per side: the flat displacement per rendered frame, only while the body walks (speed over a 0.25 s window above
MIN_SPEED, 0.5 s trimmed off each edge of every walk, and only inside the walk_start..walk_end marks + TAIL_S when they exist):
  CV           std / mean of the step
  p95/median   95th percentile of the step over its median
  stalls       share of frames with a step under 1 % of the median (the body stopped while it walks)
JITTER PASS when, for every body and on BOTH sides (absolute, not relative to the host: the host judders too), CV <= MAX_CV,
p95/median <= MAX_P95M and stalls <= STALL_MAX, and each side renders steadily (p95 frame time <= MAX_FRAME_MS; above it the
machine is loaded and the run says so); else JITTER FAIL with the reasons.
--step2 adds the prediction criteria of the own wizard on the client: key -> first step <= 2 frames (walk_start mark to the first
frame that moved) and last_correction p95 <= 0.05 m, max <= 0.25 m.
Exit code 0 = pass, 1 = fail.
"""
import argparse
import csv
import math
import statistics
import sys

WINDOW_S = 0.25
MIN_SPEED = 0.5      # m/s over the window: walking
TRIM_S = 0.5
TAIL_S = 2.5         # a body seen across the net keeps moving after the local walk_end mark
MIN_STEPS = 30
# Absolute smoothness (user 2026-10-27: the relative criterion passed with judder plain to the eye).
MAX_CV = 0.15
MAX_P95M = 1.30
STALL_MAX = 0.01
MAX_FRAME_MS = 20.0
STALL_FRAC = 0.01
BODIES = ("own", "rival", "creature")


def read(path):
    rows = {b: [] for b in BODIES}
    marks = {}
    with open(path, newline="") as f:
        for r in csv.DictReader(f):
            t = int(r["t_usec"]) / 1e6
            if r["who"] == "mark":
                marks[r["name"]] = (t, int(r["frame"]))
            elif r["who"] in rows:
                corr = float(r["last_correction"]) if r["last_correction"] else None
                rows[r["who"]].append((t, int(r["frame"]), float(r["x"]), float(r["z"]), corr))
    return rows, marks


def walk_steps(series, marks):
    """The per-frame steps inside the trimmed walking runs of one body."""
    lo = marks["walk_start"][0] if "walk_start" in marks else -math.inf
    hi = (marks["walk_end"][0] + TAIL_S) if "walk_end" in marks else math.inf
    series = [s for s in series if lo <= s[0] <= hi]
    walking = []
    j = 0
    for i, s in enumerate(series):
        while series[j][0] < s[0] - WINDOW_S:
            j += 1
        dt = s[0] - series[j][0]
        d = math.hypot(s[2] - series[j][2], s[3] - series[j][3])
        walking.append(dt >= WINDOW_S * 0.5 and d / dt > MIN_SPEED)
    steps = []
    i = 0
    while i < len(series):
        if not walking[i]:
            i += 1
            continue
        k = i
        while k + 1 < len(series) and walking[k + 1]:
            k += 1
        t0, t1 = series[i][0] + TRIM_S, series[k][0] - TRIM_S
        for n in range(max(i, 1), k + 1):
            if t0 <= series[n][0] <= t1:
                steps.append(math.hypot(series[n][2] - series[n - 1][2], series[n][3] - series[n - 1][3]))
        i = k + 1
    return steps


def pct(sorted_values, p):
    if not sorted_values:
        return float("nan")
    k = (len(sorted_values) - 1) * p
    lo, hi = math.floor(k), math.ceil(k)
    return sorted_values[lo] + (sorted_values[hi] - sorted_values[lo]) * (k - lo)


def stats(steps):
    if len(steps) < MIN_STEPS:
        return None
    mean = statistics.fmean(steps)
    med = statistics.median(steps)
    s = sorted(steps)
    return {
        "n": len(steps),
        "cv": statistics.pstdev(steps) / mean if mean > 0 else float("nan"),
        "p95m": pct(s, 0.95) / med if med > 0 else float("nan"),
        "stall": sum(1 for v in steps if v < STALL_FRAC * med) / len(steps),
    }


def frame_p95_ms(series):
    """95th percentile of the time between rendered frames (the own wizard is sampled every frame)."""
    gaps = sorted((b[0] - a[0]) * 1000.0 for a, b in zip(series, series[1:]))
    return pct(gaps, 0.95) if gaps else float("inf")


def fmt(v, spec):
    return "   -  " if v is None else spec % v


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", required=True)
    ap.add_argument("--client", required=True)
    ap.add_argument("--step2", action="store_true")
    args = ap.parse_args()
    host_rows, host_marks = read(args.host)
    cli_rows, cli_marks = read(args.client)
    ok = True
    for side, rows in (("host", host_rows), ("client", cli_rows)):
        p95 = frame_p95_ms(rows["own"])
        steady = p95 <= MAX_FRAME_MS
        ok = ok and steady
        print("%s frame time p95 %.1f ms (<= %.0f)  %s" % (side, p95, MAX_FRAME_MS, "ok" if steady else "FAIL: loaded machine (frames lost)"))
    print("%-9s | %-26s | %-26s | %s" % ("body", "host   n   CV  p95/med  stall", "client n   CV  p95/med  stall", "verdict"))
    for body in BODIES:
        h = stats(walk_steps(host_rows[body], host_marks))
        c = stats(walk_steps(cli_rows[body], cli_marks))
        if h is None or c is None:
            ok = False
            print("%-9s | %-26s | %-26s | FAIL (not enough walking frames)" % (body, "n=%d" % (h["n"] if h else 0), "n=%d" % (c["n"] if c else 0)))
            continue
        reasons = []
        for side, v in (("host", h), ("client", c)):
            if v["cv"] > MAX_CV:
                reasons.append("%s CV %.2f > %.2f" % (side, v["cv"], MAX_CV))
            if v["p95m"] > MAX_P95M:
                reasons.append("%s p95/med %.2f > %.2f" % (side, v["p95m"], MAX_P95M))
            if v["stall"] > STALL_MAX:
                reasons.append("%s stalls %.1f %% > %.0f %%" % (side, 100 * v["stall"], 100 * STALL_MAX))
        ok = ok and not reasons
        print("%-9s | %5d %6.2f %7.2f %6.1f %% | %5d %6.2f %7.2f %6.1f %% | %s" % (
            body, h["n"], h["cv"], h["p95m"], 100 * h["stall"], c["n"], c["cv"], c["p95m"], 100 * c["stall"],
            "ok" if not reasons else "FAIL " + "; ".join(reasons)))
    if args.step2:
        ok = step2(cli_rows["own"], cli_marks) and ok
    print("JITTER PASS" if ok else "JITTER FAIL")
    return 0 if ok else 1


def step2(own, marks):
    good = True
    if "walk_start" in marks and own:
        t0, f0 = marks["walk_start"]
        before = [s for s in own if s[0] <= t0]
        if before:
            ref = before[-1]
            first = next((s for s in own if s[0] > t0 and math.hypot(s[2] - ref[2], s[3] - ref[3]) > 0.01), None)
            if first is None:
                print("step2: key -> first step: the own wizard never moved  FAIL")
                good = False
            else:
                frames = first[1] - f0
                verdict = frames <= 2
                good = good and verdict
                print("step2: key -> first step %d frames (<= 2)  %s" % (frames, "ok" if verdict else "FAIL"))
    lo = marks["walk_start"][0] if "walk_start" in marks else -math.inf
    hi = marks["walk_end"][0] if "walk_end" in marks else math.inf
    corr = sorted(s[4] for s in own if s[4] is not None and lo <= s[0] <= hi)
    if len(corr) < MIN_STEPS:
        print("step2: last_correction: no samples (the own wizard has no MpActor)  FAIL")
        return False
    p95, mx = pct(corr, 0.95), corr[-1]
    verdict = p95 <= 0.05 and mx <= 0.25
    print("step2: last_correction p95 %.3f m (<= 0.05), max %.3f m (<= 0.25)  %s" % (p95, mx, "ok" if verdict else "FAIL"))
    return good and verdict


if __name__ == "__main__":
    sys.exit(main())
