#!/usr/bin/env bash
# Self-test of the determinism module with its own scene (example/det_selftest.tscn), no game needed.
#   bash addons/agent_kit/determinism/det_selftest.sh        (needs Godot; GODOT_BIN or godot in PATH; a few minutes)
# Checks, in a scratch folder (the project baseline is never touched):
#   1. `all fixed fixed2 stress`: same digests in every mode -> DETERMINISM PASS
#   2. `bless` + `quick --no-window` -> QUICK PASS
#   3. a baseline with a false digest -> `baseline ... FAIL` and QUICK FAIL
#   4. `--break` (a script that does not compile) -> watchdog=script_error_kill, well before any time limit
# Prints SELFTEST PASS or SELFTEST FAIL. Put an external limit on it, e.g.:
#   perl -e 'alarm 900; exec @ARGV' bash addons/agent_kit/determinism/det_selftest.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/det_run.sh"
CASES="$HERE/example/det_cases.txt"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export DET_OUT="$T/out"
export DET_BASELINE="$T/base.txt"
fail=0
ok()  { echo "PASS $1"; }
bad() { echo "FAIL $1"; fail=1; }

log="$T/all.log"
bash "$RUN" "$CASES" all fixed fixed2 stress > "$log" 2>&1
cat "$log"
grep -q "^DETERMINISM PASS" "$log" && ok "all: same digest in fixed, fixed2 and stress" || bad "all"

bash "$RUN" "$CASES" bless > "$T/bless.log" 2>&1 && [ -s "$DET_BASELINE" ] && ok "bless wrote the baseline" || bad "bless"

bash "$RUN" "$CASES" quick --no-window > "$T/q1.log" 2>&1
cat "$T/q1.log"
grep -q "^QUICK PASS" "$T/q1.log" && ok "quick with a fresh baseline" || bad "quick PASS"

sed '1s/ .*/ 0000000000000000000000000000000000000000000000000000000000000000/' "$DET_BASELINE" > "$T/fake.txt"
DET_BASELINE="$T/fake.txt" bash "$RUN" "$CASES" quick --no-window > "$T/q2.log" 2>&1
cat "$T/q2.log"
grep -q "^baseline .* FAIL" "$T/q2.log" && grep -q "^QUICK FAIL" "$T/q2.log" && ok "false baseline -> QUICK FAIL" || bad "false baseline"

bash "$RUN" "$CASES" broken fixed > "$T/b.log" 2>&1
cat "$T/b.log"
grep -q "watchdog=script_error_kill" "$DET_OUT/broken_fixed.meta" 2>/dev/null && ok "broken script -> script_error_kill" || bad "script_error_kill"

[ $fail = 0 ] && { echo "SELFTEST PASS"; exit 0; } || { echo "SELFTEST FAIL"; exit 1; }
