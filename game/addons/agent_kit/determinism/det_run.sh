#!/usr/bin/env bash
# Determinism bench of AgentKit: the same run on different clocks must give the same digest.
#   det_run.sh CASES_FILE CASE|all [MODE...] [--no-window]
#   det_run.sh CASES_FILE quick [--no-window]     short pass: quick cases against the baseline (see below)
#   det_run.sh CASES_FILE table [CASE...]         verdict + markdown table from the out folder
#   det_run.sh CASES_FILE bless                   write the baseline from the current `fixed` results of the quick cases
# MODE: fixed stress window fixed2 (default: fixed stress window; with --no-window: fixed fixed2 stress).
#   fixed   headless --fixed-fps 60 (as fast as it can, 1/60 per frame: the reference)
#   fixed2  fixed again (a run must repeat itself)
#   stress  headless in real time, --max-fps $DET_STRESS_FPS (several physics steps per frame: render clock != tick clock)
#   window  --max-fps 60 --resolution $DET_WINDOW_RES $DET_WINDOW_ARGS (a window is comparable only if the scene
#           autostarts and quits by itself; never run two windows at once)
# CASES_FILE: one case per line `name|args|quick|set` (# comments). quick: all (every mode) | fixed (reference only)
#   | empty (not in quick). set: all (part of the `all` run) | empty. `args` go to the scene after `--`.
# Config: a shell file `det.cfg` next to CASES_FILE (or $DET_CFG), sourced. Paths are relative to the project.
#   DET_SCENE (required, res://...)  DET_PROJECT (default: the folder with project.godot above CASES_FILE)
#   DET_OUT (default agent/out/det)  DET_BASELINE (default agent/det_baseline.txt: lines `case digest`)
#   DET_RSS_LIMIT_KB (2500000)  DET_LIMIT_FIXED (600)  DET_LIMIT_STRESS (900)  DET_LIMIT_WINDOW (900)  (seconds)
#   DET_STRESS_FPS (6)  DET_WINDOW_RES (1280x720)  DET_WINDOW_ARGS (--autostart --quit)
#   GODOT_BIN, GODOT_RUN_NS (queue namespace, see harness/godot_run.sh). DET_OUT and DET_BASELINE can also come from the
#   environment (they win over the cfg).
# Every Godot goes through harness/godot_run.sh, one queue. The watchdog kills at RSS > limit, after the time limit of the
# mode, and AT ONCE when the log has Parse Error / Compile Error / Failed to load script (watchdog=script_error_kill).
# CONTAMINATED in the meta: another Godot (not an editor) showed up during the run.
# Out: $DET_OUT/<case>_<mode>.json (report), .events (record lines), .log, .meta (wall_s rss_max_kb contaminated watchdog).
# quick deletes the old results of its cases first, runs them, compares each `fixed` digest with the baseline
# (`baseline CASE OK|FAIL`) and needs at least two fresh modes in the table. Prints QUICK PASS or QUICK FAIL.
# A verdict only looks at the modes this invocation ran (DET_MODES); `table` by hand shows all that is on disk.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
CASES_FILE="${1:?usage: det_run.sh CASES_FILE CASE|all|quick|table|bless [MODE...] [--no-window]}"
shift
CASES_FILE="$(cd "$(dirname "$CASES_FILE")" && pwd)/$(basename "$CASES_FILE")"
[ -f "$CASES_FILE" ] || { echo "no cases file $CASES_FILE"; exit 2; }
CMD="${1:?usage: det_run.sh CASES_FILE CASE|all|quick|table|bless [MODE...] [--no-window]}"
shift

_E_OUT="${DET_OUT:-}"; _E_BASE="${DET_BASELINE:-}"
CFG="${DET_CFG:-$(dirname "$CASES_FILE")/det.cfg}"
export DET_CFG="$CFG"
# shellcheck disable=SC1090
[ -f "$CFG" ] && . "$CFG"
[ -n "$_E_OUT" ] && DET_OUT="$_E_OUT"
[ -n "$_E_BASE" ] && DET_BASELINE="$_E_BASE"
if [ -z "${DET_PROJECT:-}" ]; then
  d="$(dirname "$CASES_FILE")"
  while [ "$d" != "/" ] && [ ! -f "$d/project.godot" ]; do d="$(dirname "$d")"; done
  DET_PROJECT="$d"
