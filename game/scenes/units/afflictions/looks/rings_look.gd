class_name RingsLook
extends Node3D

## The rings of flame around a body while Rings of Fire lasts: every 25 ticks (and now and then in between) a circle of 30 flames appears
## around it at a random height, as wide as the height, and closes down to its feet. When the state ends three more rings fall where the
## body stood. The flames are the scene's SpriteEmitter children, used in turn: each one is a single burst of 30. It does not decide
## when the state is on (Affliction) nor burn anyone (SpellAffliction). Presentation only, on every peer, from the replicated mask; its
## dice are a stream of their own.
## Ref: sacengine animateRingsOfFire, updateRingsOfFire (state.d:17662-17704).

## The state that shows it, and the body it surrounds.
@export var affliction: Affliction
@export var body: Node3D
@export_group("Rings")
## A ring is born every this many ticks, and with chance 1 in `extra_chance` on any tick.
@export_range(1, 200) var every_ticks := 25
@export_range(1, 500) var extra_chance := 50
## Height of a ring over the body's box (a fraction of it; above 1 is over the head) and how long it takes to close.
@export var height_range := Vector2(0.4, 1.2)
@export var close_range_s := Vector2(0.8, 1.2)
## Radius = this range times the box's half diagonal times the height.
@export var radius_range := Vector2(1.2, 1.25)
@export var flames := 30
## Rings that fall where the body stood when the state ends.
@export var end_rings := 3

var _emitters: Array[SpriteEmitter] = []
var _next := 0
var _tick := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_physics_process(false)
	if Engine.is_editor_hint() or affliction == null:
		return
	for node in find_children("*", "SpriteEmitter", false, false):
		_emitters.append(node as SpriteEmitter)
	MatchSeed.seed_rng(_rng, ["rings_look", String(body.name)])
	affliction.shown_changed.connect(_on_shown)
	if affliction.is_on():
		_on_shown(true)


func _on_shown(on: bool) -> void:
	_tick = 0
	set_physics_process(on)
	if not on:
		for _ring in end_rings:
			_spawn(false)


func _physics_process(_delta: float) -> void:
	if _tick % every_ticks == 0 or _rng.randi() % extra_chance == 0:
		_spawn(true)
	_tick += 1


## One ring: `follow` it moves with the body, else it stays in the world.
func _spawn(follow: bool) -> void:
	if _emitters.is_empty() or DisplayServer.get_name() == "headless":
		return
	var emitter := _emitters[_next]
	_next = (_next + 1) % _emitters.size()
	var box := BodyNudge.box(body)
	var feet := body.to_local(Vector3(box.get_center().x, box.position.y, box.get_center().z))
	var fraction := _rng.randf_range(height_range.x, height_range.y)
	var seconds := _rng.randf_range(close_range_s.x, close_range_s.y)
	var radius := _rng.randf_range(radius_range.x, radius_range.y) * 0.5 * Vector2(box.size.x, box.size.z).length() * fraction
	var height := box.size.y * fraction
	var points := PackedVector3Array()
	for k in flames:
		var angle := _rng.randf_range(-PI, PI)
		points.append(Vector3(cos(angle) * radius, height, sin(angle) * radius))
	emitter.local_coords = follow
	emitter.position = feet if follow else Vector3.ZERO
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	emitter.emission_points = points
	emitter.amount = flames
	emitter.lifetime = seconds
	emitter.initial_velocity_min = 0.0
	emitter.initial_velocity_max = 0.0
	## A pull toward the emitter's origin (the feet) that brings every flame there in `seconds`.
	var pull := -2.0 * Vector2(radius, height).length() / (seconds * seconds)
	emitter.radial_accel_min = pull
	emitter.radial_accel_max = pull
	emitter.scale_amount_min = radius
	emitter.scale_amount_max = radius
	if not follow:
		emitter.global_position = body.global_position
	emitter.restart()
	emitter.emitting = true


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if affliction == null or body == null:
		warnings.append("Faltan affliction y body.")
	return warnings
