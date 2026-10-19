#!/usr/bin/env bash
# GODOT wrapper for cli.sh: 60 fps cap; swaps the project's window size for $PT_RES (e.g. 1920x1080).
args=()
for a in "$@"; do
  if [[ -n "${PT_RES:-}" && "$a" =~ ^[0-9]+x[0-9]+$ ]]; then args+=("$PT_RES"); else args+=("$a"); fi
done
. "$(dirname "$0")/env.sh"
exec "$GODOT_BIN" --max-fps 60 "${args[@]}"
