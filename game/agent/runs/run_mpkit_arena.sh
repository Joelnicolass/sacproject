#!/usr/bin/env bash
# MpKit framework e2e (no Sacrifice code): the arena_2d example of the kit, run in the lab project (../mpkit_lab), where
# only MpKit and the lab probe are autoloads. Each scenario is three processes inside ONE group reservation of the queue:
#   dedicated: server (--server) + first client + a late client that joins after the first one played;
#   listen:    host (--listen-host) + first client + a late client.
# The probes (mpkit_lab/probe/lab_probe.gd) press keys and check: remote input moves the pawn on the server and it syncs
# back, MpState score, a to_all event, a to_server call, and that the late client sees what happened before it joined.
# TRANSPORT=ws runs everything over WebSocket (TCP) instead of ENet (UDP). SCENARIOS="dedicated listen" (default both).
# Prints PASS / FAIL lines and MPKIT ARENA PASS / MPKIT ARENA FAIL (exit 0 / 1).
. "$(dirname "$0")/../harness/net_e2e.sh"
net_group 3 "$@"
TAG="MPKIT ARENA"
LIMIT_S="${PROBE_LIMIT_S:-120}"
PROC_MAX=4
TRANSPORT="${TRANSPORT:-enet}"
PORT="${E2E_PORT:-7790}"
SCENARIOS="${SCENARIOS:-dedicated listen}"
ROOT="$(cd "$ROOT/../mpkit_lab" && pwd)" # gd and the guard work on the lab project from here on
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
  gd "$dir/server.log" -- "$flag" "${common[@]}" --probe=watch --probe-linger-s=60
  local server=$LAST_PID
  sleep 0.5
  gd "$dir/client.log" -- --client1 "${common[@]}" --probe=client --probe-linger-s=60
  local client=$LAST_PID
  wait_line "$dir/client.log" "^PROBE client (PASS|FAIL)" "$client" 40
  gd "$dir/late.log" -- --client2 "${common[@]}" --probe=late --probe-first="$first"
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
}

for s in $SCENARIOS; do
  case "$s" in
    dedicated) run_scenario dedicated --server 1 ;;
    listen) run_scenario listen --listen-host 2 ;;
  esac
done
net_stop
echo "--- verdict ($((SECONDS))s, logs in $OUT) ---"
if [ "$FAILS" = 0 ]; then echo "$TAG PASS"; exit 0; fi
echo "$TAG FAIL: $FAILS"
exit 1
