@tool
class_name PropNavStats
extends RefCounted

## What the last zone bake cost and made (PropNavZones3D / PropNavZones2D `stats`), for logs.

## Parsing the source geometry, on the main thread (0 when it was reused).
var parse_ms := 0.0
## Reading the props' shapes into obstructions, on the main thread.
var obstruct_ms := 0.0
## From the first zone started to the last one done (worker threads).
var bake_ms := 0.0
## Building the index of the whole navmesh (a worker thread).
var index_ms := 0.0
var zones_baked := 0
var zones_total := 0
## Obstructions added to the bake (after merging).
var obstructions := 0
## Polygons and connected components of the whole navmesh (with the index).
var polygons := 0
var components := 0


func _to_string() -> String:
	return (
		"zones %d/%d, parse %.1f ms, obstructions %d (%.1f ms), bake %.1f ms, index %.1f ms, "
		+ "%d polygons, %d components"
	) % [
		zones_baked,
		zones_total,
		parse_ms,
		obstructions,
		obstruct_ms,
		bake_ms,
		index_ms,
		polygons,
		components
	]
