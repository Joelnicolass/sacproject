#!/usr/bin/env bash
# F166: one windowed run of agent/flows/f166_locust_ray.json (shots around the Locust's first ray).
# Call it through the Godot lock:  bash agent/harness/godot_run.sh bash agent/run_f166.sh [OUTNAME]
# 1280x720, 60 fps cap, RSS watchdog 2.5 GB. Out: agent/out/<OUTNAME> (default f166); log in <OUTNAME>/f166_locust_ray.log.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAME="${1:-f166}"
OUT="$ROOT/agent/out/$NAME"; mkdir -p "$OUT"
cd "$ROOT"
/Applications/Godot.app/Contents/MacOS/Godot --path "$ROOT" --resolution 1280x720 --max-fps 60 -- --agent=flow --flow="f166_locust_ray.json" --out="res://agent/out/$NAME" > "$OUT/f166_locust_ray.log" 2>&1 &
P=$!
( while kill -0 $P 2>/dev/null; do
    r=$(ps -o rss= -p $P | tr -d ' '); [ -n "$r" ] && [ "$r" -gt 2500000 ] && { echo "RSS $r kill" >> "$OUT/f166_locust_ray.log"; kill -9 $P; }
    sleep 2; done ) &
wait $P; code=$?
echo "exit $code"
grep -E "AGENT_(FAIL|ERROR)|SCRIPT ERROR" "$OUT/f166_locust_ray.log" | head -10
exit $code
