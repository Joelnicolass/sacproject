#!/usr/bin/env bash
# usage: run_pt86b.sh FLOW [SUFFIX] (with --clip-warm-log)   -- one windowed flow, 60 fps cap, --fail-on-error, RSS watchdog 2.5 GB. Out: agent/out/pt86/.
set -u
set -- "$1" "${2:-}"
ROOT=/Users/joelsartori/Development/sacproject/game
export GODOT="$ROOT/agent/harness/godot60.sh"
OUT="$ROOT/agent/out/pt86b"; mkdir -p "$OUT"
cd "$ROOT"
bash "$ROOT/agent/harness/godot_busy.sh" || { echo "ABORT busy"; exit 2; }
"$ROOT/addons/agent_kit/cli.sh" "$ROOT" flow --flow="$ROOT/agent/flows/$1.json" --out=res://agent/out/pt86b --fail-on-error --clip-warm-log > "$OUT/$1$2.log" 2>&1 &
P=$!
( while kill -0 $P 2>/dev/null; do
    for g in $(pgrep -f "Godot.*--agent=flow"); do
      r=$(ps -o rss= -p $g | tr -d ' '); [ -n "$r" ] && echo "$(date +%s) rss=$r" >> "$OUT/$1$2.rss" && [ "$r" -gt 2500000 ] && { echo "RSS $r kill" >> "$OUT/$1$2.log"; kill -9 $g; }
    done; sleep 2; done ) &
wait $P; echo "exit $?"
