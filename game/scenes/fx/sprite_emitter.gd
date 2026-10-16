@tool
class_name SpriteEmitter
extends CPUParticles3D

## Continuous emitter of atlas sprites driven by a ParticleType `.tres` (rate, size, speed, fade).
## Presentation only: it never draws in a headless (dedicated) process. Runs in the editor
## (@tool, no autoloads); editing the type's numbers rebuilds it live.

@export var type: ParticleType:
	set(value):
		if type != null and type.changed.is_connected(_apply):
			type.changed.disconnect(_apply)
		type = value
		if type != null:
			type.changed.connect(_apply)
		if is_node_ready():
			_apply()
		update_configuration_warnings()
## Multiplies the sprite color (the original tints Manalith smoke with the side color).
@export var tint := Color.WHITE:
	set(value):
		tint = value
		color = tint

## Emits as soon as it enters the tree (also in the editor). `emitting` itself is not saved in the
## scene: CPUParticles3D reads its global transform when that flag loads, before it is in the tree.
@export var start_active := false

var _warned := false
var _active := false


func _ready() -> void:
	_take_seed()
	_apply()
	set_active(start_active)


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray(["Falta el ParticleType."]) if type == null else PackedStringArray()


## The only switch outside code should use: a dedicated process stays off.
func set_active(active: bool) -> void:
	_active = active
	emitting = active and not _is_headless()


## What the state asks for; `emitting` is also off in a dedicated process.
func is_active() -> bool:
	return _active


## `energy_scale` > 1 brightens dark tints like sacengine's manaEnergy.
func set_tint(base: Color, energy_scale := 1.0) -> void:
	tint = Color(base.r * energy_scale, base.g * energy_scale, base.b * energy_scale, base.a)


## The scene has `use_fixed_seed`: the seed comes from FxBus's own generator, so emitting never
## draws from the global RNG the simulation uses (RFC-029 029a, H1). In the editor there is no FxBus.
func _take_seed() -> void:
	var bus := get_node_or_null(^"/root/FxBus")
	if bus != null and bus.has_method(&"next_particle_seed"):
		seed = bus.next_particle_seed()


func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _apply() -> void:
	if type == null or _is_headless():
		emitting = false
		return
	var material := FxAtlas.material_for(type)
	if material == null:
		emitting = false
		if not _warned:
			_warned = true
			push_warning("SpriteEmitter: atlas '%s' is not in the cache (run tools/export_particles.py)." % type.atlas_key)
		return
	local_coords = false
	one_shot = type.rate_per_s <= 0.0
	explosiveness = 1.0 if one_shot else 0.0
	lifetime = type.lifetime_s
	lifetime_randomness = type.lifetime_randomness
	amount = maxi(1, ceili(type.rate_per_s * type.lifetime_s) if type.rate_per_s > 0.0 else type.count)
	direction = type.direction
	spread = type.spread
	initial_velocity_min = type.speed_min
	initial_velocity_max = type.speed_max
	gravity = Vector3(0.0, -type.gravity, 0.0)
	scale_amount_min = type.scale_min
	scale_amount_max = type.scale_max
	if type.emission_radius > 0.0:
		emission_shape = EMISSION_SHAPE_RING
		emission_ring_axis = Vector3.UP
		emission_ring_height = 0.0
		emission_ring_radius = type.emission_radius
		emission_ring_inner_radius = 0.0
	else:
		emission_shape = EMISSION_SHAPE_POINT
	var cycles := type.lifetime_s / maxf(type.cycle_s(), 0.001)
	anim_speed_min = cycles
	anim_speed_max = cycles
	anim_offset_max = 1.0 if type.random_start_frame else 0.0
	color_ramp = _alpha_ramp()
	scale_amount_curve = _scale_curve()
	mesh = FxAtlas.quad_for(type)
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var reach := type.speed_max * type.lifetime_s + type.size.x + type.emission_radius
	visibility_aabb = AABB(Vector3(-reach, -reach, -reach), Vector3(reach, reach, reach) * 2.0)


## sacengine getAlpha: min(alpha_max, (time_left / fade_s)^2) over the normalised life.
func _alpha_ramp() -> Gradient:
	var ramp := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for i in 13:
		var t := float(i) / 12.0
		var left := type.lifetime_s * (1.0 - t)
		var alpha := type.alpha_max
		if type.fade_s > 0.0:
			alpha = minf(type.alpha_max, pow(left / type.fade_s, 2.0))
		offsets.append(t)
		colors.append(Color(1.0, 1.0, 1.0, alpha))
	ramp.offsets = offsets
	ramp.colors = colors
	return ramp


## sacengine getScale: min(1, time_left / scale_fade_s).
func _scale_curve() -> Curve:
	if type.scale_fade_s <= 0.0:
		return null
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, minf(1.0, type.lifetime_s / type.scale_fade_s)))
	var knee := 1.0 - type.scale_fade_s / type.lifetime_s
	if knee > 0.0:
		curve.add_point(Vector2(knee, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	return curve
