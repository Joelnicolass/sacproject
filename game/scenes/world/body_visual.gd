@tool
class_name BodyVisual
extends MeshInstance3D

## Shows a baked body or prop from BodyCatalog. Feet on local y = 0.
## This node owns its mesh and its transform (the model pose): the editor saves neither.
## To place a model, move a parent Node3D, not this node.

## The model, its pose or its capsule were just applied (a new `model`, or an edit in pose_overrides.tres).
signal posed

## Built from the cache on every load, so the editor must not write them to the scene.
const _UNSAVED: PackedStringArray = ["mesh", "transform"]
const _LOCKED: PackedStringArray = ["mesh", "position", "rotation", "scale"]

@export var model := "":
	set(value):
		model = value
		_refresh_in_editor()
## Bodies lift by foot_offset. Buildings and plants keep the sacengine origin on the ground.
@export var stand_on_feet := true:
	set(value):
		stand_on_feet = value
		_refresh_in_editor()
@export var placeholder_height := 1.8

## The list of corrections this visual is listening to. After BodyCatalog.refresh() it is a new one.
var _watched: BodyPoseOverrides


func _validate_property(property: Dictionary) -> void:
	if property.name == "model":
		var tags := BodyCatalog.models()
		if tags.is_empty():
			return
		tags.sort()
		if not model.is_empty() and not tags.has(model):
			tags.append(model)
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(tags)
	elif Engine.is_editor_hint():
		if _UNSAVED.has(property.name):
			property.usage &= ~PROPERTY_USAGE_STORAGE
		if _LOCKED.has(property.name):
			property.usage |= PROPERTY_USAGE_READ_ONLY


func _ready() -> void:
	show_model(model)


func _enter_tree() -> void:
	_watch()


func _exit_tree() -> void:
	_unwatch()


func show_model(tag: String) -> void:
	model = tag
	_apply()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if model.is_empty():
		warnings.append("Elegí un modelo en `model` para ver este visual.")
	elif not BodyCatalog.has_model(model):
		warnings.append("El modelo «%s» no está en cache/baked (bodies.json / props.json). Se muestra el relleno." % model)
	return warnings


func body_height() -> float:
	return float(BodyCatalog.info(model).get("height", placeholder_height))


func body_radius() -> float:
	return float(BodyCatalog.info(model).get("radius", 0.35))


func _refresh_in_editor() -> void:
	if Engine.is_editor_hint() and is_node_ready():
		_apply()
		notify_property_list_changed()


func _apply() -> void:
	update_configuration_warnings()
	_watch()
	transform = BodyCatalog.pose(model, stand_on_feet)
	if BodyCatalog.loads_meshes():
		var baked := BodyCatalog.mesh(model)
		if baked:
			mesh = baked
		else:
			_placeholder()
	posed.emit()


## Redraws when pose_overrides.tres changes, so a correction shows without reloading the scene.
func _watch() -> void:
	var current := BodyCatalog.overrides()
	if current == _watched:
		return
	_unwatch()
	_watched = current
	_watched.changed.connect(_on_overrides_changed)


func _unwatch() -> void:
	if _watched and _watched.changed.is_connected(_on_overrides_changed):
		_watched.changed.disconnect(_on_overrides_changed)
	_watched = null


func _on_overrides_changed() -> void:
	if is_inside_tree():
		_apply()
		notify_property_list_changed()


func _placeholder() -> void:
	var capsule := CapsuleMesh.new()
	capsule.height = placeholder_height
	capsule.radius = minf(0.35, placeholder_height * 0.4)
	mesh = capsule
	transform = Transform3D(Basis.IDENTITY, Vector3(position.x, placeholder_height * 0.5, position.z))
