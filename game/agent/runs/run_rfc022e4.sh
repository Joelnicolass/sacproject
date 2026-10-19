#!/usr/bin/env bash
. "$(dirname "$0")/../harness/env.sh"
# usage: run_rfc022e4.sh FLOW OUTDIR [extra godot user args]  -- one Godot with window, 60 fps cap, killed above 2.5 GB
G="$GODOT_BIN"
cd "$ROOT"
mkdir -p "agent/out/rfc022e4/$2"
$G --path . --resolution 1152x648 --max-fps 60 -- --agent=flow --flow="$1" --out="res://agent/out/rfc022e4/$2" "${@:3}" > "agent/out/rfc022e4/$2.log" 2>&1 &
PID=$!
PEAK=0
for i in $(seq 1 ${RUN_LOOPS:-90}); do
  sleep 2
  kill -0 $PID 2>/dev/null || break
  R=$(ps -o rss= -p $PID 2>/dev/null | tr -d ' ')
  [ -n "$R" ] && [ "$R" -gt "$PEAK" ] && PEAK=$R
  if [ -n "$R" ] && [ "$R" -gt 2500000 ]; then kill $PID; echo KILLED_RSS; fi
done
kill -0 $PID 2>/dev/null && { kill $PID; echo KILLED_TIMEOUT; }
echo "peak_rss_kb=$PEAK"
grep -E "AGENT_(OK|FAIL|STEP_ERROR|ERRORS)|SCRIPT ERROR|ERROR:|WARNING: .*grass|Parse Error" "agent/out/rfc022e4/$2.log" | grep -v "leaked\|still in use" | head -20
