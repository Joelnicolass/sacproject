#!/usr/bin/env bash
# usage: run_f79.sh FLOW [WxH] [OUTNAME]  -- one windowed flow (RFC-025b), 60 fps cap, RSS watchdog (2.5 GB).
# Refuses to start when another test Godot is running (the user's --editor does not count).
set -u
ROOT=/Users/joelsartori/Development/sacproject/game
RES="${2:-1280x720}"
NAME="${3:-f79_${RES}}"
OUT="$ROOT/agent/out/$NAME"; mkdir -p "$OUT"
if ps -axo command | grep "[G]odot.app/Contents/MacOS/Godot" | grep -v -- "--editor" | grep -q .; then
  echo "otro Godot de prueba corriendo, no arranco"; exit 3
fi
cd "$ROOT"
/Applications/Godot.app/Contents/MacOS/Godot --path "$ROOT" --resolution "$RES" --max-fps 60 -- --agent=flow --flow="$1.json" --out="res://agent/out/$NAME" --fail-on-error > "$OUT/$1.log" 2>&1 &
P=$!
( while kill -0 $P 2>/dev/null; do
    r=$(ps -o rss= -p $P | tr -d ' '); [ -n "$r" ] && [ "$r" -gt 2500000 ] && { echo "RSS $r kill" >> "$OUT/$1.log"; kill -9 $P; }
    sleep 2; done ) &
wait $P; echo "exit $?"
