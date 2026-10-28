@tool
class_name SwarmOrbit
extends Node3D

## A few things (its children) that circle what their SpellCarrier is about: Charm's three spirits (the wizard while he casts, the creature while it is being
## charmed), Intestinal Vaporization's seven guts (the creature that swells). Each member wanders: every so often it picks a point of a disc around
## the center and a push, and glides there on a smooth curve. While the carrier flies they fly with it, a little apart. Presentation only: every
## peer moves its own from the replicated phase and positions, and a headless process moves none. It hurts nobody and picks no target.

@export var carrier: SpellCarrier
## The phases in which they circle the carrier (the target); in CASTING they circle the wizard, in the others they stay by the carrier.
@export var circle_in: Array[SpellCarrier.Phase] = [
	SpellCarrier.Phase.HOLDING, SpellCarrier.Phase.LINGERING
]
## In CASTING they circle the wizard (Charm's spirits); off: they are not seen then.
@export var circles_wizard := true
## While the carrier flies they fly with it (Charm's spirits); off: they are not seen then.
@export var flies_along := true
@export_group("Disc")
## The radius of the disc is `radius_base_m` + `radius_per_size` times the half diagonal of the box of what they circle.
@export_range(0.0, 10.0, 0.05, "suffix:m") var radius_base_m := 1.0
@export_range(0.0, 10.0, 0.05) var radius_per_size := 1.1
## The push of each leg, as a multiple of the radius.
@export_range(0.0, 8.0, 0.1) var push := 3.0
## Legs per second.
@export_range(0.1, 6.0, 0.1) var legs_per_s := 1.5
## In LINGERING they are seen this long (0: while it lasts).
@export_range(0.0, 30.0, 0.1, "suffix:s") var linger_visible_s := 0.0
## They never go lower than this over the land.
@export_range(0.0, 5.0, 0.1, "suffix:m") var min_height_m := 0.0
## While the carrier flies, the members are spread round it at this distance.
@export_range(0.0, 3.0, 0.05, "suffix:m") var flight_spread_m := 0.2

## The things that circle: its children (the node itself moves, its own children draw: a ribbon, a sprite).
var members: Array[Node3D] = []
var _from: Array[Vector3] = []
var _to: Array[Vector3] = []
var _push_from: Array[Vector3] = []
var _push_to: Array[Vector3] = []
var _progress: Array[float] = []
var _rng: RandomNumberGenerator
var _phase_age := 0.0


func _init() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _get_configuration_warnings() -> PackedStringArray:
	return (
		PackedStringArray()
		if carrier != null
		else PackedStringArray(["The SpellCarrier is missing."])
	)


func _ready() -> void:
	set_process(false)
	if Engine.is_editor_hint() or carrier == null or DisplayServer.get_name() == "headless":
		return
	_rng = MatchSeed.rng(["swarm", str(carrier.name), get_path()])
	for child in get_children():
		if child is Node3D:
			members.append(child as Node3D)
	for i in members.size():
		_from.append(Vector3.ZERO)
		_to.append(Vector3.ZERO)
		_push_from.append(Vector3.ZERO)
		_push_to.append(Vector3.ZERO)
		_progress.append(1.0)
	carrier.phase_changed.connect(_restart.unbind(1))
	set_process(true)


## A new phase: every member starts a leg from where it is.
func _restart() -> void:
	_phase_age = 0.0
	for i in members.size():
		_from[i] = Vector3.ZERO
		_to[i] = Vector3.ZERO
		_progress[i] = 1.0


func _process(delta: float) -> void:
	_phase_age += delta
	var phase := carrier.phase
	var focus := _focus(phase)
	if focus == null:
		_set_visible(false)
		return
	_set_visible(true)
	var center := DrawnPose.center(focus) if focus != carrier else DrawnPose.origin(carrier)
	if phase == SpellCarrier.Phase.FLYING or phase == SpellCarrier.Phase.SHRINKING:
		for i in members.size():
			var angle := TAU * float(i) / float(members.size())
			members[i].global_position = (
				DrawnPose.origin(carrier) + Vector3(sin(angle), 0.0, cos(angle)) * flight_spread_m
			)
		return
	var radius := radius_base_m + radius_per_size * _size(focus)
	for i in members.size():
		_wander(i, center, radius, delta)


func _wander(i: int, center: Vector3, radius: float, delta: float) -> void:
	if _progress[i] >= 1.0:
		_progress[i] -= 1.0
		_from[i] = (
			_to[i]
			if _from[i] != Vector3.ZERO or _to[i] != Vector3.ZERO
			else members[i].global_position - center
		)
		_push_from[i] = _push_to[i]
		var disc := Vector2.from_angle(_rng.randf_range(-PI, PI)) * radius * sqrt(_rng.randf())
		_to[i] = Vector3(disc.x, _rng.randf_range(-0.5, 0.5) * radius, disc.y)
		_push_to[i] = (
			(
				Vector3(
					_rng.randf_range(-1.0, 1.0),
					_rng.randf_range(-1.0, 1.0),
					_rng.randf_range(-1.0, 1.0)
				)
				. normalized()
			)
			* push
			* radius
		)
	_progress[i] += legs_per_s * delta
	var at := (
		CarrierPath.hermite(
			_from[i], _push_from[i], _to[i], _push_to[i], clampf(_progress[i], 0.0, 1.0)
		)
		+ center
	)
	var ground := GroundRay.surface_y(self, at, 1, GroundRay.wizard_rids(get_tree()), -INF)
	if is_finite(ground):
		at.y = maxf(at.y, ground + min_height_m)
	members[i].global_position = at


## What they circle in this phase: the wizard while he casts, the target in `circle_in`, the carrier while it flies; null when they are not seen.
func _focus(phase: SpellCarrier.Phase) -> Node3D:
	if phase == SpellCarrier.Phase.CASTING or phase == SpellCarrier.Phase.WAITING:
		return carrier.wizard() if circles_wizard else null
	if (
		phase == SpellCarrier.Phase.LINGERING
		and linger_visible_s > 0.0
		and _phase_age > linger_visible_s
	):
		return null
	if circle_in.has(phase):
		return carrier.target_body() if carrier.target_body() != null else carrier
	return (
		carrier
		if (
			flies_along
			and (phase == SpellCarrier.Phase.FLYING or phase == SpellCarrier.Phase.SHRINKING)
		)
		else null
	)


static func _size(body: Node3D) -> float:
	return BodyNudge.box(body).size.length() * 0.5 if body != null else 1.0


func _set_visible(on: bool) -> void:
	for member in members:
		member.visible = on
