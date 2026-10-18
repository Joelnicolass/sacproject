#!/usr/bin/env bash
# RFC-034 034g (F184): reconnection, end to end, headless, with the real room server and one real dedicated process.
# 5 Godot processes: 1 room server (--room-server) + 3 lobby clients + the dedicated match that the server launches by itself.
#   a (Ana, creates the room): (1) drops the lobby and resumes it with the same session and seat, by hand and by auto_resume;
#      (2) plays; while c tries her ticket she stays connected; (3) leaves the dedicated and comes back with the same ticket: same slot.
#   b (Beto, joins the room): sits in the dedicated after A is back (so the intruder meets A alone: with both seats connected
#      the ENet host, sized for the players, does not take a third connection), leaves for good, waits past rejoin_grace_s: turned away.
#   c (Carlos, the intruder): joins A's dedicated with A's ticket while A is connected: rejected, A keeps her slot.
# Then it checks the logs: the dedicated kept the wizard of the slot that left (same place when it came back), admitted each seat
# once and A's slot twice only through the return, and B's late return found the match over (abandon, winner 1).
# The clients do not load the world (--no-flow): the dedicated simulates the real match (wizards spawn on world_ready).
# Closes by itself: every client has internal timeouts (150 s); this script kills the server, the clients and the dedicated (by pid
# and descendants, no pkill) at LIMIT_S (180 s), or if the total RSS passes RSS_LIMIT_MB.
# Needs `--import` once first (new class_names). TRANSPORT=ws uses WebSocket over TCP for the lobby and the dedicated.
# Uses port 7708 (lobby) and 7800-7803 (matches); files go in a temp folder. Prints the checks and E2E REJOIN PASS / FAIL (exit 0 / 1).
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
LIMIT_S="${PROBE_LIMIT_S:-180}"
TRANSPORT="${TRANSPORT:-enet}"
RSS_LIMIT_MB="${E2E_RSS_LIMIT_MB:-8192}"
LOBBY_PORT="${E2E_LOBBY_PORT:-7708}"
REJOIN_GRACE_S="${E2E_REJOIN_GRACE_S:-8}"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/room_rejoin_034g.XXXXXX")"
MATCHES="$OUT/matches"
SHARED="$OUT/shared"
mkdir -p "$MATCHES" "$SHARED"
export HEADLESS_SLOTS="${HEADLESS_SLOTS:-4}"
export GODOT_MAX="${GODOT_MAX:-8}"
START_S=$SECONDS
EXIT_WAIT_S=10

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
kill_all() { # the clients' pids live in a file so the background watchers (subshells) see them too
  local p
  for p in $(cat "$OUT/clients.pids" 2>/dev/null) $SERVER; do [ -n "$p" ] && kill_tree "$p"; done
  kill_stray
}
trap 'kill_all; kill $WATCH $MONITOR 2>/dev/null' EXIT

# --- room server ---------------------------------------------------------------------------------------------------
bash "$ROOT/agent/harness/godot_run.sh" "$GODOT" --headless --path "$ROOT" res://scenes/net/room_server.tscn -- \
  --room-server --transport="$TRANSPORT" --lobby-config=res://data/net/lobby_config_local.tres --lobby-port="$LOBBY_PORT" --max-matches=1 \
  --ticket-ttl-s=60 --idle-no-players-s=30 --resume-grace-s=120 --rejoin-grace-s="$REJOIN_GRACE_S" --result-quit-delay-s=3 \
  --matches-root="$MATCHES" --match-args=--no-load-hold > "$OUT/server.log" 2>&1 &
SERVER=$!

