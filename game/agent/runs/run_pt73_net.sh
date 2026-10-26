#!/usr/bin/env bash
# usage: run_pt73_net.sh PORT -- dedicated on debug/net/village_net.tscn + client A; A leaves by the pause menu and (hut already fallen)
# comes back to its seat within the grace (RFC-068: nobody joins a started match from zero, a dropped seat returns).
# Never more than two Godot processes: the server and one client.
set -u
. "$(dirname "$0")/../harness/env.sh"
export GODOT=$ROOT/agent/harness/godot60.sh
PORT="${1:-7781}"
OUT="$ROOT/agent/out/pt73/net"
WORLD=res://debug/net/village_net.tscn
mkdir -p "$OUT"; cd "$ROOT"
"$GODOT" --headless --path "$ROOT" -- --dedicated --mp-port="$PORT" --world="$WORLD" > "$OUT/server.log" 2>&1 &
SERVER=$!
for _ in $(seq 1 120); do grep -q "dedicad. listo" "$OUT/server.log" && break; sleep 0.25; done
addons/agent_kit/cli.sh "$ROOT" flow --flow=pt73_net_rejoin.json --out=res://agent/out/pt73/net --fail-on-error --mp-port="$PORT" --world="$WORLD" > "$OUT/a.log" 2>&1
echo "a (rejoin) exit $?"
kill "$SERVER" 2>/dev/null; wait "$SERVER" 2>/dev/null
grep -h "AGENT_CALL pt73_net\|AGENT_FAIL" "$OUT/a.log" | cut -c1-400
grep -E "npc farmer|servidor: jhut|dedicad" "$OUT/server.log" | head
