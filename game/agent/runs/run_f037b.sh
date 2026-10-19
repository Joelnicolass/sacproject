#!/usr/bin/env bash
# F213 (RFC-037 037b): one windowed run of agent/flows/f037_minimap.json (the minimap at the bottom right, the turn, the terrain bake).
# Call it through the Godot lock:  bash agent/harness/godot_run.sh bash agent/runs/run_f037b.sh [OUTNAME] [WxH]
# Default 1280x720, 60 fps cap, RSS watchdog 2.5 GB. Out: agent/out/<OUTNAME>; log in <OUTNAME>/f037_minimap.log.
set -u
. "$(dirname "$0")/../harness/env.sh"
NAME="${1:-f037b}"
RES="${2:-1280x720}"
OUT="$ROOT/agent/out/$NAME"; mkdir -p "$OUT"
cd "$ROOT"
"$GODOT_BIN" --path "$ROOT" --resolution "$RES" --max-fps 60 -- --agent=flow --flow="f037_minimap.json" --out="res://agent/out/$NAME" --fail-on-error > "$OUT/f037_minimap.log" 2>&1 &
P=$!
( while kill -0 $P 2>/dev/null; do
    r=$(ps -o rss= -p $P | tr -d ' '); [ -n "$r" ] && [ "$r" -gt 2500000 ] && { echo "RSS $r kill" >> "$OUT/f037_minimap.log"; kill -9 $P; }
    sleep 2; done ) &
wait $P; code=$?
echo "exit $code"
grep -c "AGENT_ASSERT ok" "$OUT/f037_minimap.log" | sed 's/^/asserts ok: /'
grep -E "AGENT_(FAIL|ERROR)|SCRIPT ERROR|assert .*(want|missing)|AGENT_PRINT" "$OUT/f037_minimap.log" | head -20
exit $code
