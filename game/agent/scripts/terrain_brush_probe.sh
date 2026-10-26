#!/usr/bin/env bash
# Plan 063D S5b editor probe. Opens the Godot EDITOR (a window) with agent/editor/terrain_brush_probe.gd as a temporary
# autoload: strokes on debug/terrain/edit_bed.tscn (raise, undo/redo, flatten, void, fill, «Aplanar bases», «Validar mapa»,
# a save that is put back) and a draft stroke on winter_wonder. Prints the TERRAIN_PROBE lines (refresh times included),
# writes agent/out/063d/probe_*.png and the log, and quits. Needs no Blender and no original game.
# Call it through the Godot lock:  bash agent/harness/godot_run.sh bash agent/scripts/terrain_brush_probe.sh
# One process. A temporary override.cfg registers the autoload (project.godot is not touched); removed always (trap).
# 600 s limit and a 4 GB RSS watchdog, both by pid (no pkill). Exit 0 when the probe printed DONE, 1 otherwise.
set -u
. "$(dirname "$0")/../harness/env.sh"   # ROOT = the Godot project folder, GODOT_BIN
OUT="$ROOT/agent/out/063d"; mkdir -p "$OUT"
LOG="$OUT/terrain_brush_probe.log"
LIMIT_S="${PROBE_LIMIT_S:-600}"
RSS_LIMIT_KB="${RSS_LIMIT_KB:-4194304}"
OVERRIDE="$ROOT/override.cfg"
if [ -e "$OVERRIDE" ]; then echo "override.cfg already exists; not touching it" >&2; exit 2; fi
trap 'rm -f "$OVERRIDE"' EXIT
printf '[autoload]\n\nTerrainBrushProbe="*res://agent/editor/terrain_brush_probe.gd"\n' > "$OVERRIDE"
"$GODOT_BIN" --editor --path "$ROOT" > "$LOG" 2>&1 &
P=$!
START=$SECONDS
( while kill -0 $P 2>/dev/null; do
    r=$(ps -o rss= -p $P | tr -d ' ')
    [ -n "$r" ] && [ "$r" -gt "$RSS_LIMIT_KB" ] && { echo "RSS $r kill" >> "$LOG"; kill -9 $P; }
    [ $((SECONDS - START)) -gt "$LIMIT_S" ] && { echo "TIMEOUT ${LIMIT_S}s kill" >> "$LOG"; kill -9 $P; }
    sleep 2; done ) &
W=$!
wait $P; code=$?
kill $W 2>/dev/null
grep -E "TERRAIN_PROBE|Terreno:|Aplanar bases|Validar mapa|SCRIPT ERROR|TIMEOUT|RSS " "$LOG" | head -60
echo "exit $code"
cat "$OUT/probe.txt" 2>/dev/null; grep -qx "DONE" "$OUT/probe.txt"
