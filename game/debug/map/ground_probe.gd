extends Node

## Watches the local wizard against the land under it (GroundSurface is_on_ground / height_at).
## The label says «en el suelo» while the feet never dropped below the land by more than
## tolerance and the body never stood over a hole, «cayó» after that, and «llegó» once the
## wizard walked reach_m from where he first touched the floor.

@export var world: Node
@export var label: Label
@export var tolerance := 1.0
@export var reach_m := 15.0
@export var report_s := 1.0

var _started := false
var _fell := false
var _start := Vector3.ZERO
var _lowest_gap := INF
var _walked := 0.0
var _elapsed := 0.0


func _physics_process(delta: float) -> void:
	var wizard: Node3D = world.call("local_wizard") if world else null
	var terrain := GroundSurface.of(world)
	if wizard == null or terrain == null:
		return
	if not _started:
		if not (wizard as CharacterBody3D).is_on_floor():
			return
		_started = true
		_start = wizard.global_position
	var at := wizard.global_position
	var ground := terrain.height_at(at.x, at.z)
	var gap := -INF if is_nan(ground) else at.y + float(wizard.call("feet_drop")) - ground
	_lowest_gap = minf(_lowest_gap, gap)
	if gap < -tolerance:
		_fell = true
	_walked = Vector2(at.x - _start.x, at.z - _start.z).length()
	var state := "cayó" if _fell else "en el suelo"
	var reached := " · llegó" if _walked >= reach_m else ""
	if label:
		label.text = "Suelo: %s · margen %.2f m · recorrió %.1f m%s" % [state, _lowest_gap, _walked, reached]
	_elapsed += delta
	if _elapsed >= report_s:
		_elapsed = 0.0
		print("suelo %s pos (%.1f, %.2f, %.1f) tierra %.2f recorrio %.1f" % [state, at.x, at.y, at.z, ground, _walked])
