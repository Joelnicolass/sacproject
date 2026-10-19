#!/usr/bin/env bash
# RFC-027 027a (F85): the frame budget, one Godot at a time.
#   agent/runs/run_perf027.sh RUN [CASE...]   CASE: many0 many50 many150 match (default: all four, in that order)
#   agent/runs/run_perf027.sh table           markdown table from agent/out/perf027/*_r*.md
# Each case: agent/harness/godot_busy.sh must find no other test Godot (3 checks) or the script stops.
# many*: AgentKit flow perf027_many.json on agent/fixtures/perf027_many{_0,_50,}.tscn (vsync off: the bench,
# alone and short; --disable-vsync: Metal ignores a vsync change at run time). match: agent/fixtures/perf027_match.tscn, ai_vs_trivial seed 1, 3 min, normal cap.
# Watchdog: kills the run at RSS > 2.5 GB or after its time limit; writes CONTAMINATED in the log if another
# test Godot shows up during the run (discard that run). Logs: agent/out/perf027/<case>_r<RUN>.log.
set -u
ROOT=/Users/joelsartori/Development/sacproject/game
BIN=/Applications/Godot.app/Contents/MacOS/Godot
OUT="$ROOT/agent/out/perf027"

# Used as GODOT by AgentKit's cli.sh: the same binary with --print-fps (the control of the wall frame).
if [ -n "${PERF027_WRAP:-}" ]; then
  exec "$BIN" --print-fps --disable-vsync "$@"
fi

if [ "${1:-}" = "table" ]; then
  python3 -I - "$OUT" <<'PY'
import json, glob, os, sys
out = sys.argv[1]
rows = []
for path in sorted(glob.glob(os.path.join(out, "*_r*.md"))):
    for line in open(path):
        if line.startswith("PERF_TABLE "):
            rows.append(json.loads(line[len("PERF_TABLE "):]))
def g(d, *keys, default=""):
    for k in keys:
        if not isinstance(d, dict) or k not in d:
            return default
        d = d[k]
    return d
head = ["caso", "run", "cuerpos", "en marcha", "frame media", "p95", "ticks/frame (max)", "tick script", "tick completo",
        "sep", "picker", "visión", "IA", "proceso", "render CPU", "resto", "render base (1ª)", "-pasto", "-barras", "-sombras", "-mallas",
        "draws", "prims", "explicado (base pausa)", "explicado (render medido)", "VRAM", "RSS"]
print("| " + " | ".join(head) + " |")
print("|" + "---|" * len(head))
for r in rows:
    items = [(r["case"], r)] if r["case"] != "match" else [("match@%s" % g(w, "match_tick"), dict(w, render=r.get("render", {}) if w.get("explained_ms") is not None else {}, memory=r.get("memory", {}))) for w in r.get("windows", [])]
    for name, w in items:
        rend = w.get("render", {}) or {}
        sub = w.get("subsystems_ms_per_tick", {})
        cells = [
            "%s %s" % (r["label"], name), r["run"], g(w, "bodies"), str(g(w, "moving_bodies")),
            g(w, "wall_ms", "mean"), g(w, "wall_ms", "p95"),
            "%s (%s)" % (g(w, "ticks_per_frame", "mean"), g(w, "ticks_per_frame", "max")),
            g(w, "script_tick_ms", "mean"), g(w, "full_tick_ms", "mean"),
            sub.get("separation", ""), sub.get("target_picker", ""), sub.get("vision", ""), sub.get("ai_sides", ""),
            g(w, "process_ms"), g(w, "render_cpu_ms"), g(w, "rest_ms"),
            ("%s (%s)" % (rend.get("base_ms"), rend.get("base_first_ms"))) if rend else "",
            g(rend, "no_grass", "saves_ms"), g(rend, "no_bars", "saves_ms"), g(rend, "no_sun_shadows", "saves_ms"), g(rend, "no_body_meshes", "saves_ms"),
            g(w, "draws"), g(w, "prims"),
            ("%s ms (%s %%)" % (w.get("explained_ms"), w.get("explained_pct"))) if w.get("explained_ms") is not None else "",
            ("%s %%" % w.get("explained_measured_pct")) if w.get("explained_measured_pct") is not None else "",
            g(w, "memory", "vram_mb"), g(w, "memory", "rss_mb"),
        ]
        print("| " + " | ".join(str(c) for c in cells) + " |")
    if r["case"] == "match":
        w = r.get("whole_match", {})
        print("| %s partida entera (tope 60) | %s | | | %s | %s | %s (%s) | %s | %s | %s | %s | %s | %s | %s | %s | %s | | | | | | %s | %s | | | %s | %s |" % (
            r["label"], r["run"], g(w, "wall_ms", "mean"), g(w, "wall_ms", "p95"), g(w, "ticks_per_frame", "mean"), g(w, "ticks_per_frame", "max"),
            g(w, "script_tick_ms", "mean"), g(w, "full_tick_ms", "mean"),
            g(r, "whole_subsystems_ms_per_tick", "separation"), g(r, "whole_subsystems_ms_per_tick", "target_picker"),
            g(r, "whole_subsystems_ms_per_tick", "vision"), g(r, "whole_subsystems_ms_per_tick", "ai_sides"),
            g(w, "process_ms"), g(w, "render_cpu_ms"), g(w, "rest_ms"), g(w, "draws"), g(w, "prims"), g(r, "memory", "vram_mb"), g(r, "memory", "rss_mb")))
