#!/usr/bin/env bash
# usage: run_pt113.sh FLOW [--flag=value ...]  -- F113 playtest: one windowed flow, 60 fps cap, --fail-on-error,
# RSS watchdog 2.5 GB. Waits (max 20 min) until godot_busy.sh passes three times in a row. Out: agent/out/pt113play/.
set -u
ROOT=/Users/joelsartori/Development/sacproject/game
export GODOT="$ROOT/agent/harness/godot60.sh"
OUT="$ROOT/agent/out/pt113play"; mkdir -p "$OUT"
cd "$ROOT"
FLOW="$1"; shift
for i in $(seq 1 100); do
  ok=1
  for k in 1 2 3; do bash "$ROOT/agent/harness/godot_busy.sh" >/dev/null || { ok=0; break; }; done
  [ $ok -eq 1 ] && break
  [ $i -eq 100 ] && { echo "ABORT busy"; exit 2; }
  sleep 10
done
"$ROOT/addons/agent_kit/cli.sh" "$ROOT" flow --flow="$ROOT/agent/flows/$FLOW.json" --out=res://agent/out/pt113play --fail-on-error "$@" > "$OUT/$FLOW.log" 2>&1 &
P=$!
( while kill -0 $P 2>/dev/null; do
    for g in $(ps -axo pid=,comm= | awk '$2 ~ /(^|\/)Godot$/ {print $1}'); do
      r=$(ps -o rss= -p $g | tr -d ' '); [ -n "$r" ] && echo "$(date +%s) rss=$r" >> "$OUT/$FLOW.rss" && [ "$r" -gt 2500000 ] && { echo "RSS $r kill" >> "$OUT/$FLOW.log"; kill -9 $g; }
    done; sleep 2; done ) &
wait $P; echo "$FLOW exit $?"
