#!/usr/bin/env bash
# MpKit relay rules (no Godot): who may host a room. Starts addons/mp_kit/relay/server.mjs three ways and tries the
# WebSocket upgrade as a host and as a client. Prints PASS / FAIL lines and MPKIT RELAY PASS / FAIL (exit 0 / 1).
#   with RELAY_HOST_SECRET   the secret in the X-Relay-Secret header or ?secret= hosts; none or a wrong one is refused;
#                            a room with a live host refuses a second host (4009, a port in use)
#   without a secret         every host is refused (a public relay nobody can take over)
#   RELAY_OPEN=1             anyone may host (local tests only)
HERE="$(cd "$(dirname "$0")" && pwd)"
SERVER="$HERE/../addons/mp_kit/relay/server.mjs"
PORT="${RELAY_TEST_PORT:-8795}"
FAILS=0
PID=""
trap '[ -n "$PID" ] && kill "$PID" 2>/dev/null' EXIT
check() { if [ "$1" = "$2" ]; then echo "PASS $3"; else echo "FAIL $3 (got $1, want $2)"; FAILS=$((FAILS + 1)); fi; }
up() { # up [VAR=value…]: the relay on $PORT with that environment
  [ -n "$PID" ] && kill "$PID" 2>/dev/null && wait "$PID" 2>/dev/null
  env PORT="$PORT" RELAY_QUIET=1 "$@" node "$SERVER" > /dev/null 2>&1 &
  PID=$!
  for _ in $(seq 1 50); do curl -sf "http://127.0.0.1:$PORT/health" > /dev/null && return 0; sleep 0.1; done
  echo "FAIL the relay did not start"; FAILS=$((FAILS + 1))
}
hold_then_second() { # one host holds the room open, a second host with the secret tries it: its close code
  node -e '
    const http = require("http");
    const port = process.argv[1], room = process.argv[2];
    const open = (onSocket) => {
      const req = http.request({ host: "127.0.0.1", port, path: "/?role=host&" + room, headers: {
        Connection: "Upgrade", Upgrade: "websocket", "Sec-WebSocket-Version": "13",
        "Sec-WebSocket-Key": "dGhlIHNhbXBsZSBub25jZQ==", "X-Relay-Secret": "s3cret" } });
      req.on("upgrade", (res, socket) => onSocket(socket));
      req.on("error", () => { console.log("error"); process.exit(0); });
      req.end();
    };
    open((first) => setTimeout(() => open((second) => {
      let buf = Buffer.alloc(0);
      second.on("data", (d) => {
        buf = Buffer.concat([buf, d]);
        for (let i = 0; i + 3 < buf.length; i++) if (buf[i] === 0x88) { console.log(buf.readUInt16BE(i + 2)); process.exit(0); }
      });
      setTimeout(() => { console.log("no close"); process.exit(0); }, 2000);
    }), 200));' "$PORT" "$1"
}
try() { # try <query> [header]: the HTTP status of the upgrade (101 = accepted)
  node -e '
    const http = require("http");
    const headers = { Connection: "Upgrade", Upgrade: "websocket", "Sec-WebSocket-Version": "13", "Sec-WebSocket-Key": "dGhlIHNhbXBsZSBub25jZQ==" };
    if (process.argv[3]) { const [k, v] = process.argv[3].split(": "); headers[k] = v; }
    const req = http.request({ host: "127.0.0.1", port: process.argv[1], path: "/" + process.argv[2], headers });
    req.on("upgrade", (res, socket) => { console.log(res.statusCode); socket.destroy(); });
    req.on("response", (res) => { console.log(res.statusCode); res.destroy(); });
    req.on("error", () => console.log("error"));
    req.end();' "$PORT" "$1" "${2:-}"
}
up RELAY_HOST_SECRET=s3cret
check "$(try '?role=host&room=a' 'X-Relay-Secret: s3cret')" 101 "with a secret: the secret in the header hosts"
check "$(try '?role=host&room=b&secret=s3cret')" 101 "with a secret: the secret in the query hosts"
check "$(try '?role=host&room=c')" 403 "with a secret: a host without it is refused"
check "$(try '?role=host&room=a' 'X-Relay-Secret: wrong')" 403 "with a secret: a wrong secret cannot take a room over"
check "$(hold_then_second 'room=busy')" 4009 "a room with a live host refuses a second host with the secret (4009)"
check "$(try '?role=client&room=nobody')" 101 "a client is let in (and closed with 4004 when the room has no host)"
up
check "$(try '?role=host&room=a' 'X-Relay-Secret: anything')" 403 "without a secret: every host is refused"
up RELAY_OPEN=1
check "$(try '?role=host&room=a')" 101 "RELAY_OPEN=1: anyone may host"
if [ "$FAILS" = 0 ]; then echo "MPKIT RELAY PASS"; exit 0; fi
echo "MPKIT RELAY FAIL: $FAILS"
exit 1
