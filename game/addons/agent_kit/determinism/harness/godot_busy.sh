#!/usr/bin/env bash
# Lists running Godot binaries except the user's main editor (3 checks, 2 s apart). Exit 1 if any.
# Matches on the executable name (`comm`), not the command text, so shell wrappers and scratchpad paths
# neither hide a real Godot nor count as one. Only the editor itself is excluded (a lone `--editor` flag,
# not `--editor-pid N`): games the user runs from the editor count as tests in progress.
busy=0
for i in 1 2 3; do
  l=""
  for pid in $(ps -axo pid=,comm= | awk '$2 ~ /(^|\/)Godot$|(^|\/)godot4?$/ {print $1}'); do
    cmd=$(ps -o pid=,etime=,rss=,command= -p "$pid" 2>/dev/null)
    [ -z "$cmd" ] && continue
    echo "$cmd" | grep -q -E -- "--editor( |$)" && continue
    l="$l${cmd:0:220}"$'\n'
  done
  [ -n "$l" ] && { printf "%s" "$l"; busy=1; }
  [ $i -lt 3 ] && sleep 2
done
exit $busy
