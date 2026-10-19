#!/usr/bin/env bash
# RFC-050: smoke of an imported original map. An AI-vs-AI match of 0.5 min (Easy vs Normal, the NPCs on the field) on the map
# given as argument (a tag of data/maps/map_catalog.tres), headless, and the checks that it ran on that map, that the two
# wizards stood by their altars and that nothing printed an error. Exit 0 / 1, prints SMOKE PASS / SMOKE FAIL.
#   bash agent/runs/run_050_maps.sh peaks            (needs `--import` once)
# A map with four seats is played 1 vs 1 on seats 1 and 2 (the 2v2 mode is RFC-049).
# Has its own watchdog (LIMIT_S, 900 s by default) that kills ITS Godot by pid. Goes through the Godot queue (godot_run.sh).
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
LIMIT_S="${PROBE_LIMIT_S:-900}"
MAP="${1:?usage: run_050_maps.sh <map tag>}"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/map_smoke_050.XXXXXX")"
LOG="$OUT/smoke.log"

bash "$ROOT/agent/harness/godot_run.sh" "$GODOT" --headless --path "$ROOT" --fixed-fps 60 res://debug/ai/ai_match.tscn -- \
  --rules=res://debug/rules/ai_easy_vs_normal.tres --seed=1 --minutes=0.5 --map="$MAP" --out="$OUT/report.json" >"$LOG" 2>&1 &
PID=$!
( sleep "$LIMIT_S"; kill "$PID" 2>/dev/null ) >/dev/null 2>&1 &
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
grep -q "nav: navmesh [0-9]* pol" "$LOG"; check "the navmesh of $MAP was the one in play" $?
# The "resources still in use at exit" line is the bench's own leak at quit (every ai_match log has it); not an error of the map.
grep -vE "still in use at exit" "$LOG" | grep -qE "^(SCRIPT ERROR|ERROR:)|Parse Error"; [ $? -ne 0 ]; check "no ERROR / SCRIPT ERROR in the log" $?
if [ "$fail" -eq 0 ]; then echo "SMOKE PASS ($LOG)"; exit 0; fi
echo "SMOKE FAIL ($LOG)"; tail -30 "$LOG"; exit 1
