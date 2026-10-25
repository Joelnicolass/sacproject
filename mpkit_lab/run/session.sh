#!/usr/bin/env bash
# MpKit session cases, in mpkit_lab: what happens around a match, not in it.
#   deadjoin  joining an address nobody serves fails cleanly; the menu still plays solo
#   full      a dedicated with --max-players=1 turns the second client away
#   leave     a player leaves to the menu and joins again (the server drops and respawns its pawn)
#   lost      the server process dies: the client is told and lands on the menu
#   lan       a listen host advertises on the LAN; a client finds it in the list and joins from there
#   mismatch  an ENet client against a WebSocket server (and the other way round) never gets in, nothing breaks
#   hostname  joining "localhost:port" (a name, not an IP)
# CASES="..." picks some (default all). Prints PASS / FAIL lines and MPKIT SESSION PASS / FAIL (exit 0 / 1).
. "$(dirname "$0")/lib.sh"
net_group 3 "$@"
TAG="MPKIT SESSION"
LIMIT_S="${PROBE_LIMIT_S:-300}"
PROC_MAX=4
PORT="${E2E_PORT:-7860}"
CASES="${CASES:-deadjoin full leave lost lan mismatch hostname}"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/mpkit_session.XXXXXX")"
kill_all() { kill_pids; }
trap 'kill_all; net_stop' EXIT
net_guard
FAILS=0
verdict() { if grep -q "^PROBE $2 PASS" "$1"; then echo "PASS $3"; else echo "FAIL $3"; grep -E "^FAIL" "$1" | head -3 | sed 's/^/   /'; FAILS=$((FAILS + 1)); fi; }
server() { gd "$1" -- "${@:2}" --mp-port="$PORT"; SERVER=$LAST_PID; sleep 0.6; }
stop() { for p in "$@"; do kill_tree "$p"; done; sleep 0.3; }

for c in $CASES; do
  d="$OUT/$c"; mkdir -p "$d"
  case "$c" in
    deadjoin)
      gd "$d/client.log" -- --probe-join="127.0.0.1:$((PORT + 30))" --probe=failjoin --probe-timeout-s=40
      wait "$LAST_PID"
      verdict "$d/client.log" failjoin "deadjoin: a dead address fails cleanly and the menu still plays solo" ;;
    full)
      server "$d/server.log" --server --max-players=1
      gd "$d/first.log" -- --client1 --mp-port="$PORT" --probe=basic --probe-linger-s=10; FIRST=$LAST_PID
      wait_line "$d/first.log" "^PROBE basic" "$FIRST" 30
      gd "$d/second.log" -- --probe-join="127.0.0.1:$PORT" --probe=refused --probe-timeout-s=20
      wait "$LAST_PID"
      stop $FIRST $SERVER
      verdict "$d/second.log" refused "full: the server with --max-players=1 turned the second client away" ;;
    leave)
      server "$d/server.log" --server --probe=rejoinwatch --probe-linger-s=3
      gd "$d/client.log" -- --client1 --mp-port="$PORT" --probe=leaver --probe-linger-s=4; CLIENT=$LAST_PID
      wait_line "$d/server.log" "^PROBE rejoinwatch" "$SERVER" 40
      wait "$CLIENT"; stop $SERVER
      verdict "$d/client.log" leaver "leave: Leave goes back to the menu and joining again works"
      verdict "$d/server.log" rejoinwatch "leave: the server removed the pawn and spawned a new one" ;;
    lost)
      server "$d/server.log" --server
      gd "$d/client.log" -- --client1 --mp-port="$PORT" --probe=lost --probe-timeout-s=30; CLIENT=$LAST_PID
      wait_line "$d/client.log" "^READY for the server to go" "$CLIENT" 30
      kill_tree "$SERVER"
      wait "$CLIENT"
      verdict "$d/client.log" lost "lost: the client is told the server is gone and is back on the menu" ;;
    lan)
      server "$d/server.log" --listen-host
      gd "$d/client.log" -- --mp-port="$PORT" --probe=browse --probe-timeout-s=20; CLIENT=$LAST_PID
      gd "$d/client2.log" -- --mp-port="$PORT" --probe=browse --probe-timeout-s=20; CLIENT2=$LAST_PID
      wait "$CLIENT"; wait "$CLIENT2"; stop $SERVER
      verdict "$d/client.log" browse "lan: the client found the listen host in the LAN list and joined it"
      verdict "$d/client2.log" browse "lan: a second window on the same PC browsing at once found it too" ;;
    mismatch)
      server "$d/server.log" --server --transport=ws
      gd "$d/enet.log" -- --transport=enet --probe-join="127.0.0.1:$PORT" --probe=refused --probe-timeout-s=20
      wait "$LAST_PID"; stop $SERVER
      server "$d/server2.log" --server --transport=enet
      gd "$d/ws.log" -- --transport=ws --probe-join="127.0.0.1:$PORT" --probe=refused --probe-timeout-s=20
      wait "$LAST_PID"; stop $SERVER
      verdict "$d/enet.log" refused "mismatch: an ENet client never gets into a WebSocket server"
      verdict "$d/ws.log" refused "mismatch: a WebSocket client never gets into an ENet server" ;;
    hostname)
      server "$d/server.log" --server --probe=watch --probe-min-move=0.5 --probe-linger-s=3
      gd "$d/client.log" -- --probe-join="localhost:$PORT" --probe=basic --probe-linger-s=2
      wait "$LAST_PID"; stop $SERVER
      verdict "$d/client.log" basic "hostname: joining localhost:port works" ;;
  esac
  if grep -qE "^SCRIPT ERROR" "$d"/*.log; then echo "FAIL $c: script errors"; grep -h -A1 "^SCRIPT ERROR" "$d"/*.log | head -4; FAILS=$((FAILS + 1)); fi
done
net_stop
echo "--- verdict (logs in $OUT) ---"
if [ "$FAILS" = 0 ]; then echo "$TAG PASS"; exit 0; fi
echo "$TAG FAIL: $FAILS"
exit 1
