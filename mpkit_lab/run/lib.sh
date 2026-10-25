#!/usr/bin/env bash
# Shared pieces of the MpKit lab e2e scripts (mpkit_lab/run/*.sh). Source it, do not run it:
#   . "$(dirname "$0")/lib.sh"
#   net_group 4 "$@"     # FIRST: with MPKIT_GODOT_GROUP set, re-run inside that queue's group reservation
# Then the script sets OUT / LIMIT_S / TAG / PROC_MAX and uses:
#   gd <log> <godot args…>     a headless Godot on the lab project; pid in LAST_PID and in $OUT/pids
#   net_guard / net_stop       watchdog (LIMIT_S), memory brake (RSS_LIMIT_MB) and process cap (PROC_MAX)
#   wait_line <file> <regex> <pid> <timeout_s>, wait_gone <text> <timeout_s>, godots_with <text>, kill_tree <pid>
# Environment: GODOT_BIN (default: godot in PATH, then the macOS app), MPKIT_GODOT_GROUP (optional: a script
# `group.sh <N> -- <command…>` that reserves a machine-wide Godot queue, e.g. the AgentKit one) and MPKIT_GODOT_RUN
# (optional: `run.sh <godot> <args…>` of that queue, for single runs outside a group; see run_godot).
LAB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$LAB"
if [ -z "${GODOT_BIN:-}" ]; then
  if command -v godot >/dev/null 2>&1; then GODOT_BIN="$(command -v godot)"; else GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"; fi
fi
GODOT="$GODOT_BIN"
RSS_LIMIT_MB="${E2E_RSS_LIMIT_MB:-6144}"
WATCH=""; MONITOR=""

net_group() { # net_group <N> "$@"
  [ -n "${MPKIT_IN_GROUP:-}" ] && return 0
  [ -z "${MPKIT_GODOT_GROUP:-}" ] && return 0
  local n="$1"; shift
  MPKIT_IN_GROUP=1 exec bash "$MPKIT_GODOT_GROUP" "$n" -- env MPKIT_IN_GROUP=1 bash "${BASH_SOURCE[1]}" "$@"
}

## One Godot run outside a group (import, tests): through MPKIT_GODOT_RUN when set.
run_godot() {
  if [ -n "${MPKIT_GODOT_RUN:-}" ]; then bash "$MPKIT_GODOT_RUN" "$GODOT" "$@"; else "$GODOT" "$@"; fi
}

descendants() { local p="$1" c; echo "$p"; for c in $(pgrep -P "$p" 2>/dev/null); do descendants "$c"; done; }
kill_tree() { local p; for p in $(descendants "$1" | sort -rn); do kill "$p" 2>/dev/null; done; }
kill_pids() { local p; for p in $(cat "$OUT/pids" 2>/dev/null); do [ -n "$p" ] && kill_tree "$p"; done; }

gd() { # gd <log> <godot args…>
  local log="$1"; shift
  "$GODOT" --headless --path "$ROOT" "$@" > "$log" 2>&1 &
  LAST_PID=$!
  echo "$LAST_PID" >> "$OUT/pids"
}

net_guard() {
  ( sleep "$LIMIT_S"; echo "$TAG FAIL: external timeout ${LIMIT_S}s" > "$OUT/timeout.flag"; kill_all ) &
  WATCH=$!; disown $WATCH
  ( while :; do
      read -r tot n < <(ps -axo rss=,args= | awk -v root="$ROOT" 'index($0, "--path " root) {s += $1; c++} END {print s + 0, c + 0}')
      if [ $((tot / 1024)) -gt "$RSS_LIMIT_MB" ] || [ "$n" -gt "${PROC_MAX:-6}" ]; then
        echo "$TAG FAIL: ${n} Godot processes, $((tot / 1024)) MB (limits ${PROC_MAX:-6}, ${RSS_LIMIT_MB} MB)" > "$OUT/timeout.flag"
        kill_all
      fi
      sleep 1
    done ) &
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

godots_with() { ps -axo args= | awk -v m="$1" 'index($0, "--path") && index($0, m)' | wc -l | tr -d ' '; }

wait_gone() { # wait_gone <text> <timeout_s>
  local end=$((SECONDS + ${2:-10}))
  while [ "$SECONDS" -lt "$end" ]; do [ "$(godots_with "$1")" = 0 ] && return 0; sleep 0.1; done
  [ "$(godots_with "$1")" = 0 ]
}
