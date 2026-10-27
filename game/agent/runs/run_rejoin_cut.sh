#!/usr/bin/env bash
# MpKit 0.12 + 069: a seat comes back after a NETWORK CUT (not a clean leave). Headless.
#   dedicated `--dedicated --start-seats=1 --map=test_flat --rejoin-grace-s=GRACE_S` (60) and one client A
#   (debug/net/dedicated_client.tscn --e2e-cut-watch). Once the match runs A prints E2E_READY_TO_CUT; the run freezes A (SIGSTOP)
#   until the server drops it on its own (ENet timeout: `slot 1 se fue`), then lets it go (SIGCONT). A loses the server, joins again
#   with the credential it kept and must sit in slot 1 and see its own Wizard1; the server logs `slot 1 volvió`.
# Processes: the dedicated + A inside one group reservation of the queue. UDP port 7885 (E2E_PORT). Kills only by pid.
# Prints REJOIN CUT PASS / REJOIN CUT FAIL (exit 0 / 1). E2E_KEEP=1 keeps the logs of a PASS.
. "$(dirname "$0")/../harness/net_e2e.sh"
net_group 2 "$@"
TAG="REJOIN CUT"
LIMIT_S="${PROBE_LIMIT_S:-240}"
PROC_MAX=3
PORT="${E2E_PORT:-7885}"
GRACE_S="${E2E_GRACE_S:-60}"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/run_rejoin_cut.XXXXXX")"
START_S=$SECONDS

kill_all() { kill_pids; }
trap 'kill_all; net_stop' EXIT
net_guard

gd "$OUT/server.log" "${FPS_FLAGS[@]}" -- --dedicated --start-seats=1 --mp-port="$PORT" --map=test_flat --rejoin-grace-s="$GRACE_S"
SERVER=$LAST_PID
READY=0
CUT=0
wait_line "$OUT/server.log" "dedicated listo" "$SERVER" 60 && READY=1
if [ "$READY" = 1 ]; then
  gd "$OUT/A.log" "${FPS_FLAGS[@]}" res://debug/net/dedicated_client.tscn -- --mp-port="$PORT" --e2e-name=A --e2e-expect-slot=1 \
    --e2e-cut-watch --e2e-linger-s=2
  A=$LAST_PID
  if wait_line "$OUT/A.log" "^E2E_READY_TO_CUT" "$A" 90; then
    kill -STOP "$A"
    echo "cut: A frozen at $((SECONDS - START_S)) s"
    wait_line "$OUT/server.log" "slot 1 se fue" "$SERVER" 60 && CUT=1
    kill -CONT "$A"
    echo "cut: A let go at $((SECONDS - START_S)) s (server dropped it: $CUT)"
  fi
  wait "$A"
fi
kill_tree "$SERVER"
wait "$SERVER" 2>/dev/null

echo "--- server ---"; grep -E "^(dedicated listo|partida |SCRIPT ERROR|ERROR)" "$OUT/server.log" | head -n 30
echo "--- A ---"; grep -E "^(PASS|FAIL|E2E|SCRIPT ERROR)" "$OUT/A.log" 2>/dev/null | tail -n 16
echo "--- verdict ---"
python3 - "$OUT" "$CUT" <<'PYEOF'
import os, sys
out, cut = sys.argv[1], sys.argv[2] == "1"
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
server, a = read("server.log"), read("A.log")
check(cut, "the server dropped the frozen client by itself (`slot 1 se fue`, no clean leave)")
left = next((i for i, l in enumerate(server) if l.endswith("slot 1 se fue")), -1)
back = next((i for i, l in enumerate(server) if l.endswith("slot 1 volvió")), -1)
check(left >= 0 and back > left, "the server logged slot 1 leaving, then coming back")
check(any(l == "E2E CLIENT A PASS" for l in a), "A: lost the server, back in slot 1 with its own Wizard1")
for name, lines in (("server", server), ("A", a)):
    check(not any("SCRIPT ERROR" in l for l in lines), "no SCRIPT ERROR in the %s log" % name)
sys.exit(1 if fails else 0)
PYEOF
VERDICT=$?
kill_all 2>/dev/null
wait_gone "--mp-port=$PORT" 5
STRAY=$(godots_with "--mp-port=$PORT")
if [ "$STRAY" != 0 ]; then echo "FAIL $STRAY Godot process of this run still alive after the kill"; VERDICT=1; else echo "PASS no Godot process left"; fi
[ "$READY" = 1 ] || { echo "REJOIN CUT FAIL: the dedicated did not announce its port"; VERDICT=1; }
[ -s "$OUT/timeout.flag" ] && { cat "$OUT/timeout.flag"; VERDICT=1; }
net_stop
echo "$((SECONDS - START_S)) s"
if [ "$VERDICT" = 0 ]; then echo "REJOIN CUT PASS"; [ -n "${E2E_KEEP:-}" ] && echo "logs in $OUT" || rm -rf "$OUT"; else echo "REJOIN CUT FAIL (logs in $OUT)"; fi
exit "$VERDICT"
