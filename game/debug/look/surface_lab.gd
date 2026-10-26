extends Node3D

## Check of RFC-067 (F6): the pilot models in three rows under one grazing light and a fixed camera. Top row: copies of their
## materials as they were before any map (debug/look/surface_lab/flat/); middle row: the real materials, with their maps; bottom
## row: a petrified Trogg (StoneLook) and a house half risen (BuildReveal). `debug_light_turn` turns the light 30 degrees around,
## `debug_light_tilt` steps its height through `elevations_deg`: the relief of the middle row follows the light, the top row does not.
## Not: what a model looks like (its material .tres), how the maps are made (addons/surface_maps). The measured capture is
## agent/harness/surface_lab_capture.gd, the numbers tools/look/measure_relief.py.

@export var light: DirectionalLight3D
## Heights of the light over the horizon that `debug_light_tilt` steps through; the first one is the start (grazing).
@export var elevations_deg := PackedFloat32Array([15.0, 45.0, 75.0])
@export_range(1.0, 180.0, 1.0, "suffix:°") var yaw_step_deg := 30.0
## The petrified Trogg is a skeletal body: its rig wears this look (a skeleton is what StoneLook dresses with the shared materials).
@export var stone_rig: BodyRig
@export var stone_look: PackedScene

var _tilt := 0


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if light == null:
		warnings.append("Asigná `light` (la DirectionalLight3D rasante).")
	if stone_rig == null or stone_look == null:
		warnings.append("Asigná `stone_rig` y `stone_look` (el Trogg de piedra).")
	return warnings


func _ready() -> void:
	if stone_rig != null and stone_look != null:
		stone_rig.mount(stone_look.instantiate() as BodyLook)
	_aim()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_light_turn"):
		light.rotation_degrees.y = fposmod(light.rotation_degrees.y + yaw_step_deg, 360.0)
	elif event.is_action_pressed(&"debug_light_tilt"):
		_tilt = (_tilt + 1) % maxi(1, elevations_deg.size())
		_aim()


## The light's height over the horizon: the current step of `elevations_deg`.
func elevation_deg() -> float:
	return elevations_deg[_tilt] if not elevations_deg.is_empty() else 15.0


func _aim() -> void:
	if light != null:
		light.rotation_degrees.x = -elevation_deg()
