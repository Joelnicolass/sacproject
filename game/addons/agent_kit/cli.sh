#!/usr/bin/env bash
# AgentKit host wrapper. Finds Godot, reads viewport, runs --agent=VERB.
#   cli.sh /path/to/godot-project capture --scene=res://x.tscn --out=/tmp/a.png
#   cli.sh /path/to/godot-project info
#   GODOT=/path/to/Godot cli.sh . flow --flow=boot_smoke.json --out=res://agent/out
set -euo pipefail

usage() {
  cat <<'EOF'
AgentKit — CLI for AI agents (Godot window or headless).

  cli.sh PROJECT VERB [flags]

  VERB     help | info | capture | flow | fetch | inspect | diff
  flags    forwarded after -- as --key=value (see addons/agent_kit/README.md)

Examples:
  cli.sh ./example capture --out=res://agent/out/boot.png --wait=1.0
  cli.sh ./example flow --flow=boot_smoke.json
  cli.sh ./example inspect --unique
  cli.sh ./example fetch --url=https://example.com --out=res://agent/out/body.html
  cli.sh ./example diff --a=res://agent/out/a.png --b=res://agent/out/b.png --out=res://agent/out/diff.png

Env: GODOT  path to the Godot 4 binary.
EOF
}

find_godot() {
  if [[ -n "${GODOT:-}" && -x "${GODOT}" ]]; then
    printf '%s\n' "$GODOT"
    return 0
  fi
  local cmd
  for cmd in godot4 godot Godot; do
    if command -v "$cmd" >/dev/null 2>&1; then
      command -v "$cmd"
      return 0
    fi
  done
  local candidate
  for candidate in \
    "/Applications/Godot.app/Contents/MacOS/Godot" \
    "/Applications/Godot_4.app/Contents/MacOS/Godot" \
    "${HOME}/Applications/Godot.app/Contents/MacOS/Godot" \
    "${HOME}/Downloads/Godot.app/Contents/MacOS/Godot" \
    "${HOME}/Downloads/Godot-7.app/Contents/MacOS/Godot"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  local glob
  shopt -s nullglob
  for glob in "${HOME}"/Downloads/Godot*.app/Contents/MacOS/Godot; do
    if [[ -x "$glob" ]]; then
      printf '%s\n' "$glob"
      return 0
    fi
  done
  return 1
}

viewport_from_project() {
  local project="$1"
  local file="${project}/project.godot"
  local w=1152
  local h=648
  if [[ -f "$file" ]]; then
    local got
    got="$(grep -E '^window/size/viewport_width=' "$file" | head -n1 | cut -d= -f2 || true)"
    if [[ -n "$got" ]]; then
      w="$got"
    fi
    got="$(grep -E '^window/size/viewport_height=' "$file" | head -n1 | cut -d= -f2 || true)"
    if [[ -n "$got" ]]; then
      h="$got"
    fi
  fi
  printf '%sx%s\n' "$w" "$h"
}

if [[ $# -lt 1 ]]; then
  usage
  exit 2
fi

if [[ "$1" == "-h" || "$1" == "--help" || "$1" == "help" ]]; then
  usage
  exit 0
fi

PROJECT="$(cd "$1" && pwd)"
shift
if [[ ! -f "${PROJECT}/project.godot" ]]; then
  echo "No project.godot in ${PROJECT}" >&2
  exit 2
fi
if [[ ! -f "${PROJECT}/addons/agent_kit/plugin.cfg" ]]; then
  echo "AgentKit is not in ${PROJECT}/addons/agent_kit — ./install.sh --addon ${PROJECT} agent_kit" >&2
  exit 2
fi

if [[ $# -lt 1 ]]; then
  usage
  exit 2
fi

VERB="$1"
shift
if [[ "$VERB" == "help" ]]; then
  usage
  exit 0
fi

GODOT_BIN="$(find_godot)" || {
  echo "Godot 4 binary not found. Set GODOT=/path/to/Godot" >&2
  exit 2
}

RES="$(viewport_from_project "$PROJECT")"
CMD=("$GODOT_BIN" --path "$PROJECT" --resolution "$RES")
case "$VERB" in
  capture|flow)
    ;;
  info|fetch|inspect|diff|help)
    CMD+=(--headless)
    ;;
  *)
    echo "Unknown verb: ${VERB}" >&2
    usage >&2
    exit 2
    ;;
esac
CMD+=(-- --agent="$VERB")
for arg in "$@"; do
  if [[ "$arg" == --* ]]; then
    CMD+=("$arg")
  else
    echo "Unexpected argument: $arg (flags must be --key=value)" >&2
    exit 2
  fi
done

exec "${CMD[@]}"
