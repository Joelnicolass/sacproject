@tool
class_name BodyVisual
extends MeshInstance3D

## Shows a static prop from BodyCatalog (`model`), or the look of a creature or wizard (draw_look): the skeleton of an animated body is
## drawn by its BodyRig (`rig`) and has no mesh here, a hybrid's static mesh is this node's own mesh. Feet on local y = 0.
## This node owns its mesh and its transform (the model pose): the editor saves neither.
## To place a model, move a parent Node3D, not this node.

## The model, its pose or its capsule were just applied (a new `model`, or an edit in pose_overrides.tres).
signal posed

## Built from the assets on every load, so the editor must not write them to the scene.
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

## The skeletal body (BodyRig, RFC-023 023c) that hangs under this node and draws instead of the static mesh. It inherits
## this node's transform (the pose, the capsule scale, DevourGrowth). Set by the body's clip animator; null otherwise.
@export var rig: BodyRig
## The body scene this visual draws (BodyMount of the creature, wizard or doctor): `body_height` and `body_radius` come from there. Empty
## for a prop, which reads its size from the catalog.
@export var mount: BodyMount

## The list of corrections this visual is listening to. After BodyCatalog.refresh() it is a new one.
var _watched: BodyPoseOverrides
## The skeleton draws this model: this node keeps the pose and the measures, and no mesh of its own.
var _skeletal := false
## A BodyLook draws this body (a creature or a wizard): `model` and the catalog do not apply, `_apply` leaves the mesh alone.
var _look_drawn := false


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


## The look of a creature or wizard decides what this node shows: with a model the rig draws and this node's mesh goes away; a hybrid
## (no model) shows its static mesh here, in the pose of the look. Called by whoever listens to the rig (BodyAnimator).
func draw_look(look: BodyLook) -> void:
	_look_drawn = true
	_skeletal = look.has_model()
	mesh = null if _skeletal else look.static_mesh
	if not _skeletal:
		transform = look.transform
	posed.emit()


## GeometryInstance3D.transparency of the whole body, rig included (it does not inherit): summoning, play dead, stealth.
func set_fade(value: float) -> void:
	transparency = value
	if rig != null:
		rig.set_fade(value)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if model.is_empty():
		warnings.append("Elegí un modelo en `model` para ver este visual.")
	elif not BodyCatalog.has_model(model):
		warnings.append("El modelo «%s» no está en data/catalog/body_sizes/ (BodySize). Se muestra el relleno." % model)
	return warnings


## The real height of the body (its footprint), before the capsule floor.
func body_height() -> float:
	if mount != null:
		return mount.facts.height_m
	return float(BodyCatalog.info(model).get("height", placeholder_height))


## Half the width of the body (the raw radius of its footprint).
func body_radius() -> float:
	if mount != null:
		return mount.facts.radius_m
	return float(BodyCatalog.info(model).get("radius", 0.35))


func _refresh_in_editor() -> void:
	if Engine.is_editor_hint() and is_node_ready():
		_apply()
		notify_property_list_changed()


func _apply() -> void:
	update_configuration_warnings()
	if _look_drawn:
		return
	_watch()
	transform = BodyCatalog.pose(model, stand_on_feet, _skeletal)
	if BodyCatalog.loads_meshes() and not _skeletal:
		var found := BodyCatalog.mesh(model)
		if found:
			mesh = found
		elif BodyCatalog.has_skeletal(model) or (model.is_empty() and rig != null):
			mesh = null
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
