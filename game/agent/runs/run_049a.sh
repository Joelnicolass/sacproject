#!/usr/bin/env bash
# RFC-049 049a (F290): the room chooses the map. Headless, with the real room server and a real dedicated:
#   1. a room with world="foo" is refused (bad_options) by the room server;
#   2. a room with world=test_flat (the server runs with --room-test-maps): two clients that REALLY LOAD THE WORLD (the real flow,
#      debug/net/room_world_client) join the dedicated; the dedicated prints `mapa test_flat` and each client `en mapa test_flat`
#      and checks that its match scene holds the map of test_flat (this measures the order snapshot {map} -> load_world);
#      the match ends by a forced defeat of slot 2 (winner 1) and the room gets the result;
#   3. a dedicated started by hand with a ticket whose world does not exist reports `bad_ticket` in result.json and quits.
# Processes: room server + 3 clients + the dedicated the server launches = 5 Godot at most; the hand-made dedicated of step 3 runs alone after.
# F350: all of them run inside ONE group reservation of the Godot queue (agent/harness/godot_group.sh), started directly; the dedicated of the
# room runs with --fixed-fps (NET_FPS, 600); the waits are on log lines. Closes by itself: the clients have internal timeouts (150 s); this script
# kills the server, the clients and the dedicated (by pid and descendants, no pkill) at LIMIT_S, or if the total RSS passes the cap.
# Prints the checks and E2E PASS / E2E FAIL (exit 0 / 1). Needs `--import` once first (new class_names). UDP 7706 (lobby),
# 7800-7803 (matches), 7810 (hand-made ticket); files go in a temp folder.
. "$(dirname "$0")/../harness/net_e2e.sh"
net_group 5 "$@"
TAG="E2E"
LIMIT_S="${PROBE_LIMIT_S:-120}"
PROC_MAX=6
LOBBY_PORT="${E2E_LOBBY_PORT:-7706}"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/room_e2e_049a.XXXXXX")"
MATCHES="$OUT/matches"
HAND="$OUT/hand"
mkdir -p "$MATCHES" "$HAND"
START_S=$SECONDS

kill_stray() { # dedicated of this run that lost their parent
  local p
  for p in $(ps -axo pid=,args= | awk -v m="$OUT" '$2 ~ /\/Godot$/ && index($0, m) {print $1}'); do kill "$p" 2>/dev/null; done
}
kill_all() { kill_pids; kill_stray; }
trap 'kill_all; net_stop' EXIT
net_guard

run_client() { # name, then the client flags
  local name="$1"; shift
  gd "$OUT/$name.log" res://debug/net/room_world_client.tscn -- --transport=enet --lobby-port="$LOBBY_PORT" --e2e-name="$name" "$@"
}

# --- room server (with the test maps on) ---------------------------------------------------------------------------
gd "$OUT/server.log" res://scenes/net/room_server.tscn -- \
  --room-server --room-test-maps --lobby-config=res://data/net/lobby_config_local.tres --lobby-port="$LOBBY_PORT" --max-matches=1 \
  --ticket-ttl-s=60 --idle-no-players-s=30 --resume-grace-s=120 --matches-root="$MATCHES" \
  --countdown-s=0.2 --poll-s=0.1 --heartbeat-s=0.5 --parent-check-s=0.5 --result-quit-delay-s=1 \
  --match-engine-args="--fixed-fps,$NET_FPS" --match-args=--force-defeat-slot=2,--force-defeat-after-ticks=300
SERVER=$LAST_PID
READY=0
wait_line "$OUT/server.log" "^salas listo puerto" "$SERVER" 30 && READY=1

if [ "$READY" = 1 ]; then
  # 1. the invalid world, and 2. the room with test_flat: two clients that load the world (the three at once: separate rooms)
  run_client Bea --e2e-room=SalaBad --e2e-bad-world
  BEA=$LAST_PID
  run_client Ana --e2e-room=SalaFlat --e2e-peer=Aldo --e2e-create --e2e-world=test_flat \
    --e2e-wizard=cwa0 --e2e-model=jnwr --e2e-god=james --e2e-expect-winner=1
  ANA=$LAST_PID
  run_client Aldo --e2e-room=SalaFlat --e2e-peer=Ana --e2e-world=test_flat \
    --e2e-wizard=cwa1 --e2e-model=serx --e2e-god=pyro --e2e-expect-winner=1
  ALDO=$LAST_PID
  wait "$BEA"; wait "$ANA"; wait "$ALDO"
  wait_gone "match-ticket-file=$MATCHES" 15
  # 3. a ticket written by hand with a world that does not exist
  mkdir -p "$HAND/hand_bad"
  python3 - "$HAND/hand_bad/ticket.json" <<'PYEOF'
import hashlib, json, sys, time
token = "0123456789abcdef0123456789abcdef"
json.dump({
    "match_id": "hand_bad", "port": 7810, "room_pid": 0, "expires_ms": int(time.time() * 1000) + 60000,
    "world": "foo", "options": {}, "seed": 12345,
    "seats": [{"slot": 1, "token_sha256": hashlib.sha256(token.encode()).hexdigest(), "meta": {"wizard": "cwa0", "god": "james"}}],
}, open(sys.argv[1], "w"))
PYEOF
  gd "$OUT/hand.log" -- --dedicated --mp-port=7810 --match-ticket-file="$HAND/hand_bad/ticket.json"
  HANDPID=$LAST_PID
  for _ in $(seq 1 300); do kill -0 "$HANDPID" 2>/dev/null || break; sleep 0.1; done
  if kill -0 "$HANDPID" 2>/dev/null; then echo "hand-made dedicated did not quit" > "$OUT/hand.stuck"; fi
