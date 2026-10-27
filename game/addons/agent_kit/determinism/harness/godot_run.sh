#!/usr/bin/env bash
# Runs ONE Godot command under a machine-wide scheme, so agents queue instead of polling each other.
# Usage: godot_run.sh <command...>   (e.g. godot_run.sh "$GODOT_BIN" --headless --path . --script ...)
#
# Three kinds of run:
# - headless (has --headless, not --import): up to HEADLESS_SLOTS at once (default 3), each ~0.3-1 GB, almost no GPU.
# - window: one at a time, alongside headless runs. Its timing is measured under load (mark it CONTAMINATED in a bench).
# - import (--import): alone; waits until no other Godot runs, and nothing starts while it holds the lock.
# Never more than GODOT_MAX Godots (default 4). Use separate worktrees for parallel agents (one .godot/ each).
# Windows never run in parallel (two heavy windowed Godots hung a 16 GB machine).
# Locks are directories (mkdir is atomic); a lock whose holder pid is gone is stale and removed.
#
# Configuration (environment):
#   GODOT_RUN_NS         namespace of the locks and the queue: /tmp/<NS>_godot.* (default agentkit). Every project
#                        (or group of agents) that must share the same machine budget uses the same NS.
#   GODOT_BIN            Godot binary used by the class_name preflight (default: godot/godot4/Godot in PATH, then
#                        the macOS app bundle).
#   HEADLESS_SLOTS       concurrent headless runs (default 3).
#   GODOT_MAX            max Godot processes at once (default 4).
#   GODOT_WINDOW_MAX_S   wall-time cap of a window run, in seconds (default 600; 0 = no cap).
#   GODOT_BUSY_SCRIPT    script that decides "no other Godot is running" before an import (default godot_busy.sh;
#                        the self-test overrides it so real Godots on the machine do not matter).
#   GODOT_RUN_NO_PREFLIGHT  set to skip the class_name preflight.
NS="${GODOT_RUN_NS:-agentkit}"
EXCL=/tmp/${NS}_godot.lock
LAUNCH=/tmp/${NS}_godot.launch
SLOTS="${HEADLESS_SLOTS:-3}"
# At most MAXG Godot processes at once. One window at a time (WIN); an import (--import) is still alone.
MAXG="${GODOT_MAX:-4}"
WIN=/tmp/${NS}_godot.window
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
# FIFO tickets: without them a stream of window runs starves headless waiters. Each run takes a ticket
# <time_ns>.<pid>.<x|h>; an exclusive run waits for every older ticket, a headless run only for older exclusive
# ones. A ticket whose pid died is stale and removed.
QUEUE=/tmp/${NS}_godot.queue
mkdir -p "$QUEUE"
ticket=""
take_ticket() {  # take_ticket <x|h>
  ticket="$QUEUE/$(python3 -c 'import time; print(time.time_ns())').$$.$1"
  : > "$ticket"
}
older() {  # older <kinds|any>: is there a live ticket older than mine of one of those kinds (i import, w window, h headless, x old exclusive)?
  local mine f base pid kind; mine=$(basename "$ticket")
  for f in "$QUEUE"/*; do
    [ -e "$f" ] || continue
    base=$(basename "$f"); pid=$(echo "$base" | cut -d. -f2); kind=$(echo "$base" | cut -d. -f3)
    if ! kill -0 "$pid" 2>/dev/null; then rm -f "$f"; continue; fi
    [ "$base" = "$mine" ] && continue
    [ "$1" != any ] && [ "${1#*$kind}" = "$1" ] && continue
    [ "${base%%.*}" -lt "${mine%%.*}" ] && return 0
  done
  return 1
}
godots() { ps -axo comm= | awk '$1 ~ /(^|\/)Godot$|(^|\/)godot4?$/' | wc -l | tr -d ' '; }

# Preflight: a `class_name` missing from the project's class cache (a merge or a new script without `--import`)
# makes every scene that uses it fail to compile, and a window run then hangs on its loading screen. Before any
# Godot run that is not itself an import, compare the class_names in the project's .gd files with
# .godot/global_script_class_cache.cfg and, if one is missing, import twice first (each import is exclusive).
project=""
prev=""
for a in "$@"; do [ "$prev" = "--path" ] && project="$a"; prev="$a"; done
[ -z "$project" ] && [ -f project.godot ] && project="$PWD"
case " $* " in *" --import "*) project="" ;; esac
if [ -n "$project" ] && [ -f "$project/project.godot" ] && [ -z "${GODOT_RUN_NO_PREFLIGHT:-}" ]; then
  cache="$project/.godot/global_script_class_cache.cfg"
  missing=$(comm -23 \
    <(grep -rhoE --include='*.gd' '^class_name [A-Za-z_][A-Za-z0-9_]*' --exclude-dir=.godot --exclude-dir=cache --exclude-dir=out "$project" | awk '{print $2}' | sort -u) \
    <(grep -oE '"class": &"[A-Za-z0-9_]+"' "$cache" 2>/dev/null | sed 's/.*&"//;s/"$//' | sort -u))
  if [ -n "$missing" ]; then
    bin="${GODOT_BIN:-$(command -v godot godot4 Godot 2>/dev/null | head -n1)}"
    [ -z "$bin" ] && bin="/Applications/Godot.app/Contents/MacOS/Godot"
    echo "godot_run: clases sin importar ($(echo $missing | tr '\n' ' ')); --import x2 en $project" >&2
    GODOT_RUN_NO_PREFLIGHT=1 bash "$0" "$bin" --headless --path "$project" --import >/dev/null 2>&1
    GODOT_RUN_NO_PREFLIGHT=1 bash "$0" "$bin" --headless --path "$project" --import >/dev/null 2>&1
  fi
fi

headless=0
case " $* " in *" --headless "*) headless=1 ;; esac
import=0
case " $* " in *" --import "*) import=1; headless=0 ;; esac

launch() {  # launch <cmd...>: start once nothing exclusive runs and fewer than MAXG Godots are up
  while :; do
    take "$LAUNCH"
    if ! held "$EXCL" && [ "$(godots)" -lt "$MAXG" ]; then break; fi
    rm -rf "$LAUNCH"; sleep 3; waited=$((waited+3))
  done
  "$@" &
  child=$!
  sleep 1; rm -rf "$LAUNCH"   # the child is visible to ps now; let the next one decide
  # A window run that never quits holds the only window for everyone. Cap its wall time (GODOT_WINDOW_MAX_S,
  # default 600 s; 0 = no cap) and kill the whole process group past it.
  if [ "${is_window:-0}" = 1 ] && [ "${GODOT_WINDOW_MAX_S:-600}" -gt 0 ]; then
    ( sleep "${GODOT_WINDOW_MAX_S:-600}"
      if kill -0 $child 2>/dev/null; then
        echo "godot_run: window passed ${GODOT_WINDOW_MAX_S:-600}s, cutting it: $*" >&2
        pkill -9 -P $child 2>/dev/null; kill -9 $child 2>/dev/null
      fi ) &
    dog=$!
  fi
  wait $child; code=$?
  [ -n "${dog:-}" ] && kill $dog 2>/dev/null
  return $code
}

if [ $import -eq 1 ]; then
  take_ticket i
  trap 'rm -f "$ticket"' EXIT INT TERM
  while older any; do sleep 2; waited=$((waited+2)); done
  take "$EXCL"; echo "$*" > "$EXCL/cmd"
  trap 'rm -rf "$EXCL"; rm -f "$ticket"' EXIT INT TERM
  until bash "${GODOT_BUSY_SCRIPT:-$HERE/godot_busy.sh}" >/dev/null; do sleep 3; waited=$((waited+3)); done
  echo "godot_run: import exclusivo, espera ${waited}s" >&2
  "$@"
  exit $?
fi

if [ $headless -eq 0 ]; then
  take_ticket w
  trap 'rm -f "$ticket"' EXIT INT TERM
  while older iwx; do sleep 2; waited=$((waited+2)); done
  take "$WIN"; echo "$*" > "$WIN/cmd"
  trap 'rm -rf "$WIN"; rm -f "$ticket"' EXIT INT TERM
  echo "godot_run: ventana, espera ${waited}s" >&2
  is_window=1
  launch "$@"
  exit $?
fi

take_ticket h
trap 'rm -f "$ticket"' EXIT INT TERM
while older ix; do sleep 2; waited=$((waited+2)); done
slot=""
until [ -n "$slot" ]; do
  for i in $(seq 0 $((SLOTS-1))); do
    d="/tmp/${NS}_godot.slot$i"
    if mkdir "$d" 2>/dev/null; then slot="$d"; break; fi
    held "$d" || rm -rf "$d"
  done
  [ -z "$slot" ] && { sleep 2; waited=$((waited+2)); }
done
echo $$ > "$slot/pid"; echo "$*" > "$slot/cmd"
trap 'rm -rf "$slot"; rm -f "$ticket"' EXIT INT TERM
echo "godot_run: headless ($(basename "$slot")), espera ${waited}s" >&2
launch "$@"
