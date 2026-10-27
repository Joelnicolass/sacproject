#!/usr/bin/env bash
# MpKit 0.12 + 069: a dedicated started by hand serves one match after another without a restart. Headless.
#   dedicated `--dedicated --map=test_flat --ai-slots=2` (1v1 against an AI, one human seat) on the debug world that forces a
#   defeat (`--force-defeat-slot=2` after `--force-defeat-after-ticks` from the first seat): no --start-seats, no --late-join.
#   1. Ana joins, the match ends (slot 1 wins), Ana leaves after the result;
#   2. her seat is away; past the grace nobody is left (the gate's all_gone): the dedicated loads a fresh world and opens the seat
#      again (MpFlow.next_open_match). The game's end of match does not reach MpKit (no MpMatch.finish / broadcast_session_ended
#      on a dedicated by hand), so the faster path «finished and empty» does not fire: the run waits the grace (GRACE_S, 5 s);
#   3. Bea joins the SAME process, sits in slot 1, plays a second match and reads its result.
# Checks: two `partida terminada` lines in the one server log, both clients PASS with winner_slots [1], no SCRIPT ERROR.
# Processes: the dedicated + one client at a time, inside one group reservation of the queue. UDP port 7883 (E2E_PORT).
# Prints NEXT MATCH PASS / NEXT MATCH FAIL (exit 0 / 1). E2E_KEEP=1 keeps the logs of a PASS.
. "$(dirname "$0")/../harness/net_e2e.sh"
net_group 2 "$@"
TAG="NEXT MATCH"
LIMIT_S="${PROBE_LIMIT_S:-240}"
PROC_MAX=3
PORT="${E2E_PORT:-7883}"
FORCE_TICKS="${E2E_FORCE_TICKS:-240}"
GRACE_S="${E2E_GRACE_S:-5}"
WORLD="res://debug/net/forced_defeat_match.tscn"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/run_next_match.XXXXXX")"
START_S=$SECONDS

kill_all() { kill_pids; }
trap 'kill_all; net_stop' EXIT
net_guard

gd "$OUT/server.log" "${FPS_FLAGS[@]}" -- --dedicated --mp-port="$PORT" --map=test_flat --ai-slots=2 --world="$WORLD" --rejoin-grace-s="$GRACE_S" \
  --force-defeat-slot=2 --force-defeat-after-ticks="$FORCE_TICKS"
SERVER=$LAST_PID
READY=0
wait_line "$OUT/server.log" "dedicated listo" "$SERVER" 60 && READY=1
if [ "$READY" = 1 ]; then
  for who in Ana Bea; do
    gd "$OUT/$who.log" "${FPS_FLAGS[@]}" res://debug/net/dedicated_client.tscn -- --mp-port="$PORT" --world="$WORLD" --e2e-name="$who" \
      --e2e-expect-slot=1 --e2e-expect-winners=1 --e2e-timeout-s=90
    wait "$LAST_PID"
    [ "$who" = Ana ] && sleep $((GRACE_S + 3)) # past the grace: all_gone, a fresh world
  done
fi
kill_tree "$SERVER"
wait "$SERVER" 2>/dev/null

echo "--- server ---"; grep -E "^(dedicated listo|partida |derrota forzada|SCRIPT ERROR|ERROR)" "$OUT/server.log" | head -n 40
for n in Ana Bea; do echo "--- $n ---"; grep -E "^(PASS|FAIL|E2E|SCRIPT ERROR)" "$OUT/$n.log" 2>/dev/null | tail -n 12; done
echo "--- verdict ---"
python3 - "$OUT" <<'PYEOF'
import os, sys
out = sys.argv[1]
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
server, ana, bea = read("server.log"), read("Ana.log"), read("Bea.log")
ends = [l for l in server if l.startswith("partida terminada")]
check(len(ends) == 2, "one dedicated process played two matches (%d `partida terminada`)" % len(ends))
check(any(l == "E2E CLIENT Ana PASS" for l in ana), "Ana: slot 1, first match, winner_slots [1]")
check(any(l == "E2E CLIENT Bea PASS" for l in bea), "Bea: slot 1 again in the same process, second match, winner_slots [1]")
for name, lines in (("server", server), ("Ana", ana), ("Bea", bea)):
    check(not any("SCRIPT ERROR" in l for l in lines), "no SCRIPT ERROR in the %s log" % name)
sys.exit(1 if fails else 0)
PYEOF
VERDICT=$?
kill_all 2>/dev/null
wait_gone "--mp-port=$PORT" 5
STRAY=$(godots_with "--mp-port=$PORT")
if [ "$STRAY" != 0 ]; then echo "FAIL $STRAY Godot process of this run still alive after the kill"; VERDICT=1; else echo "PASS no Godot process left"; fi
[ "$READY" = 1 ] || { echo "NEXT MATCH FAIL: the dedicated did not announce its port"; VERDICT=1; }
[ -s "$OUT/timeout.flag" ] && { cat "$OUT/timeout.flag"; VERDICT=1; }
net_stop
echo "$((SECONDS - START_S)) s"
if [ "$VERDICT" = 0 ]; then echo "NEXT MATCH PASS"; [ -n "${E2E_KEEP:-}" ] && echo "logs in $OUT" || rm -rf "$OUT"; else echo "NEXT MATCH FAIL (logs in $OUT)"; fi
exit "$VERDICT"
