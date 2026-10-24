class_name BodyBoxLook
extends MeshInstance3D

## A translucent box around a body while one of its states is on, the size of the body's hit box, that grows from nothing and vanishes at
## once when the state ends (Freeze's ice). It does not decide when the state is on (Affliction) nor break into shards (Frozen).
## It is not turned with the body: it stays aligned to the world, as the box of the original. Presentation only, on every peer, from the
## replicated mask. The mesh and the material are the scene's: a BoxMesh of 1 m and a material to tune in the editor.
## Ref: sacengine Freeze (state.d:3037-3045, renderer.d:2183-2207).

## The state that shows it.
@export var affliction: Affliction
## The body whose box it takes.
@export var body: Node3D
## Ticks it takes to grow to the full box.
@export_range(1, 300) var grow_ticks := 30

var _grown := 0.0


func _ready() -> void:
	top_level = true
	visible = false
	set_process(false)
	if Engine.is_editor_hint() or affliction == null:
		return
	affliction.shown_changed.connect(_on_shown)
	if affliction.is_on():
		_on_shown(true)


func _on_shown(on: bool) -> void:
	_grown = 0.0
	visible = on
	set_process(on)
	if on:
		_fit()


func _process(delta: float) -> void:
	_grown = minf(1.0, _grown + delta * MatchClock.TICKS_PER_SECOND_F / float(grow_ticks))
	_fit()


## The box of the body now, scaled by how much it has grown, centred on it.
func _fit() -> void:
	if body == null:
		return
	var box := BodyNudge.box(body)
	global_transform = Transform3D(Basis.from_scale(box.size * maxf(_grown, 0.001)), box.get_center())


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if affliction == null or body == null:
		warnings.append("Faltan affliction y body.")
	return warnings
