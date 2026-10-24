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
# Comments and doc lines that only mention a path are not reads (audit 055R, user decision 2026-10-24).
grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' "$OUT/C13.txt" > "$OUT/C13.tmp" || true; mv "$OUT/C13.tmp" "$OUT/C13.txt"

# C14: print( in scenes/ (DebugLog is the logger; comments do not count).
xargs grep -nE '(^|[^A-Za-z0-9_.])print\(' < "$OUT/all.txt" 2>/dev/null \
	| grep -v 'DebugLog' | grep -vE ':[0-9]+:[ 	]*#' > "$OUT/C14.txt" || true
grep -v '/debug_log\.gd' "$OUT/C14.txt" > "$OUT/C14b.txt"; mv "$OUT/C14b.txt" "$OUT/C14.txt"

# ---- Editor-first rules (RFC-055 §15): "todo en el editor, movible con gizmo, sin capas de abstraccion". ----

# C15: content nodes built with .new() in code (allowlist: pools, buses, planters, previews).
xargs grep -nE '[A-Z][A-Za-z0-9]*(3D|2D|Player|Timer|Light|Camera)[A-Za-z0-9]*\.new\(' < "$OUT/all.txt" 2>/dev/null \
	| grep -vE '(Transform|Basis|Vector|Plane|Color|Texture)[A-Za-z0-9]*\.new\(' \
	| grep -vE '^scenes/[a-z_/]*/(fx_bus|sound_bus|fx_light_layer|mesh_planter|patch_planner|grass_field|npc_spawn)\.gd:' \
	| grep -vE ':[0-9]+:[ 	]*#' > "$OUT/C15.txt" || true

# C16: heights/offsets typed in code instead of a Marker3D socket.
xargs grep -nE 'Vector3\.UP[ ]*\*[ ]*([-0-9.(]|[a-z_]*(height|offset|lift|reach|spread|_h)\b)|^[ 	]*const [A-Z_]*(HEIGHT|OFFSET|LIFT|REACH|SPREAD)' < "$OUT/all.txt" 2>/dev/null \
	| grep -vE ':[0-9]+:[ 	]*#' > "$OUT/C16.txt" || true

# C17: FX/sound named by text literal or by an exported String instead of a typed Resource.
xargs grep -nE 'FxBus\.[a-z_]+\([ ]*&?"|@export[a-z_]* var [a-z_]*(fx|sfx|sound|effect)[a-z_]*[ ]*:[ ]*(String|StringName)\b' < "$OUT/all.txt" 2>/dev/null \
	| grep -vE ':[0-9]+:[ 	]*#' > "$OUT/C17.txt" || true

# C18: text-tag lookups of content in gameplay (allowed in spawners, scenes/net/, scenes/core/catalog/).
xargs grep -nE 'GameData\.(creature|spell|ability|wizard|god|book)[a-z_]*\(|BodyCatalog\.(info|pose|has_model)\(|MapCatalog\.|GameModeCatalog\.' < "$OUT/all.txt" 2>/dev/null \
	| grep -vE '^scenes/(net|core/catalog)/|^scenes/[a-z_/]*[a-z_]*spawn[a-z_]*\.gd:' \
	| grep -vE ':[0-9]+:[ 	]*#' > "$OUT/C18.txt" || true

# C19: data/*.tres that store positions/offsets/transforms (counted by FILE). debug/ is reported, not ratcheted.
TRES_POS='^([a-z_0-9]*_(offset|position|origin|transform|pos)|position[a-z_0-9]*|offsets|origin|transform) = |Transform3D\('
find data -name '*.tres' 2>/dev/null | sort | xargs grep -lE "$TRES_POS" 2>/dev/null | grep -v 'roughness_offset' > "$OUT/C19.txt" || true
find debug -name '*.tres' 2>/dev/null | sort | xargs grep -lE "$TRES_POS" 2>/dev/null > "$OUT/C19debug.txt" || true

# C20: place/effect radii exported from MatchRules (they belong in a CollisionShape3D).
grep -nE '^@export.*(_radius|_height|_distance)' scenes/match/match_rules.gd > "$OUT/C20.txt" 2>/dev/null || true

# C21: file paths as text instead of typed references.
xargs grep -nE '@export_file' < "$OUT/all.txt" 2>/dev/null > "$OUT/C21.txt" || true

RULES="C1a:scripts>150_lines C1b:scripts>300_lines C5:get_node(\"Cap\") C6:group_lookup_literal C7:.call/has_method C8:raw_fields_in_*_type.gd C9:doc_opens_with_original C11:inheritance_depth>=2 C12:MpKit_outside_allowlist C13:reads_original_assets C14:print() C15:content_nodes_with_new C16:height_offset_in_code C17:fx_by_text C18:content_lookup_by_text C19:data_tres_with_positions C20:matchrules_place_radii C21:export_file"

baseline_of() { grep -E "^$1=" "$BASELINE" 2>/dev/null | head -1 | cut -d= -f2; }

if [ "$UPDATE" -eq 1 ]; then
	: > "$BASELINE"
	for r in $RULES; do
		key="${r%%:*}"
		echo "$key=$(wc -l < "$OUT/$key.txt" | tr -d ' ')" >> "$BASELINE"
	done
	echo "baseline rewritten: $BASELINE"
fi

echo "info: debug/*.tres with positions/offsets (not ratcheted): $(wc -l < "$OUT/C19debug.txt" | tr -d ' ')"
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
