#!/usr/bin/env bash
# F350: the EVERYDAY network check. One launch, about 10 s, no full match:
#   - a room server and two lobby clients that REALLY LOAD THE WORLD (debug/net/room_world_client), room with a map (test_flat);
#   - ticket -> real dedicated -> both clients join it and load the world the room chose;
#   - the dedicated forces a defeat of slot 2 a few ticks after the first player sat (winner 1, "result") and the result reaches
#     both clients and the ROOM (the room server prints it);
#   - a room with an invalid world (world=foo) is refused with `bad_options` and no match is launched for it;
#   - no Godot process and no match folder left.
# How it is fast: no queue wait (one group reservation), the three clients start together as soon as the server prints its port;
# the dedicated runs with `--fixed-fps 600` (no real-time wait between frames, 60 physics ticks per simulated second as always); the short
# grace and delays are CLI flags of the config (no new code path); every wait is on a log line, never a fixed sleep.
# Use the full suites (run_034*.sh, run_049*.sh) when closing an RFC; see agent/runs/README.md.
# TRANSPORT=ws bash agent/runs/run_net_quick.sh   -> WebSocket over TCP for the lobby and the dedicated.
# All Godot processes run inside ONE group reservation of the queue (agent/harness/godot_group.sh): they cannot deadlock against an import.
# Needs `--import` once first (new class_names). Uses lobby port 7706 (E2E_LOBBY_PORT) and 7800-7803 (matches); files go in a temp folder.
# Prints the checks and NET QUICK PASS / NET QUICK FAIL (exit 0 / 1).
. "$(dirname "$0")/../harness/net_e2e.sh"
net_group 5 "$@"
TAG="NET QUICK"
LIMIT_S="${PROBE_LIMIT_S:-90}"
PROC_MAX=6 # server + 3 clients + the dedicated (+1 of margin while one exits)
TRANSPORT="${TRANSPORT:-enet}"
LOBBY_PORT="${E2E_LOBBY_PORT:-7706}"
FORCE_TICKS="${E2E_FORCE_TICKS:-120}"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/net_quick.XXXXXX")"
MATCHES="$OUT/matches"
mkdir -p "$MATCHES"
START_S=$SECONDS
export NET_T0=$(perl -MTime::HiRes=time -e "print time")

kill_stray() { # the dedicated of this run, if it lost its parent
  local p
  for p in $(ps -axo pid=,args= | awk -v m="$OUT" '$2 ~ /\/Godot$/ && index($0, m) {print $1}'); do kill "$p" 2>/dev/null; done
}
kill_all() { kill_pids; kill_stray; }
trap 'kill_all; net_stop' EXIT
net_guard

CLIENT_FLAGS=(--transport="$TRANSPORT" --lobby-port="$LOBBY_PORT")
gd "$OUT/server.log" res://scenes/net/room_server.tscn -- \
  --room-server --room-test-maps --transport="$TRANSPORT" --lobby-config=res://data/net/lobby_config_local.tres --lobby-port="$LOBBY_PORT" \
  --max-matches=1 --ticket-ttl-s=30 --idle-no-players-s=20 --resume-grace-s=5 --matches-root="$MATCHES" \
  --countdown-s=0.2 --poll-s=0.1 --heartbeat-s=0.5 --parent-check-s=0.5 --rejoin-grace-s=2 --result-quit-delay-s=1 \
  --match-engine-args="--fixed-fps,$NET_FPS" --match-args=--force-defeat-slot=2,--force-defeat-after-ticks="$FORCE_TICKS"
SERVER=$LAST_PID
# the clients start once the server listens (a WebSocket client does not retry a refused TCP connection; startup is ~0.6 s)
READY=0
wait_line "$OUT/server.log" "^salas listo puerto" "$SERVER" 30 && READY=1
gd "$OUT/Bea.log" res://debug/net/room_world_client.tscn -- "${CLIENT_FLAGS[@]}" --e2e-name=Bea --e2e-room=SalaBad --e2e-bad-world
BEA=$LAST_PID
gd "$OUT/Ana.log" res://debug/net/room_world_client.tscn -- "${CLIENT_FLAGS[@]}" --e2e-name=Ana --e2e-room=SalaFlat --e2e-peer=Aldo --e2e-create \
  --e2e-world=test_flat --e2e-wizard=cwa0 --e2e-model=jnwr --e2e-god=james --e2e-expect-winner=1
ANA=$LAST_PID
gd "$OUT/Aldo.log" res://debug/net/room_world_client.tscn -- "${CLIENT_FLAGS[@]}" --e2e-name=Aldo --e2e-room=SalaFlat --e2e-peer=Ana \
  --e2e-world=test_flat --e2e-wizard=cwa1 --e2e-model=serx --e2e-god=pyro --e2e-expect-winner=1
