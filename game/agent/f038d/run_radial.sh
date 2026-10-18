#!/usr/bin/env bash
# F219 (RFC-038 038d): one windowed run of agent/flows/f038d_radial.json (right tap / hold, Tab hold, Alt+3 on debug/orders_radial.tscn).
# Call it through the Godot lock:  bash agent/harness/godot_run.sh bash agent/f038d/run_radial.sh [WxH]
# Default 1280x720, 60 fps cap, RSS watchdog 2.5 GB, ends by itself (flow timeout 420 s, kill at 540 s). Out: agent/out/f038d.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RES="${1:-1280x720}"
OUT="$ROOT/agent/out/f038d"; mkdir -p "$OUT"
cd "$ROOT"
/Applications/Godot.app/Contents/MacOS/Godot --path "$ROOT" --resolution "$RES" --max-fps 60 -- --agent=flow --flow="f038d_radial.json" --out="res://agent/out/f038d" --fail-on-error > "$OUT/f038d.log" 2>&1 &
P=$!
( s=0; while kill -0 $P 2>/dev/null; do
    r=$(ps -o rss= -p $P | tr -d ' '); [ -n "$r" ] && [ "$r" -gt 2500000 ] && { echo "RSS $r kill" >> "$OUT/f038d.log"; kill -9 $P; }
    s=$((s+2)); [ $s -gt 540 ] && { echo "TIMEOUT kill" >> "$OUT/f038d.log"; kill -9 $P; }
    sleep 2; done ) &
wait $P; code=$?
echo "exit $code"
grep -E "RADIAL_PROBE|AGENT_(FAIL|ERROR|OK)|SCRIPT ERROR|assert .*(want|missing)" "$OUT/f038d.log" | head -60
exit $code
