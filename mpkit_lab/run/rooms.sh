#!/usr/bin/env bash
# MpKit online rooms e2e (no game code), in mpkit_lab: the example's room server (MpRoomServer, rooms.tscn) and players
# that go through the lobby screen (MpLobbyScreen) like a person. Scenarios (SCENARIOS="...", default all):
#   public    Ana creates a room, Bea joins it from the list, both ready, the room server launches a dedicated match,
#             Ana scores 3 (MpMatch.finish), the result reaches both and the room, both are back in the lobby
#   private   a private room: Bea joins with its code, leaves the room once and comes back, says hello in the chat
#   rejoin    Bea drops out of the match and comes back with the same ticket: the match counts her back (player_back)
#   abandon   Bea drops out and stays away past the grace: she loses (player_abandoned), Ana wins without scoring
#   wait      Bea joins the match 3 s late: Ana's world stays paused until every seat loaded
#   tworooms  two rooms play at the same time on one room server (two dedicated processes)
#   cap       --max-matches=1: while one match runs, a second full room is answered matches_cap
# Every scenario also checks: no script errors, no match process and no match folder left.
# TRANSPORT=ws runs it over WebSocket; TLS=1 over wss:// (lobby and match, self-signed certificate; a client without
# TLS cannot get in). Prints PASS / FAIL lines and MPKIT ROOMS PASS / MPKIT ROOMS FAIL (exit 0 / 1).
. "$(dirname "$0")/lib.sh"
## Reserve only what the asked scenarios need: two rooms (tworooms, cap) run 7 processes at once, the rest 4.
case " ${SCENARIOS:-public private rejoin abandon wait tworooms cap} " in *" tworooms "*|*" cap "*) NEED=7 ;; *) NEED=4 ;; esac
net_group "$NEED" "$@"
TAG="MPKIT ROOMS"
LIMIT_S="${PROBE_LIMIT_S:-420}"
PROC_MAX=8
TRANSPORT="${TRANSPORT:-enet}"
LOBBY_PORT="${E2E_LOBBY_PORT:-7720}"
SCENARIOS="${SCENARIOS:-public private rejoin abandon wait tworooms cap}"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/mpkit_rooms.XXXXXX")"
kill_stray() {
  local p
  for p in $(ps -axo pid=,args= | awk -v m="$OUT" 'index($0, "--path") && index($0, m) {print $1}'); do kill "$p" 2>/dev/null; done
}
kill_all() { kill_pids; kill_stray; }
trap 'kill_all; net_stop' EXIT
net_guard
relay_up

SERVER_TLS=(); CLIENT_TLS=()
if [ "${TLS:-0}" = 1 ]; then
  TRANSPORT=ws
  "$GODOT" --headless --path "$ROOT" --script res://probe/make_cert.gd -- --cert-dir="$OUT" > "$OUT/cert.log" 2>&1
  grep -q "^CERT OK" "$OUT/cert.log" || echo "FAIL the test certificate was not made"
  SERVER_TLS=(--tls-certificate-path="$OUT/cert.crt" --tls-key-path="$OUT/key.key")
  CLIENT_TLS=(--tls-client --tls-trusted-ca="$OUT/cert.crt" --tls-common-name=mpkit.test)
fi
FAILS=0
check() { if eval "$1"; then echo "PASS $2"; else echo "FAIL $2"; FAILS=$((FAILS + 1)); fi; }

