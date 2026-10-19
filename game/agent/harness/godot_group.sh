#!/usr/bin/env bash
# F350: reserve the whole Godot queue for a GROUP of processes that depend on each other (a room server and its clients,
# a dedicated and its players), then run ONE command that launches them directly, outside the per-process queue.
#
#   godot_group.sh <N> -- <command...>      (N = how many Godot processes the command may have at once; informational + cap)
#
# Why: the per-process queue (godot_run.sh) hands out slots one process at a time. A server that got its slot and clients that
# wait behind somebody else's exclusive import (or behind another group) never meet: the server waits for clients that cannot start,
# the import waits for the server. Here the group takes ONE ticket in the same FIFO queue (/tmp/<NS>_godot.queue), waits until
# every older ticket (import, window, headless, group) is gone, and keeps its ticket until the command ends. While it holds it,
# every later run (import included) waits behind it, so nothing can start in the middle and nothing is left half-reserved.
#
# Inside the command export GODOT_GROUP=<N> is set. Its Godot processes must NOT go through godot_run.sh (that would queue
# behind this very group): start them with "$GODOT_BIN" directly (agent/harness/net_e2e.sh `gd`), with their own RSS and
# process caps (net_e2e.sh `net_guard`). The class_name cache must be current (`--import` once); the group does not run the preflight.
# Same namespace as godot_run.sh: GODOT_RUN_NS (sacproject here). A ticket whose pid died is stale and removed.
N="${1:?usage: godot_group.sh <N> -- <command...>}"
shift
[ "$1" = "--" ] && shift
[ "$#" -gt 0 ] || { echo "godot_group: no command" >&2; exit 2; }
NS="${GODOT_RUN_NS:-sacproject}"
QUEUE=/tmp/${NS}_godot.queue
mkdir -p "$QUEUE"
ticket="$QUEUE/$(python3 -c 'import time; print(time.time_ns())').$$.x"
: > "$ticket"
trap 'rm -f "$ticket"' EXIT INT TERM
waited=0
older() { # is there a live ticket older than mine?
  local mine f base pid
  mine=$(basename "$ticket")
  for f in "$QUEUE"/*; do
    [ -e "$f" ] || continue
    base=$(basename "$f"); pid=$(echo "$base" | cut -d. -f2)
    if ! kill -0 "$pid" 2>/dev/null; then rm -f "$f"; continue; fi
    [ "$base" = "$mine" ] && continue
    [ "${base%%.*}" -lt "${mine%%.*}" ] && return 0
  done
  return 1
}
while older; do sleep 1; waited=$((waited + 1)); done
echo "godot_group: grupo de $N procesos, espera ${waited}s" >&2
export GODOT_GROUP="$N"
"$@"
