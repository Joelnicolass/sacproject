#!/usr/bin/env bash
# Lists running Godot binaries except the user's main editor (3 checks, 2 s apart). Exit 1 if any.
# Matches on the executable name (`comm`), not the command text, so shell wrappers and scratchpad paths
# neither hide a real Godot nor count as one. Only the editor itself is excluded (a lone `--editor` flag,
# not `--editor-pid N`): games the user runs from the editor count as tests in progress.
# Usage: godot_busy.sh [project_dir]  — with a folder, only the Godots working on it count (its path in the command, or
# `--path .`/no --path with that folder as their working directory); other projects (worktrees) run freely.
proj="${1:-}"
busy=0
for i in 1 2 3; do
  l=""
  for pid in $(ps -axo pid=,comm= | awk '$2 ~ /(^|\/)Godot$|(^|\/)godot4?$/ {print $1}'); do
    cmd=$(ps -o pid=,etime=,rss=,command= -p "$pid" 2>/dev/null)
    [ -z "$cmd" ] && continue
    echo "$cmd" | grep -q -E -- "--editor( |$)" && continue
    if [ -n "$proj" ]; then
      cwd=$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -n1)
      case "$cmd" in
        *"--path $proj"*) ;;
        *"--path "*) [ "$cwd" = "$proj" ] && echo "$cmd" | grep -q -- "--path \." || continue ;;
        *) [ "$cwd" = "$proj" ] || continue ;;
      esac
    fi
    l="$l${cmd:0:220}"$'\n'
  done
  [ -n "$l" ] && { printf "%s" "$l"; busy=1; }
  [ $i -lt 3 ] && sleep 2
done
exit $busy
