#!/usr/bin/env bash
# RFC-032 032a (F144): the determinism bench. Same match, three clocks, one digest.
#   agent/run_determinism.sh CASE|all [MODE...]   CASE: s7 s7_npcs s1_trivial f139 f148 (F148: Abomination drops) f121 (F121: push, vortex, implosion) f122 (F122: poison shots) f123 (F123: fire shots) f149 (F149: Silverback freeze)   MODE: fixed stress window fixed2
#                                                  (default modes: fixed stress window; fixed2 = fixed again, criterion 1)
#   agent/run_determinism.sh table                 verdict + markdown table from agent/out/det/
#   agent/run_determinism.sh quick                 short pass for intermediate cuts (see below)
# Modes (debug/ai_match.tscn):
#   fixed   headless --fixed-fps 60 (as fast as it can, 1/60 per frame: the reference)
#   stress  headless in real time, --max-fps 6 (up to 8 physics steps per frame: render clock != tick clock)
#   window  --max-fps 60 --resolution 1280x720 --autostart --quit (a window is comparable only with --autostart)
# Every Godot goes through agent/harness/godot_run.sh, one at a time. Watchdog: kill at RSS > 2.5 GB or after the
# time limit of the mode; CONTAMINATED in the meta if another Godot (not the user's editor) shows up during the run.
# Out: agent/out/det/<case>_<mode>.json (AI_REPORT), .events (audit lines), .log, .meta (wall_s, rss, flags).
# Verdict: a case passes when every mode it has gives the digest of `fixed`; the first different events line is printed.
set -u
ROOT=/Users/joelsartori/Development/sacproject/game
BIN=/Applications/Godot.app/Contents/MacOS/Godot
OUT="$ROOT/agent/out/det"
ALL_CASES=(s7 s7_npcs s1_trivial f139)
RSS_LIMIT_KB=2500000

report() { # [case...]
  python3 -I - "$OUT" "$@" <<'PY'
import json, os, sys
out, wanted = sys.argv[1], sys.argv[2:]
cases = wanted or ["s7", "s7_npcs", "s1_trivial", "f139"]
modes = ["fixed", "fixed2", "stress", "window"]
def load(case, mode):
    base = os.path.join(out, "%s_%s" % (case, mode))
    rep, meta, lines = None, {}, None
    try: rep = json.load(open(base + ".json"))
    except Exception: pass
    try:
        for kv in open(base + ".meta").read().split():
            k, _, v = kv.partition("="); meta[k] = v
    except Exception: pass
    try: lines = open(base + ".events").read().splitlines()
    except Exception: pass
    return rep, meta, lines
rows, verdict = [], True
for case in cases:
    ref, _, ref_lines = load(case, "fixed")
    for mode in modes:
        rep, meta, lines = load(case, mode)
        if rep is None and not meta:
            continue
        digest = rep.get("digest", "") if rep else "(sin reporte)"
        same = rep is not None and ref is not None and digest == ref.get("digest")
        if mode != "fixed" and not same:
            verdict = False
        if ref is None or (mode == "fixed" and rep is None):
            verdict = False
        first = ""
        if mode != "fixed" and lines is not None and ref_lines is not None and not same:
            for i in range(max(len(lines), len(ref_lines))):
                a = ref_lines[i] if i < len(ref_lines) else "<fin>"
                b = lines[i] if i < len(lines) else "<fin>"
                if a != b:
                    first = "línea %d: fixed «%s» · %s «%s»" % (i + 1, a[:90], mode, b[:90]); break
        flags = " ".join(f for f in ("CONTAMINATED" if meta.get("contaminated") == "1" else "",
                                      meta.get("watchdog", "") if meta.get("watchdog", "none") != "none" else "") if f)
        rows.append([case, mode, digest, str(rep.get("end_tick", "")) if rep else "", str(rep.get("events", "")) if rep else "",
                     "=" if mode == "fixed" else ("=" if same else "≠"), meta.get("wall_s", ""),
                     "%d" % (int(meta["rss_max_kb"]) // 1024) if meta.get("rss_max_kb") else "", flags, first])
        if flags:
            verdict = False
print("| caso | modo | sha256 | end_tick | líneas | vs fixed | pared (s) | RSS máx (MB) | avisos | primera línea distinta |")
print("|---|---|---|---|---|---|---|---|---|---|")
for r in rows:
    print("| " + " | ".join(c.replace("|", "\\|") for c in r) + " |")
print()
print("DETERMINISM %s" % ("PASS" if verdict and rows else "FAIL"))
PY
}

if [ "${1:-}" = "table" ]; then
  shift; report "$@"; exit 0
fi

CASE_ARG=${1:?usage: run_determinism.sh CASE|all [MODE...] | table}
shift
MODES=("$@"); [ ${#MODES[@]} -eq 0 ] && MODES=(fixed stress window)
# quick (cortes intermedios, ~3-4 min): s1_quick (IA con hechizos, 0,5 min) en los 3 modos + s7, f139, f148, f121, f122, f123 y f149 solo fixed,
# comparados con agent/det_baseline.txt (caso digest). La pasada `all` queda para el cierre de cada RFC.
if [ "$CASE_ARG" = quick ]; then
  "$0" s1_quick fixed stress window || true
  "$0" s7 fixed >/dev/null; "$0" f139 fixed >/dev/null; "$0" f148 fixed >/dev/null; "$0" f121 fixed >/dev/null; "$0" f122 fixed >/dev/null; "$0" f123 fixed >/dev/null; "$0" f149 fixed >/dev/null
  ok=1
  while read -r c want; do
    [ -z "$c" ] && continue
    got=$(python3 -I -c "import json,sys;print(json.load(open(sys.argv[1])).get('digest',''))" "$OUT/${c}_fixed.json" 2>/dev/null)
    if [ "$got" = "$want" ]; then echo "baseline $c OK ${got:0:8}"; else echo "baseline $c FAIL got=${got:0:8} want=${want:0:8}"; ok=0; fi
  done < "$ROOT/agent/det_baseline.txt"
  "$0" table s1_quick | grep -q "DETERMINISM PASS" || ok=0
  [ $ok = 1 ] && { echo "QUICK PASS"; exit 0; } || { echo "QUICK FAIL"; exit 1; }
fi
if [ "$CASE_ARG" = all ]; then CASES=("${ALL_CASES[@]}"); else CASES=("$CASE_ARG"); fi
mkdir -p "$OUT"
cd "$ROOT"

case_args() { # case -> ai_match args (no out/events)
  case "$1" in
    s7) echo "--rules=res://debug/rules/ai_duel_seeded.tres --seed=7 --minutes=2" ;;
    s7_npcs) echo "--rules=res://debug/rules/ai_duel_seeded.tres --seed=7 --minutes=2 --npcs" ;;
    s1_trivial) echo "--rules=res://debug/rules/ai_vs_trivial.tres --seed=1 --minutes=3" ;;
    f139) echo "--rules=res://debug/rules/f139_ff_clouds.tres --seed=7 --minutes=0.5" ;;
    s1_quick) echo "--rules=res://debug/rules/ai_vs_trivial.tres --seed=1 --minutes=0.5" ;;
    f148) echo "--rules=res://debug/rules/f148_droplets.tres --seed=7 --minutes=0.5" ;;
    f121) echo "--rules=res://debug/rules/f121_push.tres --seed=7 --minutes=0.5" ;;
    f122) echo "--rules=res://debug/rules/f122_poison.tres --seed=7 --minutes=0.5" ;;
    f123) echo "--rules=res://debug/rules/f123_fire_shots.tres --seed=7 --minutes=0.5" ;;
    f149) echo "--rules=res://debug/rules/f149_freeze.tres --seed=7 --minutes=0.6" ;;
    *) return 1 ;;
  esac
}

