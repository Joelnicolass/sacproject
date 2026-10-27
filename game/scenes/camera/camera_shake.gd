@tool
class_name CameraShake
extends Node

## The camera's shake, a child of WorldCamera. It only computes; WorldCamera._place composes `offset()` and
## `roll()` on top of its own placement. Presentation only: no RPC, no sim writes, no global RNG (its own FastNoiseLite with a
## fixed seed). In a headless or dedicated process it does nothing (`run_headless` lets a check run it).
## - Trauma (0…1) from the hits to the local wizard (the `local_wizard` group): lost fraction × `wizard_hit_trauma_per_max`,
##   read from Health.changed (every peer has it), and from the `camera_trauma` of the FX near the camera (FxBus.played; `shake_map` gives the fall-off).
## - Trauma falls by `decay_per_s` a second. Offset = trauma² × `max_offset_m` × noise, roll = trauma² × `max_roll_deg` × noise,
##   both × FeelPrefs.shake_scale (0 = none, exactly).
## Ref: RFC-053 053f (F375).

## Group a check counts (see `is_active`).
const GROUP := &"feel_presentation"

@export var prefs: FeelPrefs
@export var shake_map: ShakeMap
## Where the FX distance is measured from (the camera). Empty: the parent.
@export var listener: Node3D
@export var max_offset_m := 0.35
@export var max_roll_deg := 1.5
@export var decay_per_s := 2.5
@export var noise_hz := 18.0
@export var wizard_hit_trauma_per_max := 2.0
@export var noise_seed := 5309
## Debug: run in a headless process too (the --feel-script check). The product leaves it off.
@export var run_headless := false

var trauma := 0.0
var _time := 0.0
var _noise := FastNoiseLite.new()
var _active := false
var _wizard: Node
var _wizard_health: Health
var _wizard_last := 0.0
var _looked_for_wizard := 0.0


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var prefs_warning := FeelPrefs.socket_warning(prefs)
	if not prefs_warning.is_empty():
		warnings.append(prefs_warning)
	if shake_map == null:
		warnings.append("Asigná `shake_map` (data/fx/shake_map.tres).")
	return warnings


func _ready() -> void:
	add_to_group(GROUP)
	_noise.seed = noise_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 1.0
	_active = not Engine.is_editor_hint() and (run_headless or ScreenGate.is_open())
	set_process(_active)
	if not _active:
		return
	if listener == null:
		listener = get_parent() as Node3D
	FxBus.played.connect(_on_fx_played)


## False in headless and dedicated processes (unless `run_headless`): nothing listens and the offset stays 0.
func is_active() -> bool:
	return _active


func add_trauma(amount: float) -> void:
	if _active and amount > 0.0:
		trauma = clampf(trauma + amount, 0.0, 1.0)


## Camera-local offset (x right, y up), meters.
func offset() -> Vector3:
	var amount := _amount()
	if amount <= 0.0:
		return Vector3.ZERO
	var t := _time * noise_hz
	var wobble := Vector3(_noise.get_noise_2d(t, 0.0), _noise.get_noise_2d(t, 100.0), 0.0).limit_length(1.0)
	return wobble * max_offset_m * amount


## Roll about the view axis, radians.
func roll() -> float:
	var amount := _amount()
	if amount <= 0.0:
		return 0.0
	return deg_to_rad(max_roll_deg) * amount * _noise.get_noise_2d(_time * noise_hz, 200.0)


## One step of `delta` seconds (the process calls it; a check may too).
func advance(delta: float) -> void:
	_time += delta
	trauma = maxf(trauma - decay_per_s * delta, 0.0)
	_follow_wizard(delta)


func _process(delta: float) -> void:
	advance(delta)


func _amount() -> float:
	if not _active or trauma <= 0.0:
		return 0.0
	var scale := prefs.shake_scale() if prefs else 1.0
	return trauma * trauma * scale if scale > 0.0 else 0.0


func _on_fx_played(kind: StringName, fx: Resource, at: Vector3) -> void:
	if shake_map == null or listener == null or not listener.is_inside_tree():
		return
	var from := listener.global_position
	var distance := Vector2(at.x - from.x, at.z - from.z).length()
	add_trauma(shake_map.trauma_of(kind, fx, distance))


## Keeps the local wizard's Health in sight (it spawns after the camera, or is replaced on a rejoin).
func _follow_wizard(delta: float) -> void:
	if _wizard != null and is_instance_valid(_wizard) and _wizard.is_in_group(&"local_wizard"):
		return
	_looked_for_wizard -= delta
	if _looked_for_wizard > 0.0 or not is_inside_tree():
		return
	_looked_for_wizard = 0.5
	_bind_wizard(get_tree().get_first_node_in_group(&"local_wizard"))


func _bind_wizard(wizard: Node) -> void:
	if _wizard_health != null and is_instance_valid(_wizard_health) and _wizard_health.changed.is_connected(_on_wizard_health):
		_wizard_health.changed.disconnect(_on_wizard_health)
	_wizard = wizard
	_wizard_health = wizard.get_node_or_null("Health") as Health if wizard else null
	if _wizard_health == null:
		return
	_wizard_last = _wizard_health.current
	_wizard_health.changed.connect(_on_wizard_health)


func _on_wizard_health(current: float, maximum: float) -> void:
	var lost := _wizard_last - current
	_wizard_last = current
	if lost > 0.0 and maximum > 0.0:
		add_trauma(lost / maximum * wizard_hit_trauma_per_max)

