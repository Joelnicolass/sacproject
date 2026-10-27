#!/usr/bin/env bash
# Play or watch the MpKit example in WINDOWS, with the server started the way production starts it.
#   play.sh dedicated [--watch] [--relay]    a dedicated server (headless, `-- --dedicated`, starts when both loaded) + 2 windows
#   play.sh listen [--watch]                 window 1 hosts (Host LAN, starts with one client), window 2 joins
#   play.sh rooms [--watch] [--relay]        a room server (headless, `-- --room-server`) + 2 windows on the lobby
# Without --watch you play: each window shows the menu (Join 127.0.0.1, Host LAN, Online rooms…). Arrows move,
# Enter scores, Space shoots, Tab recolors, Escape rings the bell; the first to 3 wins.
# With --watch the windows play by themselves (the lab probe) so you can see a full run, then they stay open.
# --relay: everything goes through a local MpKit relay (node), like a Railway tunnel.
# Close the windows (or Ctrl+C here) to end: the server and the relay stop with them. Logs: the folder printed below.
. "$(dirname "$0")/lib.sh"
MODE="${1:-dedicated}"; shift || true
WATCH_MODE=0; for a in "$@"; do case "$a" in --watch) WATCH_MODE=1 ;; --relay) TRANSPORT=relay ;; esac; done
TRANSPORT="${TRANSPORT:-enet}"
net_group 5 "$MODE" "$@"
TAG="MPKIT PLAY"
LIMIT_S="${PLAY_LIMIT_S:-1800}"
PROC_MAX=6
PORT="${PLAY_PORT:-7777}"
## --watch: how long the windows stay open after their run (PLAY_LINGER_S).
LINGER="${PLAY_LINGER_S:-600}"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/mpkit_play.XXXXXX")"
kill_all() { kill_pids; }
trap 'kill_all; net_stop' EXIT INT TERM
net_guard
relay_up
echo "MpKit play: $MODE ($TRANSPORT$([ "$WATCH_MODE" = 1 ] && echo ', watch')) — logs in $OUT"
W1=(); W2=(); SERVER=""
case "$MODE" in
  dedicated)
    # the start gate: the match starts once both windows loaded (a third one would be turned away)
    gd "$OUT/server.log" -- --dedicated --transport="$TRANSPORT" --mp-port="$PORT" --start-seats=2; SERVER=$LAST_PID
    sleep 1
    [ "$WATCH_MODE" = 1 ] && W1=(--client1 --mp-port="$PORT" --probe=client --probe-rejoin --probe-linger-s=$LINGER) && W2=(--client2 --mp-port="$PORT" --probe=basic --probe-linger-s=$LINGER)
    gw "$OUT/window1.log" 40 60 -- --transport="$TRANSPORT" --mp-port="$PORT" "${W1[@]}"; A=$LAST_PID
    gw "$OUT/window2.log" 700 60 -- --transport="$TRANSPORT" --mp-port="$PORT" "${W2[@]}"; B=$LAST_PID ;;
  listen)
    [ "$WATCH_MODE" = 1 ] && W1=(--listen-host --probe=watch --probe-linger-s=$LINGER) && W2=(--client1 --probe=client --probe-linger-s=$LINGER)
    gw "$OUT/window1.log" 40 60 -- --transport="$TRANSPORT" --mp-port="$PORT" --start-seats=1 "${W1[@]}"; A=$LAST_PID
    sleep 1.5
    gw "$OUT/window2.log" 700 60 -- --transport="$TRANSPORT" --mp-port="$PORT" "${W2[@]}"; B=$LAST_PID ;;
  rooms)
    gd "$OUT/server.log" -- --room-server --transport="$TRANSPORT" --lobby-port=7700 --countdown-s=3; SERVER=$LAST_PID
    wait_line "$OUT/server.log" "^rooms ready" "$SERVER" 30
    [ "$WATCH_MODE" = 1 ] && W1=(--probe=lobby --probe-lobby=127.0.0.1:7700 --probe-name=Ana --probe-create=Arena --probe-linger-s=$LINGER) \
      && W2=(--probe=lobby --probe-lobby=127.0.0.1:7700 --probe-name=Bea --probe-linger-s=$LINGER)
    gw "$OUT/window1.log" 40 60 -- --transport="$TRANSPORT" "${W1[@]}"; A=$LAST_PID
    [ "$WATCH_MODE" = 1 ] && wait_line "$OUT/window1.log" "^PASS took a seat" "$A" 60
    gw "$OUT/window2.log" 700 60 -- --transport="$TRANSPORT" "${W2[@]}"; B=$LAST_PID ;;
  *) echo "unknown mode $MODE (dedicated | listen | rooms)"; exit 2 ;;
esac
echo "Windows are up. Close them to finish."
wait "$A" 2>/dev/null; wait "$B" 2>/dev/null
grep -hE "^(PROBE|FAIL)" "$OUT"/window*.log 2>/dev/null