# The Godot child of the godot_run.sh pid: RSS cap, time cap (from the moment Godot starts, not the lock wait),
# and any other Godot (not ours, not the user's editor) marks the run CONTAMINATED.
watch() { # runner_pid meta limit_s
  local runner=$1 meta=$2 limit=$3 start="" g="" rss_max=0 contaminated=0 dog=none
  while kill -0 "$runner" 2>/dev/null; do
    # Only the Godot child counts (godot_run.sh also spawns mkdir, sleep and godot_busy.sh while it waits).
    [ -z "$g" ] && g=$(ps -axo pid=,ppid=,comm= | awk -v r="$runner" '$2 == r && $3 ~ /(^|\/)Godot$/ {print $1; exit}')
    if [ -n "$g" ]; then
      [ -z "$start" ] && start=$(date +%s)
      local r; r=$(ps -o rss= -p "$g" 2>/dev/null | tr -d ' ')
      if [ -n "$r" ]; then
        [ "$r" -gt "$rss_max" ] && rss_max=$r
        if [ "$r" -gt "$RSS_LIMIT_KB" ]; then dog="rss_kill"; kill -9 "$g"; fi
      fi
      if [ $(( $(date +%s) - start )) -gt "$limit" ]; then dog="timeout_kill"; kill -9 "$g"; fi
      local p others=""
      for p in $(ps -axo pid=,comm= | awk '$2 ~ /(^|\/)Godot$|(^|\/)godot4?$/ {print $1}'); do
        [ "$p" = "$g" ] && continue
        ps -o command= -p "$p" 2>/dev/null | grep -q -E -- "--editor( |$)" && continue
        others="$others $p"
      done
      [ -n "$others" ] && contaminated=1
    fi
    sleep 1
  done
  local wall=0; [ -n "$start" ] && wall=$(( $(date +%s) - start ))
  echo "wall_s=$wall rss_max_kb=$rss_max contaminated=$contaminated watchdog=$dog" > "$meta"
}

for CASE in "${CASES[@]}"; do
  ARGS=$(case_args "$CASE") || { echo "unknown case $CASE"; exit 2; }
  for MODE in "${MODES[@]}"; do
    BASE="$OUT/${CASE}_${MODE}"
    rm -f "$BASE.json" "$BASE.events" "$BASE.log" "$BASE.meta"
    IO="--out=$BASE.json --events=$BASE.events"
    case "$MODE" in
      fixed|fixed2) GARGS=(--headless --fixed-fps 60); LIMIT=600 ;;
      stress) GARGS=(--headless --max-fps 6); LIMIT=900 ;;
      window) GARGS=(--max-fps 60 --resolution 1280x720); IO="$IO --autostart --quit"; LIMIT=900 ;;
      *) echo "unknown mode $MODE"; exit 2 ;;
    esac
    # shellcheck disable=SC2086
    bash "$ROOT/agent/harness/godot_run.sh" "$BIN" "${GARGS[@]}" --path "$ROOT" res://debug/ai_match.tscn -- $ARGS $IO > "$BASE.log" 2>&1 &
    P=$!; watch "$P" "$BASE.meta" "$LIMIT"; wait "$P"; code=$?
    echo "$CASE $MODE exit $code $(cat "$BASE.meta")"
    grep -h "SCRIPT ERROR" "$BASE.log" | head -3 | cut -c1-200
  done
done
report "${CASES[@]}"
