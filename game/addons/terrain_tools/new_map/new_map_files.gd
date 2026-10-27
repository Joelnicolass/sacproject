@tool
extends RefCounted

## The files of a new map, made from the template folder scenes/map/maps/_template/: its three pictures (flat ground, all
## grass, an even grey baked light) with their .import (the template's uid taken out, so Godot gives the copy its own), an empty navmesh, the map scene
## (the template's tree with its Terrain and NavRegion pointed at the new folder) and the MapDefinition the catalog finds.
## Each step returns "" or what failed. Not: importing, baking, opening or checking the map (NewMapAction), the dialog.

const MAPS_DIR := "res://scenes/map/maps"
const TEMPLATE_DIR := "res://scenes/map/maps/_template"
const SCENE_FILE := "map.tscn"
const NAV_FILE := "nav.res"
const PICTURES: PackedStringArray = ["heights.png", "ground_roles.png", "light.png"]
const STARTS := 2
const TAG_PATTERN := "^[a-z][a-z0-9_]*$"


## The folder a map with that tag lives in.
static func folder_of(tag: String) -> String:
	return MAPS_DIR.path_join(tag)


## Why a map cannot be made with that tag and name ("" = it can): the tag is the folder, the file name and `--map=<tag>`.
static func refusal(tag: String, display_name: String) -> String:
	if tag.is_empty():
		return "Escribí un tag (por ejemplo mi_mapa)."
	if tag.begins_with("_"):
		return "El tag no puede empezar con «_»: esas carpetas son plantillas."
	var pattern := RegEx.create_from_string(TAG_PATTERN)
	if pattern.search(tag) == null:
		return "El tag va en minúsculas, números y «_», y empieza con una letra (no «%s»)." % tag
	if DirAccess.dir_exists_absolute(folder_of(tag)):
		return "Ya hay un mapa «%s» (%s)." % [tag, folder_of(tag)]
	if display_name.strip_edges().is_empty():
		return "Escribí un nombre (lo ven las salas)."
	return ""


## Copies the template's pictures and their .import into `folder` (made if missing). Returns the files written; empty when
## a copy failed (the Output says which).
static func write_pictures(folder: String) -> PackedStringArray:
	var written := PackedStringArray()
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		push_error("Mapa nuevo: no se pudo crear %s." % folder)
		return PackedStringArray()
	for file in PICTURES:
		var source := TEMPLATE_DIR.path_join(file)
		var target := folder.path_join(file)
		if DirAccess.copy_absolute(source, target) != OK:
			push_error("Mapa nuevo: no se pudo copiar %s a %s." % [source, target])
			return PackedStringArray()
		var import_text := FileAccess.get_file_as_string(source + ".import")
		var import_file := FileAccess.open(target + ".import", FileAccess.WRITE)
		if import_text.is_empty() or import_file == null:
			push_error("Mapa nuevo: no se pudo escribir %s.import." % target)
			return PackedStringArray()
		import_file.store_string(import_for(import_text, source, target))
		import_file.close()
		written.append_array([target, target + ".import"])
	return written


## The template's .import text for the copy at `target`: without its uid line, and naming the copy (its source path and
## the imported file, whose name carries the md5 of the source path, as Godot writes it).
static func import_for(text: String, source: String, target: String) -> String:
	var lines := PackedStringArray()
	for line in text.split("\n"):
		if not line.begins_with("uid="):
			lines.append(line)
	return "\n".join(lines).replace(source.md5_text(), target.md5_text()).replace(source, target)


## An empty navmesh, so the scene loads before the first bake.
static func write_nav(folder: String) -> String:
	var path := folder.path_join(NAV_FILE)
	return "" if ResourceSaver.save(NavigationMesh.new(), path) == OK else "no se pudo escribir %s." % path


## The map scene of `folder`: the template's tree reading the folder's pictures (imported already) and navmesh.
static func write_scene(folder: String) -> String:
	var heights := load(folder.path_join(PICTURES[0])) as TerrainHeights
	var roles := load(folder.path_join(PICTURES[1])) as Texture2D
	var light := load(folder.path_join(PICTURES[2])) as Texture2D
	var nav := load(folder.path_join(NAV_FILE)) as NavigationMesh
	if heights == null or roles == null or light == null or nav == null:
		return "%s: las imágenes o el navmesh no cargan (¿se importaron?)." % folder
	var packed := scene_for(heights, roles, nav, light)
	if packed == null:
		return "no se pudo armar la escena desde %s." % TEMPLATE_DIR.path_join(SCENE_FILE)
	var path := folder.path_join(SCENE_FILE)
	return "" if ResourceSaver.save(packed, path) == OK else "no se pudo escribir %s." % path


## The template's tree, packed again with its Terrain and NavRegion holding these resources (nothing is written). A null
## `light` keeps the template's own grey light.
static func scene_for(heights: TerrainHeights, roles: Texture2D, nav: NavigationMesh, light: Texture2D = null) -> PackedScene:
	var template := load(TEMPLATE_DIR.path_join(SCENE_FILE)) as PackedScene
	if template == null:
		return null
	var root := template.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as MapRoot
	if root == null or root.terrain == null or root.nav_region == null:
		if root != null:
			root.free()
		return null
	root.scene_file_path = ""  # the new scene is its own, not an instance of the template
	root.terrain.heights = heights
	root.terrain.ground_roles = roles
	if light != null:
		root.terrain.light_map = light
	root.nav_region.navigation_mesh = nav
	var packed := PackedScene.new()
	var error := packed.pack(root)
	root.free()
	return packed if error == OK else null


## The MapDefinition `<tag>.tres` of the folder: its scene, navmesh and seats; no tiles or light (a new map reads nothing
## of the original). Written last: once it exists, the catalog lists the map.
static func write_definition(folder: String, tag: StringName, display_name: String) -> String:
	var definition := MapDefinition.new()
	definition.tag = tag
	definition.display_name = display_name.strip_edges()
	definition.map_scene = load(folder.path_join(SCENE_FILE)) as PackedScene
	definition.nav = load(folder.path_join(NAV_FILE)) as NavigationMesh
	definition.player_starts = STARTS
	if definition.map_scene == null or definition.nav == null:
		return "%s: la escena o el navmesh no cargan." % folder
	var path := folder.path_join("%s.tres" % tag)
	return "" if ResourceSaver.save(definition, path) == OK else "no se pudo escribir %s." % path
