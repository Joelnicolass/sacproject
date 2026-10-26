#!/usr/bin/env bash
# ptnet_real (2026-10-26): network playtest IN WINDOWS, like a real match. One scenario per launch:
#   bash agent/harness/ptnet_real_run.sh <scenario>
# Scenarios (each writes agent/out/ptnet_real/<scenario>/: <who>.log, <who>/*.png, the marker files):
#   cal     calibration: listen host (window) + A (window, pyro) + B (headless): banner, start, the books, a short walk.
#   lan     scenarios 1-4 in one LAN match: host `--listen-host --mode=ffa3 --map=test_flat4` (window, James) + A (window,
#           Pyro) + B (headless): the gate, a real match (summons, fight, terrain spells, a Manalith, a tower down, a soul),
#           A drops by the pause menu and comes back within the grace, B drops and stays away past it (abandon), then C
#           (headless, after B's process ended) tries to join mid-match.
#   intr    scenario 2 with a screenshot: host headless listen 1v1 + A headless + C window that clicks Join after the start.
#   local   scenario 5: «Servidor local» (a dedicated with a ticket, launched by the host window) + a rival window that types
#           the address and the code it read on the host's screen; play, a drop and a rejoin.
# Limits (user, 2026-10-26): at most 2 windows + 1 headless at once, all inside ONE reservation of the Godot queue
# (godot_group.sh, through net_e2e.sh net_group). Processes are killed only by their pid (kill_tree), never pkill.
# The windows are AgentKit flows (agent/flows/ptnet_real_<scenario>_<who>.json) run with --max-fps 60; --fail-on-error only with PTNET_FAIL_ON_ERROR=1 (a product ERROR would end the host and the whole match; every ERROR is reported from the logs instead).
# The observer/pointer is agent/harness/ptnet_real_watch.gd (idle without --ptnet-name).
. "$(dirname "$0")/net_e2e.sh"
net_group 3 "$@"
SC="${1:?usage: ptnet_real_run.sh <cal|lan|intr|local>}"
TAG="PTNET $SC"
LIMIT_S="${PROBE_LIMIT_S:-1200}"
PROC_MAX=3
PORT="${E2E_PORT:-7871}"
GRACE_S="${PTNET_GRACE_S:-30}"
LEVEL="${PTNET_LEVEL:-9}"
OUT="$ROOT/agent/out/ptnet_real/$SC${PTNET_TAG:+_$PTNET_TAG}"
rm -rf "$OUT"; mkdir -p "$OUT"
: > "$OUT/pids"
START_S=$SECONDS
kill_all() { kill_pids; }
trap 'kill_all; net_stop' EXIT
net_guard

win() { # win <who> <x,y> <flow> <game args…>: one AgentKit flow in a window (60 fps cap), log in $OUT/<who>.log
  local who="$1" at="$2" flow="$3"; shift 3
  "$GODOT" --max-fps 60 --path "$ROOT" --resolution 1280x720 --position "$at" -- --agent=flow \
    --flow="res://agent/flows/$flow" --out="res://agent/out/ptnet_real/$SC${PTNET_TAG:+_$PTNET_TAG}/$who" ${PTNET_FAIL_ON_ERROR:+--fail-on-error} \
    --ptnet-name="$who" --ptnet-dir="$OUT" --ptnet-deadline-s="${PTNET_DEADLINE_S:-900}" "$@" > "$OUT/$who.log" 2>&1 &
  LAST_PID=$!; echo "$LAST_PID" >> "$OUT/pids"
  echo "ptnet: $who pid $LAST_PID ($flow)"
}
headless() { # headless <who> <godot args…>: real time (30 fps cap), log in $OUT/<who>.log
  local who="$1"; shift
  "$GODOT" --headless --max-fps 30 --path "$ROOT" "$@" > "$OUT/$who.log" 2>&1 &
  LAST_PID=$!; echo "$LAST_PID" >> "$OUT/pids"
  echo "ptnet: $who pid $LAST_PID (headless)"
}
client_b() { # client_b <who> <flags…>: the headless player debug/net/dedicated_client.tscn
  local who="$1"; shift
  headless "$who" res://debug/net/dedicated_client.tscn -- --mp-port="$PORT" --e2e-name="$who" --ptnet-name="$who" --ptnet-dir="$OUT" --ptnet-deadline-s="${PTNET_DEADLINE_S:-900}" "$@"
}
alive() { kill -0 "$1" 2>/dev/null; }
wait_file() { # wait_file <file> <pid> <timeout_s>
  local end=$((SECONDS + $3))
  while [ "$SECONDS" -lt "$end" ]; do
    [ -e "$1" ] && return 0
    alive "$2" || return 1
    sleep 0.2
  done
  return 1
}

