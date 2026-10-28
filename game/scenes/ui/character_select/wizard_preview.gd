extends SubViewportContainer

## The wizard of the character select, turning on a pivot. Each wizard is the look of his body scene (the same appearance the match
## draws) on a BodyRig, resting on its idle clip.

const _RIG := preload("res://scenes/bodies/body_rig.tscn")

@export var spin_speed: float = 0.5
@export var model_height: float = 2.0
@export var model_rotation: Vector3 = Vector3.ZERO

@onready var _pivot: Node3D = %Pivot

var _shown: Dictionary = {}
var _model: String = ""


func _process(delta: float) -> void:
	_pivot.rotate_y(spin_speed * delta)


func show_wizard(wizard: WizardType) -> void:
	var model := wizard.model_id()
	if model == _model:
		return
	_model = model
	for key: String in _shown:
		(_shown[key] as Node3D).visible = key == model
	if _shown.has(model) or model.is_empty():
		return
	var holder := _build(wizard)
	if holder == null:
		return
	_pivot.add_child(holder)
	_shown[model] = holder


## A holder with the BodyRig of the wizard, wearing his look, scaled to model_height. The look carries the pose the match gives it.
func _build(wizard: WizardType) -> Node3D:
	var facts := BodyFacts.of(wizard.body)
	var packed := BodyLook.of_body(wizard.body)
	var look := packed.instantiate() as BodyLook if packed != null else null
	if look == null or not look.has_model():
		if look != null:
			look.free()
		return null
	var rig := _RIG.instantiate() as BodyRig
	rig.mount(look)
	var holder := Node3D.new()
	holder.add_child(rig)
	var factor := model_height / maxf(facts.height_m, 0.01)
	holder.transform = Transform3D(
		Basis.from_euler(model_rotation).scaled(Vector3.ONE * factor), Vector3.ZERO
	)
	return holder
