#!/usr/bin/env bash
# MpKit web client check (needs the Web export templates of Godot 4.7.2). Exports mpkit_lab for the browser (no threads, so
# no special headers), starts a native WebSocket dedicated server whose probe waits for a remote player to move and score,
# and serves the export on http://127.0.0.1:$HTTP_PORT. Open the printed URL in any browser (the page plays by itself as
# the first client: it passes the probe flags in its config); the verdict is the server's: MPKIT WEB PASS / FAIL.
# A page served over http may use ws://; a page over https needs wss:// (MpNetConfig TLS or a reverse proxy).
. "$(dirname "$0")/../harness/net_e2e.sh"
net_group 1 "$@"
TAG="MPKIT WEB"
LIMIT_S="${PROBE_LIMIT_S:-240}"
PROC_MAX=2
PORT="${E2E_PORT:-7793}"
HTTP_PORT="${HTTP_PORT:-8093}"
WAIT_S="${WAIT_S:-180}"
ROOT="$(cd "$ROOT/../mpkit_lab" && pwd)"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/mpkit_web.XXXXXX")"
WEB="$ROOT/scratch/web"
kill_all() { kill_pids; [ -n "${HTTP:-}" ] && kill "$HTTP" 2>/dev/null; }
trap 'kill_all; net_stop' EXIT
net_guard

mkdir -p "$WEB"
"$GODOT" --headless --path "$ROOT" --export-debug "Web" "$WEB/index.html" > "$OUT/export.log" 2>&1
[ -f "$WEB/index.wasm" ] || { echo "FAIL web export (see $OUT/export.log)"; echo "$TAG FAIL"; exit 1; }
python3 - "$WEB" "$PORT" <<'PYEOF'
import sys, os
web, port = sys.argv[1], sys.argv[2]
s = open(os.path.join(web, "index.html")).read()
args = '"args":["--","--client1","--join-ip=127.0.0.1","--mp-port=%s","--probe=client","--probe-linger-s=30"]' % port
open(os.path.join(web, "probe.html"), "w").write(s.replace('"args":[]', args))
PYEOF
gd "$OUT/server.log" -- --server --transport=ws --mp-port="$PORT" --probe=watch --probe-timeout-s="$WAIT_S" --probe-linger-s=5
SERVER=$LAST_PID
# a refused WebSocket client does not retry: only show the page once the server listens
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
( cd "$WEB" && exec python3 -m http.server "$HTTP_PORT" --bind 127.0.0.1 > "$OUT/http.log" 2>&1 ) &
HTTP=$!
echo "Open http://127.0.0.1:$HTTP_PORT/probe.html (waiting ${WAIT_S}s for the browser client)"
wait_line "$OUT/server.log" "^PROBE watch (PASS|FAIL)" "$SERVER" "$((WAIT_S + 10))"
grep -E "^(PASS|FAIL|SCRIPT ERROR)" "$OUT/server.log" | sed 's/^/server: /'
if grep -q "^PROBE watch PASS" "$OUT/server.log"; then echo "$TAG PASS"; exit 0; fi
echo "$TAG FAIL (logs in $OUT)"
exit 1
