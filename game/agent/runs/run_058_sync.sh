#!/usr/bin/env bash
# RFC-058 058-3 (criterion 7): every player sees the same sky. A dedicated started by hand + player A + player B, headless,
# for SYNC_RUN_S (300) real seconds:
#   dedicated: `--dedicated --map=test_flat --biome=charnel --match-seed=58 --log=atmosphere` (the land and seed of
#              debug/rules/ambience_storm.tres); it prints `atmosfera semilla <n>` and frees the look (no Atmosphere line).
#   A and B:   agent/fixtures/sky_sync_client.tscn; every 10 s each prints its clock, the match second, the hour, the weather
#              and seed, and each lightning strike since its last line (storm plan debug/look/storm_only.tres).
#   B is a seat that DROPS AND COMES BACK (never a new player joining mid-match): SYNC_DROP_AT_S (20) seconds in it leaves,
#              stays away SYNC_AWAY_S (10) and joins again; it must sit in the same slot and adopt the same seed and clock.
# The verdict: the same seed on the three; A's and B's match seconds against the wall clock agree within 0.5 s (so the hour
# within 0.01 h and the strikes within 0.5 s), before and after B's return; the strikes both printed for the same span are the
# same (time ±0.5 s, heading ±0.5°, distance ±1 m) and ≥ 4 s apart; the dedicated has no Atmosphere (no `atmosfera t=` line).
# REAL TIME on purpose (no --fixed-fps): the dedicated's sky counts match ticks and a client's counts wall seconds, which only
# agree when the server runs at 60 ticks a real second. One group reservation of the Godot queue (3 processes, all headless);
# the waits are on log lines; watchdog LIMIT_S kills by pid and descendants (no pkill). UDP port 7858 (E2E_PORT).
# Needs `--import` once first (new class_names). Prints the checks and SKY SYNC PASS / SKY SYNC FAIL (exit 0 / 1).
. "$(dirname "$0")/../harness/net_e2e.sh"
net_group 3 "$@"
TAG="SKY SYNC"
RUN_S="${SYNC_RUN_S:-300}"
DROP_AT_S="${SYNC_DROP_AT_S:-20}"
AWAY_S="${SYNC_AWAY_S:-10}"
LIMIT_S="${PROBE_LIMIT_S:-$((RUN_S + 120))}"
PROC_MAX=4
PORT="${E2E_PORT:-7858}"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/run_058_sync.XXXXXX")"
START_S=$SECONDS

kill_all() { kill_pids; }
trap 'kill_all; net_stop' EXIT
net_guard

gd "$OUT/server.log" --max-fps 60 -- --dedicated --start-seats=2 --log=atmosphere --mp-port="$PORT" --map=test_flat --biome=charnel --match-seed=58
SERVER=$LAST_PID
READY=0
wait_line "$OUT/server.log" "dedicated listo" "$SERVER" 30 && READY=1
if [ "$READY" = 1 ]; then
  client() { # name, then its flags
    local name="$1"; shift
    gd "$OUT/$name.log" --max-fps 30 res://agent/fixtures/sky_sync_client.tscn -- --mp-port="$PORT" --map=test_flat \
      --e2e-name="$name" --sky-god=charnel --sky-run-s="$RUN_S" "$@"
  }
  client Ana
  ANA=$LAST_PID
  wait_line "$OUT/Ana.log" "PASS Ana gets a slot" "$ANA" 60
  client Beto --sky-drop-at-s="$DROP_AT_S" --sky-away-s="$AWAY_S"
  BETO=$LAST_PID
  wait "$ANA"; wait "$BETO"
fi
kill_tree "$SERVER"
wait "$SERVER" 2>/dev/null

