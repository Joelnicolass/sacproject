#!/usr/bin/env bash
# usage: run_pt77_net.sh PORT -- dedicated with --ai-slots=2 (headless) + one windowed client (slot 1). Two processes, never more.
set -u
. "$(dirname "$0")/../harness/env.sh"
export GODOT=$ROOT/agent/harness/godot60.sh
PORT="${1:-7787}"
OUT="$ROOT/agent/out/pt77/net"
mkdir -p "$OUT"; cd "$ROOT"
"$GODOT" --headless --fixed-fps 60 --path "$ROOT" -- --dedicated --mp-port="$PORT" --ai-slots=2 > "$OUT/server.log" 2>&1 &
SERVER=$!
for _ in $(seq 1 120); do grep -q "dedicated listo" "$OUT/server.log" && break; sleep 0.25; done
addons/agent_kit/cli.sh "$ROOT" flow --flow=pt77_net_client.json --out=res://agent/out/pt77/net ${STRICT---fail-on-error} --mp-port="$PORT" > "$OUT/client.log" 2>&1
echo "client exit $?"
kill "$SERVER" 2>/dev/null; wait "$SERVER" 2>/dev/null
grep -h "AGENT_CALL\|AGENT_FAIL\|SCRIPT ERROR" "$OUT/client.log" | cut -c1-400
grep -E "ia slot|dedicad|slot [0-9] pick|SCRIPT ERROR" "$OUT/server.log" | head -20
