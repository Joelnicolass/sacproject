#!/usr/bin/env bash
# RFC-049 049g (F296): a 2v2 from end to end, headless, with the real room server and real dedicated processes.
# Two phases, one room server each (the second one forces the defeat of the AI seats):
#   A. Room "Sala2v2": FOUR humans, mode 2v2 on test_flat4. 6 Godot processes: 1 room server + 4 lobby clients + the dedicated.
#      Ana creates it (seat 0 = slot 1), Beto (slot 2), Cris (slot 3), Dani (slot 4, joins the dedicated late: the match waits for him).
#      Every client takes the slot of its seat and says its world is loaded; the simulation starts when the four have.
#      Beto leaves the dedicated and comes back with the same ticket inside the grace: same slot 2.
#      Cris (slot 3) leaves: after the grace his side is defeated and THE MATCH GOES ON (his ally Dani still stands).
#      Later Dani (slot 4) leaves: the team 1 is gone, the team 0 wins: result.json {winner_slots [1,2], reason "abandon"}.
#      The four clients get the result in the room, and the text of the room says won / lost per slot.
#   B. Room "Sala2mas2": TWO humans + TWO bots (the host puts them in seats 3 and 4). 4 processes: server + 2 clients + the dedicated.
#      The ticket has 2 rows with a token and 2 ai_seats; the dedicated seats the AI (`ia slot 3 lista`, `ia slot 4 lista`) and the
#      forced defeat of 3 and 4 gives winner_slots [1,2], reason "result".
# Checks the logs: slots per the ticket, the picks, the order of the events, one result per match, nothing left behind.
# F350: all the processes run inside ONE group reservation of the Godot queue (agent/harness/godot_group.sh), started directly. The seats fill in
# order by an EVENT (a joiner enters when the room already holds N seats: --e2e-join-when-used), not by wall-clock delays (the old delays raced with the
# startup of the processes: it never passed). Phase A (ordering, grace) runs in real time with short delays and a 2 s grace; phase B (no ordering) runs
# its dedicated with --fixed-fps. Closes by itself: the clients have internal timeouts (150 s); this script kills the server, the clients and the
# dedicated (by pid and descendants, no pkill) at LIMIT_S per phase, or if the total RSS passes the cap.
# Prints the checks, the max total RSS of the Godot processes of this project, and E2E PASS / E2E FAIL (exit 0 / 1).
# Needs `--import` once first (new class_names). Uses UDP 7709 (lobby) and 7800-7803 (matches); files go in a temp folder.
. "$(dirname "$0")/../harness/net_e2e.sh"
net_group 6 "$@"
TAG="E2E"
LIMIT_S="${PROBE_LIMIT_S:-120}"
PROC_MAX=7
TRANSPORT="${TRANSPORT:-enet}"
LOBBY_PORT="${E2E_LOBBY_PORT:-7709}"
REJOIN_GRACE_S="${E2E_REJOIN_GRACE_S:-2}"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/room_e2e_049g.XXXXXX")"
mkdir -p "$OUT/A/matches" "$OUT/B/matches" "$OUT/ports"
START_S=$SECONDS
EXIT_WAIT_S=10 # grace for the dedicated to exit after the last result

kill_stray() { # dedicated of this run that lost their parent
  local p
  for p in $(ps -axo pid=,args= | awk -v m="match-ticket-file=$OUT" '$2 ~ /\/Godot$/ && index($0, m) {print $1}'); do kill "$p" 2>/dev/null; done
}
kill_all() { kill_pids; kill_stray; }
trap 'kill_all; net_stop' EXIT
net_guard

start_server() { # phase, then the extra flags of the room server
  local phase="$1"; shift
  gd "$OUT/$phase/server.log" res://scenes/net/room_server.tscn -- \
    --room-server --room-test-maps --transport="$TRANSPORT" --lobby-config=res://data/net/lobby_config_local.tres \
    --lobby-port="$LOBBY_PORT" --max-matches=1 --ticket-ttl-s=60 --idle-no-players-s=30 --resume-grace-s=120 \
    --countdown-s=0.2 --poll-s=0.1 --heartbeat-s=0.5 --parent-check-s=0.5 --result-quit-delay-s=1 \
    --matches-root="$OUT/$phase/matches" "$@"
  SERVER=$LAST_PID
}

