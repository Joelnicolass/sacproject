#!/usr/bin/env bash
# usage: pt108_run.sh FLOW OUTNAME [extra user args] -- playtest F108: one Godot with window, 60 fps, --fail-on-error.
# Before launching, godot_busy.sh must report clear three times in a row. Killed above 2.5 GB or after RUN_LOOPS*2 s.
ROOT=/Users/joelsartori/Development/sacproject/game
cd "$ROOT"
clear=0
while [ $clear -lt 3 ]; do
  if agent/harness/godot_busy.sh >/dev/null; then clear=$((clear+1)); else clear=0; sleep 5; fi
done
OUT=agent/out/pt108/$2
mkdir -p "$OUT"
agent/harness/godot60.sh --path . --resolution 1280x720 -- --agent=flow --flow="$1" --out="res://$OUT" --fail-on-error "${@:3}" > "$OUT.log" 2>&1 &
PID=$!
PEAK=0
for i in $(seq 1 ${RUN_LOOPS:-45}); do
  sleep 2
  kill -0 $PID 2>/dev/null || break
  R=$(ps -o rss= -p $PID 2>/dev/null | tr -d ' ')
  [ -n "$R" ] && [ "$R" -gt "$PEAK" ] && PEAK=$R
  if [ -n "$R" ] && [ "$R" -gt 2500000 ]; then kill $PID; echo KILLED_RSS; fi
done
kill -0 $PID 2>/dev/null && { kill $PID; echo KILLED_TIMEOUT; }
echo "$2 peak_rss_kb=$PEAK"
grep -E "AGENT_(OK|FAIL|STEP_ERROR|ERRORS)|SCRIPT ERROR|ERROR:|WARNING:|Parse Error|unmapped" "$OUT.log" | grep -v "leaked\|still in use" | head -12
