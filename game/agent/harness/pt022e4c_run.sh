#!/usr/bin/env bash
. "$(dirname "$0")/../harness/env.sh"
# usage: pt022e4c_run.sh FLOW OUTNAME [extra user args]. One Godot with window, 60 fps, killed >2.5 GB.
# Waits while any other non-editor Godot is running.
G="$GODOT_BIN"
cd "$ROOT"
while ps -axo command | grep -E "^[^ ]*/Godot( |$)" | grep -v -e "--editor" | grep -q .; do sleep 3; done
mkdir -p "agent/out/pt022e4c/$2"
$G --path . --resolution 1280x720 --max-fps 60 -- --agent=flow --flow="$1" --out="res://agent/out/pt022e4c/$2" --fail-on-error "${@:3}" > "agent/out/pt022e4c/$2.log" 2>&1 &
PID=$!
PEAK=0
for i in $(seq 1 ${RUN_LOOPS:-60}); do
  sleep 2
  kill -0 $PID 2>/dev/null || break
  R=$(ps -o rss= -p $PID 2>/dev/null | tr -d ' ')
  [ -n "$R" ] && [ "$R" -gt "$PEAK" ] && PEAK=$R
  if [ -n "$R" ] && [ "$R" -gt 2500000 ]; then kill $PID; echo KILLED_RSS; fi
done
kill -0 $PID 2>/dev/null && { kill $PID; echo KILLED_TIMEOUT; }
echo "peak_rss_kb=$PEAK"
grep -E "AGENT_(OK|FAIL|STEP_ERROR|ERRORS)|SCRIPT ERROR|ERROR:|WARNING:|Parse Error|unmapped" "agent/out/pt022e4c/$2.log" | grep -v "leaked\|still in use" | head -20
