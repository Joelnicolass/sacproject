#!/usr/bin/env bash
# Deploys an exported MpKit server build to a Linux VPS (systemd) in one command. You run it: it uses your SSH and
# your sudo on the server. Nothing in the kit runs it by itself.
#
#   deploy.sh user@host path/to/build [options]
#     --name NAME          service and user name (default: the build's binary name without .x86_64)
#     --rooms 7700,7701    room server instances, one per lobby port (default 7700). Each gets 100 match ports:
#                          the first 7800-7899, the second 7900-7999...
#     --dedicated 7777     plain dedicated instances (no lobby), one per port. Default: none.
#     --transport enet|ws  forwarded to every instance (default: what the build's MpLobbyConfig says)
#     --open-firewall      also open the ports with ufw (UDP for ENet, TCP for WebSocket and always the lobby's)
#     --dry-run            print every command instead of running it
#
# The build folder holds the Linux export: NAME.x86_64 and NAME.pck (see deploy/README.md). Run it again to update:
# it copies the new files and restarts every instance.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:?usage: deploy.sh user@host path/to/build [options]}"
BUILD="${2:?usage: deploy.sh user@host path/to/build [options]}"
shift 2
NAME=""; ROOMS="7700"; DEDICATED=""; TRANSPORT=""; FIREWALL=0; DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --rooms) ROOMS="$2"; shift 2 ;;
    --dedicated) DEDICATED="$2"; shift 2 ;;
    --transport) TRANSPORT="$2"; shift 2 ;;
    --open-firewall) FIREWALL=1; shift ;;
    --dry-run) DRY=1; shift ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
done
BIN="$(cd "$BUILD" && ls -1 *.x86_64 2>/dev/null | head -n 1 || true)"
[ -n "$BIN" ] || { echo "no *.x86_64 in $BUILD: export the Linux preset first (deploy/README.md)" >&2; exit 1; }
[ -n "$NAME" ] || NAME="${BIN%.x86_64}"
case "$NAME" in *[!a-z0-9_-]*|"") echo "--name must be lower case letters, digits, - or _" >&2; exit 2 ;; esac
EXTRA=""
[ -n "$TRANSPORT" ] && EXTRA="--transport=$TRANSPORT"

run() { if [ "$DRY" = 1 ]; then printf 'RUN %s\n' "$*"; else "$@"; fi; }
remote() { run ssh "$TARGET" "$@"; }
unit() { sed -e "s/@NAME@/$NAME/g" -e "s/@BIN@/$BIN/g" "$HERE/$1"; }

echo "== $NAME -> $TARGET (rooms: ${ROOMS:-none}, dedicated: ${DEDICATED:-none})"
remote "id -u $NAME >/dev/null 2>&1 || sudo useradd --system --home /var/lib/$NAME --shell /usr/sbin/nologin $NAME"
remote "sudo mkdir -p /opt/$NAME /etc/$NAME /var/lib/$NAME && sudo chown $NAME:$NAME /var/lib/$NAME"
run rsync -az --delete "$BUILD"/ "$TARGET:/tmp/$NAME-build/"
remote "sudo rsync -a --delete /tmp/$NAME-build/ /opt/$NAME/ && sudo chmod +x /opt/$NAME/$BIN && rm -rf /tmp/$NAME-build"
for file in mp-rooms@.service mp-dedicated@.service; do
  short="${file#mp-}"
  if [ "$DRY" = 1 ]; then echo "RUN install /etc/systemd/system/$NAME-$short"; unit "$file" | sed 's/^/    /' | head -n 3
  else unit "$file" | ssh "$TARGET" "sudo tee /etc/systemd/system/$NAME-$short >/dev/null"; fi
done
remote "sudo systemctl daemon-reload"
k=0
for port in ${ROOMS//,/ }; do
  min=$((7800 + k * 100)); max=$((min + 99)); k=$((k + 1))
  env="MATCH_PORT_MIN=$min\nMATCH_PORT_MAX=$max\nEXTRA_ARGS=$EXTRA\n"
  remote "printf '$env' | sudo tee /etc/$NAME/rooms-$port.env >/dev/null"
  remote "sudo systemctl enable $NAME-rooms@$port >/dev/null 2>&1; sudo systemctl restart $NAME-rooms@$port"
  echo "   rooms on $port, matches on $min-$max"
  if [ "$FIREWALL" = 1 ]; then
    proto=$([ "$TRANSPORT" = ws ] && echo tcp || echo udp)
    remote "sudo ufw allow $port/$proto && sudo ufw allow $min:$max/$proto"
  fi
done
[ -n "$DEDICATED" ] && remote "printf 'EXTRA_ARGS=$EXTRA\n' | sudo tee /etc/$NAME/dedicated.env >/dev/null"
for port in ${DEDICATED//,/ }; do
  remote "sudo systemctl enable $NAME-dedicated@$port >/dev/null 2>&1; sudo systemctl restart $NAME-dedicated@$port"
  echo "   dedicated on $port"
  [ "$FIREWALL" = 1 ] && remote "sudo ufw allow $port/$([ "$TRANSPORT" = ws ] && echo tcp || echo udp)"
done
echo "== done. Logs: ssh $TARGET journalctl -u '$NAME-rooms@*' -f"
