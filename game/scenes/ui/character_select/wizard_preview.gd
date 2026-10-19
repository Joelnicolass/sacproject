extends SubViewportContainer

## The wizard of the character select, turning on a pivot. Each wizard is its BodyRig (the same skeletal body the match
## draws) resting on its idle clip.

const _RIG := preload("res://scenes/world/body/body_rig.tscn")

@export var spin_speed: float = 0.5
@export var model_height: float = 2.0
@export var model_rotation: Vector3 = Vector3.ZERO

@onready var _pivot: Node3D = %Pivot

var _shown: Dictionary = {}
var _model: String = ""


func _process(delta: float) -> void:
	_pivot.rotate_y(spin_speed * delta)


func show_wizard(wizard: WizardType) -> void:
	var model := wizard.model
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


## A holder with the BodyRig of the wizard under the pose BodyVisual gives it in the match, scaled to model_height.
func _build(wizard: WizardType) -> Node3D:
	var model := wizard.model
	if not BodyCatalog.has_skeletal(model):
		return null
	var rig := _RIG.instantiate() as BodyRig
	rig.model = model
	var holder := Node3D.new()
	holder.add_child(rig)
	var factor := model_height / maxf(float(BodyCatalog.info(model).get("height", model_height)), 0.01)
	var pose := BodyCatalog.pose(model, true, true)
	holder.transform = Transform3D(Basis.from_euler(model_rotation) * pose.basis.scaled(Vector3.ONE * factor), pose.origin * factor)
	return holder
