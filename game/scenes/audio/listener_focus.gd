@tool
class_name ListenerFocus
extends AudioListener3D

## RFC-052 052c (F362): where the player hears from. The camera flies high over the field, so attenuating from it would
## make everything far; the listener sits on the local wizard (MatchWorld.local_wizard_changed) and turns with the camera,
## so left and right stay the screen's. Before the wizard arrives (or without one) it sits on the camera.
## With the AudioGate closed (dedicated, room server, headless) it does nothing. It is SoundBus.listener: the loops of the
## SoundEmitter3D nodes measure their range from it (052d).

## Emits `local_wizard_changed(wizard)` and answers `local_wizard()` (MatchWorld). Optional: the lab sets `target` instead.
@export var world: Node
@export var camera: Camera3D:
	set(value):
		camera = value
		update_configuration_warnings()
## The node it follows; the world sets it to the local wizard.
@export var target: Node3D
## Height over the target's origin (the head of a wizard).
@export_range(0.0, 10.0, 0.1, "suffix:m") var height_m := 1.6


func _ready() -> void:
	if Engine.is_editor_hint() or not AudioGate.is_open():
		set_process(false)
		return
	if world != null:
		if world.has_signal("local_wizard_changed"):
			world.connect("local_wizard_changed", _on_local_wizard_changed)
		if target == null and world is MatchWorld:
			target = (world as MatchWorld).local_wizard()
	make_current()
	SoundBus.listener = self
	_follow()


func _exit_tree() -> void:
	if not Engine.is_editor_hint() and SoundBus.listener == self:
		SoundBus.listener = null


func _process(_delta: float) -> void:
	_follow()


func _on_local_wizard_changed(wizard: Node3D) -> void:
	target = wizard


func _follow() -> void:
	if is_instance_valid(target) and target.is_inside_tree():
		global_position = target.global_position + Vector3.UP * height_m
	elif camera != null and camera.is_inside_tree():
		global_position = camera.global_position
	if camera != null and camera.is_inside_tree():
		global_basis = camera.global_basis


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if camera != null else PackedStringArray(["Asigná `camera`: el oyente gira con ella."])
