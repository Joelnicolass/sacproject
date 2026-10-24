@tool
class_name WardEmitter
extends SpriteEmitter

## The sprites of a ward: a SpriteEmitter that follows its Ward (all the time it is on, or one burst when it starts or ends) and
## draws on the surface or inside of an ellipsoid around the body, so a bigger body gets a bigger shell. The ParticleType says what
## and how many; this only says where and when. Presentation only, on every peer, from the Ward's replicated `shown`.

enum When { WHILE_ON, WHEN_STARTS, WHEN_ENDS }

const POINTS := 192
const GOLDEN_ANGLE := 2.399963

@export var ward: Ward
@export var when := When.WHILE_ON
## Off: the emitter does nothing (an alternative look left in the scene for whoever wants to try it).
@export var enabled := true
## Half axes of the ellipsoid in metres, centred on this node (move the node with the gizmo to centre it on the body).
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


func _ready() -> void:
	super()
	if Engine.is_editor_hint() or ward == null:
		return
	ward.shown_changed.connect(_on_ward)
	if ward.shown:
		_on_ward(true)


func _on_ward(on: bool) -> void:
	if not enabled:
		return
	match when:
		When.WHILE_ON:
			set_active(on)
		When.WHEN_STARTS, When.WHEN_ENDS:
			if on == (when == When.WHEN_STARTS):
				set_active(true)
				restart()


## The sprites are born at the points of the ellipsoid (a Fibonacci spiral: the same on every peer, with no random draw).
func _apply() -> void:
	super()
	if type == null:
		return
	var points := PackedVector3Array()
	for i in POINTS:
		var height := 1.0 - 2.0 * (float(i) + 0.5) / float(POINTS)
		var ring := sqrt(1.0 - height * height)
		var angle := float(i) * GOLDEN_ANGLE
		var direction := Vector3(cos(angle) * ring, height, sin(angle) * ring)
		var depth := 1.0 if on_surface else pow(fposmod(float(i) * 0.618034, 1.0), 1.0 / 3.0)
		points.append(direction * half_axes_m * depth)
	emission_shape = EMISSION_SHAPE_POINTS
	emission_points = points
