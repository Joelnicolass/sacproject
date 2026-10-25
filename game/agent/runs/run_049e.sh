#!/usr/bin/env bash
# RFC-049 049e (F294): the dedicated started by hand plays a 2v2 with three AI, and «Contra la IA» takes a mode. Headless.
#   1. dedicated: `--dedicated --map=test_flat4 --mode=2v2 --ai-slots=2,3,4` (max_players = 1: the three AI seats are never a person's)
#      with the debug world that forces defeats (`--force-defeat-slot=3,4`, `--force-defeat-after-ticks` after the human sat), one client (Ana)
#      that takes slot 1 and a second client (Beto) that must stay out. The server log must show the three `ia slot N lista`, the
#      forced defeats and `partida terminada, gana el equipo 0: slots [1, 2]`; Ana must read winner_slots [1, 2] from the replicated state.
#   2. «Contra la IA» with the mode (`debug/net/vs_ai_mode.tscn`, flags --mode=2v2 --map=test_flat4): AI in slots 2, 3 and 4, slot 2
#      the ally of the player, 3 and 4 foes.
# Processes: dedicated + 2 clients (step 1), one solo (step 2, it starts at the same time: it needs nothing from step 1).
# F350: all of them run inside ONE group reservation of the Godot queue (agent/harness/godot_group.sh), started directly, with --fixed-fps (NET_FPS,
# 600); the waits are on log lines or real seconds (Ana lingers E2E_LINGER_S, Beto waits E2E_REJECT_WAIT_S). Own watchdog: LIMIT_S kills them
# by pid and descendants (no pkill). UDP port 7849 by default (E2E_PORT).
# E2E_AI_GOD=stratos gives the three AI that god (default: drawn from the match seed); E2E_KEEP=1 keeps the logs of a PASS.
# Prints the checks and E2E PASS / E2E FAIL (exit 0 / 1). Needs `--import` once first (new class_names).
. "$(dirname "$0")/../harness/net_e2e.sh"
net_group 4 "$@"
TAG="E2E"
LIMIT_S="${PROBE_LIMIT_S:-120}"
PROC_MAX=5
PORT="${E2E_PORT:-7849}"
FORCE_TICKS="${E2E_FORCE_TICKS:-300}"
LINGER_S="${E2E_LINGER_S:-5}"
REJECT_WAIT_S="${E2E_REJECT_WAIT_S:-3}"
WORLD="res://debug/net/forced_defeat_match.tscn"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/run_049e.XXXXXX")"
START_S=$SECONDS

kill_all() { kill_pids; }
trap 'kill_all; net_stop' EXIT
net_guard

# --- 2 (started first, it runs next to step 1). «Contra la IA» with a mode ------------------------------------------------
gd "$OUT/solo.log" "${FPS_FLAGS[@]}" res://debug/net/vs_ai_mode.tscn -- --mode=2v2 --map=test_flat4 --e2e-seats=4
SOLO=$LAST_PID

# --- 1. the dedicated with three AI ----------------------------------------------------------------------------------
gd "$OUT/server.log" "${FPS_FLAGS[@]}" -- --dedicated --mp-port="$PORT" --map=test_flat4 --mode=2v2 --ai-slots=2,3,4 \
  --world="$WORLD" --force-defeat-slot=3,4 --force-defeat-after-ticks="$FORCE_TICKS" ${E2E_AI_GOD:+--ai-god="$E2E_AI_GOD"}
SERVER=$LAST_PID
READY=0
wait_line "$OUT/server.log" "dedicated listo" "$SERVER" 30 && READY=1
if [ "$READY" = 1 ]; then
  gd "$OUT/Ana.log" "${FPS_FLAGS[@]}" res://debug/net/dedicated_client.tscn -- --mp-port="$PORT" --world="$WORLD" --e2e-name=Ana --e2e-expect-slot=1 \
    --e2e-expect-mode=2v2 --e2e-expect-winners=1,2 --e2e-timeout-s=60 --e2e-linger-s="$LINGER_S"
  ANA=$LAST_PID
  wait_line "$OUT/Ana.log" "PASS Ana gets a slot" "$ANA" 60
  gd "$OUT/Beto.log" "${FPS_FLAGS[@]}" res://debug/net/dedicated_client.tscn -- --mp-port="$PORT" --world="$WORLD" --e2e-name=Beto --e2e-expect-reject \
    --e2e-reject-wait-s="$REJECT_WAIT_S"
  BETO=$LAST_PID
  wait "$ANA"; wait "$BETO"
