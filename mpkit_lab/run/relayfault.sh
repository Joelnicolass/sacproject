#!/usr/bin/env bash
# MpKit relay faults, end to end (always over a local relay):
#   clash     other hosts already hold all but one of the match ports' relay rooms: a private match still starts,
#             on the free port (the launcher moved on from every refused one), and a friend plays it to the end
#   restart   a dedicated through the relay is killed (kill -9) and started again at once: the new one gets the room
#             (a refused host retries for 3 s) and a client plays on it
#   frozen    the dedicated is frozen (SIGSTOP): a second one is refused and stops ("in use on the relay"); once the
#             relay drops the silent host, a third one gets the room and a client plays on it
# SCENARIOS="clash restart frozen" (default all). Prints PASS / FAIL lines and MPKIT RELAYFAULT PASS / FAIL (exit 0 / 1).
. "$(dirname "$0")/lib.sh"
net_group 4 "$@"
TAG="MPKIT RELAYFAULT"
LIMIT_S="${PROBE_LIMIT_S:-300}"
PROC_MAX=5
export TRANSPORT=relay
## Longer than a refused host's 3 s grace, so the frozen case really meets a held room.
export RELAY_HOST_SILENT_MS="${RELAY_HOST_SILENT_MS:-8000}"
SCENARIOS="${SCENARIOS:-clash restart frozen}"
PORT="${E2E_PORT:-7791}"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/mpkit_relayfault.XXXXXX")"
MATCHES="$OUT/matches"
HOLDER=""
kill_stray() {
  local p
  for p in $(ps -axo pid=,args= | awk -v m="$MATCHES" '$2 ~ /\/Godot$/ && index($0, m) {print $1}'); do kill "$p" 2>/dev/null; done
}
kill_all() { kill_pids; kill_stray; [ -n "$HOLDER" ] && kill "$HOLDER" 2>/dev/null; }
trap 'kill_all; net_stop' EXIT
net_guard
RELAY_QUIET=0 relay_up
ROOM="lab$$"
FAILS=0
check() { if eval "$1"; then echo "PASS $2"; else echo "FAIL $2"; FAILS=$((FAILS + 1)); fi; }

hold_rooms() { # hold_rooms <port…>: one host per relay room, kept open (other servers of the same game)
  node -e '
    const http = require("http");
    const [port, secret, room, ...ports] = process.argv.slice(1);
    let open = 0;
    for (const p of ports) {
      const req = http.request({ host: "127.0.0.1", port, path: "/?role=host&room=" + room + "-" + p, headers: {
        Connection: "Upgrade", Upgrade: "websocket", "Sec-WebSocket-Version": "13",
        "Sec-WebSocket-Key": "dGhlIHNhbXBsZSBub25jZQ==", "X-Relay-Secret": secret } });
      req.on("upgrade", (res, socket) => {
        socket.on("data", (d) => { for (let i = 0; i + 1 < d.length; i++) if (d[i] === 0x89) socket.write(Buffer.from([0x8a, 0x80, 0, 0, 0, 0])); });
        if (++open === ports.length) console.log("HOLDING " + ports.join(","));
      });
      req.end();
    }
    setInterval(() => {}, 1000);' "$RELAY_PORT" "$RELAY_SECRET" "$ROOM" "$@" > "$OUT/holder.log" 2>&1 &
  HOLDER=$!
  for _ in $(seq 1 50); do grep -q "^HOLDING" "$OUT/holder.log" && return 0; sleep 0.1; done
  echo "FAIL the holder did not take its rooms"
}

dedicated() { # dedicated <log>: a dedicated through the relay on $PORT; pid in LAST_PID
  gd "$1" -- --dedicated --transport=relay --mp-port="$PORT"
}
hosted_times() { grep -c "^\[relay\] host $ROOM-$PORT\$" "$OUT/relay.log"; }
client_plays() { # client_plays <log>: a client that plays on the dedicated; true if its probe passed
  gd "$1" -- --client1 --transport=relay --mp-port="$PORT" --probe=client --probe-timeout-s=20
  wait_pid "$LAST_PID" 60
  grep -q "^PROBE client PASS" "$1"
}

