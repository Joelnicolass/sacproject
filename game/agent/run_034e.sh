#!/usr/bin/env bash
# RFC-034 034e: end to end, headless, with the real room server and TWO real dedicated processes in parallel.
# 7 Godot processes: 1 room server (--room-server, --max-matches=2) + 4 lobby clients + 2 dedicated matches that the
# server launches by itself. Two 1v1 rooms at once:
#   SalaA: Ana (creator, joins the dedicated 2 s late) + Aldo; the match ends by a forced defeat of slot 2 -> winner 1, "result".
#   SalaB: Beto (creator, leaves the dedicated 1 s after joining) + Bruno; the match ends by abandon -> winner 2, "abandon".
# Also: Aldo tries his ticket on SalaB's dedicated and Bruno his on SalaA's (rejected), and each one a made-up ticket on his own.
# Then it checks the logs: each dedicated admitted only the tickets of its room, picks/options/seed are those of the
# ticket, each match ended with its own result and that result reached only its room, and nothing is left behind.
# The clients do not load the world (--no-flow): the dedicated simulates the real match.
# Closes by itself: nodes under root with internal timeouts (150 s); this script kills the server, the clients and the
# dedicated (by pid and descendants, no pkill) at LIMIT_S (180 s), or if the total RSS passes RSS_LIMIT_MB.
# Prints the checks, the max total RSS of the Godot processes of this project, and E2E PASS / E2E FAIL (exit 0 / 1).
# Needs `--import` once first (new class_names). Uses UDP 7706 (lobby) and 7800-7803 (matches); files go in a temp folder.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
LIMIT_S="${PROBE_LIMIT_S:-180}"
TRANSPORT="${TRANSPORT:-enet}" # enet (UDP, default) or ws (WebSocket over TCP, lobby and dedicated): TRANSPORT=ws bash agent/run_034e.sh
RSS_LIMIT_MB="${E2E_RSS_LIMIT_MB:-8192}"
LOBBY_PORT="${E2E_LOBBY_PORT:-7706}"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/room_e2e_034e.XXXXXX")"
MATCHES="$OUT/matches"
PORTS="$OUT/ports"
mkdir -p "$MATCHES" "$PORTS"
# Five processes go through the queue (server + 4 clients); the two dedicated are children of the server and skip it.
export HEADLESS_SLOTS="${HEADLESS_SLOTS:-5}"
export GODOT_MAX="${GODOT_MAX:-9}"
START_S=$SECONDS
EXIT_WAIT_S=10 # grace for the dedicated to exit after the last result

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
CLIENT_PIDS=""
kill_all() { # the clients' pids live in a file so the background watchers (subshells) see them too
  local p
  for p in $(cat "$OUT/clients.pids" 2>/dev/null) $SERVER; do [ -n "$p" ] && kill_tree "$p"; done
  kill_stray
}
trap 'kill_all; kill $WATCH $MONITOR 2>/dev/null' EXIT

# --- room server ---------------------------------------------------------------------------------------------------
bash "$ROOT/agent/harness/godot_run.sh" "$GODOT" --headless --path "$ROOT" res://scenes/net/room_server.tscn -- \
  --room-server --transport="$TRANSPORT" --lobby-config=res://data/net/lobby_config_local.tres --lobby-port="$LOBBY_PORT" --max-matches=2 \
  --ticket-ttl-s=60 --idle-no-players-s=30 --resume-grace-s=120 --matches-root="$MATCHES" \
  --match-args=--force-defeat-slot=2,--force-defeat-after-ticks=1200,--no-load-hold > "$OUT/server.log" 2>&1 &
SERVER=$!

