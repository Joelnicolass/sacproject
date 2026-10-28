class_name SpriteParticles
extends CPUParticles3D

## One-shot burst of atlas sprites. Frees itself when the burst ends, unless FxBus's BurstPool owns it.
## Its sprites fade out at the end of their life (ParticleType.alpha_ramp): with the type's own fade_s
## or over `tail_fade_s` when the type has none, so no sprite vanishes at full alpha. The type's
## alpha_max is not applied to a burst (it never was).

@export var type: ParticleType
## Owned by FxBus's BurstPool: it waits hidden for `replay` and hides again when the burst
## ends (`finished`) instead of freeing itself. Off = one burst on entering the tree, then queue_free.
@export var pooled := false
## Seconds at the end of each sprite's life over which its alpha goes to 0 when its ParticleType has no fade_s. 0 = the old hard end.
@export_range(0.0, 1.0, 0.01, "suffix:s") var tail_fade_s := 0.25


func _ready() -> void:
	if DisplayServer.get_name() == "headless" or type == null or type.lifetime_s <= 0.0:
		queue_free()
		return
	var material := FxAtlas.material_for(type)
	if material == null:
		queue_free()
		return
	_configure(material)
	if pooled:
		finished.connect(hide)
		hide()
		return
	finished.connect(queue_free)
	restart()
	_request_light()


## The pool's play: the same configured burst again, somewhere else. `dir` ZERO = the type's own direction; else the cone points that way.
## The scene has `use_fixed_seed` and restart keeps it, so replaying never draws from the global RNG.
func replay(at: Vector3, burst_seed: int, dir := Vector3.ZERO) -> void:
	seed = burst_seed
	position = at
	direction = dir if dir != Vector3.ZERO else type.direction
	show()
	restart(true)
	_request_light()


## The type's light from the rig's pool, keyed by this emitter: a pooled emitter that plays again
## (or is taken back while playing) restarts its own light at the new place instead of adding one.
func _request_light() -> void:
	if type.light != null and is_inside_tree():
		type.light.light_up(get_tree(), self, global_position)


func _configure(material: ShaderMaterial) -> void:
	one_shot = true
	explosiveness = 1.0
	local_coords = false
	amount = maxi(1, type.count)
	lifetime = type.lifetime_s
	spread = type.spread
	direction = type.direction
	initial_velocity_min = type.speed_min
	initial_velocity_max = type.speed_max
	gravity = Vector3(0.0, -type.gravity, 0.0)
	scale_amount_min = type.scale_min
	scale_amount_max = type.scale_max
	color_ramp = type.alpha_ramp(1.0, tail_fade_s)
	scale_amount_curve = type.scale_curve()
	if type.emission_radius > 0.0:
		emission_shape = EMISSION_SHAPE_SPHERE
		emission_sphere_radius = type.emission_radius
	var cycles := type.lifetime_s / maxf(type.cycle_s(), 0.001)
	anim_speed_min = cycles
	anim_speed_max = cycles
	anim_offset_max = 1.0 if type.random_start_frame else 0.0
	mesh = FxAtlas.quad_for(type)
	material_override = material
