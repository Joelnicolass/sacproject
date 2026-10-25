#!/usr/bin/env bash
# 055c1 / c1-c1, step 2 of 2: writes the ~900 clip .res files, one headless Godot per round through the FIFO queue.
# extract_clips_055c1.gd quits by itself before the 120 s watchdog (exit 3 = "run me again"); this loop repeats it until it is done.
# Needs: tools/migrate/extract_clips_055c1.py already run (plan + libraries + scenes), the .glb real (git lfs pull) and imported.
# Usage (from game/): bash tools/migrate/run_extract_clips_055c1.sh [GODOT_BIN] [-- --force | --only=eorc,jnwr]
# Ends with "EXTRACT RUN DONE" (exit 0) or "EXTRACT RUN FAIL" (exit 1).
set -u
. "$(dirname "$0")/../../agent/harness/env.sh"
if [ -n "${1:-}" ] && [ "${1#--}" = "$1" ]; then GODOT_BIN="$1"; shift; fi
[ "${1:-}" = "--" ] && shift
RUN="$ROOT/agent/harness/godot_run.sh"
LOG="$(mktemp "${TMPDIR:-/tmp}/extract_clips.XXXXXX")"
for round in 1 2 3 4 5 6 7 8 9 10 11 12; do
  bash "$RUN" "$GODOT_BIN" --headless --path "$ROOT" --script res://tools/migrate/extract_clips_055c1.gd -- "$@" > "$LOG" 2>&1
  code=$?
  grep -E "^EXTRACT|SCRIPT ERROR|ERROR:" "$LOG" | tail -n 12
  if [ "$code" = 0 ] && grep -q "^EXTRACT DONE" "$LOG"; then echo "EXTRACT RUN DONE (round $round)"; exit 0; fi
  if [ "$code" != 3 ]; then echo "EXTRACT RUN FAIL (exit $code, log $LOG)"; exit 1; fi
done
echo "EXTRACT RUN FAIL (still partial after 12 rounds, log $LOG)"
exit 1
