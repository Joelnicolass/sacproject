#!/usr/bin/env bash
# RFC-034 034h (F185): stability soak of the room server, headless, no windows.
# Usage: bash agent/runs/run_034_soak.sh [N] [transports]     defaults: N=3, transports="enet ws"
# Each pass runs, for each transport, the two-rooms-in-parallel scenario (run_034e.sh: 1 room server + 4 clients +
# 2 real dedicated) and the reconnection scenario (run_034g.sh: 1 server + 3 clients + 1 dedicated). The scripts run
# one at a time; the lobby port rotates on every run so a socket still in TIME_WAIT never collides with the next one.
# After every run it checks that no Godot process of this project that was not there before is left alive and that no
# match folder / temp dir with logs of a PASS is left (a FAIL keeps its logs on purpose and is reported).
# Caps: each run has an external cap (RUN_CAP_S, default 300 s) enforced here by pid (and descendants); the scripts
# also carry their own internal caps. Never pkill/killall: only pids that this script started or that it found new.
# Prints one summary line per run and SOAK PASS / SOAK FAIL (exit 0 / 1). Needs `--import` once first.
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
N="${1:-3}"
TRANSPORTS="${2:-enet ws}"
RUN_CAP_S="${SOAK_RUN_CAP_S:-300}"
BASE_PORT="${SOAK_BASE_PORT:-7720}"
TMP="${TMPDIR:-/tmp}"
case "$N" in ''|*[!0-9]*) echo "usage: run_034_soak.sh [N] [\"enet ws\"]"; exit 2;; esac

descendants() { # pid -> pid and all its descendants
  local p="$1" c
  echo "$p"
  for c in $(pgrep -P "$p" 2>/dev/null); do descendants "$c"; done
}
kill_tree() { local p; for p in $(descendants "$1" | sort -rn); do kill "$p" 2>/dev/null; done; }
godot_pids() { # pids of the Godot processes of this project
  ps -axo pid=,args= | awk -v root="$ROOT" '$2 ~ /\/Godot$/ && index($0, root) {print $1}' | sort -n
}
CUR=""
trap '[ -n "$CUR" ] && kill_tree "$CUR"' EXIT INT TERM

TOTAL=0; BAD=0; IDX=0
SUMMARY=""
for ((i = 1; i <= N; i++)); do
  for tr in $TRANSPORTS; do
    for scen in 034e 034g; do
      TOTAL=$((TOTAL + 1))
      IDX=$((IDX + 1))
      PORT=$((BASE_PORT + IDX * 2))
      LOG="$(mktemp "$TMP/soak_034_${scen}_${tr}_${i}.XXXXXX")"
      BEFORE="$(godot_pids | tr '\n' ' ')"
      DIRS_BEFORE="$(ls -d "$TMP"/room_e2e_034e.* "$TMP"/room_rejoin_034g.* 2>/dev/null | sort)"
      T0=$SECONDS
      TRANSPORT="$tr" E2E_LOBBY_PORT="$PORT" bash "$ROOT/agent/run_$scen.sh" > "$LOG" 2>&1 &
      CUR=$!
      ( sleep "$RUN_CAP_S"; kill -0 "$CUR" 2>/dev/null && { echo "SOAK external cap ${RUN_CAP_S}s" >> "$LOG"; kill_tree "$CUR"; } ) &
      CAPPER=$!
      wait "$CUR"; RC=$?
      kill "$CAPPER" 2>/dev/null; wait "$CAPPER" 2>/dev/null
      CUR=""
      sleep 2
      # orphans: Godot processes of this project that were not there before the run
      ORPH=""
      for p in $(godot_pids); do
        case " $BEFORE " in *" $p "*) ;; *) ORPH="$ORPH $p";; esac
      done
      for p in $ORPH; do kill "$p" 2>/dev/null; done # by pid only
      # leftover dirs: new temp dirs of the scenarios (a PASS removes its own; a FAIL keeps logs)
      DIRS_AFTER="$(ls -d "$TMP"/room_e2e_034e.* "$TMP"/room_rejoin_034g.* 2>/dev/null | sort)"
      LEFT="$(comm -13 <(printf '%s\n' "$DIRS_BEFORE") <(printf '%s\n' "$DIRS_AFTER") | tr '\n' ' ')"
      VERDICT_LINE="$(grep -E "^E2E( REJOIN)? (PASS|FAIL)" "$LOG" | tail -n 1)"
      RSS_LINE="$(grep -E "^RSS max total" "$LOG" | tail -n 1)"
      OK=1
      [ "$RC" = 0 ] || OK=0
      case "$VERDICT_LINE" in "E2E PASS"|"E2E REJOIN PASS") ;; *) OK=0;; esac
      [ -z "$ORPH" ] || OK=0
      [ -z "${LEFT// /}" ] || OK=0
      if [ "$OK" = 1 ]; then ST="PASS"; rm -f "$LOG"; else ST="FAIL"; BAD=$((BAD + 1)); fi
      LINE="run $TOTAL (pass $i, $scen, $tr, lobby $PORT): $ST rc=$RC orphans=[${ORPH# }] leftover=[${LEFT% }] $((SECONDS - T0))s | ${VERDICT_LINE:-no verdict} | ${RSS_LINE:-no rss}"
      [ "$OK" = 1 ] || LINE="$LINE | log $LOG"
      echo "$LINE"
    done
  done
done
echo "--- $((TOTAL - BAD))/$TOTAL runs PASS"
if [ "$BAD" = 0 ]; then echo "SOAK PASS"; exit 0; else echo "SOAK FAIL"; exit 1; fi
