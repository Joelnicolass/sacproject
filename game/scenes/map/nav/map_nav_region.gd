@tool
class_name MapNavRegion
extends NavigationRegion3D

## The map's walkable surface: the NavRegion of a map scene, holding the versioned navmesh next to it (maps/<tag>/nav.res).
## The «Bake navmesh» button bakes it from the `nav_source` nodes of the map (tools/bake/bake_nav.gd runs as a headless
## subprocess) and reloads it. NavService answers from the same resource: it queries this region's navigation map, and swaps
## the region's navigation_mesh after a re-bake (NavRebake). The inspector warns when the navmesh no longer matches the map.

## The numbers the navmesh was baked with; also part of the source hash.
@export var bake_settings: NavBakeSettings
@export_tool_button("Bake navmesh", "NavigationRegion3D") var bake := _bake_map


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if bake_settings == null:
		warnings.append("Assign bake_settings (data/nav/nav_bake.tres).")
	if navigation_mesh == null or navigation_mesh.get_polygon_count() == 0:
		warnings.append("The navmesh is empty: press «Bake navmesh».")
	if bake_settings != null:
		for number in [bake_settings.zone_m, bake_settings.zone_border_m]:
			if not is_zero_approx(fmod(number, bake_settings.cell_size)):
				warnings.append(
					"zone_m and zone_border_m of nav_bake.tres have to be multiples of cell_size."
				)
				break
	if use_edge_connections:
		(
			warnings
			. append(
				"Turn use_edge_connections off: the zones fit exactly, and with it on every change costs ~850 ms on the main thread."
			)
		)
	if (
		navigation_mesh != null
		and navigation_mesh.get_polygon_count() > 0
		and bake_settings != null
		and get_parent() != null
	):
		var stored := str(navigation_mesh.get_meta(NavFingerprint.META_SOURCE, ""))
		if stored != NavFingerprint.source_hash(get_parent(), bake_settings):
			warnings.append(
				"The navmesh is stale (the map or nav_bake.tres changed): press «Bake navmesh»."
			)
	return warnings


## Editor: bakes this map's navmesh in a headless Godot (the map must be saved first) and loads the new data. The
## «Bake navmesh» button and «New map» call it; OK, or the error (the Output says why).
func bake_now() -> Error:
	var scene := owner.scene_file_path if owner != null else ""
	if scene.is_empty():
		push_warning("Bake navmesh: save the map scene first.")
		return ERR_UNCONFIGURED
	var tag := scene.get_base_dir().get_file()
	var output := []
	if bake_settings == null or bake_settings.bake_tool.is_empty():
		push_warning(
			"Bake navmesh: `bake_settings` (data/nav/nav_bake.tres) with `bake_tool` is missing."
		)
		return ERR_UNCONFIGURED
	var args := [
		"--headless",
		"--path",
		ProjectSettings.globalize_path("res://"),
		bake_settings.bake_tool,
		"--",
		"--map=" + tag
	]
	var code := OS.execute(OS.get_executable_path(), args, output, true)
	var path := scene.get_base_dir().path_join("nav.res")
	if code != OK:
		push_error("Bake navmesh: bake_nav finished with code %d.\n%s" % [code, "\n".join(output)])
		return FAILED
	navigation_mesh = (
		ResourceLoader.load(path, "NavigationMesh", ResourceLoader.CACHE_MODE_REPLACE)
		as NavigationMesh
	)
	update_configuration_warnings()
	return OK if navigation_mesh != null else ERR_FILE_CANT_READ


func _bake_map() -> void:
	bake_now()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# A client loads the region but does not log it (it never asks for a path).
	if not is_multiplayer_authority():
		return
	var polygons := navigation_mesh.get_polygon_count() if navigation_mesh != null else 0
	if DebugLog.on(&"nav"):
		print("nav: navmesh %d polygons" % polygons)
