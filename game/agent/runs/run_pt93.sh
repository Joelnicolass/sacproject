#!/usr/bin/env bash
# usage: run_pt93.sh FLOW  -- one windowed flow (60 fps cap, RSS watchdog kills at 2.5 GB). Out: agent/out/pt93.
set -u
. "$(dirname "$0")/../harness/env.sh"
export GODOT="$ROOT/agent/harness/godot60.sh"
OUT="$ROOT/agent/out/pt93"; mkdir -p "$OUT"
cd "$ROOT"
free=0; while [ $free -lt 3 ]; do if "$ROOT/agent/harness/godot_busy.sh" >/dev/null; then free=$((free+1)); else free=0; echo "esperando Godot libre"; sleep 20; fi; done
"$ROOT/addons/agent_kit/cli.sh" "$ROOT" flow --flow="$1.json" --out=res://agent/out/pt93 --fail-on-error > "$OUT/$1.log" 2>&1 &
P=$!
( while kill -0 $P 2>/dev/null; do
    for g in $(pgrep -f "Godot.*--agent=flow"); do
      r=$(ps -o rss= -p $g | tr -d ' '); [ -n "$r" ] && [ "$r" -gt 2500000 ] && { echo "RSS $r kill" >> "$OUT/$1.log"; kill -9 $g; }
      echo "$(date +%s) $1 rss=$r" >> "$OUT/rss.txt"
    done; sleep 2; done ) &
wait $P; echo "exit $?"
