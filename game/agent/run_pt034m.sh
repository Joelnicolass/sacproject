#!/usr/bin/env bash
# RFC-034 034m playtest: «Servidor local», with ONE window.
#   The windowed host is driven by an AgentKit flow (agent/flows/pt034m_host.json): menu -> «Servidor local» -> «Crear servidor
#   local» -> «Crear» -> the screen shows address, port, transport and code -> «Entrar a la partida» -> High Noon -> «Victoria».
#   When the log of the window prints `servidor local listo … puerto=P … codigo=C`, this script starts the rival: a headless client
#   (debug/net/local_server_e2e.tscn --e2e-role=rival, tells the dedicated its world is "loaded") that joins 127.0.0.1:P with the code.
#   The match ends by a forced defeat of slot 2 (the rival) 900 ticks after both loaded, so the host wins.
# Captures: agent/out/pt034m/. Closes by itself: the flow and the rival have internal timeouts; this script kills the window, the
# rival and the dedicated (by pid and descendants, no pkill) at LIMIT_S (240 s), or if the total RSS passes RSS_LIMIT_MB.
# Needs `--import` once first (new class_names). Uses UDP (TCP with TRANSPORT=ws) port 7717. Prints PT034M PASS / PT034M FAIL.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
LIMIT_S="${PROBE_LIMIT_S:-240}"
TRANSPORT="${TRANSPORT:-enet}"
RSS_LIMIT_MB="${PT_RSS_LIMIT_MB:-6144}"
LOCAL_PORT="${PT_LOCAL_PORT:-7717}"
FORCE_TICKS="${PT_FORCE_TICKS:-900}"
EXIT_WAIT_S=15
SHOTS="$ROOT/agent/out/pt034m"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/local_pt034m.XXXXXX")"
MATCHES="$OUT/matches"
mkdir -p "$MATCHES" "$SHOTS"
rm -f "$SHOTS"/*.png
export HEADLESS_SLOTS="${HEADLESS_SLOTS:-1}"
export GODOT_MAX="${GODOT_MAX:-3}"
START_S=$SECONDS

descendants() { # pid -> pid and all its descendants
  local p="$1" c
  echo "$p"
  for c in $(pgrep -P "$p" 2>/dev/null); do descendants "$c"; done
}
kill_tree() { local p; for p in $(descendants "$1" | sort -rn); do kill "$p" 2>/dev/null; done; }
kill_stray() { # the dedicated of this run, if it lost its parent
  local p
  for p in $(ps -axo pid=,args= | awk -v m="match-ticket-file=$MATCHES" '$2 ~ /\/Godot$/ && index($0, m) {print $1}'); do kill "$p" 2>/dev/null; done
}
kill_all() {
  local p
  for p in $RIVAL $WINDOW; do [ -n "$p" ] && kill_tree "$p"; done
  kill_stray
}
RIVAL=""; WINDOW=""
trap 'kill_all; kill $WATCH $MONITOR 2>/dev/null' EXIT

# --- the windowed host ------------------------------------------------------------------------------------------------
bash "$ROOT/agent/harness/godot_run.sh" "$GODOT" --max-fps 60 --path "$ROOT" --resolution 1280x720 -- \
  --agent=flow --flow="$ROOT/agent/flows/pt034m_host.json" --out=res://agent/out/pt034m --transport="$TRANSPORT" \
  --matches-root="$MATCHES" --match-port-min="$LOCAL_PORT" --match-port-max="$LOCAL_PORT" \
  --match-args=--force-defeat-slot=2,--force-defeat-after-ticks="$FORCE_TICKS" --fail-on-error > "$OUT/window.log" 2>&1 &
WINDOW=$!

( # external timeout
  sleep "$LIMIT_S"
  if kill -0 "$WINDOW" 2>/dev/null; then
    echo "PT034M FAIL: external timeout ${LIMIT_S}s" > "$OUT/timeout.flag"
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
      echo "PT034M FAIL: RSS $((tot / 1024)) MB over the limit ($RSS_LIMIT_MB MB)" > "$OUT/timeout.flag"
      kill_all
    fi
    sleep 1
  done
) &
MONITOR=$!

# --- wait for the line the host prints when its dedicated listens, then start the rival with what that line says -------
LINE=""
for _ in $(seq 1 240); do
  LINE=$(grep -m1 "^servidor local listo" "$OUT/window.log" 2>/dev/null)
  [ -n "$LINE" ] && break
  kill -0 "$WINDOW" 2>/dev/null || break
  sleep 0.5
done
PORT=$(echo "$LINE" | sed -n 's/.*puerto=\([0-9]*\).*/\1/p')
CODE=$(echo "$LINE" | sed -n 's/.*codigo=\([0-9a-f]*\).*/\1/p')
if [ -n "$PORT" ] && [ -n "$CODE" ]; then
  bash "$ROOT/agent/harness/godot_run.sh" "$GODOT" --headless --path "$ROOT" res://debug/net/local_server_e2e.tscn -- \
    --no-flow --transport="$TRANSPORT" --e2e-role=rival --e2e-address="127.0.0.1:$PORT" --e2e-code="$CODE" --e2e-ready \
    --e2e-expect-winner=1 > "$OUT/rival.log" 2>&1 &
  RIVAL=$!
  wait "$WINDOW"; WINDOW_EXIT=$?
  wait "$RIVAL"; RIVAL_EXIT=$?
  # leaving the match closes the local server: wait until no dedicated and no match folder is left
  for _ in $(seq 1 $((EXIT_WAIT_S * 2))); do
    left=$(ps -axo args= | awk -v m="match-ticket-file=$MATCHES" '$1 ~ /\/Godot$/ && index($0, m)' | wc -l | tr -d ' ')
    dirs=$(find "$MATCHES" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    [ "$left" = 0 ] && [ "$dirs" = 0 ] && break
    sleep 0.5
  done
fi

# --- verdict -----------------------------------------------------------------------------------------------------------
echo "--- window ---"; grep -E "^(servidor local|AGENT_OK|AGENT_FAIL|AGENT_STEP_ERROR|AGENT_SHOT|SCRIPT ERROR|ERROR)" "$OUT/window.log" 2>/dev/null | tail -n 30
echo "--- rival ---"; grep -E "^(PASS|FAIL|E2E|SCRIPT ERROR|ERROR)" "$OUT/rival.log" 2>/dev/null | tail -n 30
echo "--- verdict ---"
FAILS=0
check() { # ok(0/1) what
  if [ "$1" = 0 ]; then echo "PASS $2"; else echo "FAIL $2"; FAILS=$((FAILS + 1)); fi
}
check "$([ -n "$PORT" ] && [ -n "$CODE" ]; echo $?)" "the window host announced address, port and code"
check "$(grep -q '^AGENT_OK' "$OUT/window.log" 2>/dev/null; echo $?)" "the flow of the window host ended AGENT_OK"
check "$(grep -q '^AGENT_FAIL\|^AGENT_STEP_ERROR' "$OUT/window.log" 2>/dev/null; [ $? = 0 ] && echo 1 || echo 0)" "the flow had no AGENT_FAIL / AGENT_STEP_ERROR"
SHOT_COUNT=$(ls "$SHOTS"/*.png 2>/dev/null | wc -l | tr -d ' ')
check "$([ "$SHOT_COUNT" -ge 6 ]; echo $?)" "6 captures in agent/out/pt034m/ (found $SHOT_COUNT)"
check "$(grep -q '^E2E LOCAL rival PASS' "$OUT/rival.log" 2>/dev/null; echo $?)" "the headless rival joined with the code (slot 2) and got the result"
check "$(grep -q 'SCRIPT ERROR' "$OUT/window.log" "$OUT/rival.log" 2>/dev/null; [ $? = 0 ] && echo 1 || echo 0)" "no SCRIPT ERROR in any log"
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
if [ "$FAILS" = 0 ]; then echo "PT034M PASS"; rm -rf "$OUT"; exit 0; fi
echo "PT034M FAIL (logs in $OUT)"
exit 1
