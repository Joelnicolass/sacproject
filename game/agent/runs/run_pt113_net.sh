#!/usr/bin/env bash
# usage: run_pt113_net.sh FLOW PORT  -- F113 online regression at level 1: headless dedicated server + one windowed
# client flow (both 60 fps cap, RSS watchdog 2.5 GB). Waits until godot_busy.sh passes three times. Out: agent/out/pt113play/net/.
set -u
. "$(dirname "$0")/../harness/env.sh"
export GODOT="$ROOT/agent/harness/godot60.sh"
FLOW="$1"; PORT="${2:-7831}"
OUT="$ROOT/agent/out/pt113play/net"; mkdir -p "$OUT"
cd "$ROOT"
for i in $(seq 1 100); do
  ok=1
  for k in 1 2 3; do bash "$ROOT/agent/harness/godot_busy.sh" >/dev/null || { ok=0; break; }; done
  [ $ok -eq 1 ] && break
  [ $i -eq 100 ] && { echo "ABORT busy"; exit 2; }
  sleep 10
done
"$GODOT_BIN" --max-fps 60 --headless --path "$ROOT" -- --dedicated --start-seats=1 --mp-port="$PORT" > "$OUT/$FLOW.server.log" 2>&1 &
SERVER=$!
for _ in $(seq 1 120); do grep -q "listo puerto" "$OUT/$FLOW.server.log" && break; sleep 0.25; done
addons/agent_kit/cli.sh "$ROOT" flow --flow="$ROOT/agent/flows/$FLOW.json" --out=res://agent/out/pt113play/net --mp-port="$PORT" --fail-on-error > "$OUT/$FLOW.client.log" 2>&1 &
CLIENT=$!
( while kill -0 $CLIENT 2>/dev/null; do
    for g in $(ps -axo pid=,comm= | awk '$2 ~ /(^|\/)Godot$/ {print $1}'); do
      r=$(ps -o rss= -p $g | tr -d ' '); [ -n "$r" ] && echo "$(date +%s) $g rss=$r" >> "$OUT/$FLOW.rss" && [ "$r" -gt 2500000 ] && { echo "RSS $r kill $g" >> "$OUT/$FLOW.client.log"; kill -9 $g; }
    done; sleep 2; done ) &
wait $CLIENT; echo "$FLOW client exit $?"
sleep 1
kill "$SERVER" 2>/dev/null; wait "$SERVER" 2>/dev/null
echo "server stopped"
