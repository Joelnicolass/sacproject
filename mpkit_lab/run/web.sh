#!/usr/bin/env bash
# MpKit web client check (needs the Web export templates of Godot 4.7.2). Exports mpkit_lab for the browser (no threads, so
# no special headers), starts a native WebSocket dedicated server whose probe waits for a remote player to move and score,
# and serves the export on http://127.0.0.1:$HTTP_PORT. Open the printed URL in any browser (the page plays by itself as
# the first client: it passes the probe flags in its config); the verdict is the server's: MPKIT WEB PASS / FAIL.
# A page served over http may use ws://; a page over https needs wss:// (MpNetConfig TLS or a reverse proxy).
# WEB_NEED_BROWSER=1: with no browser to open, print MPKIT WEB SKIP instead of waiting for a person.
# BROWSER: the page opens by itself in a headless Chrome or Chromium with a throwaway profile when one is found
# (BROWSER=/path/to/chrome to pick one); BROWSER=none prints the URL for a person to open instead.
# TRANSPORT=relay: the server and the page meet through a local MpKit relay instead (the server hosts a relay room,
# the browser joins it), the way a web game reaches a server behind NAT through Railway.
. "$(dirname "$0")/lib.sh"
net_group 1 "$@"
TAG="MPKIT WEB"
LIMIT_S="${PROBE_LIMIT_S:-240}"
PROC_MAX=2
PORT="${E2E_PORT:-7793}"
HTTP_PORT="${HTTP_PORT:-8093}"
WAIT_S="${WAIT_S:-180}"
TRANSPORT="${TRANSPORT:-ws}"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/mpkit_web.XXXXXX")"
WEB="$ROOT/scratch/web"
kill_all() { kill_pids; [ -n "${HTTP:-}" ] && kill "$HTTP" 2>/dev/null; [ -n "${CHROME:-}" ] && kill "$CHROME" 2>/dev/null; }
find_browser() {
  [ -n "${BROWSER:-}" ] && { [ "$BROWSER" = none ] || echo "$BROWSER"; return; }
  local c
  for c in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" "/Applications/Chromium.app/Contents/MacOS/Chromium" \
      "$(command -v google-chrome 2>/dev/null)" "$(command -v chromium 2>/dev/null)" "$(command -v chromium-browser 2>/dev/null)"; do
    [ -n "$c" ] && [ -x "$c" ] && { echo "$c"; return; }
  done
}
trap 'kill_all; net_stop' EXIT
net_guard
if [ -n "${WEB_NEED_BROWSER:-}" ] && [ -z "$(find_browser)" ]; then echo "$TAG SKIP: no Chrome or Chromium to open the page"; exit 0; fi
RELAY_QUIET=0 relay_up

mkdir -p "$WEB"
"$GODOT" --headless --path "$ROOT" --export-debug "Web" "$WEB/index.html" > "$OUT/export.log" 2>&1
[ -f "$WEB/index.wasm" ] || { echo "FAIL web export (see $OUT/export.log)"; echo "$TAG FAIL"; exit 1; }
python3 - "$WEB" "$PORT" "$TRANSPORT" "${RELAY_FLAGS[@]}" <<'PYEOF'
import sys, os, json
web, port, transport, relay = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:]
s = open(os.path.join(web, "index.html")).read()
user = ["--client1", "--join-ip=127.0.0.1", "--mp-port=%s" % port, "--probe=client", "--probe-linger-s=30"]
if transport == "relay":
    user += ["--transport=relay"] + relay
args = '"args":' + json.dumps(["--"] + user)
open(os.path.join(web, "probe.html"), "w").write(s.replace('"args":[]', args))
PYEOF
gd "$OUT/server.log" -- --server --transport="$TRANSPORT" --mp-port="$PORT" --probe=watch --probe-timeout-s="$WAIT_S" --probe-linger-s=5
SERVER=$LAST_PID
# a refused WebSocket client does not retry: only show the page once the server listens
if [ "$TRANSPORT" = relay ]; then
  wait_line "$OUT/relay.log" "host lab$$-$PORT\$" "$SERVER" 30 || { echo "FAIL the server did not host its relay room"; echo "$TAG FAIL"; exit 1; }
else
python3 - "$PORT" <<'PYEOF' || { echo "FAIL the server did not open port $PORT"; echo "$TAG FAIL"; exit 1; }
import socket, sys, time
end = time.time() + 30
while time.time() < end:
    try:
        socket.create_connection(("127.0.0.1", int(sys.argv[1])), 0.5).close()
        sys.exit(0)
    except OSError:
        time.sleep(0.2)
sys.exit(1)
PYEOF
fi
( cd "$WEB" && exec python3 -m http.server "$HTTP_PORT" --bind 127.0.0.1 > "$OUT/http.log" 2>&1 ) &
HTTP=$!
URL="http://127.0.0.1:$HTTP_PORT/probe.html"
BROWSER_BIN="$(find_browser)"
if [ -n "$BROWSER_BIN" ]; then
  ## A visible tab is not needed: headless pages keep their frame loop running (a hidden tab would be throttled).
  "$BROWSER_BIN" --headless=new --user-data-dir="$OUT/browser" --no-first-run --no-default-browser-check \
    --use-angle=swiftshader --enable-unsafe-swiftshader --window-size=1024,768 --enable-logging=stderr "$URL" > "$OUT/browser.log" 2>&1 &
  CHROME=$!
  echo "$CHROME" >> "$OUT/pids"
  echo "Opened $URL in a headless browser (waiting ${WAIT_S}s for the browser client)"
else
  echo "Open $URL (waiting ${WAIT_S}s for the browser client)"
fi
wait_line "$OUT/server.log" "^PROBE watch (PASS|FAIL)" "$SERVER" "$((WAIT_S + 10))"
grep -E "^(PASS|FAIL|SCRIPT ERROR)" "$OUT/server.log" | sed 's/^/server: /'
if grep -q "^PROBE watch PASS" "$OUT/server.log"; then echo "$TAG PASS"; exit 0; fi
echo "$TAG FAIL (logs in $OUT)"
exit 1
