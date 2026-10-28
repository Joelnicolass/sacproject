@tool
class_name PortalDisc
extends MeshInstance3D

## A flat ring with a glowing center that always faces the camera: the portal around a creature
## carried by a Sac Doctor (blue) and the red vortex the doctor falls out of.
## Presentation only: it reads no simulation and the headless server draws nothing. Opens in
## `open_s`, closes in `close_s` and then frees itself (`free_when_closed`). Remove the node to
## switch it off. The mesh and the material are made here (they are not stored in the scene).

## Finished closing (openness reached 0).
signal closed

@export var look: PortalLook:
	set(value):
		look = value
		_refresh()
## Radii in meters (x, y) when fully open. A flattened disc reads better (1.1 x 0.9).
@export var radius := Vector2(1.0, 1.0):
	set(value):
		radius = value
		_apply()
## Seconds from closed to open.
@export_range(0.05, 10.0, 0.05) var open_s := 1.0
## Seconds from open to closed.
@export_range(0.05, 10.0, 0.05) var close_s := 0.75
## 0 = closed, 1 = open. In the editor it is what you see.
@export_range(0.0, 1.0, 0.01) var openness := 1.0:
	set(value):
		openness = clampf(value, 0.0, 1.0)
		_apply()
@export var free_when_closed := true

var _target := 1.0
var _material: ShaderMaterial
var _missing := false
var _started := false
## Own generator seeded per instance: the global RNG is the match's (MatchSeed), a window-only
## effect must not move it.
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_started = true
	_rng.seed = hash(get_instance_id())
	_refresh()
	set_process(not Engine.is_editor_hint())


func _validate_property(property: Dictionary) -> void:
	if property.name == "mesh" or property.name == "material_override":
		property.usage &= ~PROPERTY_USAGE_STORAGE
		property.usage |= PROPERTY_USAGE_READ_ONLY


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if look == null:
		warnings.append(
			"Assign in `look` the PortalLook (data/fx/portal_blue.tres or portal_red.tres)."
		)
	elif _missing:
		(
			warnings
			. append(
				# gdlint: ignore=max-line-length
				"The PortalLook has no `rim` or `center` (the ring and centre textures): a fill is drawn."
			)
		)
	return warnings


## Opens from where it is.
func open() -> void:
	_target = 1.0
	visible = true


## Closes from where it is; frees itself when done if `free_when_closed`.
func close() -> void:
	_target = 0.0


func is_closing() -> bool:
	return _target <= 0.0


func _process(delta: float) -> void:
	if is_equal_approx(openness, _target):
		return
	var step := delta / (open_s if _target > openness else close_s)
	openness = move_toward(openness, _target, step)
	if _target <= 0.0 and openness <= 0.0:
		closed.emit()
		if free_when_closed:
			queue_free()


func _refresh() -> void:
	if not _started:
		return
	if not BodyLook.loads_meshes():
		visible = false
		return
	if mesh == null:
		var quad := QuadMesh.new()
		quad.size = Vector2(2.0, 2.0)
		mesh = quad
	_material = null
	_missing = false
	if look != null:
		_material = ShaderMaterial.new()
		_material.shader = preload("res://scenes/fx/portal_disc.gdshader")
		var rim := look.rim
		var center := look.center
		_missing = rim == null or center == null
		_material.set_shader_parameter("use_textures", not _missing)
		_material.set_shader_parameter("rim_tex", rim)
		_material.set_shader_parameter("center_tex", center)
		_material.set_shader_parameter("fallback_color", look.fallback_color)
		_material.set_shader_parameter("rim_energy", look.rim_energy)
		_material.set_shader_parameter("center_energy", look.center_energy)
		_material.set_shader_parameter("frame_s", look.frame_s)
		_material.set_shader_parameter("inner_ratio", look.inner_ratio)
		_material.set_shader_parameter("zigzag_repeats", look.zigzag_repeats)
		_material.set_shader_parameter("phase", _rng.randf_range(0.0, 0.5))
	material_override = _material
	_apply()
	update_configuration_warnings()


func _apply() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("half_size", radius)
	_material.set_shader_parameter("openness", openness)
