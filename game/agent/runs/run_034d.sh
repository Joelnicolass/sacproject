#!/usr/bin/env bash
# RFC-034 034d: lobby protocol over ENet. 2 headless processes: the room server (stub runner, no real dedicated)
# and one process with 4 lobby clients (rooms A and B, 1v1 each, in parallel).
# F350: both processes run inside ONE group reservation of the Godot queue (agent/harness/godot_group.sh), started directly.
# The wait for the server is on its `SERVER READY` line (0.1 s), the countdown and the poll of the config are short flags.
# Closes by itself (internal timeouts 90 s / 80 s); this script also kills both and their descendants (by pid) at LIMIT_S (120 s).
# Prints LOBBY NET PASS / FAIL and exits 0 / 1. Needs `--import` once first (new class_names).
# Uses UDP 7705 (lobby) and user://mp_lobby_net/. The launcher's port range is only probed (the stub opens nothing).
. "$(dirname "$0")/../harness/net_e2e.sh"
net_group 2 "$@"
TAG="LOBBY NET"
LIMIT_S="${PROBE_LIMIT_S:-120}"
PROC_MAX=3
TRANSPORT="${TRANSPORT:-enet}" # enet (UDP, default) or ws (WebSocket over TCP): TRANSPORT=ws bash agent/runs/run_034d.sh
OUT="$(mktemp -d "${TMPDIR:-/tmp}/lobby_net_034d.XXXXXX")"
kill_all() { kill_pids; }
trap 'kill_all; net_stop' EXIT
net_guard

gd "$OUT/server.log" res://debug/net/lobby_net_cases.tscn -- --no-flow --role=server --transport="$TRANSPORT" --countdown-s=0.2 --poll-s=0.1
SERVER=$LAST_PID
READY=0
wait_line "$OUT/server.log" "SERVER READY" "$SERVER" "$LIMIT_S" && READY=1
CODE=1
if [ "$READY" = 1 ]; then
  gd "$OUT/clients.log" res://debug/net/lobby_net_cases.tscn -- --no-flow --role=clients --transport="$TRANSPORT"
  CLIENTS=$LAST_PID
  wait "$CLIENTS"; CCODE=$?
  wait "$SERVER"; SCODE=$?
  if [ "$CCODE" = 0 ] && [ "$SCODE" = 0 ] && grep -q "CLIENT CASES PASS" "$OUT/clients.log" && grep -q "SERVER CASES PASS" "$OUT/server.log"; then
    CODE=0
  fi
else
  kill_tree "$SERVER"
  wait "$SERVER" 2>/dev/null
fi
if [ -s "$OUT/timeout.flag" ]; then cat "$OUT/timeout.flag"; CODE=1; fi
net_stop
echo "--- server ---"; grep -E "^(PASS|FAIL|SERVER|SCRIPT ERROR|ERROR)" "$OUT/server.log" | tail -n 40
echo "--- clients ---"; grep -E "^(PASS|FAIL|CLIENT|SCRIPT ERROR|ERROR)" "$OUT/clients.log" 2>/dev/null | tail -n 80
if [ "$CODE" = 0 ]; then echo "$TAG PASS"; rm -rf "$OUT"; else echo "$TAG FAIL (logs in $OUT)"; fi
exit "$CODE"
