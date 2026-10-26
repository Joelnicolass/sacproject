#!/usr/bin/env bash
# RFC-068 (F392): the start gate of a LAN match. A listen host waits, paused, until its seats load; then only a seat that dropped
# comes back, within the grace. The host is the game itself (boot -> SacrificeFlow -> match.tscn), no debug world:
#   host `--listen-host --mode=ffa3 --map=test_flat4 --rejoin-grace-s=6` (slot 1) and three headless debug/net/dedicated_client:
#   A (slot 2) leaves 2 s after the start and comes back 2 s later; B (slot 3) leaves 6 s after the start and comes back 10 s later,
#   past the grace; C joins once the match runs and is turned away.
# Criteria (rfcs/RFC-068-start-gate.md §1), read from the `partida lan: …` lines of the host and the clients' PASS/FAIL lines:
#   1. `slot 2 cargó el mundo (1/2)` and `slot 3 cargó el mundo (2/2)` come BEFORE `la simulación arranca (todos cargaron) en el tick 0`;
#   2. A and B print `E2E_CLOCK <name> at_start=<n>` with n <= 2 (they waited paused);
#   3. C ends with no slot and no world, turned away with `match_started`; the host prints `peer N rechazado (match_started)` and
#      C's status shows LOCAL_REJECT_MATCH_STARTED;
#   4. A is back in slot 2 and sees its Wizards/Wizard2; the host logs `slot 2 mago en X Z, … (al irse)` and `(al volver)` with
#      the same X Z (±0.1 m) and the same rest of the line (the same wizard and creatures);
#   5. B's return is turned away with `grace_over` (host: `peer N rechazado (grace_over)`, `slot 3 abandonó y pierde`).
# Processes: at most 4 Godot (the host and three clients; GATE_WINDOW=1 shows the host in a window, the clients stay headless).
# All of them run inside ONE group reservation of the Godot queue (agent/harness/godot_group.sh, the same FIFO as godot_run.sh: a
# server and its clients started one by one through the per-process queue would wait for each other). --fixed-fps NET_FPS (600)
# on the headless processes; every wait is a log line or real seconds. Own watchdog: LIMIT_S kills them by pid and descendants
# (no pkill). UDP port 7868 by default (E2E_PORT). E2E_KEEP=1 keeps the logs of a PASS. Needs `--import` once first.
# Prints the checks and GATE PASS / GATE FAIL (exit 0 / 1).
. "$(dirname "$0")/../harness/net_e2e.sh"
net_group 4 "$@"
TAG="GATE"
LIMIT_S="${PROBE_LIMIT_S:-150}"
PROC_MAX=4
PORT="${E2E_PORT:-7868}"
GRACE_S="${E2E_GRACE_S:-6}"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/run_068_gate.XXXXXX")"
START_S=$SECONDS

kill_all() { kill_pids; }
trap 'kill_all; net_stop' EXIT
net_guard

HOST_FLAGS=(-- --listen-host --mp-port="$PORT" --mode=ffa3 --map=test_flat4 --rejoin-grace-s="$GRACE_S")
if [ -n "${GATE_WINDOW:-}" ]; then # the human view: the host in a window (the paused world and «Esperando jugadores k/n»)
  "$GODOT" --path "$ROOT" "${HOST_FLAGS[@]}" > "$OUT/host.log" 2>&1 &
  LAST_PID=$!; echo "$LAST_PID" >> "$OUT/pids"
else
  gd "$OUT/host.log" "${FPS_FLAGS[@]}" "${HOST_FLAGS[@]}"
fi
HOST=$LAST_PID
client() { # client <name> <flags…>
  local name="$1"; shift
  gd "$OUT/$name.log" "${FPS_FLAGS[@]}" res://debug/net/dedicated_client.tscn -- --mp-port="$PORT" --e2e-name="$name" "$@"
}

READY=0
wait_line "$OUT/host.log" "^mapa test_flat4" "$HOST" 60 && READY=1
if [ "$READY" = 1 ]; then
  client A --e2e-expect-slot=2 --e2e-rejoin-after-s=2 --e2e-away-s=2
  A=$LAST_PID
  wait_line "$OUT/A.log" "PASS A gets a slot" "$A" 60
  client B --e2e-expect-slot=3 --e2e-rejoin-after-s=6 --e2e-away-s=10 --e2e-expect-reason=grace_over --e2e-reject-wait-s=15
  B=$LAST_PID
  if wait_line "$OUT/host.log" "^partida lan: la simulación arranca" "$HOST" 60; then
    client C --e2e-expect-reject --e2e-expect-reason=match_started --e2e-expect-status-key=LOCAL_REJECT_MATCH_STARTED --e2e-reject-wait-s=20
    C=$LAST_PID
    wait "$C"
  fi
  wait "$A"; wait "$B"
fi
kill_tree "$HOST"
wait "$HOST" 2>/dev/null