ALDO=$LAST_PID

for p in $BEA $ANA $ALDO; do wait "$p"; done
# the dedicated quits by itself after the result; the launcher then closes the match folder
wait_gone "match-ticket-file=$MATCHES" 15
for _ in $(seq 1 100); do [ -z "$(find "$MATCHES" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)" ] && break; sleep 0.1; done

echo "--- server ---"; grep -E "^(salas|partida|sala |SCRIPT ERROR|ERROR|dedicated listo|semilla|mapa)" "$OUT/server.log" | head -n 30
for n in Bea Ana Aldo; do
  echo "--- $n ---"; grep -E "^(PASS|FAIL|E2E|SCRIPT ERROR|ERROR|en mapa|mapa)" "$OUT/$n.log" 2>/dev/null | tail -n 20
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
bea = read("Bea.log")
check(any(l == "E2E CLIENT Bea PASS" for l in bea), "Bea: a room with world=foo is refused with bad_options")
check(not any(l.startswith("partida ") and "SalaBad" in l for l in server), "no match was launched for the refused room")
launch = None
for l in server:
    m = re.match(r'^partida (\S+) sala "SalaFlat" puerto (\d+) semilla (\d+)$', l)
    if m:
        launch = {"id": m.group(1), "port": int(m.group(2)), "seed": int(m.group(3))}
check(launch is not None, "the server launched the match of SalaFlat (ticket -> dedicated)")
if launch:
    pre = "partida %s: " % launch["id"]
    mine = [l for l in server if l.startswith(pre)]
    check(any(l.startswith(pre + "ticket con 2 asientos") for l in mine), "the dedicated read its ticket (2 seats)")
    check("mapa test_flat" in server, "the dedicated loaded the map test_flat")
    check(any(re.match(r"^" + re.escape(pre) + r"slot \d cargó el mundo \(2/2\)$", l) for l in mine), "both clients loaded their world before the simulation started")
    results = [json.loads(l[len(pre + "resultado "):]) for l in mine if l.startswith(pre + "resultado ")]
    check(len(results) == 1 and results[0].get("reason") == "result" and int(results[0].get("winner_slot", -1)) == 1, "the match ended by the forced defeat (winner 1, result)")
    seen = [json.loads(m.group(1)) for l in server for m in [re.match(r'^sala "SalaFlat" resultado (\{.*\})$', l)] if m]
    check(len(seen) == 1 and seen[0].get("match_id") == launch["id"] and int(seen[0].get("winner_slot", -1)) == 1, "the result reached the room (once)")
    for who in ("Ana", "Aldo"):
        log = read(who + ".log")
        check(any(l == "E2E CLIENT %s PASS" % who for l in log), "%s passed all its checks (slot, world loaded, result)" % who)
        check(any(l.startswith("E2E_MAP %s tag=test_flat scene=res://scenes/map/maps/test_flat/map.tscn" % who) for l in log), "%s: the match scene holds the map of test_flat" % who)
        check(not any("SCRIPT ERROR" in l for l in log), "no SCRIPT ERROR in %s's log" % who)
check(not any("SCRIPT ERROR" in l for l in server), "no SCRIPT ERROR in the server log")
check(not any("SCRIPT ERROR" in l for l in bea), "no SCRIPT ERROR in Bea's log")
try:
    registry = json.load(open(os.path.join(matches, "registry.json")))
    check(registry.get("matches", None) == {}, "registry.json has no match")
except (OSError, ValueError):
    check(False, "registry.json is readable")
check([e for e in os.listdir(matches) if e != "registry.json"] == [], "no match folder or file left")
sys.exit(1 if fails else 0)
PYEOF
VERDICT=$?
kill_tree "$SERVER"; wait "$SERVER" 2>/dev/null
kill_all 2>/dev/null
wait_gone "$OUT" 5
STRAY=$(godots_with "$OUT")
if [ "$STRAY" != 0 ]; then echo "FAIL $STRAY Godot process of this run still alive after the kill"; VERDICT=1; else echo "PASS no Godot process left"; fi
read -r RSS_KB PROCS < "$OUT/rss.max" 2>/dev/null
echo "RSS max total: $(( ${RSS_KB:-0} / 1024 )) MB, at most ${PROCS:-0} Godot processes at once, $((SECONDS - START_S)) s ($TRANSPORT)"
if [ -s "$OUT/timeout.flag" ]; then cat "$OUT/timeout.flag"; VERDICT=1; fi
[ "$READY" = 1 ] || { echo "$TAG FAIL: the room server did not announce its port"; VERDICT=1; }
net_stop
if [ "$VERDICT" = 0 ]; then echo "$TAG PASS"; rm -rf "$OUT"; else echo "$TAG FAIL (logs in $OUT)"; fi
exit "$VERDICT"
