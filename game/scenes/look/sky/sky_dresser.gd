class_name SkyDresser
extends RefCounted

## What sky material the Environment's Sky wears for an atmosphere sample: the SkyLook's own material while the sample
## is neutral, else a private copy with the atmosphere's uniforms (SkyLook.write_atmosphere). It rewrites the copy at
## most `sky_hz` times a second, because every change re-bakes the reflection cubemap. EnvironmentLayer owns it and
## calls it; it writes nothing else. The shared `.tres` material is never touched.

var _copy: ShaderMaterial
var _written := AtmosphereSample.neutral()
var _written_ms := -100000
var _cloud_phase := 0.0


## Forget the copy (a new look, or its material was edited): the next dress makes it again.
func reset() -> void:
	_copy = null
	_cloud_phase = 0.0
	_written = AtmosphereSample.neutral()


## Puts the right material on `sky`. `force` skips the rate limit (a new look, a preset). `moon_dir_deg` = azimuth and
## elevation of the moon light.
func dress(sky: Sky, look: SkyLook, sample: AtmosphereSample, moon_dir_deg: Vector2, sky_hz: float, force: bool) -> void:
	var due := Time.get_ticks_msec() - _written_ms >= int(1000.0 / maxf(sky_hz, 0.1))
	if not force and (not due or sample.is_close(_written, 1e-3)):
		return
	_cloud_phase = _next_cloud_phase(look, sample)
	_written = sample
	_written_ms = Time.get_ticks_msec()
	if look.material == null or (sample.is_neutral(0.0) and _cloud_phase == 0.0):
		sky.sky_material = look.material
		return
	if _copy == null:
		_copy = look.material.duplicate() as ShaderMaterial
	look.write_atmosphere(_copy, sample, moon_dir_deg, _cloud_phase)
	sky.sky_material = _copy


## The drift is t / period * speed + phase: when the speed changes the phase takes the difference, so nothing jumps.
func _next_cloud_phase(look: SkyLook, sample: AtmosphereSample) -> float:
	if is_equal_approx(_written.cloud_speed_mul, sample.cloud_speed_mul):
		return _cloud_phase
	var period: Variant = look.material.get_shader_parameter(&"cloud_period_s") if look.material else null
	var t := Time.get_ticks_msec() / 1000.0  # close to the shader's TIME; an error only shifts the clouds by a hair
	return _cloud_phase + t / maxf(float(period) if period != null else 64.0, 1.0) * (_written.cloud_speed_mul - sample.cloud_speed_mul)
