#!/usr/bin/env bash
# usage: agent/harness/godot_run.sh agent/harness/run_pt134.sh FLOW -- F134 playtest: one windowed flow,
# 60 fps cap, 1280x720, --fail-on-error, RSS watchdog 2.5 GB. Out: agent/out/pt134/.
set -u
. "$(dirname "$0")/../harness/env.sh"
export GODOT="$ROOT/agent/harness/godot60_res.sh"
export PT_RES=1280x720
OUT="$ROOT/agent/out/pt134"; mkdir -p "$OUT"
cd "$ROOT"
FLOW="$1"; shift
"$ROOT/addons/agent_kit/cli.sh" "$ROOT" flow --flow="$ROOT/agent/flows/$FLOW.json" --out=res://agent/out/pt134 --fail-on-error "$@" > "$OUT/$FLOW.log" 2>&1 &
P=$!
( while kill -0 $P 2>/dev/null; do
    for g in $(ps -axo pid=,comm= | awk '$2 ~ /(^|\/)Godot$/ {print $1}'); do
      r=$(ps -o rss= -p $g | tr -d ' '); [ -n "$r" ] && echo "$(date +%s) rss=$r" >> "$OUT/$FLOW.rss" && [ "$r" -gt 2500000 ] && { echo "RSS $r kill" >> "$OUT/$FLOW.log"; kill -9 $g; }
    done; sleep 2; done ) &
wait $P; echo "$FLOW exit $?"