wait_ready() { # phase
  READY=0
  wait_line "$OUT/$1/server.log" "^salas listo puerto" "$SERVER" 30 && READY=1
}

client() { # phase, name, then the client flags
  local phase="$1" name="$2"; shift 2
  gd "$OUT/$phase/$name.log" res://debug/net/room_e2e_client.tscn -- \
    --no-flow --transport="$TRANSPORT" --lobby-port="$LOBBY_PORT" --e2e-dir="$OUT/ports" --e2e-name="$name" "$@"
  PHASE_PIDS="$PHASE_PIDS $LAST_PID"
}

settle() { # phase: the server closes the match by itself; wait until no dedicated and no match folder is left
  wait_gone "match-ticket-file=$OUT/$1/matches" "$EXIT_WAIT_S"
  for _ in $(seq 1 100); do [ -z "$(find "$OUT/$1/matches" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)" ] && break; sleep 0.1; done
}

# --- phase A: four humans -------------------------------------------------------------------------------------------
PHASE_PIDS=""
start_server A --rejoin-grace-s="$REJOIN_GRACE_S"
wait_ready A
READY_A=$READY
if [ "$READY_A" = 1 ]; then
  COMMON="--e2e-room=Sala2v2 --e2e-seats=4 --e2e-world-ready --e2e-expect-winners=1,2 --e2e-expect-reason=abandon"
  client A Ana  $COMMON --e2e-create --e2e-mode=2v2 --e2e-world=test_flat4 --e2e-level=2 --e2e-peers=Beto,Cris,Dani --e2e-seat=0 \
    --e2e-wizard=cwa0 --e2e-model=jnwr --e2e-god=james
  client A Beto $COMMON --e2e-peers=Ana,Cris,Dani --e2e-seat=1 --e2e-join-when-used=1 --e2e-leave-after-s=4 --e2e-rejoin-after-s=0.8 \
    --e2e-wizard=cwa1 --e2e-model=serx --e2e-god=pyro
  client A Cris $COMMON --e2e-peers=Ana,Beto,Dani --e2e-seat=2 --e2e-join-when-used=2 --e2e-leave-after-s=5 \
    --e2e-wizard=cwa2 --e2e-model=mrdk --e2e-god=stratos
  client A Dani $COMMON --e2e-peers=Ana,Beto,Cris --e2e-seat=3 --e2e-join-when-used=3 --e2e-join-delay-s=2 --e2e-leave-after-s=8 \
    --e2e-wizard=cwd0 --e2e-model=xwiz --e2e-god=charnel
  for p in $PHASE_PIDS; do wait "$p"; done
  settle A
fi
kill_tree "$SERVER"; wait "$SERVER" 2>/dev/null; kill_stray

# --- phase B: two humans + two bots (no ordering to keep: the dedicated runs with --fixed-fps) -----------------------
PHASE_PIDS=""
start_server B --match-engine-args="--fixed-fps,$NET_FPS" --match-args=--log=ai_seat,--force-defeat-slot=3+4,--force-defeat-after-ticks=300
wait_ready B
READY_B=$READY
if [ "$READY_B" = 1 ]; then
  COMMON="--e2e-room=Sala2mas2 --e2e-seats=4 --e2e-world-ready --e2e-expect-winners=1,2 --e2e-expect-reason=result"
  client B Ana  $COMMON --e2e-create --e2e-mode=2v2 --e2e-world=test_flat4 --e2e-level=2 --e2e-peers=Beto --e2e-seat=0 \
    --e2e-bot-seats=2,3 --e2e-bot-gods=pyro, --e2e-wizard=cwa0 --e2e-model=jnwr --e2e-god=james
  client B Beto $COMMON --e2e-peers=Ana --e2e-seat=1 --e2e-join-when-used=3 --e2e-wizard=cwa1 --e2e-model=serx --e2e-god=pyro
  for p in $PHASE_PIDS; do wait "$p"; done
  settle B
fi
kill_tree "$SERVER"; wait "$SERVER" 2>/dev/null; kill_stray

# --- verdict -------------------------------------------------------------------------------------------------------
for phase in A B; do
  echo "--- server $phase ---"; grep -E "^(salas|partida|sala |bando|ia slot|derrota|SCRIPT ERROR|ERROR|dedicated listo)" "$OUT/$phase/server.log" | head -n 60
