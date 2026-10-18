#!/usr/bin/env bash
# RFC-034 034d: lobby protocol over ENet. 2 headless processes: the room server (stub runner, no real dedicated)
# and one process with 4 lobby clients (rooms A and B, 1v1 each, in parallel).
# Closes by itself (internal timeouts 90 s / 80 s); this script also kills both and their descendants (by pid) at 120 s.
# Prints LOBBY NET PASS / FAIL and exits 0 / 1. Needs `--import` once first (new class_names).
# Uses UDP 7705 (lobby) and user://mp_lobby_net/. The launcher's port range is only probed (the stub opens nothing).
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
LIMIT_S="${PROBE_LIMIT_S:-120}"
OUT="${TMPDIR:-/tmp}/lobby_net_034d.$$"
mkdir -p "$OUT"

descendants() { # pid -> pid and all its descendants
  local p="$1" c
  echo "$p"
  for c in $(pgrep -P "$p" 2>/dev/null); do descendants "$c"; done
}
kill_tree() { local p; for p in $(descendants "$1" | sort -rn); do kill "$p" 2>/dev/null; done; }

bash "$ROOT/agent/harness/godot_run.sh" "$GODOT" --headless --path "$ROOT" res://debug/net/lobby_net_cases.tscn -- --no-flow --role=server > "$OUT/server.log" 2>&1 &
SERVER=$!
(
  sleep "$LIMIT_S"
  if kill -0 "$SERVER" 2>/dev/null; then
    echo "LOBBY NET FAIL: external timeout ${LIMIT_S}s"
    kill_tree "$SERVER"
    if [ -s "$OUT/clients.pid" ]; then kill_tree "$(cat "$OUT/clients.pid")"; fi
  fi
) &
WATCH=$!

READY=0
for _ in $(seq 1 $((LIMIT_S * 2))); do
  if grep -q "SERVER READY" "$OUT/server.log" 2>/dev/null; then READY=1; break; fi
  kill -0 "$SERVER" 2>/dev/null || break
  sleep 0.5
done
CODE=1
if [ "$READY" = 1 ]; then
  bash "$ROOT/agent/harness/godot_run.sh" "$GODOT" --headless --path "$ROOT" res://debug/net/lobby_net_cases.tscn -- --no-flow --role=clients > "$OUT/clients.log" 2>&1 &
  CLIENTS=$!
  echo "$CLIENTS" > "$OUT/clients.pid"
  wait "$CLIENTS"; CCODE=$?
  wait "$SERVER"; SCODE=$?
  if [ "$CCODE" = 0 ] && [ "$SCODE" = 0 ] && grep -q "CLIENT CASES PASS" "$OUT/clients.log" && grep -q "SERVER CASES PASS" "$OUT/server.log"; then
    CODE=0
  fi
else
  kill_tree "$SERVER"
  wait "$SERVER" 2>/dev/null
fi
kill "$WATCH" 2>/dev/null
echo "--- server ---"; grep -E "^(PASS|FAIL|SERVER|SCRIPT ERROR|ERROR)" "$OUT/server.log" | tail -n 40
echo "--- clients ---"; grep -E "^(PASS|FAIL|CLIENT|SCRIPT ERROR|ERROR)" "$OUT/clients.log" 2>/dev/null | tail -n 80
if [ "$CODE" = 0 ]; then echo "LOBBY NET PASS"; rm -rf "$OUT"; else echo "LOBBY NET FAIL (logs in $OUT)"; fi
exit "$CODE"