fi
[ -f "$DET_PROJECT/project.godot" ] || { echo "no project.godot (set DET_PROJECT)"; exit 2; }
DET_SCENE="${DET_SCENE:?DET_SCENE not set (res://... in det.cfg)}"
abs() { case "$1" in /*) echo "$1" ;; *) echo "$DET_PROJECT/$1" ;; esac; }
OUT="$(abs "${DET_OUT:-agent/out/det}")"
BASELINE="$(abs "${DET_BASELINE:-agent/det_baseline.txt}")"
RSS_LIMIT_KB="${DET_RSS_LIMIT_KB:-2500000}"
STRESS_FPS="${DET_STRESS_FPS:-6}"
WINDOW_RES="${DET_WINDOW_RES:-1280x720}"
WINDOW_ARGS="${DET_WINDOW_ARGS---autostart --quit}"
if [ -z "${GODOT_BIN:-}" ]; then
  GODOT_BIN="$(command -v godot godot4 Godot 2>/dev/null | head -n1)"
  [ -z "$GODOT_BIN" ] && [ -x /Applications/Godot.app/Contents/MacOS/Godot ] && GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
fi
export GODOT_BIN DET_CFG DET_OUT="$OUT" DET_BASELINE="$BASELINE"
BIN="$GODOT_BIN"

cases_where() { # awk condition on $3 (quick) / $4 (set) -> case names
  awk -F'|' "!/^[[:space:]]*(#|\$)/ && ($1) {print \$1}" "$CASES_FILE"
}
case_args() { # case -> args; fails if the case is unknown
  awk -F'|' -v c="$1" '!/^[[:space:]]*(#|$)/ && $1 == c {print $2; found = 1} END {exit found ? 0 : 1}' "$CASES_FILE"
}
report() { # [case...]
  python3 -I "$HERE/det_report.py" "$OUT" "$@"
}

NOWIN=0; MODES=()
for a in "$@"; do
  if [ "$a" = "--no-window" ]; then NOWIN=1; else MODES+=("$a"); fi
done

if [ "$CMD" = table ]; then
  report ${MODES[@]+"${MODES[@]}"}; exit 0
fi

if [ "$CMD" = bless ]; then
  mkdir -p "$(dirname "$BASELINE")"
  : > "$BASELINE"
  for c in $(cases_where '$3 == "all" || $3 == "fixed"'); do
    d=$(python3 -I -c "import json,sys;print(json.load(open(sys.argv[1])).get('digest',''))" "$OUT/${c}_fixed.json" 2>/dev/null)
    [ -z "$d" ] && { echo "bless: no fixed result for $c (run it first)"; exit 1; }
    echo "$c $d" >> "$BASELINE"
  done
  echo "baseline written: $BASELINE"; exit 0
fi

# quick: the quick cases against the baseline. Old results are deleted first: a stale file read as OK once hid that no case had run.
if [ "$CMD" = quick ]; then
  QALL=$(cases_where '$3 == "all"'); QFIX=$(cases_where '$3 == "fixed"')
  for c in $QALL $QFIX; do
    rm -f "$OUT/${c}_"*.json "$OUT/${c}_"*.meta "$OUT/${c}_"*.events "$OUT/${c}_"*.log
  done
  if [ $NOWIN = 1 ]; then QMODES="fixed fixed2 stress"; else QMODES="fixed stress window"; fi
  ok=1
  for c in $QALL; do bash "$0" "$CASES_FILE" "$c" $QMODES >/dev/null || true; done
  for c in $QFIX; do bash "$0" "$CASES_FILE" "$c" fixed >/dev/null || true; done
  if [ -f "$BASELINE" ]; then
    while read -r c want; do
      [ -z "$c" ] && continue
      got=$(python3 -I -c "import json,sys;print(json.load(open(sys.argv[1])).get('digest',''))" "$OUT/${c}_fixed.json" 2>/dev/null)
      if [ -n "$got" ] && [ "$got" = "$want" ]; then echo "baseline $c OK ${got:0:8}"; else echo "baseline $c FAIL got=${got:0:8} want=${want:0:8}"; ok=0; fi
    done < "$BASELINE"
  else
    echo "baseline FAIL no file $BASELINE"; ok=0
  fi
  if [ -n "$QALL" ]; then
    # shellcheck disable=SC2086
    DET_MODES="$QMODES" report $QALL | grep -q "DETERMINISM PASS" || ok=0
  else
    ok=0
  fi
  [ $ok = 1 ] && { echo "QUICK PASS"; exit 0; } || { echo "QUICK FAIL"; exit 1; }
fi

if [ "$CMD" = all ]; then CASES=($(cases_where '$4 == "all"')); else CASES=("$CMD"); fi
[ ${#CASES[@]} -eq 0 ] && { echo "no cases"; exit 2; }
if [ ${#MODES[@]} -eq 0 ]; then
  if [ $NOWIN = 1 ]; then MODES=(fixed fixed2 stress); else MODES=(fixed stress window); fi
fi
# `fixed` is the reference: always run it in this invocation, and a verdict needs at least two fresh modes.
case " ${MODES[*]} " in *" fixed "*) ;; *) MODES=(fixed "${MODES[@]}") ;; esac
if [ $NOWIN = 1 ]; then
  KEEP=(); for m in "${MODES[@]}"; do [ "$m" != window ] && KEEP+=("$m"); done; MODES=("${KEEP[@]}")
fi
mkdir -p "$OUT"
cd "$DET_PROJECT" || exit 2

# The Godot child of the godot_run.sh pid: RSS cap, time cap (from the moment Godot starts, not the lock wait),
# a script that does not compile (kill at once) and any other Godot (not an editor) marks the run CONTAMINATED.
watch() { # runner_pid meta limit_s log
  local runner=$1 meta=$2 limit=$3 log=$4 start="" g="" rss_max=0 contaminated=0 dog=none
  while kill -0 "$runner" 2>/dev/null; do
    # Only the Godot child counts (godot_run.sh also spawns mkdir, sleep and godot_busy.sh while it waits).
    [ -z "$g" ] && g=$(ps -axo pid=,ppid=,comm= | awk -v r="$runner" '$2 == r && $3 ~ /(^|\/)[Gg]odot4?$/ {print $1; exit}')
    if [ -n "$g" ]; then
      [ -z "$start" ] && start=$(date +%s)
      local r; r=$(ps -o rss= -p "$g" 2>/dev/null | tr -d ' ')
      if [ -n "$r" ]; then
        [ "$r" -gt "$rss_max" ] && rss_max=$r
        if [ "$r" -gt "$RSS_LIMIT_KB" ]; then dog="rss_kill"; kill -9 "$g"; fi
      fi
      if [ $(( $(date +%s) - start )) -gt "$limit" ]; then dog="timeout_kill"; kill -9 "$g"; fi
      if [ -n "$log" ] && grep -q -E "Parse Error|Failed to load script|Compile Error" "$log" 2>/dev/null; then
        dog="script_error_kill"; kill -9 "$g"
      fi
      local p others=""
      for p in $(ps -axo pid=,comm= | awk '$2 ~ /(^|\/)[Gg]odot4?$/ {print $1}'); do
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
      fixed|fixed2) GARGS=(--headless --fixed-fps 60); LIMIT="${DET_LIMIT_FIXED:-600}" ;;
      stress) GARGS=(--headless --max-fps "$STRESS_FPS"); LIMIT="${DET_LIMIT_STRESS:-900}" ;;
      window) GARGS=(--max-fps 60 --resolution "$WINDOW_RES"); IO="$IO $WINDOW_ARGS"; LIMIT="${DET_LIMIT_WINDOW:-900}" ;;
      *) echo "unknown mode $MODE"; exit 2 ;;
    esac
    # shellcheck disable=SC2086
    bash "$HERE/harness/godot_run.sh" "$BIN" "${GARGS[@]}" --path "$DET_PROJECT" "$DET_SCENE" -- $ARGS $IO > "$BASE.log" 2>&1 &
    P=$!; watch "$P" "$BASE.meta" "$LIMIT" "$BASE.log"; wait "$P"; code=$?
    echo "$CASE $MODE exit $code $(cat "$BASE.meta")"
    grep -h "SCRIPT ERROR" "$BASE.log" | head -3 | cut -c1-200
  done
done
DET_MODES="${MODES[*]}" report "${CASES[@]}"