# --- verdict -------------------------------------------------------------------------------------------------------
echo "--- host ---"; grep -E "^(partida lan|mapa|modo|SCRIPT ERROR|ERROR)" "$OUT/host.log" | head -n 60
for n in A B C; do echo "--- $n ---"; grep -E "^(PASS|FAIL|E2E|SCRIPT ERROR|ERROR)" "$OUT/$n.log" 2>/dev/null | tail -n 25; done
echo "--- verdict ---"
python3 - "$OUT" <<'PYEOF'
import os, re, sys
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
host, a, b, c = read("host.log"), read("A.log"), read("B.log"), read("C.log")
pre = "partida lan: "
lan = [l for l in host if l.startswith(pre)]
def first(rx):
    for i, l in enumerate(lan):
        if re.match("^" + re.escape(pre) + rx, l):
            return i
    return -1

# 1. both seats loaded, then the start at tick 0
one, two = first(r"slot 2 cargó el mundo \(1/2\)$"), first(r"slot 3 cargó el mundo \(2/2\)$")
start = first(r"la simulación arranca \(todos cargaron\) en el tick 0$")
check(one >= 0 and two >= 0, "the host logged slot 2 (1/2) and slot 3 (2/2) loading the world")
check(start >= 0, "the host logged `la simulación arranca (todos cargaron) en el tick 0`")
check(start > one >= 0 and start > two >= 0, "both seats loaded BEFORE the start (lines %d, %d, start %d)" % (one, two, start))

# 2. the clients waited paused
for name, log in (("A", a), ("B", b)):
    clock = [int(m.group(1)) for m in (re.match(r"^E2E_CLOCK %s at_start=(-?\d+)$" % name, l) for l in log) if m]
    check(len(clock) >= 1 and 0 <= clock[0] <= 2, "%s saw the start at MatchClock tick <= 2 (got %s)" % (name, clock[:1]))

# 3. a newcomer after the start is turned away
check(any(l == "E2E CLIENT C PASS" for l in c), "C passed: no slot, no world, reason match_started, the status shows the refusal")
check(first(r"peer \d+ rechazado \(match_started\)$") > start >= 0, "the host turned a peer away with match_started after the start")
check(not any("slot 4" in l for l in lan), "no fourth seat was ever given")

# 4. A drops and comes back to the same seat, the same wizard where it stood
check(any(l == "E2E CLIENT A PASS" for l in a), "A passed all its checks (slot 2, same slot again, sees Wizards/Wizard2)")
check(any(l == "E2E_BACK A slot=2" for l in a), "A came back to slot 2")
check(lan.count(pre + "slot 2 se fue") == 1 and lan.count(pre + "slot 2 volvió") == 1, "the host logged slot 2 leaving once and coming back once")
def state(slot, when):
    for l in lan:
        m = re.match(r"^" + re.escape(pre) + r"slot %d (.*) \(%s\)$" % (slot, when), l)
        if m:
            return m.group(1)
    return None
gone, back = state(2, "al irse"), state(2, "al volver")
check(gone is not None and back is not None, "the host logged the state of slot 2 at the drop and at the return")
if gone and back:
    pos = r"mago en (-?\d+(?:\.\d+)?) (-?\d+(?:\.\d+)?)"
    mg, mb = re.search(pos, gone), re.search(pos, back)
    check(mg is not None and mb is not None, "slot 2 had a wizard at the drop and at the return (%s | %s)" % (gone, back))
    if mg and mb:
        dx, dz = abs(float(mg.group(1)) - float(mb.group(1))), abs(float(mg.group(2)) - float(mb.group(2)))
        check(dx <= 0.11 and dz <= 0.11, "the wizard of slot 2 stood still while away (dx %.2f dz %.2f m)" % (dx, dz))
        check(re.sub(pos, "", gone) == re.sub(pos, "", back), "the same wizard and creatures at the return (%s | %s)" % (gone, back))

# 5. B comes back past the grace and is turned away
check(any(l == "E2E CLIENT B PASS" for l in b), "B passed: slot 3, then its late return turned away with grace_over")
check(lan.count(pre + "slot 3 se fue") == 1 and lan.count(pre + "slot 3 volvió") == 0, "slot 3 left and never came back")
check(first(r"slot 3 abandonó y pierde$") >= 0, "the host declared slot 3 abandoned past the grace")
check(first(r"peer \d+ rechazado \(grace_over\)$") >= 0, "the host turned B's return away with grace_over")

for name, log in (("host", host), ("A", a), ("B", b), ("C", c)):
    check(not any("SCRIPT ERROR" in l for l in log), "no SCRIPT ERROR in the %s log" % name)
sys.exit(1 if fails else 0)
PYEOF
VERDICT=$?
kill_all 2>/dev/null
wait_gone "--mp-port=$PORT" 5
STRAY=$(godots_with "--mp-port=$PORT")
if [ "$STRAY" != 0 ]; then echo "FAIL $STRAY Godot process of this run still alive after the kill"; VERDICT=1; else echo "PASS no Godot process left"; fi
[ "$READY" = 1 ] || { echo "GATE FAIL: the host never loaded test_flat4"; VERDICT=1; }
[ -s "$OUT/timeout.flag" ] && { cat "$OUT/timeout.flag"; VERDICT=1; }
net_stop
echo "$((SECONDS - START_S)) s"
if [ "$VERDICT" = 0 ]; then echo "GATE PASS"; [ -n "${E2E_KEEP:-}" ] && echo "logs in $OUT" || rm -rf "$OUT"; else echo "GATE FAIL (logs in $OUT)"; fi
exit "$VERDICT"