( # external timeout
  sleep "$LIMIT_S"
  if kill -0 "$SERVER" 2>/dev/null; then
    echo "E2E REJOIN FAIL: external timeout ${LIMIT_S}s" > "$OUT/timeout.flag"
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
      echo "E2E REJOIN FAIL: RSS $((tot / 1024)) MB over the limit ($RSS_LIMIT_MB MB)" > "$OUT/timeout.flag"
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

if [ "$READY" = 1 ]; then
  CLIENT_PIDS=""
  client() { # role, name, then the client flags
    local role="$1" name="$2"; shift 2
    bash "$ROOT/agent/harness/godot_run.sh" "$GODOT" --headless --path "$ROOT" res://debug/net/room_rejoin_client.tscn -- \
      --no-flow --transport="$TRANSPORT" --lobby="127.0.0.1:$LOBBY_PORT" --e2e-lobby-port="$LOBBY_PORT" --e2e-dir="$SHARED" \
      --e2e-role="$role" --e2e-name="$name" "$@" > "$OUT/$role.log" 2>&1 &
    CLIENT_PIDS="$CLIENT_PIDS $!"
    echo "$!" >> "$OUT/clients.pids"
  }
  client a Ana   --e2e-room=SalaR --e2e-peer=Beto --e2e-wizard=cwa0 --e2e-model=jnwr --e2e-god=james
  client b Beto  --e2e-room=SalaR --e2e-peer=Ana  --e2e-wizard=cwa1 --e2e-model=serx --e2e-god=pyro --e2e-leave-wait-s=$((REJOIN_GRACE_S + 1)).5
  client c Carlos
  for p in $CLIENT_PIDS; do wait "$p"; done
  for _ in $(seq 1 40); do
    left=$(ps -axo args= | awk -v m="match-ticket-file=$MATCHES" '$1 ~ /\/Godot$/ && index($0, m)' | wc -l | tr -d ' ')
    dirs=$(find "$MATCHES" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    [ "$left" = 0 ] && [ "$dirs" = 0 ] && break
    sleep 0.5
  done
fi

# --- verdict -------------------------------------------------------------------------------------------------------
echo "--- server ---"; grep -E "^(salas|partida|sala |SCRIPT ERROR|ERROR|dedicated listo|semilla)" "$OUT/server.log" | head -n 60
for n in a b c; do
  echo "--- $n ---"; grep -E "^(PASS|FAIL|E2E|SCRIPT ERROR|ERROR)" "$OUT/$n.log" 2>/dev/null | tail -n 40
done
echo "--- verdict ---"
python3 - "$OUT" "$MATCHES" "$LOBBY_PORT" <<'PYEOF'
import json, os, re, sys
out, matches, lobby_port = sys.argv[1], sys.argv[2], int(sys.argv[3])
fails = []
def check(ok, what):
    print(("PASS " if ok else "FAIL ") + what)
    if not ok:
        fails.append(what)
def read(name):
    try:
        return open(os.path.join(out, name), errors="replace").read().splitlines()
    except OSError:
        return []
server = read("server.log")
check(any(l.startswith("salas listo puerto %d" % lobby_port) for l in server), "the room server announced its port")
launch = None
for l in server:
    m = re.match(r'^partida (\S+) sala "([^"]+)" puerto (\d+) semilla (\d+)$', l)
    if m:
        launch = {"id": m.group(1), "port": int(m.group(3))}
check(launch is not None, "the server launched the match")
if launch:
    pre = "partida %s: " % launch["id"]
    mine = [l for l in server if l.startswith(pre)]
    check(mine.count(pre + "slot 1 adentro") == 1 and mine.count(pre + "slot 2 adentro") == 1, "each slot was admitted once for the first time")
    check(not any("slot 3" in l for l in mine), "no third slot (the intruder never got one)")
    check(mine.count(pre + "slot 1 se fue") == 1, "slot 1 left the dedicated once")
    check(mine.count(pre + "slot 1 volvió") == 1, "slot 1 came back to the dedicated once (same ticket, same slot)")
    check(mine.count(pre + "slot 2 se fue") == 1 and mine.count(pre + "slot 2 volvió") == 0, "slot 2 left and did not come back")
    def state(slot, when):
        for l in mine:
            m = re.match(r"^" + re.escape(pre) + r"slot %d (.*) \(%s\)$" % (slot, when), l)
            if m:
                return m.group(1)
        return None
    gone, back = state(1, "al irse"), state(1, "al volver")
    check(gone is not None and back is not None, "the dedicated logged the state of slot 1 at the drop and at the return")
    if gone and back:
        check(gone.startswith("mago en "), "slot 1 had a wizard in the world (%s)" % gone)
        check(gone == back, "the wizard and the creatures of slot 1 are the same at the return (%s | %s)" % (gone, back))
    results = [json.loads(l[len(pre + "resultado "):]) for l in mine if l.startswith(pre + "resultado ")]
    check(len(results) == 1, "the dedicated reported exactly one result")
    if results:
        r = results[0]
        check(r.get("reason") == "abandon" and int(r.get("winner_slot", -1)) == 1 and [int(x) for x in r.get("defeated_slots", [])] == [2],
              "result abandon, winner slot 1, slot 2 defeated (got %s, %s)" % (r.get("reason"), r.get("winner_slot")))
for who, name in (("a", "Ana"), ("b", "Beto"), ("c", "Carlos")):
    log = read(who + ".log")
    check(any(l == "E2E REJOIN %s PASS" % name for l in log), "%s passed all its checks" % name)
    check(not any("SCRIPT ERROR" in l for l in log), "no SCRIPT ERROR in %s's log" % name)
check(any(l.startswith("E2E_BACK Ana slot=1") for l in read("a.log")), "Ana came back to slot 1")
check(any(l == "E2E_LEFT Beto" for l in read("b.log")), "Beto left the dedicated for good")
check(not any("SCRIPT ERROR" in l for l in server), "no SCRIPT ERROR in the server log")
try:
    registry = json.load(open(os.path.join(matches, "registry.json")))
    check(registry.get("matches", None) == {}, "registry.json has no match")
except (OSError, ValueError):
    check(False, "registry.json is readable")
left = [e for e in os.listdir(matches) if e != "registry.json"]
check(left == [], "no match folder or file left (%s)" % left)
sys.exit(1 if fails else 0)
PYEOF
VERDICT=$?
for _ in $(seq 1 $((EXIT_WAIT_S * 2))); do
  STRAY=$(ps -axo args= | awk -v m="match-ticket-file=$MATCHES" '$1 ~ /\/Godot$/ && index($0, m)' | wc -l | tr -d ' ')
  [ "$STRAY" = 0 ] && break
  sleep 0.5
done
if [ "$STRAY" = 0 ]; then echo "PASS no dedicated process left"; else echo "FAIL $STRAY dedicated process still alive after ${EXIT_WAIT_S}s"; VERDICT=1; fi
kill_all
sleep 1
STRAY=$(ps -axo args= | awk -v m="$OUT" 'index($0, m)' | grep -c Godot)
if [ "$STRAY" != 0 ]; then echo "FAIL $STRAY Godot process of this run still alive after the kill"; VERDICT=1; fi
read -r RSS_KB PROCS < "$OUT/rss.max" 2>/dev/null
echo "RSS max total: $(( ${RSS_KB:-0} / 1024 )) MB, at most ${PROCS:-0} Godot processes at once, $((SECONDS - START_S)) s"
if [ -s "$OUT/timeout.flag" ]; then cat "$OUT/timeout.flag"; VERDICT=1; fi
[ "$READY" = 1 ] || { echo "E2E REJOIN FAIL: the room server did not announce its port"; VERDICT=1; }
kill $WATCH $MONITOR 2>/dev/null
if [ "$VERDICT" = 0 ]; then echo "E2E REJOIN PASS"; rm -rf "$OUT"; else echo "E2E REJOIN FAIL (logs in $OUT)"; fi
exit "$VERDICT"
