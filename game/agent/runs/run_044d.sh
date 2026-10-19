#!/usr/bin/env bash
# RFC-044 044d: smoke of the second map. An AI-vs-AI match of 0.5 min on test_flat (--map=test_flat), headless, and the
# checks that it ran on that map and printed no error. Exit 0 / 1, prints SMOKE PASS / SMOKE FAIL.
#   bash agent/runs/run_044d.sh            (needs `--import` once)
# Has its own watchdog (LIMIT_S, 600 s by default) that kills ITS Godot by pid. Goes through the Godot queue (godot_run.sh).
. "$(dirname "$0")/../harness/env.sh"
GODOT="$GODOT_BIN"
LIMIT_S="${PROBE_LIMIT_S:-600}"
MAP="${SMOKE_MAP:-test_flat}"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/map_smoke_044d.XXXXXX")"
LOG="$OUT/smoke.log"

bash "$ROOT/agent/harness/godot_run.sh" "$GODOT" --headless --path "$ROOT" --fixed-fps 60 res://debug/ai/ai_match.tscn -- \
  --rules=res://debug/rules/map_test_flat.tres --seed=1 --minutes=0.5 --map="$MAP" --out="$OUT/report.json" >"$LOG" 2>&1 &
PID=$!
( sleep "$LIMIT_S"; kill "$PID" 2>/dev/null ) &
WATCH=$!
wait "$PID"
RC=$?
kill "$WATCH" 2>/dev/null

fail=0
check() { # description, condition (exit code)
  if [ "$2" -eq 0 ]; then echo "ok    $1"; else echo "FAIL  $1"; fail=1; fi
}
[ "$RC" -eq 0 ]; check "Godot exited 0 (exit $RC)" $?
grep -q "^AI_REPORT " "$LOG"; check "the bench printed its AI_REPORT" $?
grep -q "nav: navmesh 28 pol" "$LOG"; check "the navmesh of $MAP was the one in play" $?
# The "resources still in use at exit" line is the bench's own leak at quit (every ai_match log has it); not an error of the map.
grep -vE "still in use at exit" "$LOG" | grep -qE "^(SCRIPT ERROR|ERROR:)|Parse Error"; [ $? -ne 0 ]; check "no ERROR / SCRIPT ERROR in the log" $?
if [ "$fail" -eq 0 ]; then echo "SMOKE PASS ($LOG)"; exit 0; fi
echo "SMOKE FAIL ($LOG)"; tail -30 "$LOG"; exit 1
