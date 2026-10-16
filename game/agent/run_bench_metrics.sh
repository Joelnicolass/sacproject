#!/usr/bin/env bash
# usage: run_bench_metrics.sh pyro|persephone OUTDIR [bench args...]  -- one bench run (runner of 022e4) + metrics, summary in OUTDIR.txt
cd "$(dirname "$0")/.."
GOD=$1; OUT=$2; shift 2
rm -rf "agent/out/rfc022e4/$OUT"
RUN_LOOPS=${RUN_LOOPS:-150} bash agent/run_rfc022e4.sh "rfc022e4c_bench_$GOD" "$OUT" "$@" > "agent/out/rfc022e4/$OUT.run" 2>&1
BASE=""
[ -n "$BASEDIR" ] && BASE="--base $BASEDIR"
python3 -I agent/grass_bench_metrics.py "agent/out/rfc022e4/$OUT" $BASE > "agent/out/rfc022e4/$OUT.txt" 2>&1
echo FINISHED >> "agent/out/rfc022e4/$OUT.txt"
