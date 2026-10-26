@tool
extends EditorPlugin

## The terrain tools of the editor. Today: the importer that turns a map's heights.png and void.png into its
## TerrainHeights, and a reimport of heights.png when the void.png beside it is (re)imported, since an importer reads
## one source file only. Dev only: the export excludes `addons/terrain_tools/*` (the game loads the imported resource).
## Not: the importer itself (TerrainHeightsImporter), the pictures (MapImages).

const Importer := preload("res://addons/terrain_tools/terrain_heights_importer.gd")
const MapImages := preload("res://addons/terrain_tools/map_images.gd")

var _importer: EditorImportPlugin


func _enter_tree() -> void:
	_importer = Importer.new()
	add_import_plugin(_importer)
	EditorInterface.get_resource_filesystem().resources_reimported.connect(_on_resources_reimported)


func _exit_tree() -> void:
	EditorInterface.get_resource_filesystem().resources_reimported.disconnect(_on_resources_reimported)
	remove_import_plugin(_importer)
	_importer = null


## A void.png came in or changed: the heights.png beside it imports again, unless it already did in the same batch.
func _on_resources_reimported(resources: PackedStringArray) -> void:
	var stale := PackedStringArray()
	for path in resources:
		if path.get_file() != MapImages.VOID_FILE:
			continue
		var heights := path.get_base_dir().path_join(MapImages.HEIGHTS_FILE)
		if FileAccess.file_exists(heights) and not resources.has(heights) and not stale.has(heights):
			stale.append(heights)
	if not stale.is_empty():
		EditorInterface.get_resource_filesystem().reimport_files.call_deferred(stale)
