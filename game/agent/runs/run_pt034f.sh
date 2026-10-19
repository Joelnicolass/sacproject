#!/usr/bin/env bash
# RFC-034 034f playtest: the room screens, with ONE window.
#   1 room server (headless) + 1 headless second player (agent/fixtures/pt034f_peer, drives the same lobby client the buttons use,
#   the real room screen reacts) + 1 windowed player driven by an AgentKit flow (agent/flows/pt034f_host.json) + the dedicated that
#   the server launches (4th process, no window).
# The windowed player: menu -> «Salas online» -> connect -> empty list -> create «Duelo» -> room alone -> second player sits ->
# chat line -> wizard and god selector -> ready -> countdown -> High Noon -> result + «Volver a salas» -> room with the result.
# The match ends by a forced defeat of slot 2 (the headless player), so the window player wins ("Ganaste").
# Captures: agent/out/pt034f/. Logs: the temp folder printed at the end on FAIL.
# Closes by itself: internal timeouts in the peer (150 s) and the flow; this script kills the server, the clients and the dedicated
# (by pid and descendants, no pkill) at LIMIT_S (240 s), or if the total RSS passes RSS_LIMIT_MB.
# Needs `--import` once first (new class_names). Uses UDP 7712 (lobby) and 7800-7803 (matches).
# Prints the checks and PT034F PASS / PT034F FAIL (exit 0 / 1).
. "$(dirname "$0")/../harness/env.sh"
GODOT="$GODOT_BIN"
LIMIT_S="${PROBE_LIMIT_S:-240}"
TRANSPORT="${TRANSPORT:-enet}" # enet (UDP, default) or ws (TCP)
RSS_LIMIT_MB="${PT_RSS_LIMIT_MB:-6144}"
LOBBY_PORT="${PT_LOBBY_PORT:-7712}"
COUNTDOWN_S="${PT_COUNTDOWN_S:-4}"             # long enough for the capture of «La partida empieza en…»
RESULT_QUIT_S="${PT_RESULT_QUIT_S:-20}"        # the dedicated stays open this long after the result (banner + button)
FORCE_TICKS="${PT_FORCE_TICKS:-900}"           # ticks after EVERY seat loaded its world when slot 2 is defeated (the match waits for the slow window)
EXIT_WAIT_S=15
SHOTS="$ROOT/agent/out/pt034f"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/room_pt034f.XXXXXX")"
MATCHES="$OUT/matches"
mkdir -p "$MATCHES" "$SHOTS"
rm -f "$SHOTS"/*.png
export HEADLESS_SLOTS="${HEADLESS_SLOTS:-2}"
export GODOT_MAX="${GODOT_MAX:-4}"
START_S=$SECONDS

descendants() { # pid -> pid and all its descendants
  local p="$1" c
  echo "$p"
  for c in $(pgrep -P "$p" 2>/dev/null); do descendants "$c"; done
}
kill_tree() { local p; for p in $(descendants "$1" | sort -rn); do kill "$p" 2>/dev/null; done; }
kill_stray() { # dedicated of this run that lost their parent
  local p
  for p in $(ps -axo pid=,args= | awk -v m="match-ticket-file=$MATCHES" '$2 ~ /\/Godot$/ && index($0, m) {print $1}'); do kill "$p" 2>/dev/null; done
}
kill_all() {
  local p
  for p in $PEER $WINDOW $SERVER; do [ -n "$p" ] && kill_tree "$p"; done
  kill_stray
}
trap 'kill_all; kill $WATCH $MONITOR 2>/dev/null' EXIT

# --- room server ----------------------------------------------------------------------------------------------------
bash "$ROOT/agent/harness/godot_run.sh" "$GODOT" --headless --path "$ROOT" res://scenes/net/room_server.tscn -- \
  --room-server --transport="$TRANSPORT" --lobby-config=res://data/net/lobby_config_local.tres --lobby-port="$LOBBY_PORT" \
  --countdown-s="$COUNTDOWN_S" --result-quit-delay-s="$RESULT_QUIT_S" --idle-no-players-s=30 --resume-grace-s=120 \
  --matches-root="$MATCHES" \
  --match-args=--force-defeat-slot=2,--force-defeat-after-ticks="$FORCE_TICKS" > "$OUT/server.log" 2>&1 &
SERVER=$!

( # external timeout
  sleep "$LIMIT_S"
  if kill -0 "$SERVER" 2>/dev/null; then
    echo "PT034F FAIL: external timeout ${LIMIT_S}s" > "$OUT/timeout.flag"
    kill_all
  fi
) &
WATCH=$!

( # total RSS of the Godot processes of this project, and a brake for the machine
  max=0; maxn=0
  while :; do
    read -r tot n < <(ps -axo rss=,args= | awk -v root="$ROOT" '$2 ~ /\/Godot$/ && index($0, root) {s += $1; c++} END {print s + 0, c + 0}')
    [ "$tot" -gt "$max" ] && max=$tot
    [ "$n" -gt "$maxn" ] && maxn=$n
    echo "$max $maxn" > "$OUT/rss.max"
    if [ $((tot / 1024)) -gt "$RSS_LIMIT_MB" ]; then
      echo "PT034F FAIL: RSS $((tot / 1024)) MB over the limit ($RSS_LIMIT_MB MB)" > "$OUT/timeout.flag"
      kill_all
    fi
    sleep 1
  done
) &
MONITOR=$!

READY=0
for _ in $(seq 1 240); do
  if grep -q "^salas listo puerto" "$OUT/server.log" 2>/dev/null; then READY=1; break; fi
  kill -0 "$SERVER" 2>/dev/null || break
  sleep 0.5
done

PEER=""; WINDOW=""
if [ "$READY" = 1 ]; then
  # --- the windowed player: the AgentKit flow (same flags as agent_kit/cli.sh flow) ---------------------------------
  bash "$ROOT/agent/harness/godot_run.sh" "$GODOT" --max-fps 60 --path "$ROOT" --resolution 1280x720 -- \
    --agent=flow --flow="$ROOT/agent/flows/pt034f_host.json" --out=res://agent/out/pt034f \
    --transport="$TRANSPORT" --lobby="127.0.0.1:$LOBBY_PORT" --fail-on-error > "$OUT/window.log" 2>&1 &
  WINDOW=$!
  # --- the headless second player ---------------------------------------------------------------------------------
  bash "$ROOT/agent/harness/godot_run.sh" "$GODOT" --headless --path "$ROOT" res://agent/fixtures/pt034f_peer.tscn -- \
    --transport="$TRANSPORT" --lobby="127.0.0.1:$LOBBY_PORT" --pt-name=Rival --pt-room=Duelo --pt-wizard=cwa1 --pt-god=pyro \
    > "$OUT/peer.log" 2>&1 &
  PEER=$!
  wait "$WINDOW"; WINDOW_EXIT=$?
  wait "$PEER"; PEER_EXIT=$?
  # the server closes the match by itself: wait until no dedicated and no match folder is left
  for _ in $(seq 1 $((EXIT_WAIT_S * 2))); do
    left=$(ps -axo args= | awk -v m="match-ticket-file=$MATCHES" '$1 ~ /\/Godot$/ && index($0, m)' | wc -l | tr -d ' ')
    dirs=$(find "$MATCHES" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    [ "$left" = 0 ] && [ "$dirs" = 0 ] && break
    sleep 0.5
  done
fi

# --- verdict -----------------------------------------------------------------------------------------------------------
FAILS=0
check() { # ok(0/1) what
  if [ "$1" = 0 ]; then echo "PASS $2"; else echo "FAIL $2"; FAILS=$((FAILS + 1)); fi
}
echo "--- server ---"; grep -E "^(salas|partida|sala |SCRIPT ERROR|ERROR|dedicated listo|semilla)" "$OUT/server.log" | head -n 40
echo "--- peer ---"; grep -E "^(PASS|FAIL|PT034F|SCRIPT ERROR|ERROR)" "$OUT/peer.log" 2>/dev/null | tail -n 30
echo "--- window ---"; grep -E "^(AGENT_OK|AGENT_FAIL|AGENT_STEP_ERROR|AGENT_SHOT|SCRIPT ERROR|ERROR)" "$OUT/window.log" 2>/dev/null | tail -n 30
echo "--- verdict ---"
check "$([ "$READY" = 1 ]; echo $?)" "the room server announced its port"
check "$(grep -q '^AGENT_OK' "$OUT/window.log" 2>/dev/null; echo $?)" "the flow of the window player ended AGENT_OK"
check "$(grep -q '^AGENT_FAIL\|^AGENT_STEP_ERROR' "$OUT/window.log" 2>/dev/null; [ $? = 0 ] && echo 1 || echo 0)" "the flow had no AGENT_FAIL / AGENT_STEP_ERROR"
SHOT_COUNT=$(ls "$SHOTS"/*.png 2>/dev/null | wc -l | tr -d ' ')
check "$([ "$SHOT_COUNT" -ge 11 ]; echo $?)" "11 captures in agent/out/pt034f/ (found $SHOT_COUNT)"
check "$(grep -q '^PT034F PEER Rival PASS' "$OUT/peer.log" 2>/dev/null; echo $?)" "the headless player passed all its checks"
check "$(grep -q '^PT034F_PEER in_match' "$OUT/peer.log" 2>/dev/null; echo $?)" "the headless player played the match through the room screen"
check "$(grep -q '^sala "Duelo" resultado .*"winner_slot":1' "$OUT/server.log" 2>/dev/null; echo $?)" "the room got the result: winner slot 1"
check "$(grep -q 'SCRIPT ERROR' "$OUT/server.log" "$OUT/peer.log" "$OUT/window.log" 2>/dev/null; [ $? = 0 ] && echo 1 || echo 0)" "no SCRIPT ERROR in any log"
STRAY=$(ps -axo args= | awk -v m="match-ticket-file=$MATCHES" '$1 ~ /\/Godot$/ && index($0, m)' | wc -l | tr -d ' ')
check "$([ "$STRAY" = 0 ]; echo $?)" "no dedicated process left ($STRAY)"
kill_all
sleep 1
STRAY=$(ps -axo args= | awk -v m="$OUT" 'index($0, m)' | grep -c Godot)
check "$([ "$STRAY" = 0 ]; echo $?)" "no Godot process of this run left after the kill ($STRAY)"
read -r RSS_KB PROCS < "$OUT/rss.max" 2>/dev/null
echo "RSS max total: $(( ${RSS_KB:-0} / 1024 )) MB, at most ${PROCS:-0} Godot processes at once, $((SECONDS - START_S)) s"
if [ -s "$OUT/timeout.flag" ]; then cat "$OUT/timeout.flag"; FAILS=$((FAILS + 1)); fi
kill $WATCH $MONITOR 2>/dev/null
if [ "$FAILS" = 0 ]; then echo "PT034F PASS"; rm -rf "$OUT"; exit 0; fi
echo "PT034F FAIL (logs in $OUT)"
exit 1
