extends Node

## RFC-054 054c (F382): playtest scene of the map flora. Instances the setup's real map.tscn (with its FloraLayers), applies
## the setup's preset and puts the camera on pose 0; `check_tick` goes to the next pose (the last one of each setup is
## aerial, 120 m). The label shows what FloraField draws: instances, cells, nodes, pending cells, build time, draw calls.
## `--setup=<name>` (user arg) loads res://debug/look/flora_lab_<name>.tres instead of the exported one.
##   godot --path game res://debug/look/flora_lab.tscn -- --setup=roads_low

@export var setup: FloraLabSetup
@export var camera: Camera3D
@export var label: Label

var _map: Node3D
var _field: FloraField
var _terrain: Terrain
var _pose := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--setup="):
			setup = load("res://debug/look/flora_lab_%s.tres" % arg.get_slice("=", 1)) as FloraLabSetup
	if setup == null or setup.map_scene == null:
		push_warning("FloraLab: falta setup o su map_scene.")
		return
	_map = setup.map_scene.instantiate() as Node3D
	add_child(_map)
	var rig := _map.get_node_or_null("Look") as LookRig
	_terrain = _map.get_node_or_null("Terrain") as Terrain
	if rig:
		_field = rig.get_node_or_null("Layers/Flora") as FloraField
		if setup.quality:
			rig.apply_quality(setup.quality)
	if setup.quality:
		QualityApplier.apply_to(get_viewport(), setup.quality)
	camera.current = true
	_go(0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("check_tick") and setup and not setup.eyes.is_empty():
		_go((_pose + 1) % setup.eyes.size())


func _go(index: int) -> void:
	_pose = index
	if setup.eyes.is_empty():
		return
	var eye := _on_ground(setup.eyes[index])
	var target := _on_ground(setup.targets[mini(index, setup.targets.size() - 1)]) if not setup.targets.is_empty() else eye + Vector3.FORWARD
	camera.global_position = eye
	camera.look_at(target, Vector3.UP)


func _on_ground(point: Vector3) -> Vector3:
	var ground := _terrain.height_at(point.x, point.z) if _terrain else NAN
	var local := Vector3(point.x, (0.0 if is_nan(ground) else ground) + point.y, point.z)
	return _terrain.global_transform * local if _terrain else local


func _process(_delta: float) -> void:
	if label == null or setup == null:
		return
	var note := setup.notes[_pose] if _pose < setup.notes.size() else ""
	var line := "pose %d/%d %s · fps %d · draw %d" % [_pose + 1, setup.eyes.size(), note, Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]
	if is_instance_valid(_field):
		var build := _field.build_us()
		line += "\nplantas %d · celdas %d · nodos %d · pendientes %d · armado %.2f ms (peor %.2f)" % [
			_field.instance_count(), _field.cell_count(), _field.node_count(), _field.pending_count(), build.x / 1000.0, build.y / 1000.0]
	label.text = line
