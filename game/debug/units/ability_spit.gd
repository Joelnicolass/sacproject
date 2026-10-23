extends Node

## F29: an own Earthfling and a still enemy creature gap_m apart, ahead of the local wizard
## (or the nearest spot no mana source reaches, see clear_of_mana).
## The Earthfling picks the target by itself and spits (its ranged attack) once it is within
## range. Prints every spit (`escupe <dmg> mana <before>-><after>`), hit and melee blow
## (`golpe <from> a <to> <dmg>`, with the unscaled amount while the victim is a rock).
## The Earthfling starts selected, so use_ability (Ctrl+Q / Shift+B) goes through
## MatchCommand like in a match; check_tick starts over.

@export var world: Node
@export var unit_scene: PackedScene
@export var arena: Node3D
@export var camera: Camera3D
@export var log_label: Label

@export_group("Field")
@export var shooter_tag := "palk"
@export var shooter_slot := 1
@export var target_tag := "nmuh"
@export var target_slot := 2
## Meters ahead of the wizard where the shooter stands.
@export var ahead_m := 12.0
@export var gap_m := 60.0
## Fixed seed: the same rolls (accuracy) every run.
@export var shooter_seed := 29
## F165: the shooter neither picks a target nor attacks (it only uses its ability), as the target does.
@export var shooter_idle := false
@export var settle_frames := 4
## Creatures recharge mana only at sources (updateCreatureStats, state.d:14409): the pair goes to
## the nearest spot on land no source reaches, so the mana each spit costs stays spent.
@export var clear_of_mana := true
@export var clear_search_m := 600.0
@export var clear_step_m := 20.0
@export var clear_margin_m := 10.0

@export_group("Target")
## Target's mana at the start, as a share of its maximum. A creature regenerates
## regeneration·mana/maxMana per second (state.d:14400-14403), so 0 means no regeneration.
@export_range(0.0, 1.0, 0.05) var target_mana_share := 1.0
## The target walks to the Earthfling and fights it; in melee contact the Earthfling stops
## spitting and swings (sacengine attack, state.d:12849-12855).
@export var target_approaches := false
## While the Earthfling is a rock, starts the target's swing whenever it stands in reach. The AI
## never picks a rock (isVisibleToAI, state.d:93), but dealDamage scales a landed blow by 0.05
## (state.d:8964); this shows that blow.
@export var force_swings_at_rock := false

@export_group("Camera")
@export var camera_side_m := 10.0
@export var camera_up_m := 8.0
@export var camera_look_up_m := 1.0
@export var camera_follow := 4.0

var _shooter: Node3D
var _target: Node3D
var _spit := ""
var _hit := ""
var _blow := ""
var _round := 0


func _ready() -> void:
	DebugLog.enable(&"gap")  # melee_gap_expect reads the approach of the final_spit_melee flow
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
	_round += 1
	_spit = "sin escupir"
	_hit = "sin impacto"
	_blow = "sin golpes"
	var ahead := Vector3(0.0, 0.0, 1.0)
	if wizard.has_method("facing_flat"):
		ahead = wizard.call("facing_flat")
	var spot := _field_spot(wizard.global_position, ahead)
	var shooter_at: Vector3 = spot[0]
	ahead = spot[1]
	var target_at := _on_land(shooter_at + ahead * gap_m)
	_shooter = _spawn(shooter_tag, shooter_slot, shooter_at, ahead)
	_shooter.set("rng_seed", shooter_seed)
	if shooter_idle:
		_shooter.set("target_groups", PackedStringArray())
		_shooter.set("idle_aggro", false)
	_target = _spawn(target_tag, target_slot, target_at, -ahead)
	if target_approaches:
		_target.set("target_groups", PackedStringArray(["unit"]))
	else:
		_target.set("target_groups", PackedStringArray())
		_target.set("idle_aggro", false)
	arena.add_child(_shooter)
	arena.add_child(_target)
	_shooter.global_position = shooter_at
	_target.global_position = target_at
	var target_mana := _target.get_node("ManaPool")
	target_mana.set("current", float(target_mana.get("maximum")) * target_mana_share)
	_shooter.get_node("RangedAttack").fired.connect(_on_fired)
	_target.get_node("Health").hurt.connect(_on_hurt)
	_shooter.connect("struck", _on_struck.bind(_shooter))
	_target.connect("struck", _on_struck.bind(_target))
	world.get_node("%Selection").call("click", _shooter, Vector2(-1.0, -1.0), false, false)
	print("escupir %d %s slot %d vs %s slot %d a %.1f m, en %s (maná del blanco %d%%)" % [_round, shooter_tag, shooter_slot, target_tag, target_slot, gap_m, shooter_at.snapped(Vector3.ONE * 0.1), roundi(target_mana_share * 100.0)])
	camera.current = true
	_frame_camera(1.0)


func _spawn(tag: String, slot: int, at: Vector3, facing: Vector3) -> Node3D:
	var unit: Node3D = unit_scene.instantiate()
	unit.name = "%s%d" % [tag.capitalize(), _round]
	unit.set("creature_tag", tag)
	unit.set("owner_slot", slot)
	unit.position = at
	unit.rotation.y = atan2(facing.x, facing.z)
	return unit


