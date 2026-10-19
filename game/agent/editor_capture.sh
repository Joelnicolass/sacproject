#!/usr/bin/env bash
# RFC-035 editor probe. Opens the scene in the Godot EDITOR (a window), frames the terrain, writes
# agent/out/035/editor_open.{png,json} (and editor_reload.* with RELOAD=1), prints the EDITOR_CAPTURE lines and quits.
# Call it through the Godot lock:  bash agent/harness/godot_run.sh bash agent/editor_capture.sh [OUTNAME]
#   OUTNAME  folder under agent/out (default 035; use 035_before / 035_after to compare)
#   RELOAD=1 also reloads terrain.gd and captures again (step "reload")   SCENE=res://... to probe another scene
# One process. A temporary override.cfg registers the autoload (project.godot is not touched); removed always (trap).
# 120 s limit and a 4 GB RSS watchdog, both by pid (no pkill). Exit 0 when every step printed, 1 otherwise.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
NAME="${1:-035}"
SCENE="${SCENE:-res://scenes/match/high_noon.tscn}"
OUT="$ROOT/agent/out/$NAME"; mkdir -p "$OUT"
LOG="$OUT/editor_capture.log"
LIMIT_S="${PROBE_LIMIT_S:-120}"
RSS_LIMIT_KB="${RSS_LIMIT_KB:-4194304}"
OVERRIDE="$ROOT/override.cfg"
if [ -e "$OVERRIDE" ]; then echo "override.cfg already exists in $ROOT; not touching it" >&2; exit 2; fi
trap 'rm -f "$OVERRIDE"' EXIT
printf '[autoload]\n\nEditorCapture="*res://agent/editor/editor_capture.gd"\n' > "$OVERRIDE"
ARGS=(--scene="$SCENE" --out="res://agent/out/$NAME")
[ "${RELOAD:-0}" = "1" ] && ARGS+=(--reload)
cd "$ROOT"
"$GODOT" --editor --path "$ROOT" -- "${ARGS[@]}" > "$LOG" 2>&1 &
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
grep -E "EDITOR_CAPTURE|SCRIPT ERROR|TIMEOUT|RSS " "$LOG" | head -20
want=1; [ "${RELOAD:-0}" = "1" ] && want=2
got=$(grep -c "^EDITOR_CAPTURE" "$LOG")
echo "exit $code steps $got/$want"
[ "$got" -ge "$want" ]
