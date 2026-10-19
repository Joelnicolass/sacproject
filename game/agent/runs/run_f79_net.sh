#!/usr/bin/env bash
# usage: run_f79_net.sh FLOW PORT  -- dedicated (default world) + one client flow (RFC-025b, flows online migrados).
# Two processes of the same test: only starts when NO other test Godot runs; kills both past 2.5 GB RSS each.
set -u
. "$(dirname "$0")/../harness/env.sh"
FLOW="$1"; PORT="${2:-7781}"
OUT="$ROOT/agent/out/f79_net"; mkdir -p "$OUT"
if ps -axo command | grep "Godot.app/Contents/MacOS/Godot" | grep -v grep | grep -qv -- "--editor"; then echo "otro Godot de prueba, no arranco"; exit 3; fi
cd "$ROOT"
G="$GODOT_BIN"
"$G" --headless --max-fps 60 --path "$ROOT" -- --dedicated --mp-port="$PORT" > "$OUT/$FLOW.server.log" 2>&1 &
SERVER=$!
for _ in $(seq 1 80); do grep -q "dedicado listo" "$OUT/$FLOW.server.log" && break; sleep 0.25; done
GODOT="$ROOT/agent/harness/godot60.sh" addons/agent_kit/cli.sh "$ROOT" flow --flow="$FLOW.json" --out=res://agent/out/f79_net --fail-on-error --mp-port="$PORT" > "$OUT/$FLOW.client.log" 2>&1 &
CLIENT=$!
( while kill -0 $CLIENT 2>/dev/null; do
    for p in $(pgrep -f "Godot.*(--dedicated|--agent=flow)"); do
      r=$(ps -o rss= -p $p | tr -d ' '); [ -n "$r" ] && [ "$r" -gt 2500000 ] && { echo "RSS $r kill" >> "$OUT/$FLOW.client.log"; kill -9 $p; }
    done; sleep 2; done ) &
wait $CLIENT; echo "client exit $?"
sleep 1; kill "$SERVER" 2>/dev/null; wait "$SERVER" 2>/dev/null; echo "server stopped"
