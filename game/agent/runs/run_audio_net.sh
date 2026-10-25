#!/usr/bin/env bash
# RFC-052 052c (F362): the creature sounds also play on a REMOTE client of a dedicated server, deduced from replicated state.
#   dedicated: `--dedicated --map=test_flat --world=res://debug/audio/audio_net_match.tscn` (its gate is closed: no audio);
#   client:    debug/audio/audio_net_client.tscn with `--audio-probe` joins it; the server summons a duel next to its wizard and the
#              client's SoundLog must get summon, swing, damaged and death of the creatures, and fx: the server then
#              broadcasts an FX (blood) and the client hears it through FxBus.played and FxSounds (052d).
#              052e: the client asks for a spell nobody has; the server's refusal (bad_target) comes back through the cast feedback
#              RPC and the client's advisor says it (advice).
# Both run inside ONE group reservation of the Godot queue, with --fixed-fps (NET_FPS, 600); every wait is on a log line or real
# seconds. Watchdog LIMIT_S kills them by pid and descendants (no pkill). UDP port 7861 by default (E2E_PORT).
# Extra user args go to the client. Prints the counts and AUDIO NET PASS / AUDIO NET FAIL (exit 0 / 1).
. "$(dirname "$0")/../harness/net_e2e.sh"
net_group 2 "$@"
TAG="AUDIO NET"
LIMIT_S="${PROBE_LIMIT_S:-90}"
PROC_MAX=3
PORT="${E2E_PORT:-7861}"
WORLD="res://debug/audio/audio_net_match.tscn"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/audio_net.XXXXXX")"
START_S=$SECONDS

kill_all() { kill_pids; }
trap 'kill_all; net_stop' EXIT
net_guard

gd "$OUT/server.log" "${FPS_FLAGS[@]}" -- --dedicated --mp-port="$PORT" --map=test_flat --world="$WORLD"
SERVER=$LAST_PID
READY=0
wait_line "$OUT/server.log" "dedicated listo" "$SERVER" 30 && READY=1
gd "$OUT/client.log" "${FPS_FLAGS[@]}" res://debug/audio/audio_net_client.tscn -- --mp-port="$PORT" --world="$WORLD" --map=test_flat \
  --audio-probe --e2e-name=Ana --e2e-timeout-s=60 "$@"
CLIENT=$LAST_PID
wait "$CLIENT"; CODE=$?
kill_tree "$SERVER"; wait "$SERVER" 2>/dev/null

echo "--- server ---"; grep -E "^(duelo de audio|mapa|dedicated listo|SCRIPT ERROR|ERROR)" "$OUT/server.log" | head -20
echo "--- client ---"; grep -E "^(AUDIO_NET|en mapa|SCRIPT ERROR|ERROR|WARNING)" "$OUT/client.log" | head -30
VERDICT=0
[ "$READY" = 1 ] || { echo "FAIL the dedicated did not start"; VERDICT=1; }
grep -q "^AUDIO_NET Ana PASS" "$OUT/client.log" || VERDICT=1
[ "$CODE" = 0 ] || VERDICT=1
if grep -qE "SCRIPT ERROR" "$OUT/server.log" "$OUT/client.log"; then echo "FAIL SCRIPT ERROR in a log"; VERDICT=1; fi
if [ -s "$OUT/timeout.flag" ]; then cat "$OUT/timeout.flag"; VERDICT=1; fi
net_stop
echo "$((SECONDS - START_S)) s"
if [ "$VERDICT" = 0 ]; then echo "$TAG PASS"; rm -rf "$OUT"; else echo "$TAG FAIL (logs in $OUT)"; fi
exit "$VERDICT"
