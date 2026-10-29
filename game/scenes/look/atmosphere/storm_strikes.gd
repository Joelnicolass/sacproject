@tool
class_name StormStrikes
extends Node

## The storm's lightning, drawn on this screen. Weather tells it the ruling weather and the match
## second; it asks AtmosphereRules which strikes fell since the last time (the same instant, heading
## and distance from each player's camera on every peer), draws each one (a bolt and a flash with
## its light from the rig's pool, through FxBus), plays the thunder later by the distance (sound at
## 343 m/s) and says `struck(at)`. For a moment after a strike it gives the sky and the ambient
## their flash amount (never the glow). It never decides when lightning falls, does nothing in the
## editor and touches no simulation: a strike hurts nobody.

## A strike hit the ground at `at` (Weather says it again as `strike`).
signal struck(at: Vector3)

const SOUND_MPS := 343.0
const EMITTER := &"storm"
## A gap longer than this between two calls (a hitch, a rejoin) starts over from now: no backlog of
## old strikes.
const MAX_CATCH_UP_S := 2.0

## The bolt from the sky to the ground (`scenes/fx/effects/beams/storm_bolt.tres`).
@export var bolt: BeamType
## The flash on the ground, with its light (`scenes/fx/effects/storm_flash.tres`).
@export var flash: ParticleType
## The thunder (`scenes/audio/cues/thunder.tres`), heard `distance / 343` seconds after the flash.
@export var thunder: SoundCue
## How near and how far from the camera a strike falls.
@export_range(0.0, 2000.0, 1.0, "suffix:m") var min_strike_m: float = 150.0
@export_range(0.0, 2000.0, 1.0, "suffix:m") var max_strike_m: float = 600.0
## How high above the ground the bolt starts (the length of the bolt).
@export_range(10.0, 500.0, 1.0, "suffix:m") var bolt_top_m: float = 120.0
## Least time between two strikes (photosensitivity): no two flashes come closer than this.
@export_range(1.0, 30.0, 0.1, "suffix:s") var min_gap_s: float = 4.0
## How long the sky's flash lasts after a strike (at most 150 ms), and how strong it is (× the
## weather's `flash_strength`; the sky is 1 + this times brighter at the peak). 0 = no flash on the
## sky.
@export_range(0.02, 0.15, 0.005, "suffix:s") var flash_s: float = 0.12
@export_range(0.0, 1.0, 0.01) var flash_scale: float = 1.0

var _last_t := -1.0
var _flash_usec := -1
var _flash_peak := 0.0


## Draws the strikes of `state` that fell since the last call, up to match second `t_s`, and returns
## the sky's flash now.
func follow(state: WeatherState, sky_seed: int, t_s: float) -> float:
	if Engine.is_editor_hint():
		return 0.0
	var behind := _last_t < 0.0 or t_s < _last_t or t_s - _last_t > MAX_CATCH_UP_S
	var from_s := t_s if behind else _last_t
	_last_t = t_s
	if state != null and state.strikes_per_min > 0.0:
		var strikes := AtmosphereRules.strikes_between(
			sky_seed, from_s, t_s, state.strikes_per_min, min_gap_s, min_strike_m, max_strike_m
		)
		for strike in strikes:
			_strike(strike, state.flash_strength)
	return flash_now()


## No storm (the layer is hidden or has no look): forget where it was.
func quiet() -> void:
	_last_t = -1.0
	_flash_usec = -1


## The sky's flash now: the peak at the strike, down to 0 over `flash_s`.
func flash_now() -> float:
	if _flash_usec < 0:
		return 0.0
	var age := float(Time.get_ticks_usec() - _flash_usec) / 1000000.0
	return _flash_peak * (1.0 - age / flash_s) if age < flash_s else 0.0


## `strike` = (match second, heading_deg, distance_m) from AtmosphereRules.
func _strike(strike: Vector3, strength: float) -> void:
	_flash_usec = Time.get_ticks_usec()
	_flash_peak = clampf(strength * flash_scale, 0.0, 1.0)
	if DebugLog.on(&"atmosphere"):
		print("rayo t=%.2f rumbo=%.1f dist=%.0f" % [strike.x, strike.y, strike.z])
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		return
	var at := _ground(camera.global_position, strike.y, strike.z)
	FxBus.play_beam(bolt, Vector3(at.x, at.y + bolt_top_m, at.z), at)
	FxBus.play(flash, at)
	if thunder != null:
		get_tree().create_timer(strike.z / SOUND_MPS).timeout.connect(_thunder)
	struck.emit(at)


## The ground `distance_m` away from `from` toward `heading_deg` (0 = -Z, 90 = +X). Off the land:
## the height under `from`.
func _ground(from: Vector3, heading_deg: float, distance_m: float) -> Vector3:
	var angle := deg_to_rad(heading_deg)
	var at := Vector3(from.x + sin(angle) * distance_m, 0.0, from.z - cos(angle) * distance_m)
	var terrain := Terrain.of(self)
	var y := terrain.height_at(at.x, at.z) if terrain else NAN
	if is_nan(y):
		y = terrain.height_at(from.x, from.z) if terrain else 0.0
	at.y = y if not is_nan(y) else 0.0
	return at


func _thunder() -> void:
	SoundBus.play_2d(thunder, EMITTER, &"thunder")


func _get_configuration_warnings() -> PackedStringArray:
	var missing := PackedStringArray()
	if bolt == null:
		missing.append("Without Bolt the lightning is not seen (only the flash and the thunder).")
	if max_strike_m < min_strike_m:
		missing.append("Max Strike M has to be ≥ Min Strike M.")
	return missing
