#!/usr/bin/env bash
# RFC-069 W5: the loading screen's warm-up, measured (rfcs/plans/069-loading-warmup-plan.md §4). Two windowed runs of
# agent/perf/warmup_probe.tscn, «Contra la IA» on test_flat4 (MODE, default 2v2), one Godot at a time through the queue:
#   cold   the pipeline/shader caches of this project's user folder are removed first: load <= 8 s (COLD_LIMIT_S);
#   cached the caches the cold run left: load <= 3 s (CACHED_LIMIT_S).
# Each run checks: compilations DRAW+SPECIALIZATION > 0 while loading and = 0 after world_loaded; no frame > 50 ms and the longest
# <= 2x the median; VRAM at the end <= VRAM at world_loaded + 15 %. Criterion 5 (the gate) is agent/runs/run_068_gate.sh.
# The user folder is shared by every worktree of this project (same config/name): the cold run makes the others' next start
# slower, nothing else. MATCH_S (default 60) = seconds of play measured. Logs: agent/out/warmup/{cold,cached}.log.
# Needs `--import` once first. Prints WARMUP RUN PASS / WARMUP RUN FAIL (exit 0 / 1).
set -u
. "$(dirname "$0")/../harness/env.sh"
OUT="$ROOT/agent/out/warmup"
MODE="${MODE:-2v2}"
MAP="${MAP:-test_flat4}"
MATCH_S="${MATCH_S:-60}"
mkdir -p "$OUT"

NAME="$(sed -n 's/^config\/name="\(.*\)"$/\1/p' "$ROOT/project.godot" | head -1)"
case "$(uname -s)" in
  Darwin) USER_DIR="$HOME/Library/Application Support/Godot/app_userdata/$NAME" ;;
  *) USER_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/app_userdata/$NAME" ;;
esac

probe() { # <label> <load limit s>
  bash "$ROOT/agent/harness/godot_run.sh" "$GODOT_BIN" --path "$ROOT" res://agent/perf/warmup_probe.tscn -- \
    --map="$MAP" --mode="$MODE" --load-limit-s="$2" --match-s="$MATCH_S" > "$OUT/$1.log" 2>&1
  local code=$?
  echo "== $1 (exit $code)"
  grep -E "^(WARMUP_PROBE|PASS|FAIL|WARMUP )" "$OUT/$1.log"
  return $code
}

FAILS=0
for cache in shader_cache vulkan metal; do
  if [ -d "$USER_DIR/$cache" ]; then
    echo "cold: removing $USER_DIR/$cache"
    rm -rf "${USER_DIR:?}/$cache"
  fi
done
probe cold "${COLD_LIMIT_S:-8}" || FAILS=$((FAILS + 1))
probe cached "${CACHED_LIMIT_S:-3}" || FAILS=$((FAILS + 1))
if [ "$FAILS" -eq 0 ]; then echo "WARMUP RUN PASS"; exit 0; fi
echo "WARMUP RUN FAIL ($FAILS of 2)"; exit 1
