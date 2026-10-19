#!/usr/bin/env bash
# usage: run_pt84.sh FLOW TAG RES SCALE  -- one windowed flow at RES (e.g. 1280x720) and --hud-scale=SCALE
# ("" = no argument, the default). 60 fps cap, RSS watchdog (kills at 2.5 GB). Out: agent/out/pt84/TAG.
set -u
ROOT=/Users/joelsartori/Development/sacproject/game
export GODOT="$ROOT/agent/harness/godot60_res.sh"
export PT_RES="$3"
OUT="$ROOT/agent/out/pt84/$2"; mkdir -p "$OUT"
EXTRA=(); [ -n "$4" ] && EXTRA=(--hud-scale="$4")
cd "$ROOT"
"$ROOT/addons/agent_kit/cli.sh" "$ROOT" flow --flow="$1.json" --out=res://agent/out/pt84/$2 --fail-on-error ${EXTRA[@]+"${EXTRA[@]}"} > "$OUT/$1.log" 2>&1 &
P=$!
( while kill -0 $P 2>/dev/null; do
    for g in $(pgrep -f "Godot.*--agent=flow"); do
      r=$(ps -o rss= -p $g | tr -d ' '); [ -n "$r" ] && [ "$r" -gt 2500000 ] && { echo "RSS $r kill" >> "$OUT/$1.log"; kill -9 $g; }
      echo "$(date +%s) rss=$r" >> "$OUT/rss.txt"
    done; sleep 2; done ) &
wait $P; echo "exit $?"
