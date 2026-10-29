#!/usr/bin/env bash
# MpKit private match e2e (no game code), in mpkit_lab (this folder's project): a player starts MpLocalServer (a dedicated match process on
# their own PC with invite codes), a friend joins with "ip:port#code", a stranger with a wrong code is turned away, the
# host wins and every process is gone at the end. Also: the match HUD shows the invite, a second click gives the
# running server back, and a second private server of another process on the same PC leaves the first match alone. TRANSPORT=ws runs it over WebSocket.
# Prints PASS / FAIL lines and MPKIT PRIVATE PASS / MPKIT PRIVATE FAIL (exit 0 / 1).
. "$(dirname "$0")/lib.sh"
net_group 4 "$@"
TAG="MPKIT PRIVATE"
LIMIT_S="${PROBE_LIMIT_S:-120}"
PROC_MAX=5
TRANSPORT="${TRANSPORT:-enet}"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/mpkit_private.XXXXXX")"
CODE="$OUT/code.txt"
MATCHES="$OUT/matches"
kill_stray() {
  local p
  for p in $(ps -axo pid=,args= | awk -v m="$MATCHES" '$2 ~ /\/Godot$/ && index($0, m) {print $1}'); do kill "$p" 2>/dev/null; done
}
kill_all() { kill_pids; kill_stray; }
trap 'kill_all; net_stop' EXIT
net_guard
relay_up

COMMON=(--transport="$TRANSPORT" --probe-code-file="$CODE" --probe-timeout-s=30 --matches-root="$MATCHES" --result-quit-delay-s=1)
gd "$OUT/host.log" -- "${COMMON[@]}" --probe=private
HOST=$LAST_PID
wait_line "$OUT/host.log" "^PASS the private match process listens" "$HOST" 40
gd "$OUT/other.log" -- "${COMMON[@]}" --probe=private_other
OTHER=$LAST_PID
wait_pid "$OTHER" 40
gd "$OUT/friend.log" -- "${COMMON[@]}" --probe=invited
FRIEND=$LAST_PID
gd "$OUT/stranger.log" -- "${COMMON[@]}" --probe=badcode
STRANGER=$LAST_PID
for p in $FRIEND $STRANGER $HOST; do wait_pid "$p" 60; done
wait_gone "match-ticket-file=$MATCHES" 15
for r in host other friend stranger; do grep -E "^(PASS|FAIL|SCRIPT ERROR)" "$OUT/$r.log" | sed "s/^/$r: /"; done
FAILS=0
check() { if eval "$1"; then echo "PASS $2"; else echo "FAIL $2"; FAILS=$((FAILS + 1)); fi; }
check 'grep -q "^PROBE private PASS" "$OUT/host.log"' "the host ran a private match on its PC, played and won"
check 'grep -q "^PROBE invited PASS" "$OUT/friend.log"' "the friend joined with the code and saw the end"
check 'grep -q "^PROBE badcode PASS" "$OUT/stranger.log"' "a wrong code was turned away"
check 'grep -q "^PROBE private_other PASS" "$OUT/other.log"' "a second private server on the same PC ran without breaking the first"
check '! grep -q "^SCRIPT ERROR" "$OUT"/*.log' "no script errors"
check '[ "$(godots_with "$MATCHES")" = 0 ]' "no match process left"
net_stop
echo "--- verdict (logs in $OUT) ---"
if [ "$FAILS" = 0 ]; then echo "$TAG PASS"; exit 0; fi
echo "$TAG FAIL: $FAILS"
exit 1
