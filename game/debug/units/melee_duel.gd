extends Node

## Spawns two enemy creatures ahead of the local wizard, gap_m apart, and lets them fight.
## Prints every hit and the death. check_tick clears the field and starts a new duel.

@export var world: Node
@export var unit_scene: PackedScene
@export var arena: Node3D
@export var camera: Camera3D
@export var log_label: Label

@export_group("Duel")
@export var first_tag := "ycro"
@export var first_slot := 1
@export var second_tag := "nmuh"
@export var second_slot := 2
## Meters ahead of the wizard where the first creature stands.
@export var ahead_m := 12.0
@export var gap_m := 20.0
@export var settle_frames := 4

@export_group("Camera")
@export var camera_side_m := 6.0
@export var camera_up_m := 2.6
@export var camera_look_up_m := 1.0
@export var camera_follow := 4.0

var _units: Array[Node3D] = []
var _last := ""
var _deaths: PackedStringArray = []
var _round := 0


func _ready() -> void:
	var souls := world.get_node_or_null("SoulSystem")
	if souls:
		souls.soul_spawned.connect(_on_soul_spawned)
	world.local_wizard_changed.connect(func(_wizard: Node3D) -> void: _start.call_deferred())
	if world.call("local_wizard"):
		_start.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("check_tick"):
		_start()


func _start() -> void:
	var wizard: Node3D = world.call("local_wizard")
	if wizard == null:
		return
	for _frame in settle_frames:
		await get_tree().physics_frame
	for old in arena.get_children():
		old.queue_free()
	_units.clear()
	_deaths.clear()
	_round += 1
	var ahead := Vector3(0.0, 0.0, 1.0)
	if wizard.has_method("facing_flat"):
		ahead = wizard.call("facing_flat")
	var first_at := wizard.global_position + ahead * ahead_m
	var second_at := first_at + ahead * gap_m
	_units.append(_spawn(first_tag, first_slot, first_at, ahead))
	_units.append(_spawn(second_tag, second_slot, second_at, -ahead))
	_last = "duelo %d" % _round
	print("duelo %d %s slot %d vs %s slot %d a %.1f m" % [_round, first_tag, first_slot, second_tag, second_slot, gap_m])
	camera.current = true
	_frame_camera(1.0)


func _spawn(tag: String, slot: int, at: Vector3, facing: Vector3) -> Node3D:
	var unit: Node3D = unit_scene.instantiate()
	unit.name = "%s%d" % [tag.capitalize(), _round]
	unit.set("type", GameData.creature(tag))
	unit.set("owner_slot", slot)
	arena.add_child(unit)
	unit.global_position = at
	unit.rotation.y = atan2(facing.x, facing.z)
	unit.struck.connect(_on_struck.bind(unit))
	unit.died.connect(_on_died)
	return unit


func _on_struck(foe: Node3D, amount: float, hit_chance: float, roll: float, attacker: Node3D) -> void:
	var health := foe.get_node_or_null("Health")
	var left := float(health.get("current")) if health else 0.0
	_last = "golpe %s -> %s %.1f vida %d" % [_name_of(attacker), _name_of(foe), amount, roundi(left)]
	print("%s (p %.3f tirada %.3f)" % [_last, hit_chance, roll])


func _on_died(tag: String, slot: int, at: Vector3) -> void:
	var line := "muere %s" % tag
	_deaths.append(line)
	print("%s slot %d en (%.1f, %.1f, %.1f)" % [line, slot, at.x, at.y, at.z])


func _on_soul_spawned(soul: Node3D) -> void:
	var blue: bool = soul.call("color_for", MpKit.local_slot()) == 0
	var line := "alma %d %s" % [int(soul.get("number")), "azul" if blue else "roja"]
	_deaths.append(line)
	var at := soul.global_position
	print("%s slot %d en (%.1f, %.1f, %.1f)" % [line, int(soul.get("owner_slot")), at.x, at.y, at.z])


func _process(delta: float) -> void:
	if log_label:
		var bars: PackedStringArray = []
		for unit in _units:
			if is_instance_valid(unit):
				var health := unit.get_node("Health")
				bars.append("%s %d/%d" % [_name_of(unit), roundi(float(health.get("current"))), roundi(float(health.get("maximum")))])
		log_label.text = "%s\n%s\n%s" % [" · ".join(bars), _last, " · ".join(_deaths)]
	_frame_camera(1.0 - exp(-camera_follow * delta))


func _frame_camera(weight: float) -> void:
	if camera == null or _units.size() < 2 or not is_instance_valid(_units[0]) or not is_instance_valid(_units[1]):
		return
	var a := _units[0].global_position
	var b := _units[1].global_position
	var mid := (a + b) * 0.5
	var line := Vector3(b.x - a.x, 0.0, b.z - a.z)
	if line.length_squared() < 0.0001:
		line = Vector3(0.0, 0.0, 1.0)
	var side := line.normalized().cross(Vector3.UP)
	var spread := maxf(line.length() * 0.6, 1.0)
	var eye := mid + side * (camera_side_m + spread) + Vector3.UP * camera_up_m
	camera.global_position = camera.global_position.lerp(eye, weight)
	camera.look_at(mid + Vector3.UP * camera_look_up_m, Vector3.UP)


func _name_of(unit: Node3D) -> String:
	return str(unit.call("display_name")) if unit.has_method("display_name") else str(unit.name)
