#!/usr/bin/env python3
"""Table and verdict of the determinism runner (det_run.sh).

usage: python3 -I det_report.py OUT_DIR [CASE...]      (env DET_MODES = the modes this invocation ran)

Reads OUT_DIR/<case>_<mode>.json (report), .events (record lines) and .meta (wall_s, rss_max_kb, contaminated,
watchdog). A case passes when every mode it has gives the digest of `fixed`. With DET_MODES set only those modes
count (an old file of a previous run is not a result of now) and a case needs `fixed` plus another fresh mode.
Prints a markdown table and a last line `DETERMINISM PASS` or `DETERMINISM FAIL`.
A watchdog kill fails the case. CONTAMINATED (a Godot that is not the bench's ran meanwhile) is only a warning: the
digests do not depend on the load (headless --fixed-fps; stress and window change the clock on purpose), so a run in
parallel with others gives the same verdict; only its wall time and RSS are not comparable.
"""
import json
import os
import sys

MODES = ["fixed", "fixed2", "stress", "window"]


def load(out, case, mode):
    base = os.path.join(out, "%s_%s" % (case, mode))
    rep, meta, lines = None, {}, None
    try:
        with open(base + ".json") as f:
            rep = json.load(f)
    except Exception:
        pass
    try:
        with open(base + ".meta") as f:
            for kv in f.read().split():
                k, _, v = kv.partition("=")
                meta[k] = v
    except Exception:
        pass
    try:
        with open(base + ".events") as f:
            lines = f.read().splitlines()
    except Exception:
        pass
    return rep, meta, lines


def main():
    out, cases = sys.argv[1], sys.argv[2:]
    only = os.environ.get("DET_MODES", "").split()
    modes = [m for m in MODES if m in only] if only else MODES
    rows, verdict, nocmp, contaminated = [], True, [], []
    for case in cases:
        ref, _, ref_lines = load(out, case, "fixed")
        if only and sum(1 for m in modes if load(out, case, m)[0] is not None) < 2:
            nocmp.append(case)
            verdict = False
        for mode in modes:
            rep, meta, lines = load(out, case, mode)
            if rep is None and not meta:
                continue
            digest = rep.get("digest", "") if rep else "(no report)"
            same = rep is not None and ref is not None and digest == ref.get("digest")
            if mode != "fixed" and not same:
                verdict = False
            if ref is None or (mode == "fixed" and rep is None):
                verdict = False
            first = ""
            if mode != "fixed" and lines is not None and ref_lines is not None and not same:
                for i in range(max(len(lines), len(ref_lines))):
                    a = ref_lines[i] if i < len(ref_lines) else "<end>"
                    b = lines[i] if i < len(lines) else "<end>"
                    if a != b:
                        first = "line %d: fixed '%s' / %s '%s'" % (i + 1, a[:90], mode, b[:90])
                        break
            flags = " ".join(f for f in (
                "CONTAMINATED" if meta.get("contaminated") == "1" else "",
                meta.get("watchdog", "") if meta.get("watchdog", "none") != "none" else "") if f)
            if meta.get("contaminated") == "1":
                contaminated.append("%s %s" % (case, mode))
            rows.append([
                case, mode, digest,
                str(rep.get("end_tick", "")) if rep else "",
                str(rep.get("events", "")) if rep else "",
                "=" if mode == "fixed" else ("=" if same else "!="),
                meta.get("wall_s", ""),
                "%d" % (int(meta["rss_max_kb"]) // 1024) if meta.get("rss_max_kb") else "",
                flags, first])
            if meta.get("watchdog", "none") not in ("none", ""):
                verdict = False
    print("| case | mode | sha256 | end_tick | lines | vs fixed | wall (s) | RSS max (MB) | warnings | first different line |")
    print("|---|---|---|---|---|---|---|---|---|---|")
    for r in rows:
        print("| " + " | ".join(c.replace("|", "\\|") for c in r) + " |")
    print()
    for c in nocmp:
        print("%s: no comparison (needs fixed plus another mode run now)" % c)
    if contaminated:
        print("contaminated (another Godot ran meanwhile; digests unaffected, wall time and RSS not comparable): %s"
              % ", ".join(contaminated))
    print("DETERMINISM %s" % ("PASS" if verdict and rows else "FAIL"))


if __name__ == "__main__":
    main()
