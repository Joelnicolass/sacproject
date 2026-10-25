#!/usr/bin/env bash
# 055s s4: what the EXPORTED dedicated server costs (time to «ready» and memory), where the memory goes, and that a client plays against it.
#   1. export      `--export-pack dedicated_server` of the project: DedicatedStrip (addons/sacrifice_tools) empties audio and clip tracks.
#                  COST_AB=1 also exports the same preset with SAC_DEDICATED_STRIP=0 (no strip) to measure what the strip saves.
#   2. cost        the pack runs with this Mac's Godot, `--main-pack <pck> --headless -- --dedicated --no-flow` (the flags of the
#                  3626fb2e measure): seconds to the line `dedicated listo puerto` and RSS (ps) COST_RSS_WAIT_S (5) seconds after it, median of
#                  COST_RUNS (3) runs. The same run from the project folder («today's», no export) and a room server (`--room-server`) from the pack
#                  and from the project (line `salas listo puerto`). Also the RSS of an empty Godot project (engine floor of this binary).
#   3. client      a room server (project) whose dedicated is the EXPORTED pack (`--match-engine-args=--main-pack,<pck>`; the folder of the
#                  project is also passed with --path, the pack wins) and two project clients that load the world, play to a forced defeat
#                  and read the result: the same checks as run_net_quick.sh, plus «the dedicated of the match ran from the pack».
#   4. breakdown   a second pack with the memory probe inside (agent/harness/dedicated_mem_probe.gd, put there by DedicatedStrip with
#                  SAC_PACK_PROBE=1). The probe boots the dedicated and prints, as `COST breakdown MEM ...` lines:
#                    autoloads static=X   Performance.MEMORY_STATIC once the autoloads (GameData, catalog, buses) are up
#                    boot static=Y        the same after the main scene; Y - X is what the boot scene brings
#                    objects ...          resources / nodes / texture and buffer memory
#                    folder <dir> n=N     files of that folder (3 levels) in the resource cache, most files first
#                    class <Class> n=N units=U  resources by class; units = bytes (AudioStreamWAV), vertices (ArrayMesh), keys (Animation), pixels (Texture2D)
#                  and the script adds the RSS of the probe process and macOS `vmmap -summary` (COST_VMMAP=0 skips it).
#                  Read it: RSS = engine floor (empty project, same binary) + autoloads + boot scene + the rest of the process (malloc fragmentation,
#                  the binary, thread stacks). The 380 MB target depends on the folders/classes at the top and on `boot - autoloads`.
# The target (COST_TARGET_S 3.0, COST_TARGET_MB 380) is printed, never fails the run, unless COST_STRICT=1. A run FAILS if the export fails, a
# measure never sees its ready line, the client check fails or a Godot is left alive.
# Environment: COST_ONLY=export|cost|client|breakdown (default all), COST_RUNS, COST_AB, COST_KEEP=1 keeps the folder with the packs and logs.
# Everything runs in ONE group reservation of the Godot queue (net_group), launched directly; no pkill (pids and descendants only).
# Needs `--import` once first (new class_names). Uses UDP 7706 (lobby of the client check), 7707 (room server measure), 7800-7803 (matches).
# A copy of the summary lines goes to agent/out/055s/dedicated_cost.txt. Prints DEDICATED COST PASS / FAIL (exit 0 / 1).
. "$(dirname "$0")/../harness/net_e2e.sh"
net_group 5 "$@"
TAG="DEDICATED COST"
LIMIT_S="${PROBE_LIMIT_S:-1500}"
PROC_MAX=6
RUNS="${COST_RUNS:-3}"
RSS_WAIT_S="${COST_RSS_WAIT_S:-5}"
TARGET_S="${COST_TARGET_S:-3.0}"
TARGET_MB="${COST_TARGET_MB:-380}"
ONLY="${COST_ONLY:-all}"
LOBBY_PORT="${E2E_LOBBY_PORT:-7706}"
ROOM_PORT="${COST_ROOM_PORT:-7707}"
FORCE_TICKS="${E2E_FORCE_TICKS:-120}"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/dedicated_cost.XXXXXX")"
MATCHES="$OUT/matches"
PCK="$OUT/sacrifice_server.pck"
PCK_PLAIN="$OUT/sacrifice_server_plain.pck"
PCK_PROBE="$OUT/probe.pck"
SUMMARY="$ROOT/agent/out/055s/dedicated_cost.txt"
READY_RE="dedicated listo puerto"
FAILS=0
START_S=$SECONDS
mkdir -p "$MATCHES" "$(dirname "$SUMMARY")"
: > "$SUMMARY"
export NET_T0=$(perl -MTime::HiRes=time -e "print time")

