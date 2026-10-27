class_name ShotStrike
extends Node3D

## A creature's ranged attack with no flight, in place of a RangedShot: the Gnome's ray (plfa),
## the Styx's bolt at the next tick (dhga) and the
## Warmonger's gun (fhga, 030m-b). The scene is ShotLook.strike; RangedFire instances it on the server (or solo) only,
## as its own child, and calls launch() once. The strike is not replicated: what peers see goes through FxBus.
##
## Ticks: launch() runs tick 0 in the tick of the shot; then every physics tick runs the ticks MatchClock advanced
## since (1, 2, …). The scene's process_physics_priority is −1: the original updates its effects before its creatures.
## Variants override _strike_tick() and call finish() when done.
##
## Same names as RangedShot, so a ShotImpact reads either: damage, from_slot, velocity, ability, target_path,
## shooter_path.
## Ref: F124 (RFC-030 030m), sacengine gnomeShoot state.d:11724-11735, StyxShoot 11852-11855, 24154-24172, effects before creatures 29331 vs 29345.

const _ROCK := preload("res://scenes/spells/rock_projectile.gd")

## Already scaled by the shooter (attack_factor).
var damage := 0.0
var from_slot := 0
## The shot's direction (accuracy drawn once by RangedFire) times the ability speed.
var velocity := Vector3.ZERO
var ability: AbilityType
var target_path := NodePath()
var shooter_path := NodePath()
var look: ShotLook
## Where the shot leaves (RangedWeapon.shot_origin at the shot tick).
var origin := Vector3.ZERO
## The predicted target center, without accuracy (`target` of the *Shoot functions).
var aim := Vector3.ZERO
## The shooter's ranged accuracy (CreatureType.ranged_accuracy), for the strikes that draw it again.
var accuracy := 0.0
## The ability range (RangedFire's max_distance).
var max_distance := 0.0
## The ability tag, for the log.
var tag := ""
## The RangedWeapon that fired it (its shot_origin() for a strike that follows the shooter). Injected by launch().
var source: RangedWeapon


var _born_tick := 0
var _done_tick := 0
var _finished := false


## `data`: the keys of RangedFire.fire (the ones of RangedShot.setup plus aim_x/y/z and accuracy). Call it once the
## strike is in the tree: tick 0 may already cast against the world. `from`: the RangedWeapon that fired it. A look nobody holds yet
## becomes a child of the strike.
func launch(data: Dictionary, shot_look: ShotLook, shot_ability: AbilityType, from: RangedWeapon = null) -> void:
	source = from
	tag = str(data.get("tag", ""))
	origin = Vector3(float(data.get("x", 0.0)), float(data.get("y", 0.0)), float(data.get("z", 0.0)))
	global_position = origin
	velocity = Vector3(float(data.get("vx", 0.0)), float(data.get("vy", 0.0)), float(data.get("vz", 0.0)))
	aim = Vector3(float(data.get("aim_x", origin.x)), float(data.get("aim_y", origin.y)), float(data.get("aim_z", origin.z)))
	accuracy = float(data.get("accuracy", 0.0))
	damage = float(data.get("damage", 0.0))
	from_slot = int(data.get("slot", 0))
	max_distance = float(data.get("max_distance", 0.0))
	target_path = NodePath(str(data.get("target", "")))
	shooter_path = NodePath(str(data.get("shooter", "")))
	look = shot_look if shot_look != null else ShotLook.new()
	if look.get_parent() == null:
		add_child(look)
	ability = shot_ability
	_born_tick = MatchClock.now()
	_done_tick = 0
	_strike_tick(0)


func _physics_process(_delta: float) -> void:
	var age := MatchClock.now() - _born_tick
	while not _finished and _done_tick < age:
		_done_tick += 1
		_strike_tick(_done_tick)


## What the strike does on its tick `age` (0 = the tick of the shot). Default: nothing.
func _strike_tick(_age: int) -> void:
	pass


## Done: no more ticks; freed at the end of the frame (an impact child goes with it).
func finish() -> void:
	_finished = true
	set_physics_process(false)
	queue_free()


## The shooter while it lives, else null.
func shooter() -> Node3D:
	var body: Node3D = null
	if not shooter_path.is_empty():
		body = get_node_or_null(shooter_path) as Node3D
	return body if body != null and _ROCK.is_live_body(body) else null


## The body the shooter aimed at while it is a live target, else null.
func intended() -> Node3D:
	var body: Node3D = null
	if not target_path.is_empty():
		body = get_node_or_null(target_path) as Node3D
	return body if body != null and _ROCK.is_live_body(body) else null


## The shooter's node name (a stable id on the field: Gnome1), even after it died.
func shooter_name() -> String:
	if shooter_path.is_empty():
		return "?"
	return str(shooter_path.get_name(shooter_path.get_name_count() - 1))


func _log(line: String) -> void:
	if DebugLog.on(&"strikes"):
		print(line)


## What lands at `point` on `target` (or on nothing): ShotImpact.land. Returns the direct damage taken.
func _land(target: Node3D, point: Vector3) -> float:
	return ShotImpact.land(self, look, target, point, ability)


## A body's center: ShotAim.center.
static func center_of(body: Node3D) -> Vector3:
	return ShotAim.center(body)
