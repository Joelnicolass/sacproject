#!/usr/bin/env bash
# 055f (plan §10.1): the decision log of the AI, case by case, to compare two commits with `diff`.
#   bash agent/runs/run_ai_decisions.sh <phase> [--worktree <dir>] [--case <name>]... [GODOT_BIN]
#     phase       before | before_b | after_f4 | after_design (the folder the logs go to)
#     --worktree  run the project of another checkout (a `git worktree add <dir> <commit>`: <dir> or <dir>/game holds project.godot);
#                 default: this project. The list of cases is always this project's debug/ai/decision_cases.txt and the logs
#                 always land in this project's agent/out/055f/<phase>/.
#     --case      only these cases (repeatable); default: every line of the list.
# Each case is ONE headless run (--fixed-fps 60) through agent/harness/godot_run.sh (the machine-wide queue), with
# --decisions=agent/out/055f/<phase>/<case>.log; its stdout goes to <case>.stdout. A checkout with no .godot/ is imported first.
# Compare: diff -r agent/out/055f/before agent/out/055f/before_b (strict cases: empty diff).
# Prints DECISIONS <phase> PASS / FAIL (exit 0 / 1): FAIL when a run fails or leaves no log.
set -u
. "$(dirname "$0")/../harness/env.sh"
PHASE="${1:-}"
case "$PHASE" in
  before|before_b|after_f4|after_design) shift ;;
  *) echo "uso: run_ai_decisions.sh before|before_b|after_f4|after_design [--worktree <dir>] [--case <name>]... [GODOT_BIN]"; exit 2 ;;
esac
PROJ="$ROOT"
ONLY=()
while [ $# -gt 0 ]; do
  case "$1" in
    --worktree) shift; DIR="${1:-}"
      if [ -f "$DIR/project.godot" ]; then PROJ="$(cd "$DIR" && pwd)"
      elif [ -f "$DIR/game/project.godot" ]; then PROJ="$(cd "$DIR/game" && pwd)"
      else echo "no hay project.godot en $DIR ni en $DIR/game"; exit 2; fi ;;
    --case) shift; ONLY+=("${1:-}") ;;
    *) GODOT_BIN="$1" ;;
  esac
  shift
done
CASES="$ROOT/debug/ai/decision_cases.txt"
OUT="$ROOT/agent/out/055f/$PHASE"
RUN="$ROOT/agent/harness/godot_run.sh"
WATCHDOG_S="${DECISIONS_WATCHDOG_S:-1200}"
mkdir -p "$OUT"
echo "DECISIONS $PHASE proyecto $PROJ ($(git -C "$PROJ" rev-parse --short HEAD 2>/dev/null || echo '?'))" | tee "$OUT/_run.txt"
if [ ! -f "$PROJ/.godot/global_script_class_cache.cfg" ]; then
  echo "importando $PROJ (sin .godot/)"
  bash "$RUN" "$GODOT_BIN" --headless --path "$PROJ" --import < /dev/null > "$OUT/_import.stdout" 2>&1
fi
FAIL=0
while IFS='|' read -r name scene args; do
  case "$name" in ''|'#'*) continue ;; esac
  if [ ${#ONLY[@]} -gt 0 ] && ! printf '%s\n' "${ONLY[@]}" | grep -qx "$name"; then continue; fi
  log="$OUT/$name.log"
  rm -f "$log"
  started=$SECONDS
  # shellcheck disable=SC2086
  bash "$RUN" "$GODOT_BIN" --headless --path "$PROJ" --fixed-fps 60 "$scene" -- $args --decisions="$log" --watchdog-s="$WATCHDOG_S" \
    < /dev/null > "$OUT/$name.stdout" 2>&1
  code=$?
  lines=$( [ -f "$log" ] && wc -l < "$log" | tr -d ' ' || echo 0)
  verdict="ok"
  if [ ! -s "$log" ] || grep -q "SCRIPT ERROR" "$OUT/$name.stdout"; then verdict="FAIL"; FAIL=1; fi
  echo "$name exit $code lineas $lines $((SECONDS - started)) s $verdict" | tee -a "$OUT/_run.txt"
done < "$CASES"
if [ "$FAIL" = 0 ]; then echo "DECISIONS $PHASE PASS" | tee -a "$OUT/_run.txt"; else echo "DECISIONS $PHASE FAIL" | tee -a "$OUT/_run.txt"; fi
exit "$FAIL"