kill_stray() { # every Godot of this run (the packs and the logs live under $OUT)
  local p
  for p in $(ps -axo pid=,args= | awk -v m="$OUT" '$2 ~ /\/Godot$/ && index($0, m) {print $1}'); do kill "$p" 2>/dev/null; done
}
kill_all() { kill_pids; kill_stray; }
trap 'kill_all; net_stop' EXIT
net_guard

want() { [ "$ONLY" = all ] || [ "$ONLY" = "$1" ]; }
say() { echo "$@" | tee -a "$SUMMARY"; }
fail() { say "FAIL $*"; FAILS=$((FAILS + 1)); }
pid_of() { ps -axo pid=,args= | awk -v m="$1" '$2 ~ /\/Godot$/ && index($0, m) {print $1; exit}'; }
rss_mb() { ps -o rss= -p "$1" 2>/dev/null | awk '{printf "%.0f", $1 / 1024}'; }
median() { sort -n | awk '{a[NR] = $1} END {if (NR == 0) print "n/a"; else if (NR % 2) print a[(NR + 1) / 2]; else printf "%.2f\n", (a[NR / 2] + a[NR / 2 + 1]) / 2}'; }

export_pack() { # export_pack <pck> <log> [VAR=value ...]: the preset dedicated_server as a pack, with the Godot of this Mac
  local pck="$1" log="$2"; shift 2
  env "$@" perl -e 'alarm 900; exec @ARGV' "$GODOT" --headless --path "$ROOT" --export-pack dedicated_server "$pck" > "$log" 2>&1
  local code=$?
  if [ $code -ne 0 ] || [ ! -s "$pck" ]; then
    grep -E "ERROR|SCRIPT ERROR|Parse Error" "$log" | head -n 8
    fail "the export of $(basename "$pck") failed (exit $code, log $log)"
    return 1
  fi
  say "COST export $(basename "$pck") $(( $(wc -c < "$pck") / 1048576 )) MB; $(grep -E '^DedicatedStrip ' "$log" | tail -n 1)"
}

