@tool
class_name GrowingRing
extends MeshInstance3D

## A flat ring that grows from nothing to `radius_m` while its SpellCarrier lingers (Blind Rage's
## blast: 30 m in 128 ticks, rising 7 m as it goes), wearing one cell of its atlas after another.
## The mesh is a quad of diameter 2 and the shader (ring.gdshader) cuts the ring out of it.
## Presentation only: every peer draws its own from the replicated phase, and a headless process
## none. It hurts nobody (TargetEffect does).

@export var carrier: SpellCarrier
@export_range(1.0, 100.0, 0.5, "suffix:m") var radius_m := 30.0
## It rises this much over its life (7 m: 3 m the blast climbs plus 4 m the ring is drawn higher). A
## flat ring at the eye level of a low camera looks like a thin red line across the screen; climbing
## the full 7 m takes it above the camera.
@export_range(0.0, 10.0, 0.1, "suffix:m") var rise_m := 7.0
@export_range(0.1, 10.0, 0.01, "suffix:s") var life_s := 2.1333
## The phase that makes it grow.
@export var during := SpellCarrier.Phase.LINGERING

var _age := -1.0
var _base := Vector3.ZERO


func _get_configuration_warnings() -> PackedStringArray:
	return (
		PackedStringArray()
		if carrier != null
		else PackedStringArray(["The SpellCarrier is missing."])
	)


## This moves by itself every frame, so physics interpolation must leave it alone.
func _init() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _ready() -> void:
	visible = false
	set_process(false)
	if Engine.is_editor_hint() or carrier == null or DisplayServer.get_name() == "headless":
		return
	top_level = true
	carrier.phase_changed.connect(_on_phase)
	set_process(true)


func _on_phase(now: SpellCarrier.Phase) -> void:
	if now == during and _age < 0.0:
		_age = 0.0
		_base = carrier.global_position
		visible = true


func _process(delta: float) -> void:
	if _age < 0.0:
		return
	_age += delta
	var progress := clampf(_age / life_s, 0.0, 1.0)
	global_position = _base + Vector3.UP * rise_m * progress
	scale = Vector3(radius_m * progress, 1.0, radius_m * progress)
	set_instance_shader_parameter(&"progress", progress)
	if progress >= 1.0:
		visible = false
		_age = -1.0
