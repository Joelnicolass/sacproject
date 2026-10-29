#!/usr/bin/env bash
# Deploys an exported MpKit server build to a Linux VPS (systemd) in one command. You run it: it uses your SSH and
# your sudo on the server. Nothing in the kit runs it by itself.
#
#   deploy.sh user@host path/to/build [options]
#     --name NAME          service and user name (default: the build's binary name without .x86_64)
#     --rooms 7700,7701    room server instances, one per lobby port (default 7700 unless --dedicated is given). Each gets 100 match ports:
#                          the first 7800-7899, the second 7900-7999...
#     --dedicated 7777     plain dedicated instances (no lobby), one per port. Default: none.
#     --transport enet|ws|relay  forwarded to every instance (default: what the build's MpNetConfig says)
#     --relay-url URL      the relay (wss://your-relay.up.railway.app) when --transport relay and the build has none
#     --relay-room NAME    the relay room prefix (each port is NAME-PORT) when it differs from the build's
#                          The relay secret is read from MPKIT_RELAY_SECRET on YOUR machine and written to
#                          /etc/NAME/relay.env (only the service user reads it). Unset = that file is left as it is.
#     --tls-cert PATH      wss:// with this PEM certificate on the server (e.g. /etc/letsencrypt/live/DOMAIN/fullchain.pem)
#     --tls-key PATH       and its PEM key (…/privkey.pem). The service user must be able to read both.
#     --open-firewall      also open the ports with ufw (UDP for ENet, TCP for WebSocket; the lobby and its matches alike;
#                          nothing for the relay: the server connects out to it)
#     --dry-run            print every command instead of running it
#
# The build folder holds the Linux export: NAME.x86_64 and NAME.pck (see deploy/README.md). Run it again to update:
# it copies the new files and restarts every instance.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:?usage: deploy.sh user@host path/to/build [options]}"
BUILD="${2:?usage: deploy.sh user@host path/to/build [options]}"
shift 2
NAME=""; ROOMS=""; DEDICATED=""; TRANSPORT=""; FIREWALL=0; DRY=0; TLS_CERT=""; TLS_KEY=""; RELAY_URL=""; RELAY_ROOM=""
while [ $# -gt 0 ]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --rooms) ROOMS="$2"; shift 2 ;;
    --dedicated) DEDICATED="$2"; shift 2 ;;
    --transport) TRANSPORT="$2"; shift 2 ;;
    --relay-url) RELAY_URL="$2"; shift 2 ;;
    --relay-room) RELAY_ROOM="$2"; shift 2 ;;
    --tls-cert) TLS_CERT="$2"; shift 2 ;;
    --tls-key) TLS_KEY="$2"; shift 2 ;;
    --open-firewall) FIREWALL=1; shift ;;
    --dry-run) DRY=1; shift ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
done
## No instances asked for = one room server on 7700.
[ -z "$ROOMS$DEDICATED" ] && ROOMS="7700"
BIN="$(cd "$BUILD" && ls -1 *.x86_64 2>/dev/null | head -n 1 || true)"
[ -n "$BIN" ] || { echo "no *.x86_64 in $BUILD: export the Linux preset first (deploy/README.md)" >&2; exit 1; }
[ -n "$NAME" ] || NAME="${BIN%.x86_64}"
case "$NAME" in *[!a-z0-9_-]*|"") echo "--name must be lower case letters, digits, - or _" >&2; exit 2 ;; esac
case "$TRANSPORT" in ""|enet|ws|relay) ;; *) echo "--transport must be enet, ws or relay" >&2; exit 2 ;; esac
EXTRA=""
[ -n "$TRANSPORT" ] && EXTRA="--transport=$TRANSPORT"
[ -n "$RELAY_URL" ] && EXTRA="$EXTRA --relay-url=$RELAY_URL"
[ -n "$RELAY_ROOM" ] && EXTRA="$EXTRA --relay-room=$RELAY_ROOM"
if [ -n "$TLS_CERT$TLS_KEY" ]; then
  [ -n "$TLS_CERT" ] && [ -n "$TLS_KEY" ] || { echo "--tls-cert and --tls-key go together" >&2; exit 2; }
  [ "$TRANSPORT" = ws ] || { echo "TLS needs --transport ws" >&2; exit 2; }
  EXTRA="$EXTRA --tls-certificate-path=$TLS_CERT --tls-key-path=$TLS_KEY"
fi

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
if [ -n "${MPKIT_RELAY_SECRET:-}" ]; then
  ## Through stdin, never on a command line (ps and the shell history would show it).
  if [ "$DRY" = 1 ]; then echo "RUN write /etc/$NAME/relay.env (MPKIT_RELAY_SECRET, mode 600)"
  else printf 'MPKIT_RELAY_SECRET=%s\n' "$MPKIT_RELAY_SECRET" | ssh "$TARGET" "sudo install -m 600 -o $NAME -g $NAME /dev/stdin /etc/$NAME/relay.env"; fi
fi
k=0
for port in ${ROOMS//,/ }; do
  min=$((7800 + k * 100)); max=$((min + 99)); k=$((k + 1))
  env="MATCH_PORT_MIN=$min\nMATCH_PORT_MAX=$max\nEXTRA_ARGS=$EXTRA\n"
  remote "printf '$env' | sudo tee /etc/$NAME/rooms-$port.env >/dev/null"
  remote "sudo systemctl enable $NAME-rooms@$port >/dev/null 2>&1; sudo systemctl restart $NAME-rooms@$port"
  echo "   rooms on $port, matches on $min-$max"
  if [ "$FIREWALL" = 1 ] && [ "$TRANSPORT" != relay ]; then
    proto=$([ "$TRANSPORT" = ws ] && echo tcp || echo udp)
    remote "sudo ufw allow $port/$proto && sudo ufw allow $min:$max/$proto"
  fi
done
[ -n "$DEDICATED" ] && remote "printf 'EXTRA_ARGS=$EXTRA\n' | sudo tee /etc/$NAME/dedicated.env >/dev/null"
for port in ${DEDICATED//,/ }; do
  remote "sudo systemctl enable $NAME-dedicated@$port >/dev/null 2>&1; sudo systemctl restart $NAME-dedicated@$port"
  echo "   dedicated on $port"
  [ "$FIREWALL" = 1 ] && [ "$TRANSPORT" != relay ] && remote "sudo ufw allow $port/$([ "$TRANSPORT" = ws ] && echo tcp || echo udp)"
done
echo "== done. Logs: ssh $TARGET journalctl -u '$NAME-$([ -n "$ROOMS" ] && echo rooms || echo dedicated)@*' -f"