measure() { # measure <label> <ready_regex or -> <godot args…>: RUNS runs, medians; "-" = no ready line, only the RSS RSS_WAIT_S after the start
  local label="$1" re="$2"; shift 2
  local i log sub pid ready rss times="" mbs="" first=1
  for i in $(seq 1 "$RUNS"); do
    log="$OUT/$label.$i.log"
    ( "$GODOT" --headless "$@" --cost-run="$OUT/$label.$i" 2>&1 | perl -MTime::HiRes=time -ne 'BEGIN{$|=1;$t=time} printf "%.3f %s", time-$t, $_' > "$log" ) &
    sub=$!
    if [ "$re" = "-" ]; then
      sleep 1
      ready="-"
    elif wait_line "$log" "^[0-9.]+ $re" "" 90; then
      ready=$(grep -m1 -E "^[0-9.]+ $re" "$log" | cut -d' ' -f1)
    else
      ready=""
    fi
    sleep "$RSS_WAIT_S"
    pid=$(pid_of "--cost-run=$OUT/$label.$i")
    if [ -z "$pid" ] || [ -z "$ready" ]; then
      fail "$label run $i: the process (pid '$pid') never printed «$re» (log $log)"
    else
      echo "$pid" >> "$OUT/pids"
      rss=$(rss_mb "$pid")
      say "COST $label run $i ready_s=$ready rss_mb=$rss"
      [ "$ready" != "-" ] && times="$times$ready\n"
      mbs="$mbs$rss\n"
      if [ "$first" = 1 ] && [ "${COST_VMMAP:-1}" = 1 ] && command -v vmmap >/dev/null 2>&1; then
        vmmap -summary "$pid" 2>/dev/null | grep -E "^(Physical footprint|TOTAL|MALLOC|mapped file|VM_ALLOCATE|IOKit|Stack|__DATA|__TEXT)" | sed "s/^/COST vmmap $label /" | tee -a "$SUMMARY"
      fi
      first=0
    fi
    [ -n "$pid" ] && kill_tree "$pid"
    wait "$sub" 2>/dev/null
  done
  local t m
  t=$(printf "$times" | median); m=$(printf "$mbs" | median)
  say "COST $label MEDIAN ready_s=$t rss_mb=$m ($RUNS runs)"
  MEDIAN_S="$t"; MEDIAN_MB="$m"
}

target() { # target <label> <seconds> <mb>
  awk -v s="$2" -v m="$3" -v ts="$TARGET_S" -v tm="$TARGET_MB" 'BEGIN {
    ok_s = (s != "n/a" && s + 0 <= ts + 0) ? "OK" : "OVER"; ok_m = (m != "n/a" && m + 0 <= tm + 0) ? "OK" : "OVER"
    printf "COST target %s: time %s s (%s %s s), memory %s MB (%s %s MB)\n", "'"$1"'", s, ok_s, ts, m, ok_m, tm }' | tee -a "$SUMMARY"
  if [ "${COST_STRICT:-0}" = 1 ] && awk -v s="$2" -v m="$3" -v ts="$TARGET_S" -v tm="$TARGET_MB" 'BEGIN {exit !(s + 0 > ts + 0 || m + 0 > tm + 0)}'; then
    fail "$1 is over the target (COST_STRICT=1)"
  fi
}

# --- 1. export ----------------------------------------------------------------------------------------------------------
if want export || want cost || want client; then
  export_pack "$PCK" "$OUT/export.log" || exit 1
  if grep -q "DedicatedStrip audio=0 animations=0" "$OUT/export.log"; then
    say "WARN the export replaced nothing: Godot served the customized files from its cache (the pack is still stripped) or the plugin did not run"
  elif ! grep -q "^DedicatedStrip " "$OUT/export.log"; then
    fail "the log of the export has no DedicatedStrip line: is the addon sacrifice_tools enabled?"
  fi
  [ "${COST_AB:-0}" = 1 ] && { export_pack "$PCK_PLAIN" "$OUT/export_plain.log" SAC_DEDICATED_STRIP=0 || true; }
fi

# --- 2. cost ------------------------------------------------------------------------------------------------------------
if want cost; then
  say "COST pack on this Mac: $(basename "$GODOT") with --main-pack, flags: -- --dedicated --no-flow"
  measure dedicated_pack "$READY_RE" --main-pack "$PCK" -- --dedicated --no-flow
  target dedicated_pack "$MEDIAN_S" "$MEDIAN_MB"
  if [ "${COST_AB:-0}" = 1 ] && [ -s "$PCK_PLAIN" ]; then
    measure dedicated_pack_plain "$READY_RE" --main-pack "$PCK_PLAIN" -- --dedicated --no-flow
  fi
  measure dedicated_project "$READY_RE" --path "$ROOT" -- --dedicated --no-flow
  measure room_pack "salas listo puerto" --main-pack "$PCK" -- --room-server --room-test-maps --lobby-config=res://data/net/lobby_config_local.tres --lobby-port="$ROOM_PORT"
  measure room_project "salas listo puerto" --path "$ROOT" -- --room-server --room-test-maps --lobby-config=res://data/net/lobby_config_local.tres --lobby-port="$ROOM_PORT"
  EMPTY="$OUT/empty"; mkdir -p "$EMPTY"
  printf 'config_version=5\n\n[application]\nconfig/name="engine floor"\nrun/main_scene="res://main.tscn"\n' > "$EMPTY/project.godot"
  printf '[gd_scene format=3]\n\n[node name="Main" type="Node"]\n' > "$EMPTY/main.tscn"
  measure engine_floor - --path "$EMPTY" --
