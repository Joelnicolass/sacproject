#!/usr/bin/env bash
# F165: one windowed run of agent/flows/f165_divine_sight.json (the Ranger uses Divine Sight from the ability button).
# Call it through the Godot lock:  bash agent/harness/godot_run.sh bash agent/runs/run_f165.sh [OUTNAME]
# 1280x720, 60 fps cap, RSS watchdog 2.5 GB. Out: agent/out/<OUTNAME> (default f165); log in <OUTNAME>/f165_divine_sight.log.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
NAME="${1:-f165}"
OUT="$ROOT/agent/out/$NAME"; mkdir -p "$OUT"
cd "$ROOT"
/Applications/Godot.app/Contents/MacOS/Godot --path "$ROOT" --resolution 1280x720 --max-fps 60 -- --agent=flow --flow="f165_divine_sight.json" --out="res://agent/out/$NAME" --fail-on-error > "$OUT/f165_divine_sight.log" 2>&1 &
P=$!
( while kill -0 $P 2>/dev/null; do
    r=$(ps -o rss= -p $P | tr -d ' '); [ -n "$r" ] && [ "$r" -gt 2500000 ] && { echo "RSS $r kill" >> "$OUT/f165_divine_sight.log"; kill -9 $P; }
    sleep 2; done ) &
wait $P; code=$?
echo "exit $code"
grep -c "AGENT_ASSERT ok" "$OUT/f165_divine_sight.log" | sed 's/^/asserts ok: /'
grep -E "AGENT_(FAIL|ERROR)|SCRIPT ERROR|assert .*(want|missing)" "$OUT/f165_divine_sight.log" | head -10
exit $code