room_server() { # room_server <dir> [flags…]
  local dir="$1"; shift
  mkdir -p "$dir/matches"
  gd "$dir/rooms.log" res://addons/mp_kit/examples/arena_2d/rooms.tscn -- "${SERVER_TLS[@]}" --transport="$TRANSPORT" \
    --lobby-port="$LOBBY_PORT" --match-port-min=7730 --match-port-max=7739 --countdown-s=0.3 --matches-root="$dir/matches" \
    --result-quit-delay-s=1 --idle-no-players-s=20 --heartbeat-s=0.5 --poll-s=0.1 ${KEEP_MATCH:+--keep-match-files} "$@"
  ROOMS=$LAST_PID
  wait_line "$dir/rooms.log" "^rooms ready port" "$ROOMS" 30 || echo "FAIL the room server did not start"
}
player() { # player <dir> <name> [flags…]; pid in LAST_PID
  local dir="$1" name="$2"; shift 2
  gd "$dir/$name.log" -- "${CLIENT_TLS[@]}" --transport="$TRANSPORT" --probe=lobby --probe-lobby="127.0.0.1:$LOBBY_PORT" \
    --probe-timeout-s=30 --probe-name="$name" --probe-code-file="$dir/code.txt" "$@"
}
passed() { grep -q "^PROBE lobby PASS" "$1/$2.log"; }
show() { # show <dir> <names…>
  local dir="$1"; shift
  grep -hE "^(rooms|room|match)" "$dir/rooms.log" | sed 's/^/   rooms: /' | head -n 8
  for n in "$@"; do grep -E "^(FAIL|METRIC|SCRIPT ERROR)" "$dir/$n.log" | sed "s/^/   $n: /" | head -n 6; done
}
close() { # close <dir> <pids…>: wait for the players, then the matches, then stop the room server
  local dir="$1"; shift
  for p in "$@"; do wait "$p"; done
  wait_gone "match-ticket-file=$dir/matches" 15
  [ -n "${KEEP_MATCH:-}" ] || for _ in $(seq 1 100); do [ -z "$(find "$dir/matches" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)" ] && break; sleep 0.1; done
  kill_tree "$ROOMS"
  check '! grep -q "^SCRIPT ERROR" "$dir"/*.log' "$(basename "$dir"): no script errors"
  check '[ "$(godots_with "match-ticket-file=$dir/matches")" = 0 ]' "$(basename "$dir"): no match process left"
  [ -n "${KEEP_MATCH:-}" ] || check '[ -z "$(find "$dir/matches" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)" ]' "$(basename "$dir"): no match folder left"
}