fi

# --- 3. a client against the exported dedicated -------------------------------------------------------------------------------
READY=0
if want client; then
  CLIENT_FLAGS=(--transport=enet --lobby-port="$LOBBY_PORT")
  gd "$OUT/server.log" res://scenes/net/room_server.tscn -- \
    --room-server --room-test-maps --transport=enet --lobby-config=res://data/net/lobby_config_local.tres --lobby-port="$LOBBY_PORT" \
    --max-matches=1 --ticket-ttl-s=30 --idle-no-players-s=20 --resume-grace-s=5 --matches-root="$MATCHES" \
    --countdown-s=0.2 --poll-s=0.1 --heartbeat-s=0.5 --parent-check-s=0.5 --rejoin-grace-s=2 --result-quit-delay-s=1 \
    --match-engine-args="--main-pack,$PCK,--fixed-fps,$NET_FPS" --match-args=--force-defeat-slot=2,--force-defeat-after-ticks="$FORCE_TICKS"
  SERVER=$LAST_PID
  wait_line "$OUT/server.log" "^salas listo puerto" "$SERVER" 30 && READY=1
  gd "$OUT/Ana.log" res://debug/net/room_world_client.tscn -- "${CLIENT_FLAGS[@]}" --e2e-name=Ana --e2e-room=SalaFlat --e2e-peer=Aldo --e2e-create \
    --e2e-world=test_flat --e2e-biome=pyro --e2e-wizard=cwa0 --e2e-model=jnwr --e2e-god=james --e2e-expect-winner=1
  ANA=$LAST_PID
  gd "$OUT/Aldo.log" res://debug/net/room_world_client.tscn -- "${CLIENT_FLAGS[@]}" --e2e-name=Aldo --e2e-room=SalaFlat --e2e-peer=Ana \
    --e2e-world=test_flat --e2e-biome=pyro --e2e-wizard=cwa1 --e2e-model=serx --e2e-god=pyro --e2e-expect-winner=1
  ALDO=$LAST_PID
  ON_PACK=0
  for _ in $(seq 1 120); do # while the match runs, its dedicated must have the pack in its command line
    ON_PACK=$(ps -axo args= | awk -v p="$PCK" 'index($0, "match-ticket-file") && index($0, p)' | wc -l | tr -d ' ')
    [ "$ON_PACK" != 0 ] && break
    sleep 0.25
  done
  for p in $ANA $ALDO; do wait "$p"; done
  wait_gone "match-ticket-file=$MATCHES" 15
  python3 - "$OUT" "$LOBBY_PORT" "$ON_PACK" <<'PYEOF' | tee -a "$SUMMARY"
import json, os, re, sys
out, lobby_port, on_pack = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
fails = []
def check(ok, what):
    print(("COST client PASS " if ok else "COST client FAIL ") + what)
    if not ok:
        fails.append(what)
def read(name):
    try:
        return open(os.path.join(out, name), errors="replace").read().splitlines()
    except OSError:
        return []
server = read("server.log")
check(any(l.startswith("salas listo puerto %d" % lobby_port) for l in server), "the room server announced its port")
launch = None
for l in server:
    m = re.match(r'^partida (\S+) sala "SalaFlat" puerto (\d+) semilla (\d+)$', l)
    if m:
        launch = m.group(1)
