#!/usr/bin/env bash
# Deploys the game's MpKit server to Fly.io in one command, from the project folder: no VPS, no export templates, no
# open port (it connects out to the relay). You run it: it uses your `fly` login. Nothing in the kit runs it by
# itself.
#
#   addons/mp_kit/deploy/fly.sh --app my-game-server --relay-url wss://my-relay.fly.dev [options]
#     --app NAME           the Fly app (created when it does not exist yet; the name is global on Fly)
#     --region CODE        Fly region (default gru, São Paulo; `fly platform regions`)
#     --rooms PORT         a room server (lobby + matches) on this kit port (default, 7700)
#     --dedicated PORT     a plain dedicated instead (one match, no lobby)
#     --relay-url URL      the relay (wss://...); --relay-room NAME its rooms' prefix when not game.tres's
#     --godot X.Y.Z        the Godot version of the image (default: the `godot` in PATH or GODOT_BIN)
#     --memory SIZE        the machine's memory (default 1gb; a room server runs one process per match)
#     --dry-run            print every command instead of running it
#
# The relay's host secret goes from MPKIT_RELAY_SECRET on YOUR machine into a Fly secret, through stdin (never on a
# command line or in a file). Unset = the app's secret is left as it is. Run it again to update.
set -euo pipefail
APP=""; REGION="gru"; ROLE="--room-server"; PORT="7700"; RELAY_URL=""; RELAY_ROOM=""; GODOT_VERSION=""; MEMORY="1gb"; DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --app) APP="$2"; shift 2 ;;
    --region) REGION="$2"; shift 2 ;;
    --rooms) ROLE="--room-server"; PORT="$2"; shift 2 ;;
    --dedicated) ROLE="--dedicated"; PORT="$2"; shift 2 ;;
    --relay-url) RELAY_URL="$2"; shift 2 ;;
    --relay-room) RELAY_ROOM="$2"; shift 2 ;;
    --godot) GODOT_VERSION="$2"; shift 2 ;;
    --memory) MEMORY="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
done
[ -n "$APP" ] || { echo "usage: fly.sh --app NAME --relay-url wss://... [options]" >&2; exit 2; }
case "$APP" in *[!a-z0-9-]*) echo "--app must be lower case letters, digits or -" >&2; exit 2 ;; esac
[ -f project.godot ] || { echo "run it from the game's project folder (where project.godot is)" >&2; exit 1; }
command -v fly >/dev/null 2>&1 || [ "$DRY" = 1 ] || { echo "install flyctl first: https://fly.io/docs/flyctl/install/" >&2; exit 1; }
if [ -z "$GODOT_VERSION" ]; then
  godot_bin="${GODOT_BIN:-$(command -v godot || true)}"
  [ -n "$godot_bin" ] || { echo "no godot in PATH: pass --godot X.Y.Z (the version your project uses)" >&2; exit 1; }
  ## "4.7.2.stable.official.ed1daf0bf" -> "4.7.2"
  GODOT_VERSION="$("$godot_bin" --version | sed -E 's/^([0-9]+\.[0-9]+(\.[0-9]+)?)\..*/\1/')"
fi
case "$GODOT_VERSION" in [0-9]*.[0-9]*) ;; *) echo "--godot must look like 4.7.2" >&2; exit 2 ;; esac

## The same flags as the VPS units (deploy.sh): a room server takes 100 match ports after its lobby port's block.
if [ "$ROLE" = "--room-server" ]; then
  ARGS="--room-server --lobby-port=$PORT --match-port-min=7800 --match-port-max=7899 --matches-root=/home/game/matches"
else
  ARGS="--dedicated --mp-port=$PORT"
fi
if [ -n "$RELAY_URL" ]; then
  ARGS="$ARGS --transport=relay --relay-url=$RELAY_URL"
else
  echo "note: no --relay-url, so the game's own MpNetConfig must say transport = relay with its relay_url (this server opens no port)"
fi
[ -n "$RELAY_ROOM" ] && ARGS="$ARGS --relay-room=$RELAY_ROOM"

run() { if [ "$DRY" = 1 ]; then printf 'RUN %s\n' "$*"; else "$@"; fi; }

## fly.toml in the project folder: written once from the addon's template; later runs only update what you passed.
TEMPLATE="addons/mp_kit/deploy/fly/fly.toml"
fill() { # fill <file>: the app, region, Godot version, flags and memory of this run
  sed -E \
    -e "s|^app = .*|app = \"$APP\"|" \
    -e "s|^primary_region = .*|primary_region = \"$REGION\"|" \
    -e "s|^( *)GODOT_VERSION = .*|\1GODOT_VERSION = \"$GODOT_VERSION\"|" \
    -e "s|^( *)GAME_ARGS = .*|\1GAME_ARGS = \"$ARGS\"|" \
    -e "s|^( *)memory = .*|\1memory = \"$MEMORY\"|" "$1"
}
BASE="fly.toml"
[ -f "$BASE" ] || BASE="$TEMPLATE"
if [ "$DRY" = 1 ]; then
  echo "RUN write fly.toml:"
  fill "$BASE" | sed 's/^/    /'
else
  fill "$BASE" > fly.toml.new && mv fly.toml.new fly.toml
fi
echo "== $APP ($REGION, Godot $GODOT_VERSION): $ARGS"

if [ "$DRY" = 1 ] || ! fly status --app "$APP" >/dev/null 2>&1; then
  run fly apps create "$APP"
fi
if [ -n "${MPKIT_RELAY_SECRET:-}" ]; then
  if [ "$DRY" = 1 ]; then echo "RUN fly secrets import --app $APP --stage  (MPKIT_RELAY_SECRET through stdin)"
  else printf 'MPKIT_RELAY_SECRET=%s\n' "$MPKIT_RELAY_SECRET" | fly secrets import --app "$APP" --stage; fi
fi
run fly deploy --app "$APP" --ha=false
echo "== done. Logs: fly logs --app $APP   status: fly status --app $APP"
