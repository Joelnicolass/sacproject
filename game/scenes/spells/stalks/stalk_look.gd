@tool
class_name StalkLook
extends MeshInstance3D

## What a stalk looks and sounds like on every peer: the tube laid on the curve from the root to the tip (the shader does the rings; this
## hands it the eight control points each tick), the dirt that flies where it is born, the burst and sound at a catch and the sound of the
## fall (its light is a StateLight of the scene that follows the zone). Presentation only; it reads the stalk's replicated `tip`, `growth` and `mode` and
## writes nothing of the game. A dedicated server or a headless run draws nothing.

@export var stalk: Stalk
## Dirt that flies off the root when the stalk is born.
@export var dirt: ParticleType
## What flies off the tip at a catch (with the light of a burst).
@export var grab_burst: ParticleType
## The scar the root leaves on the ground when the stalk is born (every peer paints it).
@export var scar: ScarMark
@export var grab_sound: SoundEmitter3D
@export var fall_sound: SoundEmitter3D

var _frame := Vector3.ONE
var _points := PackedVector3Array()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if LookRig.is_presentationless():
		set_physics_process(false)
		return
	_points.resize(8)
	if stalk != null:
		stalk.mode_changed.connect(_on_mode)
		if dirt != null:
			FxBus.play(dirt, stalk.global_position)
		if scar != null:
			scar.mark()


func _physics_process(_delta: float) -> void:
	if stalk == null:
		return
	var base := stalk.global_position + Vector3.DOWN * ((1.0 - stalk.growth) * stalk.height_m)
	var curve := StalkRules.curve(base, stalk.tip, _frame)
	_frame = curve[8]
	for i in 8:
		_points[i] = curve[i] - global_position
	(material_override as ShaderMaterial).set_shader_parameter("pts", _points)
	visible = stalk.growth > 0.001


func _on_mode(mode: int) -> void:
	if mode == Stalk.Mode.HOLDING:
		if grab_sound != null:
			grab_sound.play_once()
		if grab_burst != null:
			FxBus.play(grab_burst, stalk.tip)
	elif mode == Stalk.Mode.SHRINKING:
		if fall_sound != null:
			fall_sound.play_once()


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if stalk != null else PackedStringArray(["The stalk (Stalk) it draws is missing."])