( # external timeout
  sleep "$LIMIT_S"
  if kill -0 "$SERVER" 2>/dev/null; then
    echo "E2E FAIL: external timeout ${LIMIT_S}s" > "$OUT/timeout.flag"
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
      echo "E2E FAIL: RSS $((tot / 1024)) MB over the limit ($RSS_LIMIT_MB MB)" > "$OUT/timeout.flag"
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

CODE=1
if [ "$READY" = 1 ]; then
  client() { # name, then the client flags
    local name="$1"; shift
    bash "$ROOT/agent/harness/godot_run.sh" "$GODOT" --headless --path "$ROOT" res://debug/net/room_e2e_client.tscn -- \
      --no-flow --transport="$TRANSPORT" --lobby-port="$LOBBY_PORT" --e2e-dir="$PORTS" --e2e-name="$name" "$@" > "$OUT/$name.log" 2>&1 &
    CLIENT_PIDS="$CLIENT_PIDS $!"
    echo "$!" >> "$OUT/clients.pids"
  }
  client Ana   --e2e-room=SalaA --e2e-peer=Aldo --e2e-create --e2e-level=2 --e2e-room-tag=A \
    --e2e-wizard=cwa0 --e2e-model=jnwr --e2e-god=james --e2e-join-delay-s=2 --e2e-expect-winner=1 --e2e-expect-reason=result
  client Aldo  --e2e-room=SalaA --e2e-peer=Ana --e2e-room-tag=A --e2e-cross-tag=B \
    --e2e-wizard=cwa1 --e2e-model=serx --e2e-god=pyro --e2e-expect-winner=1 --e2e-expect-reason=result
  client Beto  --e2e-room=SalaB --e2e-peer=Bruno --e2e-create --e2e-level=3 --e2e-room-tag=B \
    --e2e-wizard=cwa2 --e2e-model=mrdk --e2e-god=stratos --e2e-leave-after-s=1 --e2e-expect-winner=2 --e2e-expect-reason=abandon
  client Bruno --e2e-room=SalaB --e2e-peer=Beto --e2e-room-tag=B --e2e-cross-tag=A \
    --e2e-wizard=cwd0 --e2e-model=xwiz --e2e-god=charnel --e2e-expect-winner=2 --e2e-expect-reason=abandon
  for p in $CLIENT_PIDS; do wait "$p"; done
  # the server closes the two matches by itself: wait until no dedicated and no match folder is left
  for _ in $(seq 1 40); do
    left=$(ps -axo args= | awk -v m="match-ticket-file=$MATCHES" '$1 ~ /\/Godot$/ && index($0, m)' | wc -l | tr -d ' ')
    dirs=$(find "$MATCHES" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    [ "$left" = 0 ] && [ "$dirs" = 0 ] && break
    sleep 0.5
  done
fi

# --- verdict -------------------------------------------------------------------------------------------------------
echo "--- server ---"; grep -E "^(salas|partida|sala |SCRIPT ERROR|ERROR|dedicated listo|semilla)" "$OUT/server.log" | head -n 80
for n in Ana Aldo Beto Bruno; do
  echo "--- $n ---"; grep -E "^(PASS|FAIL|E2E|SCRIPT ERROR|ERROR)" "$OUT/$n.log" 2>/dev/null | tail -n 30
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
launch = {}
for l in server:
    m = re.match(r'^partida (\S+) sala "([^"]+)" puerto (\d+) semilla (\d+)$', l)
    if m:
        launch[m.group(2)] = {"id": m.group(1), "port": int(m.group(3)), "seed": int(m.group(4))}
check(sorted(launch) == ["SalaA", "SalaB"], "the server launched exactly two matches, one per room")
EXPECT = {
    "SalaA": {"level": 2, "picks": {1: ("jnwr", "james"), 2: ("serx", "pyro")}, "winner": 1, "reason": "result",
              "defeated": [2], "clients": ("Ana", "Aldo")},
    "SalaB": {"level": 3, "picks": {1: ("mrdk", "stratos"), 2: ("xwiz", "charnel")}, "winner": 2, "reason": "abandon",
              "defeated": [1], "clients": ("Beto", "Bruno")},
}
if len(launch) == 2:
    a, b = launch["SalaA"], launch["SalaB"]
    check(a["port"] != b["port"] and all(7800 <= x["port"] <= 7803 for x in (a, b)), "two different ports in the local range")
    check(a["seed"] != b["seed"] and a["seed"] > 0 and b["seed"] > 0, "two different seeds drawn by the server")
    check(a["id"] != b["id"], "two different match ids")
    ports_up = set(int(x) for l in server for x in re.findall(r"^dedicated listo puerto (\d+)$", l))
    check(ports_up == {a["port"], b["port"]}, "two real dedicated processes listened, on the ports the server gave (%s)" % sorted(ports_up))
    world_seeds = set(int(x) for l in server for x in re.findall(r"^semilla (\d+)$", l))
    check({a["seed"], b["seed"]} <= world_seeds, "each world drew the seed of its ticket (%s)" % sorted(world_seeds))
    for room, want in EXPECT.items():
        mid, seed = launch[room]["id"], launch[room]["seed"]
        pre = "partida %s: " % mid
        mine = [l for l in server if l.startswith(pre)]
        check(any(l == pre + "ticket con 2 asientos, semilla %d, nivel %d" % (seed, want["level"]) for l in mine),
              "%s: the dedicated read its ticket (seed %d, level %d)" % (room, seed, want["level"]))
        for slot, (model, god) in want["picks"].items():
            check(pre + "slot %d pick %s %s" % (slot, model, god) in mine, "%s: slot %d has the pick of the lobby (%s %s)" % (room, slot, model, god))
        for slot in (1, 2):
            check(mine.count(pre + "slot %d adentro" % slot) == 1, "%s: slot %d was admitted once" % (room, slot))
        check(not any("slot 3" in l for l in mine), "%s: no third slot" % room)
        results = [json.loads(l[len(pre + "resultado "):]) for l in mine if l.startswith(pre + "resultado ")]
        check(len(results) == 1, "%s: the dedicated reported exactly one result" % room)
        if results:
            r = results[0]
            check(r.get("reason") == want["reason"] and int(r.get("winner_slot", -1)) == want["winner"],
                  "%s: result %s, winner slot %d (got %s, %s)" % (room, want["reason"], want["winner"], r.get("reason"), r.get("winner_slot")))
            check([int(x) for x in r.get("defeated_slots", [])] == want["defeated"], "%s: defeated slots %s" % (room, want["defeated"]))
            check(int(r.get("seed", 0)) == seed, "%s: the result carries the ticket seed (the world used it)" % room)
            check(int(r.get("ticks", 0)) > 0, "%s: the result has ticks" % room)
        seen = [json.loads(m.group(1)) for l in server for m in [re.match(r'^sala "%s" resultado (\{.*\})$' % room, l)] if m]
        check(len(seen) == 1 and seen[0].get("match_id") == mid and int(seen[0].get("winner_slot", -1)) == want["winner"]
              and seen[0].get("reason") == want["reason"], "%s: the room got its own result (once)" % room)
        for who in want["clients"]:
            log = read(who + ".log")
            check(any(l == "E2E CLIENT %s PASS" % who for l in log), "%s: client %s passed all its checks" % (room, who))
            res = [l for l in log if l.startswith("E2E_RESULT ")]
            check(len(res) == 1 and ("match=" + mid) in res[0] and ("seed=%d" % seed) in res[0]
                  and ("winner=%d" % want["winner"]) in res[0] and ("room=" + room) in res[0],
                  "%s: client %s got the result of its match only (%s)" % (room, who, res[0] if res else "-"))
    check(any(l == "E2E_LEFT Beto" for l in read("Beto.log")), "Beto left his dedicated before the end")
    for who, other in (("Aldo", "B"), ("Bruno", "A")):
        log = read(who + ".log")
        check(any(l.startswith("PASS the ticket of room") and "is rejected" in l for l in log), "%s: his ticket on room %s's dedicated was rejected" % (who, other))
        check(any(l.startswith("PASS a made-up ticket") and "is rejected" in l for l in log), "%s: a made-up ticket on his own dedicated was rejected" % who)
check(not any("SCRIPT ERROR" in l for l in server), "no SCRIPT ERROR in the server log")
for who in ("Ana", "Aldo", "Beto", "Bruno"):
    check(not any("SCRIPT ERROR" in l for l in read(who + ".log")), "no SCRIPT ERROR in %s's log" % who)
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
# the dedicated may still be exiting (result delay): wait up to EXIT_WAIT_S for them, then it is a FAIL and they are killed
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
[ "$READY" = 1 ] || { echo "E2E FAIL: the room server did not announce its port"; VERDICT=1; }
kill $WATCH $MONITOR 2>/dev/null
if [ "$VERDICT" = 0 ]; then echo "E2E PASS"; rm -rf "$OUT"; else echo "E2E FAIL (logs in $OUT)"; fi
exit "$VERDICT"
