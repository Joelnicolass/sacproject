@tool
class_name PrecipitationFall
extends Node3D

## Shows what falls from the sky (rain, snow) in the amount it is told: the drops around the camera (`Drops`, a
## GPUParticles3D under a FollowCamera) and the bed loop (`Bed`), louder the stronger it falls. It never decides when
## it rains: Weather tells it. Amount 0 = no emitter on and the bed stopped. The editor shows the drops, never the sound.

const EMITTER := &"weather"

@export var drops: GPUParticles3D
@export var bed: AudioStreamPlayer

var _look: PrecipitationLook
var _amount := 0.0
var _density := 1.0
var _cue: SoundCue
var _sound_open := false


func _ready() -> void:
	if not Engine.is_editor_hint() and bed != null and AudioGate.is_open() and SoundBus.can_play():
		_sound_open = true
		SoundBus.adopt_channel(bed)
	_apply(true)


## What falls (null = nothing) and how strong (0..1).
func show_fall(look: PrecipitationLook, amount: float) -> void:
	var new_look := look != _look
	_look = look
	_amount = clampf(amount, 0.0, 1.0)
	_apply(new_look)


## The quality preset's `rain_density_scale`.
func set_density(scale: float) -> void:
	if not is_equal_approx(scale, _density):
		_density = scale
		_apply(true)


## Warm-up: `look` falls at full for one drawn frame, silent, then what fell before falls again.
func flash(look: PrecipitationLook) -> void:
	if drops == null or look == null:
		return
	drops.process_material = look.process_material
	drops.draw_pass_1 = look.mesh
	drops.amount_ratio = 1.0
	drops.emitting = true
	await RenderingServer.frame_post_draw
	_apply(true)


func _apply(rebuild: bool) -> void:
	if drops:
		var count := roundi(_look.amount * _density) if _look else 0
		if rebuild and _look:
			drops.process_material = _look.process_material
			drops.draw_pass_1 = _look.mesh
			drops.lifetime = _look.lifetime_s
			if count > 0 and drops.amount != count:
				drops.amount = count
		drops.amount_ratio = _amount
		drops.emitting = count > 0 and _amount > 0.001
	_play_bed()


func _play_bed() -> void:
	if not _sound_open:
		return
	var cue := _look.sound if _look else null
	if cue == null or cue.is_silent() or _amount <= 0.001:
		bed.stop()
		_cue = null
		return
	if cue != _cue or not bed.playing:
		bed.stop()
		_cue = cue
		if not SoundBus.play_on(bed, cue, EMITTER, SoundEvent.BED):
			return
	# Written after play_on (which sets the cue's volume once) and only here.
	bed.volume_db = cue.volume_db + linear_to_db(_amount)


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if drops and bed else PackedStringArray(["Faltan los sockets Drops / Bed."])
