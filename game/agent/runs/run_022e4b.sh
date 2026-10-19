#!/usr/bin/env bash
# usage: run_022e4b.sh FLOW OUTNAME [extra user args] -- AgentKit flow, one Godot with window at 60 fps, --fail-on-error.
# Waits until agent/harness/godot_busy.sh sees no other test Godot; killed above 2.5 GB or after RUN_LOOPS*2 s.
ROOT=/Users/joelsartori/Development/sacproject/game
cd "$ROOT"
until agent/harness/godot_busy.sh >/dev/null; do sleep 5; done
OUT=agent/out/rfc022e4b/$2
mkdir -p "$OUT"
agent/harness/godot60.sh --path . --resolution 1280x720 -- --agent=flow --flow="$1" --out="res://$OUT" --fail-on-error "${@:3}" > "$OUT.log" 2>&1 &
PID=$!
PEAK=0
for i in $(seq 1 ${RUN_LOOPS:-40}); do
  sleep 2
  kill -0 $PID 2>/dev/null || break
  R=$(ps -o rss= -p $PID 2>/dev/null | tr -d ' ')
  [ -n "$R" ] && [ "$R" -gt "$PEAK" ] && PEAK=$R
  if [ -n "$R" ] && [ "$R" -gt 2500000 ]; then kill $PID; echo KILLED_RSS; fi
done
kill -0 $PID 2>/dev/null && { kill $PID; echo KILLED_TIMEOUT; }
echo "$2 peak_rss_kb=$PEAK"
grep -E "AGENT_(OK|FAIL|STEP_ERROR|ERRORS)|GRASSBENCH (done|missing)|SCRIPT ERROR|ERROR:|Parse Error" "$OUT.log" | grep -v "leaked\|still in use" | head -10
