@tool
class_name SpriteEmitter
extends CPUParticles3D

## Continuous emitter of atlas sprites driven by a ParticleType `.tres` (rate, size, speed, fade).
## Presentation only: it never draws in a headless (dedicated) process. Runs in the editor
## (@tool, no autoloads); editing the type's numbers rebuilds it live.

## Relative change of the emission rate below which `set_rate` leaves the particle pool alone (resizing it drops the live sprites).
const RATE_STEP := 0.15

@export var type: ParticleType:
	set(value):
		if type != null and type.changed.is_connected(_apply):
			type.changed.disconnect(_apply)
		type = value
		if type != null and not type.changed.is_connected(_apply):
			type.changed.connect(_apply)
		if is_node_ready():
			_apply()
		update_configuration_warnings()
## Multiplies the sprite color (a Manalith tints its smoke with the side color).
@export var tint := Color.WHITE:
	set(value):
		tint = value
		color = tint

## Emits as soon as it enters the tree (also in the editor). `emitting` itself is not saved in the
## scene: CPUParticles3D reads its global transform when that flag loads, before it is in the tree.
@export var start_active := false

var _warned := false
var _active := false
## Particles per second asked by `set_rate`; negative = the type's own `rate_per_s`.
var _rate := -1.0
## The rate the pool was last sized for.
var _sized_rate := -1.0


func _ready() -> void:
	_take_seed()
	_apply()
	set_active(start_active)


## A set_active() that came while out of the tree (a Manalith released in its _exit_tree after the
## fount already left) is applied here.
func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		_apply_active()


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray(["The ParticleType is missing."]) if type == null else PackedStringArray()


## The only switch outside code should use: a dedicated process stays off. Out of the tree it only stores the state
## (turning CPUParticles3D on reads the global transform); entering the tree applies it.
func set_active(active: bool) -> void:
	_active = active
	if is_inside_tree():
		_apply_active()


func _apply_active() -> void:
	emitting = _active and _rate != 0.0 and not _is_headless()


## Emits `per_s` particles per second instead of the type's `rate_per_s` (a rate the game decides, like the Manahoar's, which
## follows the mana it gives). 0 stops; a negative value goes back to the type's. Only continuous types (rate_per_s > 0).
func set_rate(per_s: float) -> void:
	_rate = per_s if per_s < 0.0 else maxf(per_s, 0.0)
	_apply_active()
	if _rate <= 0.0 or type == null or type.rate_per_s <= 0.0 or not is_node_ready():
		return
	if _sized_rate > 0.0 and absf(_rate - _sized_rate) < _sized_rate * RATE_STEP:
		return
	_apply()


## What the state asks for; `emitting` is also off in a dedicated process.
func is_active() -> bool:
	return _active


## `energy_scale` > 1 brightens dark tints.
func set_tint(base: Color, energy_scale := 1.0) -> void:
	tint = Color(base.r * energy_scale, base.g * energy_scale, base.b * energy_scale, base.a)


## The scene has `use_fixed_seed`: the seed comes from FxBus's own generator, so emitting never
## draws from the global RNG the simulation uses. In the editor there is no FxBus.
func _take_seed() -> void:
	var bus := get_node_or_null(^"/root/FxBus")
	if bus != null and bus.has_method(&"next_particle_seed"):  # dynamic: FxBus is an autoload without a class_name, absent in the editor
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
			push_warning("SpriteEmitter: ParticleType has no atlas texture (assign `atlas`; sheets come from tools/import/import_ui.py).")
		return
	local_coords = false
	one_shot = type.rate_per_s <= 0.0
	explosiveness = 1.0 if one_shot else 0.0
	lifetime = type.lifetime_s
	lifetime_randomness = type.lifetime_randomness
	var rate := type.rate_per_s if _rate < 0.0 else _rate
	_sized_rate = rate
	amount = maxi(1, ceili(rate * type.lifetime_s) if type.rate_per_s > 0.0 else type.count)
	direction = type.direction
	spread = type.spread
	initial_velocity_min = type.speed_min
	initial_velocity_max = type.speed_max
	gravity = Vector3(0.0, -type.gravity, 0.0)
	scale_amount_min = type.scale_min
	scale_amount_max = type.scale_max
	if type.emission_radius > 0.0 or type.emission_height_m > 0.0:
		emission_shape = EMISSION_SHAPE_RING
		emission_ring_axis = Vector3.UP
		emission_ring_height = type.emission_height_m
		emission_ring_radius = type.emission_radius
		emission_ring_inner_radius = 0.0
	else:
		emission_shape = EMISSION_SHAPE_POINT
	var cycles := type.lifetime_s / maxf(type.cycle_s(), 0.001)
	anim_speed_min = cycles
	anim_speed_max = cycles
	anim_offset_max = 1.0 if type.random_start_frame else 0.0
	color_ramp = type.alpha_ramp(type.alpha_max)
	scale_amount_curve = type.scale_curve()
	mesh = FxAtlas.quad_for(type)
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var reach := type.speed_max * type.lifetime_s + type.size.x + type.emission_radius
	visibility_aabb = AABB(Vector3(-reach, -reach, -reach), Vector3(reach, reach, reach) * 2.0)
