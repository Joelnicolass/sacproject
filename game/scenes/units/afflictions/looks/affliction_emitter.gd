@tool
class_name AfflictionEmitter
extends SpriteEmitter

## The sprites of a state, in the volume of the body's box: a burst that sprays outward and up when the state starts and ends (Slime's
## splash), or a drizzle in the upper half of the box while it lasts (Slime's drips). The ParticleType says what and how many; this only says
## where and when. It does not decide when the state is on (Affliction). Presentation only, on every peer, from the replicated mask.

enum Shape { SPRAY, DRIZZLE }

## The state that drives it, and the body whose box it fills.
@export var affliction: Affliction
@export var body: Node3D
@export var shape := Shape.SPRAY
## Size of the volume over the body's box (the splash starts 1.2 times wider, the drips 0.8).
@export var box_scale := 1.2
## Spray: the speed outward (a unit) and up (m/s) of every sprite.
@export var spray_out := 1.0
@export var spray_up := 3.0


func _ready() -> void:
	super()
	if Engine.is_editor_hint() or affliction == null:
		return
	affliction.shown_changed.connect(_on_shown)
	if affliction.is_on():
		_on_shown(true)


func _on_shown(on: bool) -> void:
	_place()
	if shape == Shape.DRIZZLE:
		set_active(on)
	else:
		set_active(true)
		restart()


## Centre the emitter on the body's box (upper half for the drizzle) and shape the volume to it.
func _place() -> void:
	if body == null or type == null:
		return
	var box := BodyNudge.box(body)
	var half := box.size * 0.5 * box_scale
	var center := box.get_center()
	if shape == Shape.DRIZZLE:
		center += Vector3.UP * box.size.y * 0.25
		half.y *= 0.5
		emission_shape = EMISSION_SHAPE_BOX
		emission_box_extents = half
	else:
		var points := PackedVector3Array()
		var normals := PackedVector3Array()
		for i in maxi(type.count, 1):
			var angle := float(i) * 2.399963
			var out := Vector3(cos(angle), 0.0, sin(angle))
			points.append(
				Vector3(
					out.x * half.x,
					half.y * (2.0 * fposmod(float(i) * 0.618034, 1.0) - 1.0),
					out.z * half.z
				)
			)
			normals.append((out * spray_out + Vector3.UP * spray_up).normalized())
		direction = Vector3.RIGHT
		spread = 0.0
		var speed := Vector2(spray_out, spray_up).length()
		initial_velocity_min = speed
		initial_velocity_max = speed
		emission_shape = EMISSION_SHAPE_DIRECTED_POINTS
		emission_points = points
		emission_normals = normals
	global_position = center
