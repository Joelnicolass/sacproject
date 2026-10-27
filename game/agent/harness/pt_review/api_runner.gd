extends Node

## Playtest review (RFC-066) without the editor, for when the editor probe cannot run: drives «Mapa nuevo»'s files
## (NewMapFiles) and the brushes' canvases (RolesCanvas, DensityCanvas through BrushStroke, the same objects BrushPainter
## uses) headless, in phases separated by a `--headless --import` (only the editor imports pictures):
##   --phase=1  copy the template's pictures and an empty navmesh into scenes/map/maps/TAG
##   --phase=2  write map.tscn and TAG.tres; paint roles (rock, path, earth) and save ground_roles.png; add a FloraLayer
##              «Ferns» under Vegetation, make its blank density picture, save the scene
##   --phase=3  give Ferns its imported picture, paint flora and erase a band (Shift), save the picture and the scene
## Prints PT_API lines. The map is a test map: the caller deletes the folder after the game run.

const NewMapFiles := preload("res://addons/terrain_tools/new_map/new_map_files.gd")
const TAG := "pt_review_map"
const FERN := "res://data/vegetation/species/persephone_fern_1.tres"
const BRUSH := "res://addons/terrain_tools/brush/default_brush.tres"


func _ready() -> void:
	var phase := "0"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--phase="):
			phase = argument.get_slice("=", 1)
	var folder := NewMapFiles.folder_of(TAG)
	match phase:
		"1":
			_say("refusal of «test_flat» «%s», of «Mi-Mapa» «%s», of «%s» «%s»" % [NewMapFiles.refusal("test_flat", "x"),
					NewMapFiles.refusal("Mi-Mapa", "x"), TAG, NewMapFiles.refusal(TAG, "Mapa de prueba")])
			_say("pictures %s" % ", ".join(NewMapFiles.write_pictures(folder)))
			_say("nav '%s'" % NewMapFiles.write_nav(folder))
		"2":
			await _phase_2(folder)
		"3":
			await _phase_3(folder)
	_say("DONE phase %s" % phase)
	get_tree().quit()


func _phase_2(folder: String) -> void:
	_say("scene '%s'" % NewMapFiles.write_scene(folder))
	_say("definition '%s'" % NewMapFiles.write_definition(folder, StringName(TAG), "Mapa de prueba"))
	_say("catalog has %s" % MapCatalog.shared().has(StringName(TAG)))
	var map := await _open(folder)
	var roles := RolesCanvas.of(map.terrain)
	var brush := (load(BRUSH) as TerrainBrush).duplicate() as TerrainBrush
	brush.size_m = 20.0
	_stroke(roles, 2, brush, [Vector2(1240, 1255), Vector2(1260, 1255)])  # rock
	_stroke(roles, 3, brush, [Vector2(1195, 1300), Vector2(1220, 1300), Vector2(1245, 1300), Vector2(1270, 1300), Vector2(1295, 1300)])  # path
	_stroke(roles, 1, brush, [Vector2(1240, 1345), Vector2(1265, 1350)])  # earth
	_say("roles save '%s' dirty-before %s" % [roles.save(), true])
	var layer := FloraLayer.new()
	layer.name = "Ferns"
	layer.species = load(FERN) as VegetationSpecies
	map.get_node("Vegetation").add_child(layer)
	layer.owner = map
	var path := DensityCanvas.new_picture_path(layer)
	_say("density picture %s '%s'" % [path, DensityCanvas.create_picture(layer, path)])
	_save(map, folder)


func _phase_3(folder: String) -> void:
	var map := await _open(folder)
	var layer := map.get_node("Vegetation/Ferns") as FloraLayer
	layer.density = load(folder.path_join("flora/ferns.png")) as Texture2D
	var canvas := DensityCanvas.of(layer)
	_say("density canvas %s" % (canvas != null))
	if canvas == null:
		return
	var brush := (load(BRUSH) as TerrainBrush).duplicate() as TerrainBrush
	brush.size_m = 30.0
	for k in 3:
		_stroke(canvas, DensityCanvas.Mode.PAINT, brush, [Vector2(1200, 1225 + k * 8), Vector2(1240, 1225 + k * 8), Vector2(1280, 1225 + k * 8)])
	var painted := _count(canvas.work())
	_stroke(canvas, DensityCanvas.Mode.ERASE, brush, [Vector2(1240, 1215), Vector2(1240, 1245)])
	_say("density cells painted %d, after the Shift band %d" % [painted, _count(canvas.work())])
	_say("density save '%s'" % canvas.save())
	_save(map, folder)


func _open(folder: String) -> MapRoot:
	var map := (load(folder.path_join(NewMapFiles.SCENE_FILE)) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as MapRoot
	await get_tree().process_frame  # kept out of the tree: a running map may reshape itself (its Look) and the repack must not
	return map


func _stroke(canvas: BrushCanvas, mode: int, brush: TerrainBrush, points: Array) -> void:
	var stroke := BrushStroke.new()
	stroke.begin(canvas, mode, brush, points[0])
	for at: Vector2 in points:
		stroke.drag(at, 0.0)
	var done := stroke.finish()
	canvas.write(done["after"])
	_say("%s: rect %s" % [canvas.label(mode), done["rect"]])


func _save(map: MapRoot, folder: String) -> void:
	map.scene_file_path = ""
	var packed := PackedScene.new()
	var error := packed.pack(map)
	var saved := ResourceSaver.save(packed, folder.path_join(NewMapFiles.SCENE_FILE)) if error == OK else error
	_say("scene saved %s" % (saved == OK))
	map.free()


func _count(bytes: PackedByteArray) -> int:
	var n := 0
	for byte in bytes:
		n += int(byte > 0)
	return n


func _say(line: String) -> void:
	print("PT_API " + line)
