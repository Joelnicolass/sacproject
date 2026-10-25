#!/usr/bin/env bash
# MpKit framework e2e (no Sacrifice code): the arena_2d example of the kit, run in the lab project (mpkit_lab), where
# only MpKit and the lab probe are autoloads. Each scenario is three processes inside ONE group reservation of the queue:
#   dedicated: server (--server) + first client + a late client that joins after the first one played;
#   listen:    host (--listen-host) + first client + a late client.
# The probes (mpkit_lab/probe/lab_probe.gd) press keys and check: remote input moves the pawn on the server and it syncs
# back, MpState score, a to_all event, a to_server call, and that the late client sees what happened before it joined.
#   lag:       dedicated + an observer + a predicted player, every process with MpLagPeer (LAG_MS one way, JITTER_MS,
#              LOSS of unreliable packets): the player answers its keys at once and is barely corrected; the observer
#              sees it move steadily. Prints METRIC lines.
#   flood:     a client sends 500 tunnel messages and 500 to_server calls at once: only the burst gets through.
# TRANSPORT=ws runs everything over WebSocket (TCP) instead of ENet (UDP). SCENARIOS="dedicated listen lag flood" (default all).
# Prints PASS / FAIL lines and MPKIT ARENA PASS / MPKIT ARENA FAIL (exit 0 / 1).
. "$(dirname "$0")/lib.sh"
net_group 3 "$@"
TAG="MPKIT ARENA"
LIMIT_S="${PROBE_LIMIT_S:-120}"
PROC_MAX=4
TRANSPORT="${TRANSPORT:-enet}"
PORT="${E2E_PORT:-7790}"
SCENARIOS="${SCENARIOS:-dedicated listen lag flood}"
LAG_MS="${LAG_MS:-60}"
JITTER_MS="${JITTER_MS:-30}"
LOSS="${LOSS:-0.03}"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/mpkit_arena.XXXXXX")"
kill_all() { kill_pids; }
trap 'kill_all; net_stop' EXIT
net_guard

FAILS=0
verdict() { # verdict <log> <role>
  if grep -q "^PROBE $2 PASS" "$1"; then echo "PASS $3"; else echo "FAIL $3"; FAILS=$((FAILS + 1)); fi
}

run_scenario() { # run_scenario <name> <server flag> <first client slot>
  local name="$1" flag="$2" first="$3" dir="$OUT/$1"
  mkdir -p "$dir"
  local common=(--transport="$TRANSPORT" --mp-port="$PORT")
  gd "$dir/server.log" -- "$flag" "${common[@]}" --probe=watch --probe-server-node --probe-linger-s=60
  local server=$LAST_PID
  sleep 0.5
  gd "$dir/client.log" -- --client1 "${common[@]}" --probe=client --probe-linger-s=60
  local client=$LAST_PID
  wait_line "$dir/client.log" "^PROBE client (PASS|FAIL)" "$client" 40
  # the late client joins the way a person types it: "host:port" in the address field (MpFlow.join_address)
  gd "$dir/late.log" -- "${common[@]}" --probe-join="127.0.0.1:$PORT" --probe=late --probe-first="$first"
  local late=$LAST_PID
  wait_line "$dir/late.log" "^PROBE late (PASS|FAIL)" "$late" 40
  wait_line "$dir/server.log" "^PROBE watch (PASS|FAIL)" "$server" 5
  for p in $late $client $server; do kill_tree "$p"; done
  echo "--- $name ($TRANSPORT) ---"
  for r in server client late; do
    grep -E "^(PASS|FAIL|SCRIPT ERROR|ERROR)" "$dir/$r.log" | sed "s/^/$r: /" | head -n 20
  done
  verdict "$dir/server.log" watch "$name: the server saw the remote player move and score"
  verdict "$dir/client.log" client "$name: the first client played over the network"
  verdict "$dir/late.log" late "$name: the late client saw what happened before it joined"
  if grep -qE "^SCRIPT ERROR" "$dir"/*.log; then echo "FAIL $name: script errors"; FAILS=$((FAILS + 1)); fi
  if grep -qE "Node not found|Failed to get cached path" "$dir"/*.log; then
    echo "FAIL $name: a peer got a packet for a node it does not have"; grep -hE "Node not found|cached path" "$dir"/*.log | sort | uniq -c | head -3
    FAILS=$((FAILS + 1))
  fi
}

run_lag() { # dedicated server + an observer (slot 1) + a predicted player (slot 2), every process on a bad network
  local dir="$OUT/lag"
  mkdir -p "$dir"
  local common=(--transport="$TRANSPORT" --mp-port="$PORT" --net-lag-ms="$LAG_MS" --net-jitter-ms="$JITTER_MS" --net-loss="$LOSS")
  gd "$dir/server.log" --max-fps 120 -- --server "${common[@]}"
  local server=$LAST_PID
  sleep 0.5
  gd "$dir/observer.log" --max-fps 120 -- --client1 "${common[@]}" --probe=observe --probe-watch-slot=2
  local observer=$LAST_PID
  wait_line "$dir/observer.log" "^PASS the observer got a slot" "$observer" 20
  gd "$dir/player.log" --max-fps 120 -- --client2 "${common[@]}" --probe=lag
  local player=$LAST_PID
  wait_line "$dir/player.log" "^PROBE lag (PASS|FAIL)" "$player" 40
  wait_line "$dir/observer.log" "^PROBE observe (PASS|FAIL)" "$observer" 10
  for p in $player $observer $server; do kill_tree "$p"; done
  echo "--- lag ($TRANSPORT, ${LAG_MS} ms + ${JITTER_MS} ms jitter, loss $LOSS, every process) ---"
  for r in observer player; do
    grep -E "^(PASS|FAIL|METRIC|SCRIPT ERROR|ERROR)" "$dir/$r.log" | sed "s/^/$r: /" | head -n 20
  done
  verdict "$dir/player.log" lag "lag: the predicted player answers at once and is barely corrected"
  verdict "$dir/observer.log" observe "lag: another player moves steadily on screen (buffered interpolation)"
  if grep -qE "^SCRIPT ERROR" "$dir"/*.log; then echo "FAIL lag: script errors"; FAILS=$((FAILS + 1)); fi
}

run_flood() { # dedicated server + one client that floods the tunnel and to_server
  local dir="$OUT/flood"
  mkdir -p "$dir"
  local common=(--transport="$TRANSPORT" --mp-port="$PORT")
  gd "$dir/server.log" -- --server "${common[@]}" --probe=floodwatch
  local server=$LAST_PID
  sleep 0.5
  gd "$dir/client.log" -- --client1 "${common[@]}" --probe=flood --probe-linger-s=8
  local client=$LAST_PID
  wait_line "$dir/server.log" "^PROBE floodwatch (PASS|FAIL)" "$server" 40
  for p in $client $server; do kill_tree "$p"; done
  echo "--- flood ($TRANSPORT) ---"
  grep -hE "^(PASS|FAIL|METRIC|SCRIPT ERROR)" "$dir/server.log" | sed "s/^/server: /"
  verdict "$dir/server.log" floodwatch "flood: the server only lets in what the limits allow"
}

for s in $SCENARIOS; do
  case "$s" in
    dedicated) run_scenario dedicated --server 1 ;;
    listen) run_scenario listen --listen-host 2 ;;
    lag) run_lag ;;
    flood) run_flood ;;
  esac
done
net_stop
echo "--- verdict ($((SECONDS))s, logs in $OUT) ---"
if [ "$FAILS" = 0 ]; then echo "$TAG PASS"; exit 0; fi
echo "$TAG FAIL: $FAILS"
exit 1
