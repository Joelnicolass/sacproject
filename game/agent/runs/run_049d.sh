#!/usr/bin/env bash
# RFC-049 049d (F293): smoke of a 2v2 of AI on a real map with four starts. Four AI Normal (debug/rules/ai_2v2_flat4.tres: slots 1 and 2
# against 3 and 4, friendly fire on) play 1 minute on winter_wonder (--map --mode=2v2), headless. Checks: Godot exited 0, the bench printed
# its AI_REPORT, the navmesh of the map was the one in play, the four AI wizards were on the field, no ally was hit, and no ERROR /
# SCRIPT ERROR in the log. Exit 0 / 1, prints SMOKE PASS / SMOKE FAIL.
#   bash agent/runs/run_049d.sh            (needs `--import` once)
#   SMOKE_MAP=test_flat4 SMOKE_NAV="navmesh 110 pol" bash agent/runs/run_049d.sh
# Has its own watchdog (LIMIT_S, 600 s by default) that kills ITS Godot by pid. Goes through the Godot queue (godot_run.sh).
. "$(dirname "$0")/../harness/env.sh"
GODOT="$GODOT_BIN"
LIMIT_S="${PROBE_LIMIT_S:-600}"
MAP="${SMOKE_MAP:-winter_wonder}"
NAV="${SMOKE_NAV:-navmesh 44332 pol}"
MINUTES="${SMOKE_MINUTES:-1}"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/smoke_049d.XXXXXX")"
LOG="$OUT/smoke.log"

bash "$ROOT/agent/harness/godot_run.sh" "$GODOT" --headless --path "$ROOT" --fixed-fps 60 res://debug/ai/ai_match.tscn -- \
  --rules=res://debug/rules/ai_2v2_flat4.tres --seed=7 --minutes="$MINUTES" --map="$MAP" --mode=2v2 --out="$OUT/report.json" >"$LOG" 2>&1 &
PID=$!
( sleep "$LIMIT_S"; kill "$PID" 2>/dev/null ) &
WATCH=$!
wait "$PID"
RC=$?
kill "$WATCH" 2>/dev/null; wait "$WATCH" 2>/dev/null

fail=0
check() { # description, condition (exit code)
  if [ "$2" -eq 0 ]; then echo "ok    $1"; else echo "FAIL  $1"; fail=1; fi
}
[ "$RC" -eq 0 ]; check "Godot exited 0 (exit $RC)" $?
grep -q "^AI_REPORT " "$LOG"; check "the bench printed its AI_REPORT" $?
grep -q "nav: $NAV" "$LOG"; check "the navmesh of $MAP was the one in play ($NAV)" $?
[ "$(grep '^AI_REPORT ' "$LOG" | grep -o '"has_wizard":true' | wc -l | tr -d ' ')" = 4 ]; check "the four AI wizards were on the field" $?
! grep '^AI_REPORT ' "$LOG" | grep -qE '"ally_hits":[1-9]'; check "no AI hit an ally (ally_hits 0 in the four sides)" $?
# The "resources still in use at exit" line is the bench's own leak at quit (every ai_match log has it); not an error of the map.
grep -vE "still in use at exit" "$LOG" | grep -qE "^(SCRIPT ERROR|ERROR:)|Parse Error"; [ $? -ne 0 ]; check "no ERROR / SCRIPT ERROR in the log" $?
if [ "$fail" -eq 0 ]; then echo "SMOKE PASS ($LOG)"; exit 0; fi
echo "SMOKE FAIL ($LOG)"; tail -30 "$LOG"; exit 1
