@tool
extends EditorImportPlugin

## Imports a map's `heights.png`, with the `void.png` beside it when there is one, as the map's TerrainHeights, by
## itself like any texture: `load("res://scenes/map/maps/<tag>/heights.png")` gives the TerrainHeights, in the editor,
## in `--headless --import` and in an export. The height scale is the «metres_per_unit» option of the Import dock.
## Only files whose name ends in `heights.png` come here: Godot picks the importer by the end of the file name
## (ResourceFormatImporter::get_importer_by_file in 4.7.2), and this one outranks the texture importer (priority 2 > 1).
## void.png stays a small texture, unused by the game. A bad file or a size other than 256 x 256 fails the import with
## a message. Not: the PNG bytes (Png16), what a pixel means (MapImages), reimporting when void.png changes (plugin.gd).

const MapImages := preload("res://addons/terrain_tools/map_images.gd")
const OPTION_SCALE := "metres_per_unit"


func _get_importer_name() -> String:
	return "sacrifice.terrain_heights"


func _get_visible_name() -> String:
	return "Terrain heights (TerrainHeights)"


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray([MapImages.HEIGHTS_FILE])


func _get_save_extension() -> String:
	return "res"


func _get_resource_type() -> String:
	return "Resource"


func _get_priority() -> float:
	return 2.0


func _get_import_order() -> int:
	return 0


func _get_format_version() -> int:
	return 1


func _get_preset_count() -> int:
	return 1


func _get_preset_name(_preset_index: int) -> String:
	return "Default"


func _get_import_options(_path: String, _preset_index: int) -> Array[Dictionary]:
	return [{
		"name": OPTION_SCALE,
		"default_value": MapImages.DEFAULT_METRES_PER_UNIT,
		"property_hint": PROPERTY_HINT_RANGE,
		"hint_string": "0.001,100,0.001,or_greater",
	}]


func _get_option_visibility(_path: String, _option_name: StringName, _options: Dictionary) -> bool:
	return true


func _can_import_threaded() -> bool:
	return false


func _import(source_file: String, save_path: String, options: Dictionary, _platform_variants: Array[String], _gen_files: Array[String]) -> Error:
	var scale := float(options.get(OPTION_SCALE, MapImages.DEFAULT_METRES_PER_UNIT))
	var result := MapImages.read(source_file, scale)
	if not result.error.is_empty():
		push_error("Terrain heights: could not import. " + result.error)
		return ERR_INVALID_DATA
	return ResourceSaver.save(result.heights, "%s.%s" % [save_path, _get_save_extension()], ResourceSaver.FLAG_COMPRESS)