fi

# --- verdict -------------------------------------------------------------------------------------------------------
echo "--- server ---"; grep -E "^(salas|partida|sala |SCRIPT ERROR|ERROR|dedicated listo|semilla|mapa)" "$OUT/server.log" | head -n 60
for n in Bea Ana Aldo; do
  echo "--- $n ---"; grep -E "^(PASS|FAIL|E2E|SCRIPT ERROR|ERROR|en mapa|mapa)" "$OUT/$n.log" 2>/dev/null | tail -n 30
done
echo "--- hand-made dedicated ---"; grep -E "bad_ticket|SCRIPT ERROR" "$OUT/hand.log" | head -n 5
echo "--- verdict ---"
python3 - "$OUT" "$MATCHES" "$HAND" "$LOBBY_PORT" <<'PYEOF'
import json, os, re, sys
out, matches, hand, lobby_port = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
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
# 1. the invalid world
bea = read("Bea.log")
check(any(l == "E2E CLIENT Bea PASS" for l in bea), "Bea: a room with world=foo is refused with bad_options")
check(not any(l.startswith("partida ") and "SalaBad" in l for l in server), "no match was launched for the refused room")
# 2. the room with test_flat
launch = None
for l in server:
    m = re.match(r'^partida (\S+) sala "SalaFlat" puerto (\d+) semilla (\d+)$', l)
    if m:
        launch = {"id": m.group(1), "port": int(m.group(2)), "seed": int(m.group(3))}
check(launch is not None, "the server launched the match of SalaFlat")
if launch:
    pre = "partida %s: " % launch["id"]
    mine = [l for l in server if l.startswith(pre)]
    ticket_world = None
    check(any(l.startswith(pre + "ticket con 2 asientos") for l in mine), "the dedicated read its ticket (2 seats)")
    check("mapa test_flat" in server, "the dedicated loaded the map test_flat (`mapa test_flat`)")
    check("mapa high_noon" not in server, "the dedicated never loaded High Noon")
    check(any(re.match(r"^" + re.escape(pre) + r"slot \d cargó el mundo \(2/2\)$", l) for l in mine), "both clients loaded their world before the simulation started")
    results = [json.loads(l[len(pre + "resultado "):]) for l in mine if l.startswith(pre + "resultado ")]
    check(len(results) == 1 and results[0].get("reason") == "result" and int(results[0].get("winner_slot", -1)) == 1, "the match ended by the forced defeat (winner 1, result)")
    for who in ("Ana", "Aldo"):
        log = read(who + ".log")
        check(any(l == "E2E CLIENT %s PASS" % who for l in log), "%s passed all its checks" % who)
        check(any(l == "en mapa test_flat" for l in log), "%s loaded the world on `en mapa test_flat`" % who)
        check(not any(l == "en mapa high_noon" for l in log), "%s never loaded High Noon" % who)
        check(any(l.startswith("E2E_MAP %s tag=test_flat scene=res://scenes/map/maps/test_flat/map.tscn" % who) for l in log), "%s: the match scene holds the map of test_flat" % who)
        check(any(l.startswith("mapa de la partida test_flat (del servidor)") for l in log), "%s took the map from the server snapshot" % who)
        check(not any("SCRIPT ERROR" in l for l in log), "no SCRIPT ERROR in %s's log" % who)
check(not any("SCRIPT ERROR" in l for l in server), "no SCRIPT ERROR in the server log")
# 3. the hand-made ticket
hl = read("hand.log")
check(any("bad_ticket" in l for l in hl), "the hand-made dedicated logged bad_ticket")
check(not any(l.startswith("dedicated listo") for l in hl), "the hand-made dedicated never listened")
check(not os.path.exists(os.path.join(out, "hand.stuck")), "the hand-made dedicated quit by itself")
try:
    result = json.load(open(os.path.join(hand, "hand_bad", "result.json")))
    check(result.get("reason") == "bad_ticket", "result.json of the hand-made ticket says bad_ticket")
except (OSError, ValueError):
    check(False, "result.json of the hand-made ticket is readable")
sys.exit(1 if fails else 0)
PYEOF
VERDICT=$?
kill_tree "$SERVER"; wait "$SERVER" 2>/dev/null
kill_all 2>/dev/null
wait_gone "$OUT" 5
STRAY=$(godots_with "$OUT")
if [ "$STRAY" != 0 ]; then echo "FAIL $STRAY Godot process of this run still alive after the kill"; VERDICT=1; else echo "PASS no Godot process left"; fi
read -r RSS_KB PROCS < "$OUT/rss.max" 2>/dev/null
echo "RSS max total: $(( ${RSS_KB:-0} / 1024 )) MB, at most ${PROCS:-0} Godot processes at once, $((SECONDS - START_S)) s"
if [ -s "$OUT/timeout.flag" ]; then cat "$OUT/timeout.flag"; VERDICT=1; fi
[ "$READY" = 1 ] || { echo "E2E FAIL: the room server did not announce its port"; VERDICT=1; }
net_stop
if [ "$VERDICT" = 0 ]; then echo "E2E PASS"; rm -rf "$OUT"; else echo "E2E FAIL (logs in $OUT)"; fi
exit "$VERDICT"
