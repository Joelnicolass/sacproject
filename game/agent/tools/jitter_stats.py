#!/usr/bin/env python3
"""072 1d: render-frame jitter of the bodies a client sees vs the host, from the CSVs of agent/harness/jitter_watch.gd.

  python3 agent/tools/jitter_stats.py --host host.csv --client A.csv [--step2]

CSV columns: t_usec,frame,who,name,x,z,rtt_ms,last_correction[,tick,corr_offset,guessed]. who = own | rival | creature | camera | mark
(the marks walk_start/walk_end, walk_turn_*, warp_*, walk_knock_*, knock_cast in `name`).
Per body and per side: the flat SPEED per rendered frame (displacement / that frame's dt: the step alone mixes frame time with
the network; same metric as the kit's lab, agreed with the kit session 2026-10-27), only while the body walks (speed over a 0.25 s window above
MIN_SPEED, 0.5 s trimmed off each edge of every walk, and only inside the walk_start..walk_end marks + TAIL_S when they exist):
  CV           std / mean of the speed
  p95/median   95th percentile of the speed over its median
  stalls       share of frames with a speed under 1 % of the median (the body stopped while it walks)
JITTER PASS when, for every body and on BOTH sides (absolute, not relative to the host: the host judders too), CV <= MAX_CV,
p95/median <= MAX_P95M and stalls <= STALL_MAX, and each side renders steadily (p95 frame time <= MAX_FRAME_MS; above it the
machine is loaded and the run says so); a creature (RELATIVE_BODIES) only on the client, against max(MAX_CV, 1.10 x host CV)
and host stalls + 1 %; else JITTER FAIL with the reasons.
--step2 adds the section "paso 2 (kit)" (072, asked by the kit session), all on the client except `guessed`, with these criteria:
  key -> first step <= 2 physics ticks (the walk_start mark to the first drawn frame that moved; frames printed too)
  last_correction max <= 0.05 m walking straight (walk) and walking while turning (walk_turn)
  blips (frames with speed > 1.5 x or < 0.5 x the median, per 3 s window, straight + turn): own and rival mean <= 1 per window
    (host side, the creature and the camera are printed, not judged)
  knock (the host casts Erupt on the client's wizard in the middle of walk_knock): the correction fades with tau 0.1 s, so the
    criterion is 95 % of the corr_offset peak gone <= 0.35 s after it, and no drawn step > 3 x the mean walking step (the time
    under 1 cm is printed as data). If last_correction > 2 m (correction_snap_distance) it is drawn at once: then corr_offset
    under 1 cm <= 0.05 s after that frame
  warp (the client casts Teleport, warp_start..warp_end): the drawn wizard jumps in one frame: frames with a step > 3 x the
    median walking step other than the jump itself = 0
  guessed (host side, the client's MpInput queue): printed only.
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
# Bodies whose speed is the game's to vary (agreed with the kit session 2026-10-27): judged on the client against the host.
RELATIVE_BODIES = ("creature",)
HOST_MARGIN = 1.10
STALL_FRAC = 0.01
BODIES = ("own", "rival", "creature", "camera")


def read(path):
    rows = {b: [] for b in BODIES}
    marks = {}
    with open(path, newline="") as f:
        for r in csv.DictReader(f):
            t = int(r["t_usec"]) / 1e6
            if r["who"] == "mark":
                marks[r["name"]] = (t, int(r["frame"]), int(r["tick"]) if r.get("tick") else None)
            elif r["who"] in rows:
                corr = float(r["last_correction"]) if r["last_correction"] else None
                tick = int(r["tick"]) if r.get("tick") else None
                off = float(r["corr_offset"]) if r.get("corr_offset") else None
                guessed = int(r["guessed"]) if r.get("guessed") else None
                rows[r["who"]].append((t, int(r["frame"]), float(r["x"]), float(r["z"]), corr, tick, off, guessed))
    return rows, marks


def walk_steps(series, marks, prefix="walk"):
    """The per-frame speeds inside the trimmed walking runs of one body."""
    return [v for _, v in walk_steps_t(series, marks, prefix)]


def walk_steps_t(series, marks, prefix="walk"):
    """(time, speed) per frame inside the trimmed walking runs of one body, between <prefix>_start and <prefix>_end + TAIL_S."""
    lo = marks[prefix + "_start"][0] if prefix + "_start" in marks else -math.inf
    hi = (marks[prefix + "_end"][0] + TAIL_S) if prefix + "_end" in marks else math.inf
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
                dt = series[n][0] - series[n - 1][0]
                if dt > 0:
                    steps.append((series[n][0], math.hypot(series[n][2] - series[n - 1][2], series[n][3] - series[n - 1][3]) / dt))
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
    global SNAP_DISTANCE
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", required=True)
    ap.add_argument("--client", required=True)
    ap.add_argument("--step2", action="store_true")
    ap.add_argument("--snap-distance", type=float, default=SNAP_DISTANCE,
                    help="correction_snap_distance the client ran with (0 = off, to judge a run made before the snap)")
    args = ap.parse_args()
    SNAP_DISTANCE = args.snap_distance
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
        # A creature's own speed changes (it starts, brakes, follows its path) show on the host too: on the client it may vary
        # as much as on the host (+10 %), never less smooth than the absolute bar; the host side of it is not judged.
        sides = (("client", c),) if body in RELATIVE_BODIES else (("host", h), ("client", c))
        for side, v in sides:
            relative = body in RELATIVE_BODIES
            max_cv = max(MAX_CV, HOST_MARGIN * h["cv"]) if relative else MAX_CV
            max_stall = max(STALL_MAX, h["stall"] + STALL_MAX) if relative else STALL_MAX
            if v["cv"] > max_cv:
                reasons.append("%s CV %.2f > %.2f" % (side, v["cv"], max_cv))
            if v["p95m"] > MAX_P95M:
                reasons.append("%s p95/med %.2f > %.2f" % (side, v["p95m"], MAX_P95M))
            if v["stall"] > max_stall:
                reasons.append("%s stalls %.1f %% > %.1f %%" % (side, 100 * v["stall"], 100 * max_stall))
        ok = ok and not reasons
        print("%-9s | %5d %6.2f %7.2f %6.1f %% | %5d %6.2f %7.2f %6.1f %% | %s" % (
            body, h["n"], h["cv"], h["p95m"], 100 * h["stall"], c["n"], c["cv"], c["p95m"], 100 * c["stall"],
            "ok" if not reasons else "FAIL " + "; ".join(reasons)))
    if args.step2:
        ok = step2(host_rows, host_marks, cli_rows, cli_marks) and ok
    print("JITTER PASS" if ok else "JITTER FAIL")
    return 0 if ok else 1


BLIP_WINDOW_S = 3.0
BLIP_HIGH = 1.5
BLIP_LOW = 0.5
BLIP_MEAN_MAX = 1.0
MAX_KEY_TICKS = 2
MAX_LAST_CORRECTION = 0.05
KNOCK_SEEN_OFFSET = 0.05   # a push is seen when the drawn wizard was this far from the real one at some moment
KNOCK_SEEN_CORRECTION = 0.25
OFFSET_HOME = 0.01
KNOCK_CLEAR_FRAC = 0.05   # 95 % of the peak gone
KNOCK_CLEAR_S = 0.35
KNOCK_STEP_FACTOR = 3.0
SNAP_DISTANCE = 2.0       # MpActor.correction_snap_distance of the wizard (wizard_body.tscn)
SNAP_HOME_S = 0.05
WARP_MIN_JUMP = 5.0
WARP_STEP_FACTOR = 3.0


def segment(marks, prefix):
    a, b = marks.get(prefix + "_start"), marks.get(prefix + "_end")
    return (a[0], b[0]) if a and b else None


def blips(series, marks):
    """Frames with a speed above BLIP_HIGH x or under BLIP_LOW x the median, per BLIP_WINDOW_S window, over the straight and the
    turning walks (each against its own median; a window shorter than 2 s at the end of a walk is dropped). (mean, max, windows)."""
    counts = []
    for prefix in ("walk", "walk_turn"):
        steps = walk_steps_t(series, marks, prefix)
        if len(steps) < MIN_STEPS:
            continue
        med = statistics.median(v for _, v in steps)
        t0, t1 = steps[0][0], steps[-1][0]
        w = t0
        while w < t1:
            if min(t1, w + BLIP_WINDOW_S) - w >= 2.0:
                counts.append(sum(1 for t, v in steps if w <= t < w + BLIP_WINDOW_S and (v > BLIP_HIGH * med or v < BLIP_LOW * med)))
            w += BLIP_WINDOW_S
    if not counts:
        return None
    return statistics.fmean(counts), max(counts), len(counts)


def key_to_step(own, marks):
    """(frames, ticks) from the walk_start mark to the first drawn frame that moved; None when it never moved."""
    t0, f0, k0 = marks["walk_start"]
    before = [s for s in own if s[0] <= t0]
    if not before:
        return None
    ref = before[-1]
    first = next((s for s in own if s[0] > t0 and math.hypot(s[2] - ref[2], s[3] - ref[3]) > 0.01), None)
    if first is None:
        return None
    ticks = first[5] - k0 if first[5] is not None and k0 is not None else None
    return first[1] - f0, ticks


def correction_max(own, marks, prefix):
    seg = segment(marks, prefix)
    if seg is None:
        return None
    values = sorted(s[4] for s in own if s[4] is not None and seg[0] <= s[0] <= seg[1])
    if len(values) < MIN_STEPS:
        return None
    return pct(values, 0.95), values[-1]


def knock_report(own, marks):
    """(text, ok): the push of the host's Erupt in the middle of walk_knock, seen as the drawn wizard's offset from the real one.
    Fade (the correction is exponential, tau 0.1 s): 95 % of the peak gone (corr_offset <= 5 % of it) within KNOCK_CLEAR_S of the
    peak, and no drawn step bigger than KNOCK_STEP_FACTOR x the mean walking step. The time under 1 cm is printed as data.
    Snap (the correction is longer than SNAP_DISTANCE: drawn at once): corr_offset under 1 cm within SNAP_HOME_S of that frame;
    the jump of that frame is the correction itself and is not counted as a step."""
    seg = segment(marks, "walk_knock")
    if seg is None:
        return "knock: no walk_knock marks  FAIL", False
    rows = [s for s in own if seg[0] <= s[0] <= seg[1] + 3.0]
    offs = [s for s in rows if s[6] is not None]
    if not offs:
        return "knock: no corr_offset samples (the own wizard has no MpActor)  FAIL", False
    peak = max(offs, key=lambda s: s[6])
    corr_max = max((s[4] for s in rows if s[4] is not None), default=0.0)
    if peak[6] < KNOCK_SEEN_OFFSET and corr_max < KNOCK_SEEN_CORRECTION:
        return ("knock: no push seen (corr_offset peak %.3f m, last_correction max %.3f m): the Erupt did not reach the wizard  FAIL"
                % (peak[6], corr_max)), False
    # Drawn steps inside the knock walk (the typical one is the mean walking step before the push is over).
    inside = [s for s in own if seg[0] <= s[0] <= seg[1]]
    steps = [(b[0], math.hypot(b[2] - a[2], b[3] - a[3])) for a, b in zip(inside, inside[1:])]
    if not steps:
        return "knock: no frames inside walk_knock  FAIL", False
    typical = statistics.fmean(v for _, v in steps)
    if SNAP_DISTANCE > 0 and corr_max > SNAP_DISTANCE:
        hit = max((s for s in rows if s[4] is not None), key=lambda s: s[4])
        home = next((s for s in rows if s[0] >= hit[0] and s[6] is not None and s[6] < OFFSET_HOME), None)
        if home is None:
            return "knock: correction %.2f m (> snap %.1f m) and corr_offset never got under 1 cm  FAIL" % (corr_max, SNAP_DISTANCE), False
        back = home[0] - hit[0]
        verdict = back <= SNAP_HOME_S
        return ("knock (snap): last_correction max %.2f m > %.1f m, drawn at once; corr_offset under 1 cm %.3f s after it (<= %.2f)  %s"
                % (corr_max, SNAP_DISTANCE, back, SNAP_HOME_S, "ok" if verdict else "FAIL")), verdict
    if peak[6] < KNOCK_SEEN_OFFSET:
        return ("knock: last_correction max %.2f m with no fade (corr_offset peak %.3f m): corrected in one step  ok" % (corr_max, peak[6])), True
    clear = next((s for s in rows if s[0] > peak[0] and s[6] is not None and s[6] <= KNOCK_CLEAR_FRAC * peak[6]), None)
    home = next((s for s in rows if s[0] > peak[0] and s[6] is not None and s[6] < OFFSET_HOME), None)
    if clear is None:
        return "knock: corr_offset peak %.2f m and 95 %% of it never went away  FAIL" % peak[6], False
    back = clear[0] - peak[0]
    big = max(v for _, v in steps)
    fade_ok = back <= KNOCK_CLEAR_S
    step_ok = big <= KNOCK_STEP_FACTOR * typical
    verdict = fade_ok and step_ok
    home_text = "%.2f s" % (home[0] - peak[0]) if home is not None else "never"
    return ("knock: corr_offset peak %.2f m (%.2f s into walk_knock), 95 %% gone %.2f s later (<= %.2f) %s; under 1 cm %s (data); "
            "largest drawn step %.2f m vs mean walking step %.2f m (<= %.0f x) %s; last_correction max %.2f m  %s"
            % (peak[6], peak[0] - seg[0], back, KNOCK_CLEAR_S, "ok" if fade_ok else "FAIL", home_text, big, typical,
               KNOCK_STEP_FACTOR, "ok" if step_ok else "FAIL", corr_max, "ok" if verdict else "FAIL")), verdict


def warp_report(own, marks):
    """(text, ok): the drawn wizard jumps in ONE frame when Teleport lands (warp_start..warp_end)."""
    seg = segment(marks, "warp")
    start = segment(marks, "walk")
    if seg is None or start is None:
        return "warp: no warp/walk marks  FAIL", False
    walking = [s for s in own if start[0] + 1.0 <= s[0] <= start[1] - 1.0]
    walk_steps_m = sorted(math.hypot(b[2] - a[2], b[3] - a[3]) for a, b in zip(walking, walking[1:]))
    if not walk_steps_m:
        return "warp: no walking frames to compare with  FAIL", False
    typical = statistics.median(walk_steps_m)
    rows = [s for s in own if seg[0] <= s[0] <= seg[1]]
    steps = [math.hypot(b[2] - a[2], b[3] - a[3]) for a, b in zip(rows, rows[1:])]
    if not steps:
        return "warp: no frames between the marks  FAIL", False
    jump = max(steps)
    at = steps.index(jump)
    if jump < WARP_MIN_JUMP:
        return "warp: no warp seen (largest step %.2f m between warp_start and warp_end)  FAIL" % jump, False
    between = [v for k, v in enumerate(steps) if k != at and v > WARP_STEP_FACTOR * typical]
    verdict = not between
    after = [s[6] for s in rows[at + 1:] if s[6] is not None]
    return ("warp: jump %.1f m in one frame (%.3f s dt); frames with a step > %.0f x the walking step (%.2f m) besides it: %d (0)%s  %s"
            % (jump, rows[at + 1][0] - rows[at][0], WARP_STEP_FACTOR, typical, len(between),
               ", intermediate steps %s m" % ", ".join("%.2f" % v for v in between[:6]) if between else "",
               "ok" if verdict else "FAIL")
            + ("  corr_offset after it max %.3f m" % max(after) if after else "")), verdict


def guessed_report(rival_rows):
    values = [(s[0], s[7]) for s in rival_rows if s[7] is not None]
    if not values:
        return "guessed (host, the client's MpInput): no samples"
    seconds = sorted({round(t) for t, _ in values})
    per_second = {}
    for t, g in values:
        per_second[int(t)] = g
    keys = sorted(per_second)
    jumps = [per_second[b] - per_second[a] for a, b in zip(keys, keys[1:])]
    return ("guessed (host, the client's MpInput): %d -> %d over %d s, most in one second +%d, seconds with a guess %d"
            % (values[0][1], values[-1][1], len(seconds), max(jumps, default=0), sum(1 for j in jumps if j > 0)))


def step2(host_rows, host_marks, cli_rows, cli_marks):
    print("--- paso 2 (kit) ---")
    own = cli_rows["own"]
    good = True
    if "walk_start" in cli_marks and own:
        got = key_to_step(own, cli_marks)
        if got is None:
            print("key -> first step: the own wizard never moved  FAIL")
            good = False
        else:
            frames, ticks = got
            if ticks is None:
                verdict = frames <= MAX_KEY_TICKS
                print("key -> first step: %d frames (no tick column; <= %d)  %s" % (frames, MAX_KEY_TICKS, "ok" if verdict else "FAIL"))
            else:
                verdict = ticks <= MAX_KEY_TICKS
                print("key -> first step: %d ticks, %d frames (<= %d ticks)  %s" % (ticks, frames, MAX_KEY_TICKS, "ok" if verdict else "FAIL"))
            good = good and verdict
    for prefix, label in (("walk", "straight"), ("walk_turn", "turning")):
        got = correction_max(own, cli_marks, prefix)
        if got is None:
            print("last_correction walking %s: no samples (marks or MpActor missing)  FAIL" % label)
            good = False
            continue
        verdict = got[1] <= MAX_LAST_CORRECTION
        good = good and verdict
        print("last_correction walking %s: p95 %.3f m, max %.3f m (<= %.2f)  %s" % (label, got[0], got[1], MAX_LAST_CORRECTION, "ok" if verdict else "FAIL"))
    print("blips per %.0f s window (speed > %.1f x or < %.1f x the median), straight + turning walks: mean / max (windows)" % (BLIP_WINDOW_S, BLIP_HIGH, BLIP_LOW))
    for side, rows, marks in (("client", cli_rows, cli_marks), ("host  ", host_rows, host_marks)):
        for body in BODIES:
            got = blips(rows[body], marks)
            if got is None:
                print("  %s %-8s -" % (side, body))
                continue
            judged = side == "client" and body in ("own", "rival")
            verdict = got[0] <= BLIP_MEAN_MAX
            if judged:
                good = good and verdict
            print("  %s %-8s %.2f / %d (%d)%s" % (side, body, got[0], got[1], got[2], ("  " + ("ok" if verdict else "FAIL (mean > %.0f)" % BLIP_MEAN_MAX)) if judged else ""))
    text, verdict = knock_report(own, cli_marks)
    good = good and verdict
    print(text)
    text, verdict = warp_report(own, cli_marks)
    good = good and verdict
    print(text)
    print(guessed_report(host_rows["rival"]))
    return good


if __name__ == "__main__":
    sys.exit(main())