for s in $SCENARIOS; do
  d="$OUT/$s"; mkdir -p "$d"
  echo "--- $s ($TRANSPORT$([ "${TLS:-0}" = 1 ] && echo ', wss://')) ---"
  case "$s" in
    public)
      room_server "$d"
      player "$d" Ana --probe-create=Arena; A=$LAST_PID
      wait_line "$d/Ana.log" "^PASS took a seat" "$A" 30
      player "$d" Bea; B=$LAST_PID
      for p in $A $B; do wait "$p"; done
      if [ "${TLS:-0}" = 1 ]; then # a plain ws:// client must not get into the wss:// lobby
        gd "$d/Plain.log" -- --transport=ws --probe=lobby --probe-lobby="127.0.0.1:$LOBBY_PORT" --probe-timeout-s=4 --probe-name=Plain
        wait "$LAST_PID"
        check 'grep -q "^FAIL connected to the lobby" "$d/Plain.log"' "public: a client without TLS cannot get into the wss:// lobby"
      fi
      close "$d"
      show "$d" Ana Bea
      check 'passed "$d" Ana && passed "$d" Bea' "public: create, join from the list, play, the result reaches both and the room"
      check 'grep -q "^match .* ended .*winner" "$d/rooms.log"' "public: the room server got the result" ;;
    private)
      room_server "$d"
      player "$d" Ana --probe-create=Secret --probe-private --probe-expect-chat=hola; A=$LAST_PID
      wait_line "$d/Ana.log" "^PASS the private room has a code" "$A" 30
      player "$d" Bea --probe-join-code --probe-leave-room-once --probe-chat=hola; B=$LAST_PID
      close "$d" $A $B
      show "$d" Ana Bea
      check 'passed "$d" Ana && passed "$d" Bea' "private: join by code, leave and come back, chat, play to the end" ;;
    rejoin)
      room_server "$d" --rejoin-grace-s=15
      player "$d" Ana --probe-create=Arena --probe-expect-back=2; A=$LAST_PID
      wait_line "$d/Ana.log" "^PASS took a seat" "$A" 30
      player "$d" Bea --probe-drop=rejoin; B=$LAST_PID
      close "$d" $A $B
      show "$d" Ana Bea
      check 'passed "$d" Ana && passed "$d" Bea' "rejoin: Bea left the match and came back with her ticket; the match counted her back" ;;
    abandon)
      room_server "$d" --rejoin-grace-s=1
      player "$d" Ana --probe-create=Arena --probe-score=0 --probe-expect-result=winner:p1; A=$LAST_PID
      wait_line "$d/Ana.log" "^PASS took a seat" "$A" 30
      player "$d" Bea --probe-drop=abandon; B=$LAST_PID
      close "$d" $A $B
      show "$d" Ana Bea
      check 'passed "$d" Ana && passed "$d" Bea' "abandon: Bea stayed away past the grace and Ana won without scoring"
      check 'grep -q "^match .* ended .*abandoned" "$d/rooms.log"' "abandon: the result says who abandoned" ;;
    wait)
      room_server "$d"
      player "$d" Ana --probe-create=Arena --probe-check-paused; A=$LAST_PID
      wait_line "$d/Ana.log" "^PASS took a seat" "$A" 30
      player "$d" Bea --probe-delay-join-s=3; B=$LAST_PID
      close "$d" $A $B
      show "$d" Ana Bea
      check 'passed "$d" Ana && passed "$d" Bea' "wait: the world stayed paused until the late seat loaded, then the match ran" ;;
    tworooms)
      room_server "$d"
      player "$d" Ana --probe-create=North; A=$LAST_PID
      player "$d" Cid --probe-create=South; C=$LAST_PID
      wait_line "$d/Ana.log" "^PASS took a seat" "$A" 30
      wait_line "$d/Cid.log" "^PASS took a seat" "$C" 30
      player "$d" Bea --probe-join-room=North; B=$LAST_PID
      player "$d" Dan --probe-join-room=South; D=$LAST_PID
      close "$d" $A $B $C $D
      show "$d" Ana Bea Cid Dan
      check 'passed "$d" Ana && passed "$d" Bea && passed "$d" Cid && passed "$d" Dan' "tworooms: two rooms played at the same time"
      check '[ "$(grep -c "^match .* ended .*winner" "$d/rooms.log")" = 2 ]' "tworooms: the room server got two results"
      check '[ "$(grep -oE "^match for room \"[A-Za-z]+\" on port [0-9]+" "$d/rooms.log" | sort -u | wc -l | tr -d " ")" = 2 ]' "tworooms: each match had its own process and port" ;;
    cap)
      room_server "$d" --max-matches=1
      player "$d" Ana --probe-create=North --probe-hold-s=10; A=$LAST_PID
      wait_line "$d/Ana.log" "^PASS took a seat" "$A" 30
      player "$d" Bea --probe-join-room=North; B=$LAST_PID
      wait_line "$d/Ana.log" "^PASS P1 exists here" "$A" 40
      player "$d" Cid --probe-create=South --probe-expect-error=matches_cap; C=$LAST_PID
      wait_line "$d/Cid.log" "^PASS took a seat" "$C" 30
      player "$d" Dan --probe-join-room=South --probe-expect-error=matches_cap; D=$LAST_PID
      close "$d" $A $B $C $D
      show "$d" Ana Bea Cid Dan
      check 'passed "$d" Cid && passed "$d" Dan' "cap: with max_matches=1 the second full room was answered matches_cap"
      check 'passed "$d" Ana && passed "$d" Bea' "cap: the running match was not disturbed" ;;
  esac
done
net_stop
echo "--- verdict (logs in $OUT) ---"
if [ "$FAILS" = 0 ]; then echo "$TAG PASS"; exit 0; fi
echo "$TAG FAIL: $FAILS"
exit 1
