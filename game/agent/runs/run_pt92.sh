#!/usr/bin/env bash
# usage: run_pt92.sh FLOW TAG RES  -- one windowed flow at RES, 60 fps cap, RSS watchdog 2.5 GB. Out: agent/out/pt92/TAG
set -u
. "$(dirname "$0")/../harness/env.sh"
export GODOT="$ROOT/agent/harness/godot60_res.sh"
export PT_RES="$3"
OUT="$ROOT/agent/out/pt92/$2"; mkdir -p "$OUT"
free=0
for k in $(seq 1 400); do
  "$ROOT/agent/harness/godot_busy.sh" >/dev/null && "$ROOT/agent/harness/godot_busy.sh" >/dev/null && "$ROOT/agent/harness/godot_busy.sh" >/dev/null && { free=1; break; }
  sleep 3
done
[ $free = 1 ] || { echo "BUSY"; exit 9; }
cd "$ROOT"
"$ROOT/addons/agent_kit/cli.sh" "$ROOT" flow --flow="$1.json" --out=res://agent/out/pt92/$2 --fail-on-error > "$OUT/$1.log" 2>&1 &
P=$!
( while kill -0 $P 2>/dev/null; do
    for g in $(pgrep -f "Godot.*--agent=flow"); do
      r=$(ps -o rss= -p $g | tr -d ' '); [ -n "$r" ] && [ "$r" -gt 2500000 ] && { echo "RSS $r kill" >> "$OUT/$1.log"; kill -9 $g; }
      echo "$(date +%s) rss=$r" >> "$OUT/rss_$1.txt"
    done; sleep 2; done ) &
wait $P; echo "exit $?"
