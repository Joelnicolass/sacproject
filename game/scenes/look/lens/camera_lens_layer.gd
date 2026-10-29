class_name CameraLensLayer
extends LookLayer

## The lens of the camera that draws the match: its field of view and its depth of field
## (LookQuality, group «Camera»). The focus follows the camera's subject (WorldCamera.follow), so
## the zoom moves it: past `dof_far_start` times the distance to the subject the land goes soft,
## and with `dof_near` what stands close to the lens too. A camera that follows nothing focuses at
## `fallback_focus_m`. Presentation only, never in the editor (the editor's camera is its own).

## Where the focus is when the camera follows no body.
@export_range(1.0, 500.0, 1.0, "suffix:m") var fallback_focus_m := 40.0

var _preset: LookQuality
var _attributes := CameraAttributesPractical.new()
var _camera: Camera3D


func _init() -> void:
	process_priority = 15001  # after the camera (15000), which it focuses


func _ready() -> void:
	set_process(not Engine.is_editor_hint())


func apply_quality(preset: LookQuality) -> void:
	_preset = preset
	if preset == null:
		return
	RenderingServer.camera_attributes_set_dof_blur_quality(preset.dof_quality, true)
	RenderingServer.camera_attributes_set_dof_blur_bokeh_shape(preset.dof_bokeh)


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != _camera:
		if is_instance_valid(_camera) and _camera.attributes == _attributes:
			_camera.attributes = null
		_camera = camera
	if _camera == null or _preset == null or not visible:
		return
	_camera.fov = _preset.field_of_view
	var focus := _focus_distance(_camera)
	var blur := _preset.depth_of_field
	_attributes.dof_blur_far_enabled = blur
	_attributes.dof_blur_near_enabled = blur and _preset.dof_near
	_attributes.dof_blur_amount = _preset.dof_blur_amount
	_attributes.dof_blur_far_distance = focus * _preset.dof_far_start
	_attributes.dof_blur_far_transition = focus * _preset.dof_far_transition
	_attributes.dof_blur_near_distance = focus * 0.5
	_attributes.dof_blur_near_transition = focus * 0.4
	if _camera.attributes != _attributes:
		_camera.attributes = _attributes


## Hidden (the layer off): the camera keeps its own lens.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible and is_instance_valid(_camera):
		if _camera.attributes == _attributes:
			_camera.attributes = null


func _focus_distance(camera: Camera3D) -> float:
	var subject := camera.get("follow") as Node3D
	if subject == null or not subject.is_inside_tree():
		return fallback_focus_m
	return maxf(camera.global_position.distance_to(DrawnPose.origin(subject)), 1.0)
