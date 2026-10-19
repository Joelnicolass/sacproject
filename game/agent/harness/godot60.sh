#!/usr/bin/env bash
# GODOT wrapper for cli.sh: same binary, capped to 60 fps (Mac safety rule).
. "$(dirname "$0")/env.sh"
exec "$GODOT_BIN" --max-fps 60 "$@"
