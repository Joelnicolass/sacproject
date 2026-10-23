#!/usr/bin/env bash
# Conventions lint (see game/CONVENTIONS.md). Plain bash + grep/awk/wc/find: no Godot, ~1 s.
# Ratchet: every rule has a count in baseline.txt; the lint fails when a count goes UP.
# Usage: tools/lint/conventions.sh [--verbose] [--update-baseline]
set -u
LC_ALL=C
export LC_ALL

HERE="$(cd "$(dirname "$0")" && pwd)"
GAME="$(cd "$HERE/../.." && pwd)"
BASELINE="$HERE/baseline.txt"
VERBOSE=0
UPDATE=0
for arg in "$@"; do
	case "$arg" in
		--verbose) VERBOSE=1 ;;
		--update-baseline) UPDATE=1 ;;
		-h|--help) sed -n 2,5p "$0"; exit 0 ;;
		*) echo "unknown option: $arg" >&2; exit 2 ;;
	esac
done

cd "$GAME" || exit 2
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

# Every product script (addons are not under scenes/, so they are out).
find scenes -name '*.gd' | sort > "$OUT/all.txt"
grep -v '^scenes/net/' "$OUT/all.txt" > "$OUT/not_net.txt"

# Lists are "path" or "path:line:text" lines, one offender each.
scan() { # $1 = key, then grep args; reads the file list from $OUT/all.txt
	local key="$1"; shift
	xargs grep -nE "$@" < "$OUT/all.txt" > "$OUT/$key.txt" 2>/dev/null || true
}

# C1: long scripts.
: > "$OUT/C1a.txt"; : > "$OUT/C1b.txt"
while IFS= read -r f; do
	n=$(wc -l < "$f" | tr -d ' ')
	[ "$n" -gt 150 ] && echo "$f ($n lines)" >> "$OUT/C1a.txt"
	[ "$n" -gt 300 ] && echo "$f ($n lines)" >> "$OUT/C1b.txt"
done < "$OUT/all.txt"

# C5: cross-node lookup by capitalized name.
scan C5 'get_node(_or_null)?\("[A-Z]'
# C6: group lookup with a literal string.
scan C6 'get_(first_node_in_group|nodes_in_group)\(&?"'
# C7: stringly-typed calls.
scan C7 '\.call\("|has_method\('

# C8: raw fields in *_type.gd Resources.
grep '_type\.gd$' "$OUT/all.txt" > "$OUT/types.txt"
xargs grep -nE '^@export.*(var (flags[a-z0-9_]*|folder|components)\b|Dictionary)' < "$OUT/types.txt" > "$OUT/C8.txt" 2>/dev/null || true

# C9: the first "##" line opens with a reference to the original instead of plain words.
xargs awk '
	FNR == 1 { seen = 0 }
	!seen && /^##/ {
		seen = 1
		if ($0 ~ /RFC-|sacengine|\.d:|WAD|(^|[^A-Za-z0-9_])F[0-9]/) print FILENAME ":" FNR ":" $0
	}' < "$OUT/all.txt" > "$OUT/C9.txt"

# C11: own inheritance depth >= 2 (extends an own class_name that itself extends an own class_name).
xargs awk '
	FNR == 1 { cur = FILENAME }
	/^class_name[ \t]+[A-Za-z0-9_]+/ { name[cur] = $2 }
	/^extends[ \t]+[A-Za-z0-9_]+[ \t]*$/ { ext[cur] = $2 }
	{ }
	END {
		for (f in name) own[name[f]] = f
		for (f in ext) {
			p = ext[f]
			if (!(p in own)) continue
			pf = own[p]
			if ((pf in ext) && (ext[pf] in own)) print f ":1:extends " p " -> " ext[pf]
		}
	}' < "$OUT/all.txt" | sort > "$OUT/C11.txt"

# C12: MpKit. outside the allowlist (scenes/net/, owners of submit_*/@rpc, MultiplayerSpawner users).
: > "$OUT/C12.txt"
xargs grep -lE 'MpKit\.' < "$OUT/not_net.txt" 2>/dev/null | while IFS= read -r f; do
	grep -qE 'func submit_|@rpc|MultiplayerSpawner' "$f" || echo "$f" >> "$OUT/C12.txt"
done

# C13: the product reading the original's formats.
scan C13 'assets/original|OriginalAssets\.|res://tools'

# C14: print( in scenes/ (DebugLog is the logger; comments do not count).
xargs grep -nE '(^|[^A-Za-z0-9_.])print\(' < "$OUT/all.txt" 2>/dev/null \
	| grep -v 'DebugLog' | grep -vE ':[0-9]+:[ 	]*#' > "$OUT/C14.txt" || true
grep -v '/debug_log\.gd' "$OUT/C14.txt" > "$OUT/C14b.txt"; mv "$OUT/C14b.txt" "$OUT/C14.txt"

RULES="C1a:scripts>150_lines C1b:scripts>300_lines C5:get_node(\"Cap\") C6:group_lookup_literal C7:.call/has_method C8:raw_fields_in_*_type.gd C9:doc_opens_with_original C11:inheritance_depth>=2 C12:MpKit_outside_allowlist C13:reads_original_assets C14:print()"

baseline_of() { grep -E "^$1=" "$BASELINE" 2>/dev/null | head -1 | cut -d= -f2; }

if [ "$UPDATE" -eq 1 ]; then
	: > "$BASELINE"
	for r in $RULES; do
		key="${r%%:*}"
		echo "$key=$(wc -l < "$OUT/$key.txt" | tr -d ' ')" >> "$BASELINE"
	done
	echo "baseline rewritten: $BASELINE"
fi

FAILED=0
for r in $RULES; do
	key="${r%%:*}"; label="${r#*:}"
	count=$(wc -l < "$OUT/$key.txt" | tr -d ' ')
	base="$(baseline_of "$key")"
	if [ -z "$base" ]; then base=0; fi
	if [ "$count" -gt "$base" ]; then
		echo "$key $label: $count (baseline $base) FAIL (+$((count - base)))"
		FAILED=1
		echo "  offenders:"
		if [ "$VERBOSE" -eq 1 ]; then sed 's/^/    /' "$OUT/$key.txt"; else cut -d: -f1 "$OUT/$key.txt" | sort | uniq -c | sort -rn | head -15 | sed 's/^ *\([0-9]*\) /    \1x /'; fi
	else
		echo "$key $label: $count (baseline $base) OK$([ "$count" -lt "$base" ] && echo " (below baseline: run --update-baseline to lock it in)")"
		if [ "$VERBOSE" -eq 1 ] && [ "$count" -gt 0 ]; then sed 's/^/    /' "$OUT/$key.txt"; fi
	fi
done
exit "$FAILED"
