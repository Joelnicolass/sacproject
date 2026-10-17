#!/usr/bin/env bash
# Runs ONE Godot command under a machine-wide scheme, so agents queue instead of polling each other.
# Usage: agent/harness/godot_run.sh <command...>   (e.g. godot_run.sh /Applications/Godot.app/.../Godot --headless ...)
#
# Two kinds of run (2026-10-17, the user closed the editor to go faster):
# - headless (has --headless, not --import): up to HEADLESS_SLOTS at once (default 2), each ~0.3-1 GB, almost no GPU.
#   Use separate worktrees for parallel agents: two runs never share a .godot/ being written.
# - exclusive (a window, or --import): alone. Waits until no other Godot runs; headless runs wait while it holds the lock.
# The 16 GB Mac hung on 2026-10-14 with two heavy Godots: windows never run in parallel.
# Locks are directories (mkdir is atomic); a lock whose holder pid is gone is stale and removed.
EXCL=/tmp/sacproject_godot.lock
LAUNCH=/tmp/sacproject_godot.launch
SLOTS="${HEADLESS_SLOTS:-2}"
HERE="$(cd "$(dirname "$0")" && pwd)"
waited=0

take() {  # take <dir>: wait for a lock dir, clearing it if its holder died.
  until mkdir "$1" 2>/dev/null; do
    local holder; holder=$(cat "$1/pid" 2>/dev/null)
    if [ -n "$holder" ] && ! kill -0 "$holder" 2>/dev/null; then rm -rf "$1"; continue; fi
    sleep 2; waited=$((waited+2))
  done
  echo $$ > "$1/pid"
}
held() {  # held <dir>: a live process holds it.
  local holder; holder=$(cat "$1/pid" 2>/dev/null)
  [ -n "$holder" ] && kill -0 "$holder" 2>/dev/null
}
godots() { ps -axo comm= | awk '$1 ~ /(^|\/)Godot$|(^|\/)godot4?$/' | wc -l | tr -d ' '; }

headless=0
case " $* " in *" --headless "*) headless=1 ;; esac
case " $* " in *" --import "*) headless=0 ;; esac

if [ $headless -eq 0 ]; then
  take "$EXCL"; echo "$*" > "$EXCL/cmd"
  trap 'rm -rf "$EXCL"' EXIT INT TERM
  until bash "$HERE/godot_busy.sh" >/dev/null; do sleep 3; waited=$((waited+3)); done
  echo "godot_run: exclusivo, espera ${waited}s" >&2
  "$@"
  exit $?
fi

# Headless: grab a free slot, then launch only while nothing exclusive runs and fewer than SLOTS Godots are up.
slot=""
until [ -n "$slot" ]; do
  for i in $(seq 0 $((SLOTS-1))); do
    d="/tmp/sacproject_godot.slot$i"
    if mkdir "$d" 2>/dev/null; then slot="$d"; break; fi
    held "$d" || rm -rf "$d"
  done
  [ -z "$slot" ] && { sleep 2; waited=$((waited+2)); }
done
echo $$ > "$slot/pid"; echo "$*" > "$slot/cmd"
trap 'rm -rf "$slot"' EXIT INT TERM
while :; do
  take "$LAUNCH"
  if ! held "$EXCL" && [ "$(godots)" -lt "$SLOTS" ]; then break; fi
  rm -rf "$LAUNCH"; sleep 3; waited=$((waited+3))
done
echo "godot_run: headless ($(basename "$slot")), espera ${waited}s" >&2
"$@" &
child=$!
sleep 1; rm -rf "$LAUNCH"   # the child is visible to ps now; let the next one decide
wait $child
