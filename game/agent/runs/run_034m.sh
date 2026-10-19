#!/usr/bin/env bash
# RFC-034 034m: «Servidor local», end to end, headless. No room server: the host process launches its own dedicated with the
# same code as the VPS (MpMatchLauncher) and joins it; the rival joins with address:port and the code; a third player without
# credential is turned away. 4 Godot processes: host (+ its dedicated, child of the host), rival, intruder.
#   host    (debug/net/local_server_e2e.tscn --e2e-role=host)     starts LocalServerHost, joins slot 1, waits for the result
#   rival   (--e2e-role=rival)    reads address:port + code (from the host's file), joins slot 2
#   intruder(--e2e-role=intruder) no credential / made-up code / the rival's code after he sat: all rejected
# The match ends by a forced defeat of slot 2 (test hook of the dedicated, passed with --match-args; when the intruder is done) -> winner 1, "result".
# Checks: the host launched the local dedicated, the rival got slot 2 with the code, the intruder got nothing, the match ended with
# a result in the three processes, the local server closed itself, and no process or match folder is left.
# F350: the 4 processes run inside ONE group reservation of the Godot queue (agent/harness/godot_group.sh), started directly; the waits are on log
# lines; the match ends when the INTRUDER is done (it writes a file and the test dedicated defeats slot 2 on it: `--force-defeat-when-file`), not
# after a tick count. An ENet attempt on a full dedicated gets no answer, so each one waits E2E_REJECT_S (3 s). Closes by itself: nodes with internal
# timeouts (150 s); this script kills the host, the clients and the dedicated (by pid and descendants, no pkill) at LIMIT_S, or if the total RSS passes the cap.
# Needs `--import` once first (new class_names). Uses UDP (or TCP with TRANSPORT=ws) port 7716 (LOCAL_PORT). Files go in a temp folder.
# Prints the checks and E2E LOCAL PASS / E2E LOCAL FAIL (exit 0 / 1).
. "$(dirname "$0")/../harness/net_e2e.sh"
net_group 4 "$@"
TAG="E2E LOCAL"
LIMIT_S="${PROBE_LIMIT_S:-120}"
PROC_MAX=5
TRANSPORT="${TRANSPORT:-enet}" # enet (UDP, default) or ws (WebSocket over TCP): TRANSPORT=ws bash agent/runs/run_034m.sh
LOCAL_PORT="${E2E_LOCAL_PORT:-7716}"
REJECT_S="${E2E_REJECT_S:-3}"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/local_e2e_034m.XXXXXX")"
MATCHES="$OUT/matches"
INFO="$OUT/info"
mkdir -p "$MATCHES" "$INFO"
START_S=$SECONDS
EXIT_WAIT_S=10 # grace for the dedicated to exit after the result

kill_stray() { # the dedicated of this run, if it lost its parent
  local p
  for p in $(ps -axo pid=,args= | awk -v m="match-ticket-file=$MATCHES" '$2 ~ /\/Godot$/ && index($0, m) {print $1}'); do kill "$p" 2>/dev/null; done
}
kill_all() { kill_pids; kill_stray; }
HOST=""; RIVAL=""; INTRUDER=""
trap 'kill_all; net_stop' EXIT
net_guard

client() { # role, then extra flags
  local role="$1"; shift
  gd "$OUT/$role.log" res://debug/net/local_server_e2e.tscn -- \
    --no-flow --transport="$TRANSPORT" --e2e-role="$role" --e2e-dir="$INFO" --e2e-reject-s="$REJECT_S" "$@"
}

client host --matches-root="$MATCHES" --match-port-min="$LOCAL_PORT" --match-port-max="$LOCAL_PORT" \
  --result-quit-delay-s=1 --poll-s=0.1 --heartbeat-s=0.5 --parent-check-s=0.5 \
  --match-args=--force-defeat-slot=2,--force-defeat-when-file="$INFO/intruder_done.flag",--no-load-hold \
  --e2e-expect-winner=1 --e2e-expect-reason=result
HOST=$LAST_PID

READY=0
wait_line "$OUT/host.log" "^servidor local listo" "$HOST" 30 && READY=1

if [ "$READY" = 1 ]; then
  client rival --e2e-bad-first --e2e-wizard=cwa1 --e2e-god=pyro; RIVAL=$LAST_PID
  client intruder; INTRUDER=$LAST_PID
  wait "$HOST"; HOST_EXIT=$?
  wait "$RIVAL"; RIVAL_EXIT=$?
  wait "$INTRUDER"; INTRUDER_EXIT=$?
  # the local server closes the match by itself: wait until no dedicated and no match folder is left
  wait_gone "match-ticket-file=$MATCHES" "$EXIT_WAIT_S"
  for _ in $(seq 1 100); do [ -z "$(find "$MATCHES" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)" ] && break; sleep 0.1; done
fi

# --- verdict -------------------------------------------------------------------------------------------------------
for n in host rival intruder; do
  echo "--- $n ---"; grep -E "^(PASS|FAIL|E2E|SCRIPT ERROR|ERROR|servidor local)" "$OUT/$n.log" 2>/dev/null | tail -n 40
done
echo "--- verdict ---"
FAILS=0
check() { # ok(0/1) what
  if [ "$1" = 0 ]; then echo "PASS $2"; else echo "FAIL $2"; FAILS=$((FAILS + 1)); fi
}
has() { grep -q "$2" "$OUT/$1.log" 2>/dev/null; echo $?; }
check "$([ "$READY" = 1 ]; echo $?)" "the host launched the local dedicated and announced address, port and code"
check "$(has host '^E2E LOCAL host PASS')" "the host passed all its checks (slot 1, result, the server closed itself)"
check "$(has rival '^E2E LOCAL rival PASS')" "the rival: invalid pick rejected, then address:port + code + his own pick at slot 2, result with his pick at seat 2"
check "$(has intruder '^E2E LOCAL intruder PASS')" "the third player was rejected: no credential, made-up code, the rival's code"
check "$(has host '^servidor local resultado .*"reason":"result"')" "the local server reported the result of the match"
check "$(grep -q 'SCRIPT ERROR' "$OUT/host.log" "$OUT/rival.log" "$OUT/intruder.log" 2>/dev/null; [ $? = 0 ] && echo 1 || echo 0)" "no SCRIPT ERROR in any log"
STRAY=$(ps -axo args= | awk -v m="match-ticket-file=$MATCHES" '$1 ~ /\/Godot$/ && index($0, m)' | wc -l | tr -d ' ')
check "$([ "$STRAY" = 0 ]; echo $?)" "no dedicated process left ($STRAY)"
DIRS=$(find "$MATCHES" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
check "$([ "$DIRS" = 0 ]; echo $?)" "no match folder left ($DIRS)"
kill_all 2>/dev/null
wait_gone "$OUT" 5
STRAY=$(godots_with "$OUT")
check "$([ "$STRAY" = 0 ]; echo $?)" "no Godot process of this run left after the kill ($STRAY)"
read -r RSS_KB PROCS < "$OUT/rss.max" 2>/dev/null
echo "RSS max total: $(( ${RSS_KB:-0} / 1024 )) MB, at most ${PROCS:-0} Godot processes at once, $((SECONDS - START_S)) s"
if [ -s "$OUT/timeout.flag" ]; then cat "$OUT/timeout.flag"; FAILS=$((FAILS + 1)); fi
net_stop
if [ "$FAILS" = 0 ]; then echo "E2E LOCAL PASS"; rm -rf "$OUT"; exit 0; fi
echo "E2E LOCAL FAIL (logs in $OUT)"
exit 1
