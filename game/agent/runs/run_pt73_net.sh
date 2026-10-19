#!/usr/bin/env bash
# usage: run_pt73_net.sh PORT -- dedicated on debug/net/village_net.tscn + client A, then (A gone, hut already fallen) a late client.
# Never more than two Godot processes: the server and one client.
set -u
export GODOT=/Users/joelsartori/Development/sacproject/game/agent/harness/godot60.sh
ROOT=/Users/joelsartori/Development/sacproject/game
PORT="${1:-7781}"
OUT="$ROOT/agent/out/pt73/net"
WORLD=res://debug/net/village_net.tscn
mkdir -p "$OUT"; cd "$ROOT"
"$GODOT" --headless --path "$ROOT" -- --dedicated --mp-port="$PORT" --world="$WORLD" > "$OUT/server.log" 2>&1 &
SERVER=$!
for _ in $(seq 1 120); do grep -q "dedicad. listo" "$OUT/server.log" && break; sleep 0.25; done
addons/agent_kit/cli.sh "$ROOT" flow --flow=pt73_net_a.json --out=res://agent/out/pt73/net --fail-on-error --mp-port="$PORT" --world="$WORLD" > "$OUT/a.log" 2>&1
echo "a exit $?"
sleep 2
addons/agent_kit/cli.sh "$ROOT" flow --flow=pt73_net_late.json --out=res://agent/out/pt73/net --fail-on-error --mp-port="$PORT" --world="$WORLD" > "$OUT/late.log" 2>&1
echo "late exit $?"
kill "$SERVER" 2>/dev/null; wait "$SERVER" 2>/dev/null
grep -h "AGENT_CALL pt73_net\|AGENT_FAIL" "$OUT/a.log" "$OUT/late.log" | cut -c1-400
grep -E "npc farmer|servidor: jhut|dedicad" "$OUT/server.log" | head
