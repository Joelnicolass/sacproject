#!/usr/bin/env bash
# Self-test of godot_run.sh without Godot: fake commands (bash -c 'sleep N' --headless) exercise the queue.
# Usage: bash selftest_queue.sh      (about 20 s; uses its own namespace, no interference with real runs)
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
export GODOT_RUN_NS="selftest$$"
export GODOT_RUN_NO_PREFLIGHT=1
RUN="$HERE/godot_run.sh"
T="$(mktemp -d)"
echo 'exit 0' > "$T/nobusy.sh"
export GODOT_BUSY_SCRIPT="$T/nobusy.sh"
fail=0
ok()  { echo "PASS $1"; }
bad() { echo "FAIL $1"; fail=1; }
trap 'rm -rf "$T" /tmp/${GODOT_RUN_NS}_godot.*' EXIT

# 1. Two headless at once take slot0 and slot1.
bash "$RUN" bash -c 'sleep 4' --headless 2> "$T/a.err" &
sleep 1
bash "$RUN" bash -c 'sleep 1' --headless 2> "$T/b.err" &
wait
grep -q 'slot0)' "$T/a.err" && grep -q 'slot1)' "$T/b.err" && ok "two headless -> slot0/slot1" || bad "slots: $(cat "$T/a.err" "$T/b.err")"

# 2. HEADLESS_SLOTS=1: the second waits for the first.
HEADLESS_SLOTS=1 bash "$RUN" bash -c 'sleep 4' --headless 2> "$T/c.err" &
sleep 1
s=$(date +%s)
HEADLESS_SLOTS=1 bash "$RUN" bash -c 'true' --headless 2> "$T/d.err"
e=$(( $(date +%s) - s ))
wait
[ "$e" -ge 2 ] && ok "slot limit waits (${e}s)" || bad "slot limit did not wait (${e}s)"

# 3. An --import waits for a running headless and says so.
bash "$RUN" bash -c 'sleep 4' --headless 2> "$T/e.err" &
sleep 1
bash "$RUN" bash -c 'true' --import 2> "$T/f.err"
wait
grep -q 'import exclusivo' "$T/f.err" && ok "import exclusive" || bad "import: $(cat "$T/f.err")"

# 4. Preflight: a missing class_name in the cache triggers import x2 (fake GODOT_BIN records its calls).
P="$T/proj"; mkdir -p "$P/.godot"
: > "$P/project.godot"
echo 'class_name SelftestThing' > "$P/thing.gd"
cat > "$T/fakegodot" <<EOS
#!/usr/bin/env bash
echo "\$*" >> "$T/imports.log"
EOS
chmod +x "$T/fakegodot"
( unset GODOT_RUN_NO_PREFLIGHT; GODOT_BIN="$T/fakegodot" bash "$RUN" bash -c 'true' --headless --path "$P" 2> "$T/g.err" )
grep -q 'clases sin importar (SelftestThing' "$T/g.err" && [ "$(grep -c -- '--import' "$T/imports.log" 2>/dev/null)" = 2 ] && ok "preflight imports x2" || bad "preflight: $(cat "$T/g.err") / $(cat "$T/imports.log" 2>/dev/null)"

# 5. An --import of ANOTHER project does not wait for a headless run of this one (per-project import lock).
mkdir -p "$T/other"
bash "$RUN" bash -c 'sleep 5' --headless 2> "$T/h.err" &
sleep 1
s=$(date +%s)
( cd "$T/other" && bash "$RUN" bash -c 'true' --import 2> "$T/i.err" )
e=$(( $(date +%s) - s ))
wait
[ "$e" -le 3 ] && grep -q 'import exclusivo' "$T/i.err" && ok "import of another project runs at once (${e}s)" || bad "import of another project waited ${e}s: $(cat "$T/i.err")"

exit $fail
