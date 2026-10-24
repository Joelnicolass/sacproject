@tool
class_name WardEmitter
extends SpriteEmitter

## The sprites of a ward: a SpriteEmitter that follows its Ward (all the time it is on, one burst when it starts or ends, or while its
## spell is being cast) and draws on the surface or inside of an ellipsoid around the body, so a bigger body gets a bigger shell. The
## ParticleType says what and how many; this only says where and when. Presentation only, on every peer, from the Ward's replicated
## `shown` and the wizard's replicated cast particle.

enum When { WHILE_ON, WHEN_STARTS, WHEN_ENDS, WHILE_CASTING }

const POINTS := 192
const GOLDEN_ANGLE := 2.399963
## The rate of a ramp climbs in this many steps (a smaller change would resize the particle pool for nothing).
const RAMP_STEPS := 4.0

@export var ward: Ward
@export var when := When.WHILE_ON
## Off: the emitter does nothing (an alternative look left in the scene for whoever wants to try it).
@export var enabled := true
## Half axes of the ellipsoid in metres, centred on this node (move the node with the gizmo to centre it on the body). With y = 0
## the sprites are born on a flat ring of that radius (Skin of Stone's ring on the ground).
@export var half_axes_m := Vector3.ONE:
	set(value):
		half_axes_m = value
		if is_node_ready():
			_apply()
## Points on the surface (a shell) or inside it (a cloud).
@export var on_surface := true:
	set(value):
		on_surface = value
		if is_node_ready():
			_apply()
@export_group("Fade")
## After the ward goes off it keeps emitting this long, so the look thins out instead of being cut (Ethereal Form: 30 ticks).
@export_range(0.0, 5.0, 0.05, "suffix:s") var linger_s := 0.0
@export_group("Casting")
## WHILE_CASTING: the rate climbs from nothing to the type's over the casting time (Fireform's flames grow while it is cast).
@export var ramp := false
## WHILE_CASTING: the ellipsoid closes to this fraction of its axes over the casting time (Skin of Stone's ring of dirt). 1 = it stays.
@export_range(0.0, 1.0, 0.05) var shrink_to := 1.0
## Sprites are pulled toward the centre of the ellipsoid at this m/s² (Air Shield's sparks converge on the wizard). 0 = no pull.
@export_range(0.0, 100.0, 0.5, "suffix:m/s²") var pull_m_s2 := 0.0

var _cast_tween: Tween


func _ready() -> void:
	super()
	if Engine.is_editor_hint() or ward == null:
		return
	ward.shown_changed.connect(_on_ward)
	ward.casting_changed.connect(_on_casting)
	if ward.shown:
		_on_ward(true)
	if ward.casting:
		_on_casting(true)


func _on_ward(on: bool) -> void:
	if not enabled:
		return
	match when:
		When.WHILE_ON:
			if on or linger_s <= 0.0:
				set_active(on)
			else:
				get_tree().create_timer(linger_s).timeout.connect(_end_linger)
		When.WHEN_STARTS, When.WHEN_ENDS:
			if on == (when == When.WHEN_STARTS):
				set_active(true)
				restart()


func _end_linger() -> void:
	if not ward.shown:
		set_active(false)


func _on_casting(on: bool) -> void:
	if not enabled or when != When.WHILE_CASTING:
		return
	if _cast_tween:
		_cast_tween.kill()
	if not on:
		set_active(false)
		set_rate(-1.0)
		_set_points(half_axes_m)
		return
	set_active(true)
	if not ramp and shrink_to >= 1.0:
		return
	var seconds := maxf(ward.spell.casting_time_s if ward.spell else 1.0, 0.05)
	_cast_tween = create_tween()
	_cast_tween.tween_method(_cast_progress, 0.0, 1.0, seconds)


func _cast_progress(t: float) -> void:
	if ramp and type != null:
		set_rate(type.rate_per_s * (floorf(t * RAMP_STEPS) + 1.0) / RAMP_STEPS)
	if shrink_to < 1.0:
		_set_points(half_axes_m.lerp(half_axes_m * shrink_to, t))


## The sprites are born at the points of the ellipsoid (a Fibonacci spiral: the same on every peer, with no random draw).
func _apply() -> void:
	super()
	if type == null:
		return
	_set_points(half_axes_m)
	radial_accel_min = -pull_m_s2
	radial_accel_max = -pull_m_s2


## Only the emission points: cheap enough to run every frame while the ellipsoid closes (it never restarts the particles).
func _set_points(axes: Vector3) -> void:
	var points := PackedVector3Array()
	for i in POINTS:
		var height := 1.0 - 2.0 * (float(i) + 0.5) / float(POINTS)
		var ring := sqrt(1.0 - height * height)
		var angle := float(i) * GOLDEN_ANGLE
		var direction := Vector3(cos(angle) * ring, height, sin(angle) * ring)
		if axes.y <= 0.0:
			direction = Vector3(cos(TAU * float(i) / float(POINTS)), 0.0, sin(TAU * float(i) / float(POINTS)))
		var depth := 1.0 if on_surface else pow(fposmod(float(i) * 0.618034, 1.0), 1.0 / 3.0)
		points.append(direction * axes * depth)
	emission_shape = EMISSION_SHAPE_POINTS
	emission_points = points