print()
print("Barridos por cuerpo (ms por pasada sobre todas las criaturas = un tick):")
for r in rows:
    sw = r.get("sweeps_ms_per_tick") or next((w.get("sweeps_ms_per_tick") for w in r.get("windows", []) if w.get("sweeps_ms_per_tick")), {})
    print("- %s %s r%s: %s" % (r["label"], r["case"], r["run"], json.dumps(sw)))
PY
  exit 0
fi

RUN=${1:?usage: run_perf027.sh RUN [CASE...] | table}
shift
CASES=("$@"); [ ${#CASES[@]} -eq 0 ] && CASES=(many0 many50 many150 match)
mkdir -p "$OUT"
cd "$ROOT"

watch() { # pid log limit_s
  local pid=$1 log=$2 limit=$3 start; start=$(date +%s)
  while kill -0 "$pid" 2>/dev/null; do
    local r; r=$(ps -o rss= -p "$pid" | tr -d ' ')
    [ -n "$r" ] && echo "$(date +%s) rss=$r" >> "$log.rss"
    if [ -n "$r" ] && [ "$r" -gt 2500000 ]; then echo "WATCHDOG RSS $r kill" >> "$log"; kill -9 "$pid"; fi
    if [ $(( $(date +%s) - start )) -gt "$limit" ]; then echo "WATCHDOG timeout ${limit}s kill" >> "$log"; kill -9 "$pid"; fi
    # Another test Godot during this run (not this one, not the user's editor): the numbers are not clean.
    local others; others=$(ps -axo pid=,args= | awk -v me="$pid" '$2 ~ /Godot\.app\/Contents\/MacOS\/Godot$/ && $1 != me && $NF != "--editor"' | cut -c1-160)
    [ -n "$others" ] && ! grep -q CONTAMINATED "$log" && echo "CONTAMINATED other Godot: $others" >> "$log"
    sleep 2
  done
}

for CASE in "${CASES[@]}"; do
  if ! bash "$ROOT/agent/harness/godot_busy.sh"; then
    echo "ABORT: another test Godot is running (see above); case $CASE not run"; exit 2
  fi
  LOG="$OUT/${CASE}_r${RUN}.log"
  rm -f "$LOG" "$LOG.rss"
  case "$CASE" in
    many0|many50|many150)
      SCENE="res://agent/fixtures/perf027_many.tscn"
      [ "$CASE" = many0 ] && SCENE="res://agent/fixtures/perf027_many_0.tscn"
      [ "$CASE" = many50 ] && SCENE="res://agent/fixtures/perf027_many_50.tscn"
      FLOW="$OUT/flow_${CASE}.json"
      sed "s#res://agent/fixtures/perf027_many.tscn#$SCENE#" "$ROOT/agent/flows/perf027_many.json" > "$FLOW"
      PERF027_WRAP=1 GODOT="$ROOT/agent/runs/run_perf027.sh" "$ROOT/addons/agent_kit/cli.sh" "$ROOT" flow \
        --flow="$FLOW" --out=res://agent/out/perf027/shots --perf-run="$RUN" > "$LOG" 2>&1 &
      P=$!; watch $P "$LOG" 900; wait $P; echo "$CASE r$RUN exit $?"
      ;;
    match)
      "$BIN" --print-fps --disable-vsync --path "$ROOT" --resolution 1280x720 res://agent/fixtures/perf027_match.tscn -- \
        --rules=res://debug/rules/ai_vs_trivial.tres --seed=1 --minutes=3 --autostart --perf-run="$RUN" > "$LOG" 2>&1 &
      P=$!; watch $P "$LOG" 900; wait $P; echo "$CASE r$RUN exit $?"
      ;;
    *) echo "unknown case $CASE"; exit 2 ;;
  esac
  grep -h "PERF_TABLE\|PERF_ABORT\|SCRIPT ERROR\|AGENT_OK\|AGENT_FAIL\|CONTAMINATED\|WATCHDOG" "$LOG" | cut -c1-200
done
