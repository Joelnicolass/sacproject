#!/usr/bin/env bash
# F350: shared pieces of the network e2e scripts (agent/runs/run_net_quick.sh, run_034*.sh, run_049*.sh). Source it, do not run it:
#   . "$(dirname "$0")/../harness/net_e2e.sh"
#   net_group 6 "$@"        # FIRST thing: re-run this script inside a group reservation of the Godot queue (see godot_group.sh)
# Then the script sets OUT / LIMIT_S / TAG / PROC_MAX and uses:
#   gd <log> <godot args…>      start a headless Godot directly (not through godot_run.sh): LAST_PID, pid saved in $OUT/pids
#   net_guard                   start the watchdog (LIMIT_S wall) and the monitor (RSS_LIMIT_MB, PROC_MAX processes)
#   wait_line <file> <regex> <pid> <timeout_s>   wait for a log line (0.1 s), or the pid dying, or the timeout; 0 = found
#   wait_gone <awk-pattern> <timeout_s>          wait until no Godot of this run has that text in its command line
#   net_stop                    stop the guard processes
# Speed knobs (environment): NET_FPS (default 600): `--fixed-fps` of every process, i.e. no real-time wait between frames.
# The tick semantics do not change (60 physics ticks per simulated second); only the wall time shrinks.
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
GODOT="$GODOT_BIN"
NET_FPS="${NET_FPS:-600}"
FPS_FLAGS=(--fixed-fps "$NET_FPS")
RSS_LIMIT_MB="${E2E_RSS_LIMIT_MB:-8192}"

net_group() { # net_group <N> "$@": inside the group reservation (all later Godot processes are launched with `gd`)
  [ -n "${GODOT_GROUP:-}" ] && return 0
  local n="$1"; shift
  exec bash "$ROOT/agent/harness/godot_group.sh" "$n" -- bash "${BASH_SOURCE[1]}" "$@"
}

descendants() { # pid -> pid and all its descendants
  local p="$1" c
  echo "$p"
  for c in $(pgrep -P "$p" 2>/dev/null); do descendants "$c"; done
}
kill_tree() { local p; for p in $(descendants "$1" | sort -rn); do kill "$p" 2>/dev/null; done; }
kill_pids() { # kill (by pid, with descendants) every pid of the file $OUT/pids
  local p
  for p in $(cat "$OUT/pids" 2>/dev/null); do [ -n "$p" ] && kill_tree "$p"; done
}

gd() { # gd <log> <godot args…>; the pid is in LAST_PID. Always headless, with the project; no queue (we are in a group).
  local log="$1"; shift
  if [ -n "${NET_TS:-}" ]; then # debugging: every log line starts with the seconds since the group started
    ( "$GODOT" --headless --path "$ROOT" "$@" 2>&1 | perl -MTime::HiRes=time -ne 'BEGIN{$|=1;$t=$ENV{NET_T0}} printf "%.2f %s", time-$t, $_' > "$log" ) &
  else
    "$GODOT" --headless --path "$ROOT" "$@" > "$log" 2>&1 &
  fi
  LAST_PID=$!
  echo "$LAST_PID" >> "$OUT/pids"
}

# kill_all must be defined by the script (it knows its dedicated processes); the guard calls it.
net_guard() {
  ( # external timeout
    sleep "$LIMIT_S"
    echo "$TAG FAIL: external timeout ${LIMIT_S}s" > "$OUT/timeout.flag"
    kill_all
  ) &
  WATCH=$!; disown $WATCH
  ( # total RSS and number of the Godot processes of this project, and a brake for the machine
    max=0; maxn=0
    while :; do
      read -r tot n < <(ps -axo rss=,args= | awk -v root="$ROOT" '$2 ~ /\/Godot$/ && index($0, root) {s += $1; c++} END {print s + 0, c + 0}')
      [ "$tot" -gt "$max" ] && max=$tot
      [ "$n" -gt "$maxn" ] && maxn=$n
      echo "$max $maxn" > "$OUT/rss.max"
      if [ $((tot / 1024)) -gt "$RSS_LIMIT_MB" ]; then
        echo "$TAG FAIL: RSS $((tot / 1024)) MB over the limit ($RSS_LIMIT_MB MB)" > "$OUT/timeout.flag"
        kill_all
      elif [ "$n" -gt "${PROC_MAX:-9}" ]; then
        echo "$TAG FAIL: $n Godot processes, over the limit (${PROC_MAX:-9})" > "$OUT/timeout.flag"
        kill_all
      fi
      sleep 1
    done
  ) &
  MONITOR=$!; disown $MONITOR
}

net_stop() { local p; for p in $WATCH $MONITOR; do [ -n "$p" ] && kill_tree "$p"; done; WATCH=""; MONITOR=""; }

wait_line() { # wait_line <file> <regex> <pid> <timeout_s>
  local file="$1" re="$2" pid="$3" end=$((SECONDS + ${4:-60}))
  while [ "$SECONDS" -lt "$end" ]; do
    grep -q -E "$re" "$file" 2>/dev/null && return 0
    [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null && { grep -q -E "$re" "$file" 2>/dev/null; return $?; }
    sleep 0.1
  done
  return 1
}

godots_with() { # number of Godot processes with this text in their command line
  ps -axo args= | awk -v m="$1" '$1 ~ /\/Godot$/ && index($0, m)' | wc -l | tr -d ' '
}

wait_gone() { # wait_gone <text> <timeout_s>: no Godot of this run has <text> in its command line
  local end=$((SECONDS + ${2:-10}))
  while [ "$SECONDS" -lt "$end" ]; do
    [ "$(godots_with "$1")" = 0 ] && return 0
    sleep 0.1
  done
  [ "$(godots_with "$1")" = 0 ]
}