fi
kill_tree "$SERVER"
wait "$SERVER" 2>/dev/null
wait "$SOLO"

# --- verdict -------------------------------------------------------------------------------------------------------
echo "--- server ---"; grep -E "^(dedicado|dedicated listo|ia slot|derrota forzada|partida terminada|bando|modo|mapa|SCRIPT ERROR|ERROR)" "$OUT/server.log" | head -n 40
for n in Ana Beto; do echo "--- $n ---"; grep -E "^(PASS|FAIL|E2E|SCRIPT ERROR|ERROR|modo|mapa)" "$OUT/$n.log" 2>/dev/null | tail -n 20; done
echo "--- solo ---"; grep -E "^(PASS|FAIL|VS_AI_MODE|ia slot|SCRIPT ERROR|ERROR)" "$OUT/solo.log" | head -n 20
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
server, ana, beto, solo = read("server.log"), read("Ana.log"), read("Beto.log"), read("solo.log")
check(any(l.startswith("dedicado con ia en slots [2, 3, 4]") for l in server), "the dedicated read --ai-slots=2,3,4")
check(any(l.startswith("dedicated listo") for l in server), "the dedicated listened")
for slot in (2, 3, 4):
    check(any(l.startswith("ia slot %d lista" % slot) for l in server), "ia slot %d lista" % slot)
check(any(l.startswith("derrota forzada del slot 3") for l in server) and any(l.startswith("derrota forzada del slot 4") for l in server), "the slots 3 and 4 were defeated by the hook")
check(any(re.match(r"^partida terminada, gana el equipo \d+: slots \[1, 2\]$", l) for l in server), "partida terminada: the team of slots [1, 2] wins")
check(not any("SCRIPT ERROR" in l for l in server), "no SCRIPT ERROR in the server log")
check(any(l == "E2E CLIENT Ana PASS" for l in ana), "Ana passed all her checks (slot 1, mode 2v2, winner_slots [1, 2])")
check(any(l.startswith("E2E_RESULT Ana winner_slots=[1, 2]") for l in ana), "Ana read winner_slots [1, 2] from the replicated MatchState")
check(not any("SCRIPT ERROR" in l for l in ana), "no SCRIPT ERROR in Ana's log")
check(any(l == "E2E CLIENT Beto PASS" for l in beto), "Beto (the extra human) is left out: no slot, no world")
check(any(l == "VS_AI_MODE PASS" for l in solo), "«Contra la IA» with --mode=2v2: AI in slots 2, 3, 4, slot 2 an ally and 3, 4 foes")
for slot in (2, 3, 4):
    check(any(l.startswith("ia slot %d lista" % slot) for l in solo), "solo: ia slot %d lista" % slot)
check(not any("SCRIPT ERROR" in l for l in solo), "no SCRIPT ERROR in the solo log")
sys.exit(1 if fails else 0)
PYEOF
VERDICT=$?
kill_all 2>/dev/null
wait_gone "--mp-port=$PORT" 5
STRAY=$(godots_with "--mp-port=$PORT")
if [ "$STRAY" != 0 ]; then echo "FAIL $STRAY Godot process of this run still alive after the kill"; VERDICT=1; else echo "PASS no Godot process left"; fi
[ "$READY" = 1 ] || { echo "E2E FAIL: the dedicated did not announce its port"; VERDICT=1; }
[ -s "$OUT/timeout.flag" ] && { cat "$OUT/timeout.flag"; VERDICT=1; }
net_stop
echo "$((SECONDS - START_S)) s"
if [ "$VERDICT" = 0 ]; then echo "E2E PASS"; [ -n "${E2E_KEEP:-}" ] && echo "logs in $OUT" || rm -rf "$OUT"; else echo "E2E FAIL (logs in $OUT)"; fi
exit "$VERDICT"