done
for n in Ana Beto Cris Dani; do
  echo "--- A $n ---"; grep -E "^(PASS|FAIL|E2E|SCRIPT ERROR|ERROR)" "$OUT/A/$n.log" 2>/dev/null | tail -n 40
done
for n in Ana Beto; do
  echo "--- B $n ---"; grep -E "^(PASS|FAIL|E2E|SCRIPT ERROR|ERROR)" "$OUT/B/$n.log" 2>/dev/null | tail -n 40
done
echo "--- verdict ---"
python3 - "$OUT" "$LOBBY_PORT" <<'PYEOF'
import json, os, re, sys
out, lobby_port = sys.argv[1], int(sys.argv[2])
fails = []
def check(ok, what):
    print(("PASS " if ok else "FAIL ") + what)
    if not ok:
        fails.append(what)
def read(phase, name):
    try:
        return open(os.path.join(out, phase, name), errors="replace").read().splitlines()
    except OSError:
        return []
def idx(lines, pred, start=0):
    for i in range(start, len(lines)):
        if pred(lines[i]):
            return i
    return -1
def launch_of(server, room):
    for l in server:
        m = re.match(r'^partida (\S+) sala "%s" puerto (\d+) semilla (\d+)$' % room, l)
        if m:
            return {"id": m.group(1), "port": int(m.group(2)), "seed": int(m.group(3))}
    return None
def results_of(server, mid):
    pre = "partida %s: resultado " % mid
    return [json.loads(l[len(pre):]) for l in server if l.startswith(pre)]