## [shooter position, line direction]: ahead_m in front of the wizard, or with clear_of_mana the
## closest ring spot (16 headings, clear_step_m apart) whose shooter, target and midpoint stand
## on land out of every mana source's radius + clear_margin_m.
func _field_spot(origin: Vector3, ahead: Vector3) -> Array:
	var fallback := [_on_land(origin + ahead * ahead_m), ahead]
	if not clear_of_mana:
		return fallback
	var distance := ahead_m
	while distance <= clear_search_m:
		for heading in 16:
			var line := ahead.rotated(Vector3.UP, TAU * float(heading) / 16.0)
			var a := origin + line * distance
			var b := a + line * gap_m
			if _spot_clear(a) and _spot_clear(b) and _spot_clear((a + b) * 0.5):
				return [_on_land(a), line]
		distance += clear_step_m
	print("escupir: no hay lugar sin fuentes de maná a %d m" % roundi(clear_search_m))
	return fallback


func _spot_clear(at: Vector3) -> bool:
	var terrain := TerrainShape.of(self)
	if terrain and not terrain.is_on_ground(at.x, at.z):
		return false
	var flat := Vector2(at.x, at.z)
	for source in get_tree().get_nodes_in_group("mana_source"):
		var center := (source as Node3D).global_position
		if flat.distance_to(Vector2(center.x, center.z)) < float(source.get("radius")) + clear_margin_m:
			return false
	return true


func _on_land(at: Vector3) -> Vector3:
	var terrain := TerrainShape.of(self)
	if terrain:
		var height := float(terrain.height_at(at.x, at.z))
		if is_finite(height):
			at.y = height
	return at


func _physics_process(_delta: float) -> void:
	if not force_swings_at_rock or not _alive(_shooter) or not _alive(_target):
		return
	if not _shooter.call("is_rock_form"):
		return
	var mode := int(_target.get("mode"))
	if mode != UnitBody.Mode.IDLE and mode != UnitBody.Mode.CHASE:
		return
	var melee := _target.get_node("MeleeAttack")
	if melee.call("is_swinging") or not melee.call("can_start", _shooter):
		return
	melee.call("start", _shooter)
	_target.set("target", _shooter)
	_target.set("swings", int(_target.get("swings")) + 1)
	_target.set("mode", UnitBody.Mode.ATTACK)


func _on_struck(foe: Node3D, amount: float, _hit_chance: float, _roll: float, from: Node3D) -> void:
	_blow = "golpe %s a %s %d" % [_name_of(from), _name_of(foe), roundi(amount)]
	var factor := float(foe.get_node("Health").get("damage_factor"))
	if foe.has_method("is_rock_form") and foe.call("is_rock_form") and factor > 0.0:
		_blow += " (roca, sin roca %d, ×%.2f)" % [roundi(amount / factor), factor]
	print(_blow)


func _on_fired(foe: Node3D, damage: float, before: float, after: float) -> void:
	var meters := _shooter.global_position.distance_to(foe.global_position)
	_spit = "escupe %d mana %d->%d a %d m" % [roundi(damage), roundi(before), roundi(after), roundi(meters)]
	print(_spit)


func _on_hurt(amount: float, _kind: StringName, _from_slot: int) -> void:
	var health := _target.get_node("Health")
	_hit = "dano %s %d vida %d" % [_name_of(_target), roundi(amount), roundi(float(health.get("current")))]
	print(_hit)


func _process(delta: float) -> void:
	if log_label:
		var lines: PackedStringArray = []
		var bars: PackedStringArray = []
		for unit in [_shooter, _target]:
			if _alive(unit):
				var health: Node = unit.get_node("Health")
				var mana: Node = unit.get_node("ManaPool")
				bars.append("%s %d/%d maná %d/%d" % [_name_of(unit), roundi(float(health.get("current"))), roundi(float(health.get("maximum"))), roundi(float(mana.get("current"))), roundi(float(mana.get("maximum")))])
		lines.append(" · ".join(bars))
		lines.append(_spit)
		lines.append(_hit)
		lines.append(_blow)
		if _alive(_shooter):
			lines.append("roca sí" if _shooter.call("is_rock_form") else "roca no")
		log_label.text = "\n".join(lines)
	_frame_camera(1.0 - exp(-camera_follow * delta))


func _frame_camera(weight: float) -> void:
	if camera == null or not _alive(_shooter) or not _alive(_target):
		return
	var a := _shooter.global_position
	var b := _target.global_position
	var mid := (a + b) * 0.5
	var line := Vector3(b.x - a.x, 0.0, b.z - a.z)
	if line.length_squared() < 0.0001:
		line = Vector3(0.0, 0.0, 1.0)
	var side := line.normalized().cross(Vector3.UP)
	var spread := maxf(line.length() * 0.6, 1.0)
	var eye := mid + side * (camera_side_m + spread) + Vector3.UP * (camera_up_m + spread * 0.3)
	camera.global_position = camera.global_position.lerp(eye, weight)
	camera.look_at(mid + Vector3.UP * camera_look_up_m, Vector3.UP)


func _alive(unit: Variant) -> bool:
	return unit != null and is_instance_valid(unit) and (unit as Node).is_inside_tree()


func _name_of(unit: Node3D) -> String:
	return str(unit.call("display_name")) if unit.has_method("display_name") else str(unit.name)
