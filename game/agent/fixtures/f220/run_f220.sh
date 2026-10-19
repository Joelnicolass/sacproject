#!/usr/bin/env bash
# F220: one windowed run of agent/flows/f220_order_marker.json (order on the Druid, capture, capture 3 s later).
# Call it through the Godot lock:  bash agent/harness/godot_run.sh bash agent/fixtures/f220/run_f220.sh
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/agent/out/f220"; mkdir -p "$OUT"
cd "$ROOT"
/Applications/Godot.app/Contents/MacOS/Godot --path "$ROOT" --resolution 1280x720 --max-fps 60 -- --agent=flow --flow="f220_order_marker.json" --out="res://agent/out/f220" --fail-on-error > "$OUT/f220.log" 2>&1 &
P=$!
( s=0; while kill -0 $P 2>/dev/null; do s=$((s+2)); [ $s -gt 120 ] && { echo "TIMEOUT kill" >> "$OUT/f220.log"; kill -9 $P; }; sleep 2; done ) &
wait $P; code=$?
echo "exit $code"
grep -E "AGENT_(FAIL|ERROR|OK)|SCRIPT ERROR|assert" "$OUT/f220.log" | head -30
exit $code
