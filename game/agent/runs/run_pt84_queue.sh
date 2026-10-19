#!/usr/bin/env bash
# usage: run_pt84_queue.sh "FLOW TAG RES SCALE" ...  -- before each run waits until no other Godot
# (except the user's --editor) is running, then runs it with run_pt84.sh. One process at a time.
H="$(cd "$(dirname "$0")/.." && pwd)"
for job in "$@"; do
  set -- $job
  until "$H/harness/godot_busy.sh" >/dev/null; do sleep 10; done
  echo "$(date +%T) start $job"
  "$H/run_pt84.sh" "$1" "$2" "$3" "${4:-}"
done
echo "$(date +%T) queue done"
