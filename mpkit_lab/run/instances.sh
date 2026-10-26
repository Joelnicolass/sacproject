#!/usr/bin/env bash
# MpKit: several room server instances on one machine, started the way deploy/mp-rooms@.service starts them
# (`-- --room-server --lobby-port=P --match-port-min/max --matches-root`), in mpkit_lab (this folder's project). Instance A (7750) and instance
# B (7760) run side by side with their own match ports and folders; two players play a full match on B while A keeps
# serving; at the end no match process is left and only B's folder saw a match.
# Prints PASS / FAIL lines and MPKIT INSTANCES PASS / FAIL (exit 0 / 1).
. "$(dirname "$0")/lib.sh"
net_group 5 "$@"
TAG="MPKIT INSTANCES"
LIMIT_S="${PROBE_LIMIT_S:-150}"
PROC_MAX=6
OUT="$(mktemp -d "${TMPDIR:-/tmp}/mpkit_instances.XXXXXX")"
kill_stray() {
  local p
  for p in $(ps -axo pid=,args= | awk -v m="$OUT" '$2 ~ /\/Godot$/ && index($0, m) {print $1}'); do kill "$p" 2>/dev/null; done
}
kill_all() { kill_pids; kill_stray; }
trap 'kill_all; net_stop' EXIT
net_guard

instance() { # instance <name> <lobby port> <match min> <match max>
  mkdir -p "$OUT/matches-$1"
  gd "$OUT/rooms-$1.log" -- --room-server --lobby-port="$2" --match-port-min="$3" --match-port-max="$4" \
    --matches-root="$OUT/matches-$1" --countdown-s=0.3 --result-quit-delay-s=1 --heartbeat-s=0.5 --poll-s=0.1
}
instance A 7750 7751 7759
A=$LAST_PID
instance B 7760 7761 7769
B=$LAST_PID
wait_line "$OUT/rooms-A.log" "^rooms ready port 7750" "$A" 30
wait_line "$OUT/rooms-B.log" "^rooms ready port 7760" "$B" 30
CLIENT=(--probe=lobby --probe-lobby=127.0.0.1:7760 --probe-timeout-s=30)
gd "$OUT/Ana.log" -- "${CLIENT[@]}" --probe-name=Ana --probe-create=Arena
ANA=$LAST_PID
wait_line "$OUT/Ana.log" "^PASS took a seat" "$ANA" 30
gd "$OUT/Bea.log" -- "${CLIENT[@]}" --probe-name=Bea
BEA=$LAST_PID
for p in $ANA $BEA; do wait "$p"; done
wait_gone "match-ticket-file=$OUT" 15
A_ALIVE=0; kill -0 "$A" 2>/dev/null && A_ALIVE=1
for p in $A $B; do kill_tree "$p"; done
grep -hE "^(rooms|match|room)" "$OUT"/rooms-*.log | sed 's/^/rooms: /'
FAILS=0
check() { if eval "$1"; then echo "PASS $2"; else echo "FAIL $2"; FAILS=$((FAILS + 1)); fi; }
check 'grep -q "^rooms ready port 7750" "$OUT/rooms-A.log" && grep -q "^rooms ready port 7760" "$OUT/rooms-B.log"' "two room server instances started side by side (--room-server)"
check 'grep -q "^PROBE lobby PASS" "$OUT/Ana.log" && grep -q "^PROBE lobby PASS" "$OUT/Bea.log"' "a full match was played on instance B"
check 'grep -qE "^match for room .* on port 776[1-9]" "$OUT/rooms-B.log"' "B used its own match ports (7761-7769)"
check '[ "$A_ALIVE" = 1 ] && ! grep -q "^match for room" "$OUT/rooms-A.log"' "A kept serving, untouched"
check '[ "$(godots_with "match-ticket-file=$OUT")" = 0 ]' "no match process left"
check '! grep -q "^SCRIPT ERROR" "$OUT"/*.log' "no script errors"
net_stop
echo "--- verdict (logs in $OUT) ---"
if [ "$FAILS" = 0 ]; then echo "$TAG PASS"; exit 0; fi
echo "$TAG FAIL: $FAILS"
exit 1