# ---------------- phase A ----------------
sa = read("A", "server.log")
check(any(l.startswith("salas listo puerto %d" % lobby_port) for l in sa), "A: the room server announced its port")
la = launch_of(sa, "Sala2v2")
check(la is not None, "A: the server launched one match for the room Sala2v2")
if la:
    mid, seed = la["id"], la["seed"]
    pre = "partida %s: " % mid
    mine = [l for l in sa if l.startswith(pre)]
    check(sum(1 for l in sa if l.startswith("partida ") and " sala " in l) == 1, "A: exactly one match launched")
    check(any(l == pre + "ticket con 4 asientos, semilla %d, nivel 2" % seed for l in mine), "A: the dedicated read a ticket with 4 seats (seed %d, level 2)" % seed)
    check(pre + "mapa test_flat4 modo 2v2, 0 IA" in mine, "A: map test_flat4, mode 2v2, no AI")
    check(any(l == "dedicated listo puerto %d" % la["port"] for l in sa), "A: a real dedicated listened on the port the server gave")
    picks = {1: ("jnwr", "james"), 2: ("serx", "pyro"), 3: ("mrdk", "stratos"), 4: ("xwiz", "charnel")}
    for slot, (model, god) in picks.items():
        check(pre + "slot %d pick %s %s" % (slot, model, god) in mine, "A: slot %d has the pick of its seat (%s %s)" % (slot, model, god))
        check(mine.count(pre + "slot %d adentro" % slot) == 1, "A: slot %d was admitted once" % slot)
    check(not any("slot 5" in l for l in mine), "A: no fifth slot")
    check(any(l.startswith(pre + "la simulación arranca (todos cargaron)") for l in mine), "A: the simulation waited for the four to load")
    i_start = idx(mine, lambda l: "la simulación arranca" in l)
    i_dani = idx(mine, lambda l: l == pre + "slot 4 adentro")
    check(i_dani >= 0 and i_start > i_dani, "A: the late client (slot 4) came in before the start; the match waited for him")
    check(pre + "slot 2 se fue" in mine and pre + "slot 2 volvió" in mine, "A: slot 2 left and came back to the same slot")
    i_back = idx(sa, lambda l: l == pre + "slot 2 volvió")
    check(not any(l == pre + "slot 2 abandonó y pierde" for l in mine), "A: slot 2 never lost: it came back inside the grace")
    i_c_left = idx(sa, lambda l: l == pre + "slot 3 se fue")
    i_c_lost = idx(sa, lambda l: l == pre + "slot 3 abandonó y pierde")
    i_b3 = idx(sa, lambda l: l == "bando 3 derrotado")
    i_d_left = idx(sa, lambda l: l == pre + "slot 4 se fue")
    i_d_lost = idx(sa, lambda l: l == pre + "slot 4 abandonó y pierde")
    i_b4 = idx(sa, lambda l: l == "bando 4 derrotado")
    i_end = idx(sa, lambda l: re.match(r"^partida terminada, gana el equipo \d+: slots \[1, 2\]$", l) is not None)
    i_res = idx(sa, lambda l: l.startswith(pre + "resultado "))
    check(i_c_left >= 0 and i_c_left < i_c_lost < i_b3, "A: slot 3 left, then lost (abandon), then `bando 3 derrotado`")
    check(i_b3 >= 0 and i_d_left > i_b3, "A: the ally was defeated and slot 4 was still in the match (it left later)")
    check(i_res < 0 or i_res > i_b4, "A: no result while the ally still stood")
    check(0 < i_d_left < i_d_lost < i_b4 < i_end < i_res, "A: slot 4 left, lost, `bando 4 derrotado`, then the team 0 won and the result came out")
    results = results_of(sa, mid)
    check(len(results) == 1, "A: the dedicated reported exactly one result")
    if results:
        r = results[0]
        check(r.get("reason") == "abandon" and [int(x) for x in r.get("winner_slots", [])] == [1, 2] and int(r.get("winner_slot", -1)) == 1,
              "A: result abandon, winner_slots [1, 2] (got %s, %s)" % (r.get("reason"), r.get("winner_slots")))
        check([int(x) for x in r.get("defeated_slots", [])] == [3, 4], "A: defeated slots [3, 4]")
        check(int(r.get("seed", 0)) == seed and int(r.get("ticks", 0)) > 0, "A: the result carries the ticket seed and ticks")
    seen = [json.loads(m.group(1)) for l in sa for m in [re.match(r'^sala "Sala2v2" resultado (\{.*\})$', l)] if m]
    check(len(seen) == 1 and seen[0].get("match_id") == mid and seen[0].get("reason") == "abandon", "A: the room got the result (once)")
    for who, slot in (("Ana", 1), ("Beto", 2), ("Cris", 3), ("Dani", 4)):
        log = read("A", who + ".log")
        check(any(l == "E2E CLIENT %s PASS" % who for l in log), "A: client %s passed all its checks" % who)
        check(any(l == "E2E_SLOT %s slot=%d" % (who, slot) for l in log), "A: client %s sat in slot %d" % (who, slot))
        res = [l for l in log if l.startswith("E2E_RESULT ")]
        check(len(res) == 1 and ("match=" + mid) in res[0] and ("slot=%d" % slot) in res[0], "A: client %s got the result of the match (%s)" % (who, res[0] if res else "-"))
        check(not any("SCRIPT ERROR" in l for l in log), "A: no SCRIPT ERROR in %s's log" % who)
    check(any(l == "E2E_BACK Beto slot=2" for l in read("A", "Beto.log")), "A: Beto came back to slot 2")
    check(any(l == "E2E_LEFT Cris" for l in read("A", "Cris.log")) and any(l == "E2E_LEFT Dani" for l in read("A", "Dani.log")), "A: Cris and Dani left the match")
check(not any("SCRIPT ERROR" in l for l in sa), "A: no SCRIPT ERROR in the server log")
try:
    registry = json.load(open(os.path.join(out, "A", "matches", "registry.json")))
    check(registry.get("matches", None) == {}, "A: registry.json has no match")
except (OSError, ValueError):
    check(False, "A: registry.json is readable")
check([e for e in os.listdir(os.path.join(out, "A", "matches")) if e != "registry.json"] == [], "A: no match folder or file left")

