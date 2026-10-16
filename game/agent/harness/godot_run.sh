#!/usr/bin/env bash
# Runs ONE Godot command with a machine-wide lock, so agents queue instead of polling each other.
# Usage: agent/harness/godot_run.sh <command...>   (e.g. godot_run.sh /Applications/Godot.app/.../Godot --headless ...)
# The lock is a directory (mkdir is atomic). It waits for the lock, then for godot_busy.sh to report free
# (the user's own editor games count), runs the command and always releases the lock.
LOCK=/tmp/sacproject_godot.lock
HERE="$(cd "$(dirname "$0")" && pwd)"
waited=0
until mkdir "$LOCK" 2>/dev/null; do
  # Stale lock: holder pid gone.
  holder=$(cat "$LOCK/pid" 2>/dev/null)
  if [ -n "$holder" ] && ! kill -0 "$holder" 2>/dev/null; then rm -rf "$LOCK"; continue; fi
  sleep 2; waited=$((waited+2))
done
echo $$ > "$LOCK/pid"
echo "$*" > "$LOCK/cmd"
trap 'rm -rf "$LOCK"' EXIT INT TERM
until bash "$HERE/godot_busy.sh" >/dev/null; do sleep 3; waited=$((waited+3)); done
echo "godot_run: espera ${waited}s" >&2
"$@"