for s in $SCENARIOS; do
  echo "--- $s ---"
  case "$s" in
    clash)
      hold_rooms 7860 7861 7862 7863 7864 7865 7866 7867 7868
      COMMON=(--transport=relay --probe-code-file="$OUT/code.txt" --probe-timeout-s=40 --matches-root="$MATCHES"
        --result-quit-delay-s=1 --match-port-min=7860 --match-port-max=7869)
      gd "$OUT/host.log" -- "${COMMON[@]}" --probe=private
      HOST=$LAST_PID
      wait_line "$OUT/host.log" "^PASS the private match process listens" "$HOST" 60
      gd "$OUT/friend.log" -- "${COMMON[@]}" --probe=invited
      FRIEND=$LAST_PID
      for p in $FRIEND $HOST; do wait_pid "$p" 90; done
      kill "$HOLDER" 2>/dev/null; HOLDER=""
      refused=$(grep -c "host refused: $ROOM-786[0-8] is in use" "$OUT/relay.log")
      echo "   the relay refused the match on $refused taken port(s) before it found the free one"
      check '[ "$(cut -d" " -f1 "$OUT/code.txt" 2>/dev/null)" = 7869 ]' "clash: the private match listens on the one free relay port (7869)"
      check 'grep -q "^PROBE private PASS" "$OUT/host.log" && grep -q "^PROBE invited PASS" "$OUT/friend.log"' "clash: the host and a friend played it to the end"
      check '! grep -q "^SCRIPT ERROR" "$OUT"/host.log "$OUT"/friend.log' "clash: no script errors" ;;
    restart)
      before=$(hosted_times)
      dedicated "$OUT/restart_a.log"; A=$LAST_PID
      for _ in $(seq 1 100); do [ "$(hosted_times)" -gt "$before" ] && break; sleep 0.1; done
      check '[ "$(hosted_times)" -gt "$before" ]' "restart: the first dedicated hosts its relay room"
      kill -9 "$A"
      dedicated "$OUT/restart_b.log"; B=$LAST_PID
      for _ in $(seq 1 100); do [ "$(hosted_times)" -gt $((before + 1)) ] && break; sleep 0.1; done
      check '[ "$(hosted_times)" -gt $((before + 1)) ]' "restart: killed and started again at once, the new one gets the room"
      check 'client_plays "$OUT/restart_client.log"' "restart: a client plays on the restarted server"
      kill_tree "$B" ;;
    frozen)
      before=$(hosted_times)
      dedicated "$OUT/frozen_a.log"; A=$LAST_PID
      for _ in $(seq 1 100); do [ "$(hosted_times)" -gt "$before" ] && break; sleep 0.1; done
      kill -STOP "$A"
      dedicated "$OUT/frozen_b.log"; B=$LAST_PID
      wait_pid "$B" 20
      check 'grep -q "is in use on the relay" "$OUT/frozen_b.log"' "frozen: while the frozen host still holds the room, a second dedicated is refused and says so"
      check '! kill -0 "$B" 2>/dev/null' "frozen: the refused dedicated stopped (as a busy port would)"
      for _ in $(seq 1 300); do grep -q "host $ROOM-$PORT silent, dropped" "$OUT/relay.log" && break; sleep 0.1; done
      check 'grep -q "host $ROOM-$PORT silent, dropped" "$OUT/relay.log"' "frozen: the relay drops the silent host (RELAY_HOST_SILENT_MS=$RELAY_HOST_SILENT_MS)"
      hosted=$(hosted_times)
      dedicated "$OUT/frozen_c.log"; C=$LAST_PID
      for _ in $(seq 1 100); do [ "$(hosted_times)" -gt "$hosted" ] && break; sleep 0.1; done
      check 'client_plays "$OUT/frozen_client.log"' "frozen: a third dedicated gets the room and a client plays on it"
      kill -CONT "$A" 2>/dev/null; kill_tree "$A"; kill_tree "$C" ;;
  esac
done
check '! grep -q "^SCRIPT ERROR" "$OUT"/*.log' "no script errors"
net_stop
echo "--- verdict (logs in $OUT) ---"
if [ "$FAILS" = 0 ]; then echo "$TAG PASS"; exit 0; fi
echo "$TAG FAIL: $FAILS"
exit 1