# ---------------- phase B ----------------
sb = read("B", "server.log")
check(any(l.startswith("salas listo puerto %d" % lobby_port) for l in sb), "B: the room server announced its port")
lb = launch_of(sb, "Sala2mas2")
check(lb is not None, "B: the server launched one match for the room Sala2mas2")
if lb:
    mid, seed = lb["id"], lb["seed"]
    pre = "partida %s: " % mid
    mine = [l for l in sb if l.startswith(pre)]
    check(any(l == pre + "ticket con 2 asientos, semilla %d, nivel 2" % seed for l in mine), "B: the ticket has 2 rows with a token (the humans)")
    check(pre + "mapa test_flat4 modo 2v2, 2 IA" in mine, "B: map test_flat4, mode 2v2, 2 AI seats in the ticket")
    check(pre + "ia en slots [3, 4] (del ticket)" in mine, "B: the AI sits in slots 3 and 4 (from the ticket)")
    for slot in (3, 4):
        check(any(l.startswith("ia slot %d lista" % slot) for l in sb), "B: ia slot %d lista" % slot)
        check(pre + "slot %d adentro" % slot not in mine, "B: nobody was admitted into the bot seat %d" % slot)
    check(any(l.startswith("ia slot 3 lista (pyro") for l in sb), "B: the bot of seat 3 plays the god of its meta (pyro)")
    for slot, (model, god) in {1: ("jnwr", "james"), 2: ("serx", "pyro")}.items():
        check(pre + "slot %d pick %s %s" % (slot, model, god) in mine, "B: slot %d has the pick of its seat" % slot)
        check(mine.count(pre + "slot %d adentro" % slot) == 1, "B: slot %d was admitted once" % slot)
    check(any(l == pre + "derrota forzada del slot 3 (prueba)" for l in mine) and any(l == pre + "derrota forzada del slot 4 (prueba)" for l in mine), "B: the slots 3 and 4 were defeated by the hook")
    check(idx(sb, lambda l: re.match(r"^partida terminada, gana el equipo \d+: slots \[1, 2\]$", l) is not None) >= 0, "B: the team of slots [1, 2] won")
    results = results_of(sb, mid)
    check(len(results) == 1, "B: the dedicated reported exactly one result")
    if results:
        r = results[0]
        check(r.get("reason") == "result" and [int(x) for x in r.get("winner_slots", [])] == [1, 2], "B: result `result`, winner_slots [1, 2] (got %s, %s)" % (r.get("reason"), r.get("winner_slots")))
        check([int(x) for x in r.get("defeated_slots", [])] == [3, 4], "B: defeated slots [3, 4]")
    for who, slot in (("Ana", 1), ("Beto", 2)):
        log = read("B", who + ".log")
        check(any(l == "E2E CLIENT %s PASS" % who for l in log), "B: client %s passed all its checks" % who)
        check(any(l == "E2E_SLOT %s slot=%d" % (who, slot) for l in log), "B: client %s sat in slot %d" % (who, slot))
        check(not any("SCRIPT ERROR" in l for l in log), "B: no SCRIPT ERROR in %s's log" % who)
check(not any("SCRIPT ERROR" in l for l in sb), "B: no SCRIPT ERROR in the server log")
try:
    registry = json.load(open(os.path.join(out, "B", "matches", "registry.json")))
    check(registry.get("matches", None) == {}, "B: registry.json has no match")
except (OSError, ValueError):
    check(False, "B: registry.json is readable")
check([e for e in os.listdir(os.path.join(out, "B", "matches")) if e != "registry.json"] == [], "B: no match folder or file left")
sys.exit(1 if fails else 0)
PYEOF
VERDICT=$?
# the dedicated may still be exiting (result delay): wait up to EXIT_WAIT_S for them, then it is a FAIL and they are killed
if wait_gone "match-ticket-file=$OUT" "$EXIT_WAIT_S"; then echo "PASS no dedicated process left"; else echo "FAIL dedicated process still alive after ${EXIT_WAIT_S}s"; VERDICT=1; fi
kill_all 2>/dev/null
wait_gone "$OUT" 5
STRAY=$(godots_with "$OUT")
if [ "$STRAY" != 0 ]; then echo "FAIL $STRAY Godot process of this run still alive after the kill"; VERDICT=1; else echo "PASS no Godot process left"; fi
read -r RSS_KB PROCS < "$OUT/rss.max" 2>/dev/null
echo "RSS max total: $(( ${RSS_KB:-0} / 1024 )) MB, at most ${PROCS:-0} Godot processes at once, $((SECONDS - START_S)) s"
if [ -s "$OUT/timeout.flag" ]; then cat "$OUT/timeout.flag"; VERDICT=1; fi
[ "$READY_A" = 1 ] && [ "$READY_B" = 1 ] || { echo "E2E FAIL: a room server did not announce its port"; VERDICT=1; }
net_stop
if [ "$VERDICT" = 0 ]; then echo "E2E PASS"; rm -rf "$OUT"; else echo "E2E FAIL (logs in $OUT)"; fi
exit "$VERDICT"
