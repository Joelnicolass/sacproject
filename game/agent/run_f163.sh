#!/usr/bin/env bash
# F163: one windowed run of agent/flows/f163_phoenix_shield.json (shots of the Phoenix shield).
# Call it through the Godot lock:  bash agent/harness/godot_run.sh bash agent/run_f163.sh [OUTNAME]
# 1280x720, 60 fps cap, RSS watchdog 2.5 GB. Out: agent/out/<OUTNAME> (default f163); log in <OUTNAME>/f163_phoenix_shield.log.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAME="${1:-f163}"
OUT="$ROOT/agent/out/$NAME"; mkdir -p "$OUT"
cd "$ROOT"
/Applications/Godot.app/Contents/MacOS/Godot --path "$ROOT" --resolution 1280x720 --max-fps 60 -- --agent=flow --flow="f163_phoenix_shield.json" --out="res://agent/out/$NAME" > "$OUT/f163_phoenix_shield.log" 2>&1 &
P=$!
( while kill -0 $P 2>/dev/null; do
    r=$(ps -o rss= -p $P | tr -d ' '); [ -n "$r" ] && [ "$r" -gt 2500000 ] && { echo "RSS $r kill" >> "$OUT/f163_phoenix_shield.log"; kill -9 $P; }
    sleep 2; done ) &
wait $P; code=$?
echo "exit $code"
grep -E "AGENT_(FAIL|ERROR)|SCRIPT ERROR" "$OUT/f163_phoenix_shield.log" | head -10
exit $code
