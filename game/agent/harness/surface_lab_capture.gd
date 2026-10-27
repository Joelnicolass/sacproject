extends SceneTree

## RFC-067 P4: two captures of debug/look/surface_lab.tscn from its fixed camera, with the pilot maps off (`before`: what the
## materials drew before they had maps) and on (`after`), plus the screen box of every model (`rects.json`), for
## tools/look/measure_relief.py, with the lab's orbiting light paused at its start. Then, maps on, `orbit_0..N-1.png`: the light
## turned ORBIT_STEP_DEG further for each one, to see the relief follow it. The maps are turned off in memory only (normal_enabled of the loaded materials): nothing is saved.
## Run with a fixed frame rate so both captures show the same frame of the animated bodies:
##   Godot --path . --fixed-fps 30 --resolution 1600x900 --script res://agent/harness/surface_lab_capture.gd -- [--out=res://agent/out/surface_lab] [--frames=40]
##   python3 -I tools/look/measure_relief.py --before=agent/out/surface_lab/before.png --after=agent/out/surface_lab/after.png --rects=agent/out/surface_lab/rects.json

const LAB := "res://debug/look/surface_lab.tscn"
const STONE_LOOK := "res://scenes/look/stone_look.gd"
## The pilots are the materials that have a flat copy in the lab.
const FLAT_DIR := "res://debug/look/surface_lab/flat/"
const PRODUCT_DIR := "res://scenes/bodies/materials/"
const ROWS: Array[String] = ["Flat", "Product", "Effects"]
## The cell of one model in the lab's grid (columns 3.8 m apart, rows 4.5 m apart), from the model's origin.
const CELL_HALF_WIDTH_M := 1.9
const CELL_BELOW_M := 0.75
const CELL_ABOVE_M := 3.75

## The orbit sequence: this many shots, this far apart (yaw).
const ORBIT_SHOTS := 8
const ORBIT_STEP_DEG := 45.0
const ORBIT_SETTLE_FRAMES := 2

var _out := "res://agent/out/surface_lab"
var _frames := 40
var _pilots: Array[BaseMaterial3D] = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--frames="):
			_frames = int(arg.trim_prefix("--frames="))
	for file in DirAccess.get_files_at(FLAT_DIR):
		var material := load(PRODUCT_DIR + file) as BaseMaterial3D if file.get_extension() == "tres" else null
		if material != null and material.normal_enabled:
			_pilots.append(material)
	print("SURFACE_LAB pilots with a normal map: %d" % _pilots.size())
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_set_maps(false)
	await _shoot("before")
	_set_maps(true)
	await _shoot("after")
	quit()


func _set_maps(on: bool) -> void:
	for material in _pilots:
		material.normal_enabled = on


func _shoot(label: String) -> void:
	# StoneLook keeps one stone material per source: the ones built with the maps off must not be reused with them on.
	# Loaded here, not named: a --script main loop compiles before the autoloads exist (StoneLook's deps name them).
	var stone_look: Variant = load(STONE_LOOK)
	(stone_look._materials as Dictionary).clear()
	var lab := (load(LAB) as PackedScene).instantiate() as Node3D
	var lab_script: Variant = lab  # debug/look/surface_lab.gd has no class_name
	lab_script.orbiting = false  # the measured shots keep the light where the scene starts it
	root.add_child(lab)
	for i in _frames:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [_out, label]
	image.save_png(path)
	print("SURFACE_LAB %s %s" % [label, ProjectSettings.globalize_path(path)])
	if label == "after":
		_save_rects(lab, image)
		await _orbit(lab)
	lab.queue_free()
	await process_frame


func _orbit(lab: Variant) -> void:
	for i in ORBIT_SHOTS:
		if i > 0:
			lab.turn_light(ORBIT_STEP_DEG)
		for _frame in ORBIT_SETTLE_FRAMES:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/orbit_%d.png" % [_out, i])
	print("SURFACE_LAB orbit %d shots, %d degrees apart" % [ORBIT_SHOTS, roundi(ORBIT_STEP_DEG)])


## The screen box of every model of the three rows: the cell of the lab's grid around it (CELL_* metres from its origin, projected
## by the lab's camera; a skinned mesh's own box does not follow its skeleton) and the background colour.
func _save_rects(lab: Node3D, image: Image) -> void:
	var camera := root.get_camera_3d()
	# unproject_position works in the viewport's own size (project 1280x720 under canvas_items stretch), the capture is the window's.
	var to_image := Vector2(image.get_size()) / root.get_visible_rect().size
	var items: Array = []
	for row in ROWS:
		for item in lab.get_node(row).get_children():
			var origin := (item as Node3D).global_transform.origin
			var low := camera.unproject_position(origin + Vector3(-CELL_HALF_WIDTH_M, -CELL_BELOW_M, 0.0))
			var high := camera.unproject_position(origin + Vector3(CELL_HALF_WIDTH_M, CELL_ABOVE_M, 0.0))
			var box := Rect2(low * to_image, Vector2.ZERO).expand(high * to_image)
			items.append({"name": "%s/%s" % [row.to_lower(), item.name], "row": row.to_lower(),
					"rect": [box.position.x, box.position.y, box.end.x, box.end.y]})
	var corner_px := image.get_pixel(2, 2)
	var layout := {"background": [corner_px.r8, corner_px.g8, corner_px.b8], "items": items}
	var file := FileAccess.open("%s/rects.json" % _out, FileAccess.WRITE)
	file.store_string(JSON.stringify(layout, "  "))
	file.close()
