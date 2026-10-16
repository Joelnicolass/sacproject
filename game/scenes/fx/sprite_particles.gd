class_name SpriteParticles
extends CPUParticles3D

## One-shot burst of atlas sprites. Frees itself when the burst ends, unless FxBus pools it.

@export var type: ParticleType
@export_file("*.json") var catalog_path: String = "res://cache/look/fx/fx.json"
## Owned by FxBus's pool (RFC-029 029b): it waits hidden for `replay` and hides again when the burst
## ends (`finished`) instead of freeing itself. Off = one burst on entering the tree, then queue_free.
@export var pooled := false


func _ready() -> void:
	if DisplayServer.get_name() == "headless" or type == null or type.lifetime_s <= 0.0:
		queue_free()
		return
	var material := _material_for(type, catalog_path)
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


## The pool's play: the same configured burst again, somewhere else, in the type's direction.
## The scene has `use_fixed_seed` and restart keeps it, so replaying never draws from the global RNG.
func replay(at: Vector3, burst_seed: int) -> void:
	seed = burst_seed
	position = at
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
	if type.emission_radius > 0.0:
		emission_shape = EMISSION_SHAPE_SPHERE
		emission_sphere_radius = type.emission_radius
	var cycles := type.lifetime_s / maxf(type.cycle_s(), 0.001)
	anim_speed_min = cycles
	anim_speed_max = cycles
	anim_offset_max = 1.0 if type.random_start_frame else 0.0
	mesh = _quad_for(type)
	material_override = material


static func atlas_texture(atlas_key: String, path: String) -> Texture2D:
	return FxAtlas.catalog_texture(atlas_key, path)


static func catalog_entry(atlas_key: String, path: String) -> Dictionary:
	return FxAtlas.catalog_entry(atlas_key, path)


static func _material_for(particle: ParticleType, path: String) -> ShaderMaterial:
	return FxAtlas.material_for(particle, path)


static func _quad_for(particle: ParticleType) -> QuadMesh:
	return FxAtlas.quad_for(particle)
