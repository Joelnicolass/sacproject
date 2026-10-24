extends Node3D

## RFC-059b: the tutorial's valley (tutorial_valley) with Persephone's look from three fixed cameras: the ground close to
## the camera, the stone arch, and the hills far away. These are the three views the plan's targets are measured in
## (tools/import/measure_ground.py: near / mid / far). `check_tick` goes to the next camera. Only shows; it simulates nothing.
## F6 opens it; `-- --persephone-compare=N` starts on camera N (0 ground, 1 arch, 2 hills).

const MAP_TAG := &"tutorial_valley"

@export var map: MapRoot
@export var cameras: Array[Camera3D] = []
@export var god: StringName = &"persephone"

var _index := 0


func _init() -> void:
	# The terrain, the grass and the plants ask the active map for its tiles: it has to be this one before they are built.
	MapCatalog.use(MAP_TAG)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--persephone-compare="):
			_index = clampi(int(argument.get_slice("=", 1)), 0, cameras.size() - 1)
	_show.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("check_tick") and not cameras.is_empty():
		_index = (_index + 1) % cameras.size()
		_show()


func _show() -> void:
	var type := GameCatalog.shared().god(String(god))
	if type != null and map != null and map.look != null and map.look.profile != type.look:
		map.look.apply_profile(type.look)
	for k in cameras.size():
		cameras[k].current = k == _index
	print("persephone_compare camera %s" % cameras[_index].name)