HOST_LAN=(--listen-host --mp-port="$PORT" --rejoin-grace-s="$GRACE_S" --level="$LEVEL" --match-seed=71)

case "$SC" in
  cal)
    win host 0,40 ptnet_real_cal_host.json "${HOST_LAN[@]}" --mode=ffa3 --map=test_flat4
    HOST=$LAST_PID
    wait_line "$OUT/host.log" "^mapa test_flat4" "$HOST" 120
    win A 700,300 ptnet_real_cal_a.json --mp-port="$PORT"
    A=$LAST_PID
    wait_line "$OUT/host.log" "^partida lan: slot 2 cargó el mundo" "$HOST" 120
    client_b B --e2e-expect-slot=3 --e2e-timeout-s=600
    B=$LAST_PID
    wait "$A"; echo "A exit $?"
    kill_tree "$B"; wait "$HOST"; echo "host exit $?"
    ;;
  lan)
    win host 0,40 ptnet_real_lan_host.json "${HOST_LAN[@]}" --mode=ffa3 --map=test_flat4
    HOST=$LAST_PID
    wait_line "$OUT/host.log" "^mapa test_flat4" "$HOST" 120
    win A 700,300 ptnet_real_lan_a.json --mp-port="$PORT"
    A=$LAST_PID
    wait_line "$OUT/host.log" "^partida lan: slot 2 cargó el mundo" "$HOST" 180
    client_b B --e2e-expect-slot=3 --e2e-timeout-s=1000   # the third seat: sits in, idle
    B=$LAST_PID
    wait "$A"; echo "A exit $?"
    wait "$HOST"; echo "host exit $?"
    kill_tree "$B"; wait "$B" 2>/dev/null
    ;;
  lanr)
    win host 0,40 ptnet_real_lanr_host.json "${HOST_LAN[@]}" --mode=ffa3 --map=test_flat4
    HOST=$LAST_PID
    wait_line "$OUT/host.log" "^mapa test_flat4" "$HOST" 120
    win A 700,300 ptnet_real_lanr_a.json --mp-port="$PORT"
    A=$LAST_PID
    wait_line "$OUT/host.log" "^partida lan: slot 2 cargó el mundo" "$HOST" 180
    # B sits in slot 3, drops when told (seconds after the start) and comes back past the grace: grace_over, abandon.
    client_b B --e2e-expect-slot=3 --e2e-rejoin-after-s="${PTNET_B_LEAVE_S:-150}" --e2e-away-s="$((GRACE_S + 12))" \
      --e2e-expect-reason=grace_over --e2e-reject-wait-s=30
    B=$LAST_PID
    wait "$B"; echo "B exit $?"
    : > "$OUT/run.B_done"
    # C: a newcomer after the start (B's process is gone: still 2 windows + 1 headless)
    if alive "$HOST"; then
      client_b C --e2e-expect-reject --e2e-expect-reason=match_started --e2e-expect-status-key=LOCAL_REJECT_MATCH_STARTED --e2e-reject-wait-s=30
      C=$LAST_PID
      wait "$C"; echo "C exit $?"
    fi
    : > "$OUT/run.C_done"
    wait "$A"; echo "A exit $?"
    wait "$HOST"; echo "host exit $?"
    ;;
  intr)
    headless host --max-fps 60 -- "${HOST_LAN[@]}" --mode=1v1 --map=test_flat --ptnet-name=host --ptnet-dir="$OUT"
    HOST=$LAST_PID
    wait_line "$OUT/host.log" "^mapa test_flat" "$HOST" 120
    win A 0,40 ptnet_real_intr_a.json --mp-port="$PORT"
    A=$LAST_PID
    wait_line "$OUT/host.log" "^partida lan: la simulación arranca" "$HOST" 180
    win C 700,300 ptnet_real_intr_c.json --mp-port="$PORT"
    C=$LAST_PID
    wait "$C"; echo "C exit $?"
    : > "$OUT/run.C_done"
    wait "$A"; echo "A exit $?"
    kill_tree "$HOST"; wait "$HOST" 2>/dev/null
    ;;
  intr3)
    # scenario 2 with the intruder in a window: host (window) ffa3 starts early with «Empezar ya» once A (headless) loaded;
    # a seat stays open, so a newcomer reaches the start gate and must be turned away with match_started.
    win host 0,40 ptnet_real_intr3_host.json "${HOST_LAN[@]}" --mode=ffa3 --map=test_flat4
    HOST=$LAST_PID
    wait_line "$OUT/host.log" "^mapa test_flat4" "$HOST" 120
    client_b A --e2e-expect-slot=2 --e2e-timeout-s=400
    A=$LAST_PID
    wait_line "$OUT/host.log" "^partida lan: la simulación arranca" "$HOST" 180
    win C 700,300 ptnet_real_intr3_c.json --mp-port="$PORT"
    C=$LAST_PID
    wait "$C"; echo "C exit $?"
    : > "$OUT/run.C_done"
    wait "$HOST"; echo "host exit $?"
    kill_tree "$A"; wait "$A" 2>/dev/null
    ;;
  local)
    win host 0,40 ptnet_real_local_host.json --level="$LEVEL" --match-args=--level="$LEVEL"
    HOST=$LAST_PID
    # the dedicated it launches writes to the same stdout: its `partida local_…` lines are in host.log
    # the host's flow prints the address, the port and the code it reads on its screen (AGENT_PRINT of %HostPort / %HostCode)
    if wait_line "$OUT/host.log" "AGENT_PRINT node=%HostCode" "$HOST" 180; then
      CODE=$(grep -m1 "AGENT_PRINT node=%HostCode" "$OUT/host.log" | sed -E 's/.*value=[^:]*: *//' | tr -d '[:space:]')
      LPORT=$(grep -m1 "AGENT_PRINT node=%HostPort" "$OUT/host.log" | sed -E 's/.*value=[^0-9]*([0-9]+).*/\1/')
      echo "ptnet: the host's screen shows port $LPORT code $CODE"
      # the rival types what he read: a copy of the flow with the address and the code in its `type` steps
      sed -e "s/@ADDRESS@/127.0.0.1:$LPORT/g" -e "s/@CODE@/$CODE/g" "$ROOT/agent/flows/ptnet_real_local_a.json" > "$ROOT/agent/flows/ptnet_real_local_a_typed.json"
      win A 700,300 ptnet_real_local_a_typed.json
      A=$LAST_PID
      wait "$A"; echo "A exit $?"
    fi
    wait "$HOST"; echo "host exit $?"
    rm -f "$ROOT/agent/flows/ptnet_real_local_a_typed.json"
    ;;
  *) echo "unknown scenario $SC"; exit 2 ;;
esac

kill_all 2>/dev/null
net_stop
read -r RSS_KB PROCS < "$OUT/rss.max" 2>/dev/null
echo "RSS max total: $(( ${RSS_KB:-0} / 1024 )) MB, at most ${PROCS:-0} Godot processes at once, $((SECONDS - START_S)) s"
[ -s "$OUT/timeout.flag" ] && cat "$OUT/timeout.flag"
echo "ptnet: logs in $OUT"
