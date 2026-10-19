#!/usr/bin/env bash
# usage: run_pt78.sh FLOW  -- one windowed flow, 60 fps cap, RSS watchdog (kills at 2.5 GB).
set -u
ROOT=/Users/joelsartori/Development/sacproject/game
export GODOT="$ROOT/agent/harness/godot60.sh"
OUT="$ROOT/agent/out/pt78"; mkdir -p "$OUT"
cd "$ROOT"
"$ROOT/addons/agent_kit/cli.sh" "$ROOT" flow --flow="$1.json" --out=res://agent/out/pt78 --fail-on-error > "$OUT/$1.log" 2>&1 &
P=$!
( while kill -0 $P 2>/dev/null; do
    for g in $(pgrep -f "Godot.*--agent=flow"); do
      r=$(ps -o rss= -p $g | tr -d ' '); [ -n "$r" ] && [ "$r" -gt 2500000 ] && { echo "RSS $r kill" >> "$OUT/$1.log"; kill -9 $g; }
    done; sleep 2; done ) &
wait $P; echo "exit $?"
