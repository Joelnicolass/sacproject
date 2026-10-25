#!/usr/bin/env bash
# MpKit online rooms e2e (no Sacrifice code), in mpkit_lab: the example's room server (MpRoomServer, rooms.tscn) and two
# players that go through the lobby screen (MpLobbyScreen) like a person: Ana creates a room, Bea joins it from the list,
# both say ready, the room server launches a dedicated match process (MpMatchLauncher + the ticket), both join it, Ana
# scores 3 (MpMatch.finish), the result reaches both and the room, and both are back in the lobby screen.
# Also checked: no Godot process and no match folder left. TRANSPORT=ws runs it over WebSocket; TLS=1 over wss://
# (lobby and match, self-signed certificate; clients trust it with --tls-trusted-ca).
# Prints PASS / FAIL lines and MPKIT ROOMS PASS / MPKIT ROOMS FAIL (exit 0 / 1).
. "$(dirname "$0")/../harness/net_e2e.sh"
net_group 4 "$@"
TAG="MPKIT ROOMS"
LIMIT_S="${PROBE_LIMIT_S:-150}"
PROC_MAX=5
TRANSPORT="${TRANSPORT:-enet}"
LOBBY_PORT="${E2E_LOBBY_PORT:-7720}"
ROOT="$(cd "$ROOT/../mpkit_lab" && pwd)"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/mpkit_rooms.XXXXXX")"
MATCHES="$OUT/matches"
mkdir -p "$MATCHES"
kill_stray() {
  local p
  for p in $(ps -axo pid=,args= | awk -v m="$MATCHES" '$2 ~ /\/Godot$/ && index($0, m) {print $1}'); do kill "$p" 2>/dev/null; done
}
kill_all() { kill_pids; kill_stray; }
trap 'kill_all; net_stop' EXIT
net_guard

# TLS=1: wss:// for the lobby and the match (WebSocket only), with a self-signed certificate made for this run.
SERVER_TLS=(); CLIENT_TLS=()
if [ "${TLS:-0}" = 1 ]; then
  TRANSPORT=ws
  "$GODOT" --headless --path "$ROOT" --script res://probe/make_cert.gd -- --cert-dir="$OUT" > "$OUT/cert.log" 2>&1
  grep -q "^CERT OK" "$OUT/cert.log" || echo "FAIL the test certificate was not made"
  SERVER_TLS=(--tls-certificate-path="$OUT/cert.crt" --tls-key-path="$OUT/key.key")
  CLIENT_TLS=(--tls-client --tls-trusted-ca="$OUT/cert.crt" --tls-common-name=mpkit.test)
fi
gd "$OUT/rooms.log" res://addons/mp_kit/examples/arena_2d/rooms.tscn -- "${SERVER_TLS[@]}" --transport="$TRANSPORT" --lobby-port="$LOBBY_PORT" \
  --match-port-min=7730 --match-port-max=7739 --countdown-s=0.3 --matches-root="$MATCHES" --result-quit-delay-s=1 \
  --idle-no-players-s=20 --heartbeat-s=0.5 --poll-s=0.1
ROOMS=$LAST_PID
wait_line "$OUT/rooms.log" "^rooms ready port" "$ROOMS" 30 || echo "FAIL the room server did not start"
CLIENT=("${CLIENT_TLS[@]}" --transport="$TRANSPORT" --probe=lobby --probe-lobby="127.0.0.1:$LOBBY_PORT" --probe-timeout-s=30)
gd "$OUT/Ana.log" -- "${CLIENT[@]}" --probe-name=Ana --probe-create=Arena
ANA=$LAST_PID
wait_line "$OUT/Ana.log" "^PASS took a seat" "$ANA" 30
gd "$OUT/Bea.log" -- "${CLIENT[@]}" --probe-name=Bea
BEA=$LAST_PID
for p in $ANA $BEA; do wait "$p"; done
if [ "${TLS:-0}" = 1 ]; then # a plain ws:// client must not get into the wss:// lobby
  gd "$OUT/Plain.log" -- --transport=ws --probe=lobby --probe-lobby="127.0.0.1:$LOBBY_PORT" --probe-timeout-s=4 --probe-name=Plain
  wait "$LAST_PID"
fi
wait_gone "match-ticket-file=$MATCHES" 15
for _ in $(seq 1 100); do [ -z "$(find "$MATCHES" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)" ] && break; sleep 0.1; done
kill_tree "$ROOMS"

echo "--- rooms ($TRANSPORT$([ "${TLS:-0}" = 1 ] && echo ', wss://')) ---"
grep -E "^(rooms|room|match|SCRIPT ERROR)" "$OUT/rooms.log" | head -n 20
for n in Ana Bea; do grep -E "^(PASS|FAIL|METRIC|SCRIPT ERROR)" "$OUT/$n.log" | sed "s/^/$n: /" | head -n 20; done
FAILS=0
check() { if eval "$1"; then echo "PASS $2"; else echo "FAIL $2"; FAILS=$((FAILS + 1)); fi; }
check 'grep -q "^PROBE lobby PASS" "$OUT/Ana.log"' "Ana created a room, played the match and is back in the lobby with the result"
check 'grep -q "^PROBE lobby PASS" "$OUT/Bea.log"' "Bea joined from the list, played and is back in the lobby with the result"
check 'grep -q "^match .* ended .*winner" "$OUT/rooms.log"' "the room server got the match result (winner)"
check '! grep -q "^SCRIPT ERROR" "$OUT"/Ana.log "$OUT"/Bea.log "$OUT"/rooms.log' "no script errors"
if [ "${TLS:-0}" = 1 ]; then
  check 'grep -q "^FAIL connected to the lobby" "$OUT/Plain.log"' "a client without TLS cannot get into the wss:// lobby"
fi
check '[ "$(godots_with "$MATCHES")" = 0 ]' "no match process left"
check '[ -z "$(find "$MATCHES" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)" ]' "no match folder left"
net_stop
echo "--- verdict (${SECONDS}s, logs in $OUT) ---"
if [ "$FAILS" = 0 ]; then echo "$TAG PASS"; exit 0; fi
echo "$TAG FAIL: $FAILS"
exit 1
