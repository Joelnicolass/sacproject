@tool
class_name MapNav
extends PropNavZones3D

## The map's walkable surface (the Nav node of a map scene, an instance of map_nav.tscn): PropKit's
## navmesh baked in square zones, saved next to the map in maps/<tag>/nav.res (`saved`). Every bake
## number is in map_nav.tscn: the template (agent, cells, the `nav_source` colliders of layer 1),
## the zone size, the border and the fixed height of every zone. The forest trees are props (group
## `prop_obstruction`, layer 8): they cut it as projected obstructions, never parsed as colliders.
## The saved bake goes stale when the props, the bake numbers (PropKit's own fingerprint) or the map
## (`extra_fingerprint` = NavFingerprint.source_hash: the terrain's heights and the nav_source
## nodes) differ from what it was baked from; a match whose forest is off bakes every zone again on
## start. NavService drives it in a match (apply MANUAL: a change in play is swapped in at a tick).
## Bake with «Bake» in the inspector, or `godot --headless --path .
## res://addons/prop_kit/tools/bake_scene.tscn -- --scene=<map.tscn>` (`--check` twice must give the
## same hash).

const BAKE_TOOL := "res://addons/prop_kit/tools/bake_scene.tscn"


func _ready() -> void:
	extra_fingerprint = func() -> int: return hash(NavFingerprint.source_hash(owner_root()))
	super._ready()


## Bakes this map's navmesh in a headless Godot (the map must be saved first) and loads the new
## bake. «New map» calls it; OK, or the error (the Output says why).
func bake_now() -> Error:
	var root := owner_root()
	var scene := root.scene_file_path if root != null else ""
	if scene.is_empty():
		push_warning("Bake: save the map scene first.")
		return ERR_UNCONFIGURED
	var args := [
		"--headless",
		"--path",
		ProjectSettings.globalize_path("res://"),
		BAKE_TOOL,
		"--",
		"--scene=" + scene
	]
	var output := []
	if OS.execute(OS.get_executable_path(), args, output, true) != OK:
		push_error("Bake: bake_scene failed.\n%s" % "\n".join(output))
		return FAILED
	var path := scene.get_base_dir().path_join("nav.res")
	saved = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as PropNavBake
	return OK if saved != null else ERR_FILE_CANT_READ


## The map root the navmesh belongs to (the scene's owner, or the parent of a node made in code).
func owner_root() -> Node:
	return owner if owner != null else get_parent()