echo "--- server ---"; grep -E "^(dedicated listo|atmosfera|bioma|mapa|SCRIPT ERROR|ERROR)" "$OUT/server.log" | head -n 20
for n in Ana Beto; do echo "--- $n ---"; grep -E "^(PASS|FAIL|SKY $n (sale|vuelve|PASS|FAIL)|SCRIPT ERROR|ERROR)" "$OUT/$n.log" 2>/dev/null | tail -n 20; done
echo "--- verdict ---"
python3 - "$OUT" <<'PYEOF'
import os, re, statistics, sys
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
LINE = re.compile(r"^SKY (\w+) reloj=([\d.]+) t=([\d.]+) hora=([\d.]+) clima=(\w+) semilla=(\d+)$")
STRIKE = re.compile(r"^SKY (\w+) rayo t=([\d.]+) rumbo=([\d.]+) dist=([\d.]+)$")
server = read("server.log")
peers = {}
for name in ("Ana", "Beto"):
    lines, strikes, back = [], [], None
    for l in read(name + ".log"):
        m = LINE.match(l)
        if m:
            lines.append((float(m[2]), float(m[3]), float(m[4]), m[5], int(m[6]), back is not None))
        s = STRIKE.match(l)
        if s:
            strikes.append((float(s[2]), float(s[3]), float(s[4])))
        if l.startswith("SKY %s vuelve" % name):
            back = True
    peers[name] = {"lines": lines, "strikes": strikes, "log": read(name + ".log")}
server_seeds = {int(m[1]) for m in (re.match(r"^atmosfera semilla (\d+)$", l) for l in server) if m}
check(len(server_seeds) == 1, "the dedicated printed one sky seed (%s)" % sorted(server_seeds))
check(not any(l.startswith("atmosfera t=") for l in server), "the dedicated has no Atmosphere (no `atmosfera t=` line)")
check(not any("rayo" in l for l in server), "the dedicated draws no strike")
for name, peer in peers.items():
    check(any(l == "SKY %s PASS" % name for l in peer["log"]), "%s passed its own checks" % name)
    check(len(peer["lines"]) >= 5, "%s printed its sky (%d lines)" % (name, len(peer["lines"])))
    check({row[4] for row in peer["lines"]} <= server_seeds, "%s has the dedicated's seed" % name)
    check({row[3] for row in peer["lines"]} == {"storm"}, "%s: the storm plan rules" % name)
    check(not any("SCRIPT ERROR" in l for l in peer["log"]), "no SCRIPT ERROR in %s's log" % name)
check(any(l.startswith("SKY Beto sale") for l in peers["Beto"]["log"]) and any(l.startswith("SKY Beto vuelve") for l in peers["Beto"]["log"]),
      "Beto dropped and came back (same seat: his own check)")
def offsets(rows, after=None):
    return [t - wall for wall, t, _h, _c, _s, back in rows if after is None or back == after]
ana = offsets(peers["Ana"]["lines"])
for label, after in (("before the drop", False), ("after the return", True)):
    beto = offsets(peers["Beto"]["lines"], after)
    if ana and beto:
        gap = abs(statistics.median(ana) - statistics.median(beto))
        check(gap <= 0.5, "Ana and Beto count the same match second %s (%.3f s apart; hour within %.4f h)" % (label, gap, gap / 60.0))
    else:
        check(False, "Ana and Beto both printed lines %s" % label)
def spans(rows):  # the spans a peer printed strikes for: between two lines of the same sitting
    out, prev = [], None
    for _w, t, _h, _c, _s, back in rows:
        if prev is not None and prev[1] == back and t > prev[0]:
            out.append((prev[0], t))
        prev = (t, back)
    return out
beto_spans = spans(peers["Beto"]["lines"])
shared = [s for s in peers["Ana"]["strikes"] if any(a + 0.5 < s[0] <= b - 0.5 for a, b in beto_spans)]
matched = sum(1 for s in shared if any(abs(s[0] - o[0]) <= 0.5 and abs(s[1] - o[1]) <= 0.5 and abs(s[2] - o[2]) <= 1.0
                                      for o in peers["Beto"]["strikes"]))
check(len(shared) >= 3 and matched == len(shared), "the strikes match on both (%d of %d in the spans both watched)" % (matched, len(shared)))
times = sorted(s[0] for s in peers["Ana"]["strikes"])
check(all(b - a >= 4.0 for a, b in zip(times, times[1:])), "Ana's strikes are 4 s apart or more")
check(all(150.0 <= s[2] <= 600.0 for s in peers["Ana"]["strikes"]), "every strike falls 150-600 m from the camera")
sys.exit(1 if fails else 0)
PYEOF
VERDICT=$?
if [ -s "$OUT/timeout.flag" ]; then cat "$OUT/timeout.flag"; VERDICT=1; fi
net_stop
echo "$((SECONDS - START_S)) s"
if [ "$VERDICT" = 0 ]; then echo "$TAG PASS"; rm -rf "$OUT"; else echo "$TAG FAIL (logs in $OUT)"; fi
exit "$VERDICT"
