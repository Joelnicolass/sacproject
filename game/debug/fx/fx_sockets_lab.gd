extends Node

## Lab of 055x (F6): three real creatures of very different sizes in a row, a fixed camera at `camera_distance_m` and `camera_pitch_deg`, and one
## step per `check_tick`. Each step is a case (`_cases`): it fires the real component and prints `FX_LAB case=<name> body=<creature> ...` with the
## place the effect was asked for, so a capture (agent/harness/fx_sockets_capture.gd) can compare it with where the pixels are.
## x1 brings the first case (`sockets`: one burst at each socket of each creature). x4 adds Rockform, Play Dead, Stealth, Firewalking, Frozen,
## Petrified, Burning, Heal, Speedup, the break of Pull, Summon and the fall of the altar by appending to `_cases`.
## What it does not do: judge the look (the capture does), or edit the product (it only spawns and fires).

@export var world: MatchWorld
@export var unit_scene: PackedScene
@export var arena: Node3D
@export var camera: Camera3D
@export var log_label: Label

@export_group("Subjects")
## The creatures in a row, small to big (the gnome, the earthfling, the jabberocky).
@export var creatures: Array[CreatureType] = []
@export var slot := 1
## Meters ahead of the wizard where the row is centered, and between two creatures.
@export var ahead_m := 14.0
@export var spacing_m := 6.0

@export_group("Camera")
@export var camera_distance_m := 12.0
@export_range(0.0, 85.0, 1.0, "suffix:deg") var camera_pitch_deg := 35.0
@export var camera_look_up_m := 1.0

@export_group("Effects")
## The burst the `sockets` case plays at each socket.
@export var socket_fx: ParticleType
## Frames the world gets to settle before the row spawns and between two plays.
@export var settle_frames := 4

var _subjects: Array[Node3D] = []
var _step := 0
var _cases: Array[Dictionary] = [{"name": "sockets", "run": _sockets}]


func _ready() -> void:
	world.local_wizard_changed.connect(func(_wizard: Node3D) -> void: _start.call_deferred())
	if world.local_wizard() != null:
		_start.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("check_tick"):
		_run_next()


## Spawns the row and puts the camera in front of it.
func _start() -> void:
	var wizard := world.local_wizard() as WizardBody
	if wizard == null:
		return
	for _frame in settle_frames:
		await get_tree().physics_frame
	for old in arena.get_children():
		old.queue_free()
	_subjects.clear()
	var ahead := wizard.facing_flat()
	var right := ahead.cross(Vector3.UP).normalized()
	var middle := wizard.global_position + ahead * ahead_m
	for index in creatures.size():
		var at := middle + right * (float(index) - float(creatures.size() - 1) * 0.5) * spacing_m
		_subjects.append(_spawn(creatures[index], at, -ahead))
	camera.current = true
	var pitch := deg_to_rad(camera_pitch_deg)
	camera.global_position = middle + (-ahead * cos(pitch) + Vector3.UP * sin(pitch)) * camera_distance_m
	camera.look_at(middle + Vector3.UP * camera_look_up_m)
	_say("listo: %d criaturas, pulsá check_tick para el caso %s" % [_subjects.size(), _cases[0]["name"]])


## The next case (check_tick). After the last one, the first again.
func _run_next() -> void:
	if _subjects.is_empty():
		return
	var entry: Dictionary = _cases[_step % _cases.size()]
	_step += 1
	var run: Callable = entry["run"]
	run.call()


## One burst at each socket (feet, center, top, muzzle) of each creature, one body at a time.
func _sockets() -> void:
	for body in _subjects:
		for index in 4:
			var socket := index as BodyFacts.Socket
			var at := BodyFacts.point(body, socket)
			FxBus.play(socket_fx, at)
			print("FX_LAB case=sockets body=%s socket=%s at=%s" % [body.name, BodyFacts.Socket.keys()[index], at])
		await get_tree().create_timer(1.5).timeout
	_say("caso sockets")


func _spawn(type: CreatureType, at: Vector3, facing: Vector3) -> Node3D:
	var unit: Node3D = unit_scene.instantiate()
	unit.name = "%s%d" % [type.tag.capitalize(), _subjects.size()]
	unit.set("type", type)
	unit.set("owner_slot", slot)
	arena.add_child(unit)
	unit.global_position = at
	unit.rotation.y = atan2(facing.x, facing.z)
	return unit


func _say(text: String) -> void:
	print("FX_LAB %s" % text)
	if log_label != null:
		log_label.text = text