check(launch is not None, "the server launched the match of SalaFlat")
check(on_pack > 0, "the dedicated of the match ran from the exported pack (--main-pack in its command line)")
if launch:
    pre = "partida %s: " % launch
    mine = [l for l in server if l.startswith(pre)]
    check(any(l.startswith(pre + "ticket con 2 asientos") for l in mine), "the dedicated read its ticket (2 seats)")
    check("mapa test_flat" in server, "the dedicated loaded the map test_flat")
    check(any(re.match(r"^" + re.escape(pre) + r"slot \d cargó el mundo \(2/2\)$", l) for l in mine), "both clients loaded their world before the simulation started")
    results = [json.loads(l[len(pre + "resultado "):]) for l in mine if l.startswith(pre + "resultado ")]
    check(len(results) == 1 and results[0].get("reason") == "result" and int(results[0].get("winner_slot", -1)) == 1, "the match ended by the forced defeat (winner 1, result)")
    for who in ("Ana", "Aldo"):
        log = read(who + ".log")
        check(any(l == "E2E CLIENT %s PASS" % who for l in log), "%s passed all its checks (slot, world loaded, result)" % who)
        check(not any("SCRIPT ERROR" in l for l in log), "no SCRIPT ERROR in %s's log" % who)
check(not any("SCRIPT ERROR" in l for l in server), "no SCRIPT ERROR in the server log")
sys.exit(1 if fails else 0)
PYEOF
  [ "${PIPESTATUS[0]}" = 0 ] || FAILS=$((FAILS + 1))
  kill_tree "$SERVER"; wait "$SERVER" 2>/dev/null
  [ "$READY" = 1 ] || fail "the room server of the client check did not announce its port"
fi

# --- 4. where the memory goes ---------------------------------------------------------------------------------------------
if want breakdown; then
  if export_pack "$PCK_PROBE" "$OUT/export_probe.log" SAC_PACK_PROBE=1; then
    "$GODOT" --headless --main-pack "$PCK_PROBE" res://dedicated_mem_probe/probe.tscn -- --dedicated --no-flow --cost-run="$OUT/probe" > "$OUT/probe.log" 2>&1 &
    PROBE=$!
    echo "$PROBE" >> "$OUT/pids"
    if wait_line "$OUT/probe.log" "^MEM done" "$PROBE" 90; then
      PROBE_RSS=$(rss_mb "$PROBE")
      say "COST breakdown RSS of the probe process: $PROBE_RSS MB (stripped pack, boot as the dedicated does it)"
      grep -E "^MEM " "$OUT/probe.log" | sed "s/^/COST breakdown /" | tee -a "$SUMMARY"
      [ "${COST_VMMAP:-1}" = 1 ] && command -v vmmap >/dev/null 2>&1 && vmmap -summary "$PROBE" 2>/dev/null | grep -E "^(Physical footprint|TOTAL|MALLOC|mapped file|VM_ALLOCATE|IOKit|Stack|__DATA|__TEXT)" | sed "s/^/COST breakdown vmmap /" | tee -a "$SUMMARY"
    else
      say "WARN breakdown: the probe printed no «MEM done» (log $OUT/probe.log): is the probe in the pack? (grep DedicatedStrip $OUT/export_probe.log)"
    fi
    kill_tree "$PROBE"; wait "$PROBE" 2>/dev/null
  fi
fi

kill_all 2>/dev/null
wait_gone "$OUT" 5
STRAY=$(godots_with "$OUT")
[ "$STRAY" = 0 ] || fail "$STRAY Godot process of this run still alive after the kill"
[ -s "$OUT/timeout.flag" ] && { cat "$OUT/timeout.flag"; FAILS=$((FAILS + 1)); }
net_stop
say "$((SECONDS - START_S)) s; summary in $SUMMARY"
if [ "$FAILS" = 0 ]; then
  say "$TAG PASS"
  [ -n "${COST_KEEP:-}" ] || rm -rf "$OUT"
else
  say "$TAG FAIL ($FAILS; packs and logs in $OUT)"
fi
[ "$FAILS" = 0 ]
