extends Node3D

## Every BuildingType the maps use, in a grid on the flat test map, each with a label: tag, proposed name and role.
## The list comes from tools/migrate/d1_building_names.csv (tag,proposed_name,role,god,maps,doubtful), one row per type.
## Look at it to check a model against its name and role. It does not simulate anything.
## Run: Godot --path game res://debug/map/building_gallery.tscn (F6); headless with `quit_when_done` it prints one line.

const NAMES_CSV := "res://tools/migrate/d1_building_names.csv"
const TYPE_DIR := "res://data/catalog/buildings/"

@export var building_scene: PackedScene
@export var camera: Camera3D
@export var columns := 10
@export var spacing_m := 70.0
@export var origin := Vector3(800.0, 10.0, 900.0)
@export var quit_when_done := false


func _ready() -> void:
	var rows := _read_rows()
	var shown := 0
	var missing := PackedStringArray()
	for i in rows.size():
		var row: PackedStringArray = rows[i]
		var type := load("%s%s.tres" % [TYPE_DIR, row[0]]) as BuildingType
		if type == null:
			missing.append(row[0])
			continue
		var spot := origin + Vector3(i % columns, 0.0, i / columns) * spacing_m
		_place(type, row, spot)
		shown += 1
	var center := origin + Vector3(columns - 1, 0.0, (rows.size() - 1) / columns) * spacing_m * 0.5
	camera.look_at_from_position(center + Vector3(0.0, 420.0, 360.0), center)
	print("BUILDING GALLERY shown=%d missing=%s" % [shown, ",".join(missing)])
	if quit_when_done:
		get_tree().quit(0 if missing.is_empty() else 1)


func _place(type: BuildingType, row: PackedStringArray, spot: Vector3) -> void:
	var building := building_scene.instantiate() as MapBuilding
	building.building = type
	building.name = row[1]
	building.position = spot
	add_child(building)
	var label := Label3D.new()
	label.text = "%s\n%s%s\n%s%s" % [row[0], row[1], "?" if not row[5].is_empty() else "", row[2], "\n«%s»" % type.display_name if not type.display_name.is_empty() else ""]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.12
	label.font_size = 48
	label.position = spot + Vector3(0.0, 4.0, 14.0)
	add_child(label)


func _read_rows() -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var file := FileAccess.open(NAMES_CSV, FileAccess.READ)
	if file == null:
		push_error("BuildingGallery: %s is missing." % NAMES_CSV)
		return rows
	file.get_csv_line()
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() >= 6:
			rows.append(line)
	return rows
