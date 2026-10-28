@tool
class_name LifeSpot
extends Node3D

## A place on the map where ambient life gathers (a meadow, a pond, a wood, rocks): drag `life_spot.tscn` under the
## map's `LifeSpots`, pick its habitat and scale the box of `OnScreen` with its gizmo. AmbientLifeLayer hands it the
## swarm of its habitat; it shows it inside its box, and only while the box is on screen. It never picks the swarm.

@export var habitat: AmbientLifeSet.Habitat = AmbientLifeSet.Habitat.MEADOW
## The box (its gizmo) and the on-screen test.
@export var on_screen: VisibleOnScreenEnabler3D
@export var swarm_particles: GPUParticles3D

var _swarm: AmbientSwarm
var _wanted := false
var _seen := false


func _ready() -> void:
	_seen = Engine.is_editor_hint()
	if on_screen:
		on_screen.screen_entered.connect(_on_seen.bind(true))
		on_screen.screen_exited.connect(_on_seen.bind(false))
	_update()


## Show `swarm` (null = nothing) with `density` (the preset's `life_density_scale`).
func show_swarm(swarm: AmbientSwarm, density: float) -> void:
	if swarm_particles == null:
		return
	var count := maxi(1, roundi(swarm.amount * density)) if swarm else swarm_particles.amount
	# Set up stopped, then restarted: a running emitter given another material or amount kept no uniform set.
	if swarm != _swarm or count != swarm_particles.amount:
		swarm_particles.emitting = false
		if swarm != _swarm and swarm:
			swarm_particles.process_material = _fitted(swarm.process_material)
			swarm_particles.draw_pass_1 = swarm.mesh
			swarm_particles.lifetime = swarm.lifetime_s
			if on_screen:
				swarm_particles.visibility_aabb = on_screen.aabb
		_swarm = swarm
		swarm_particles.amount = count
		swarm_particles.restart()
	_wanted = swarm != null and density > 0.0
	_update()


## True while its swarm is drawn (on screen and handed one).
func is_active() -> bool:
	return swarm_particles != null and swarm_particles.emitting


func _on_seen(seen: bool) -> void:
	_seen = seen
	_update()


func _update() -> void:
	if swarm_particles:
		swarm_particles.visible = _wanted
		swarm_particles.emitting = _wanted and _seen


## The swarm's motion with its emission box fitted to this spot's box (a copy: the shared `.tres` is never written).
func _fitted(motion: ParticleProcessMaterial) -> ParticleProcessMaterial:
	if motion == null or on_screen == null:
		return motion
	var fitted := motion.duplicate() as ParticleProcessMaterial
	fitted.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	fitted.emission_box_extents = on_screen.aabb.size * 0.5
	fitted.emission_shape_offset = on_screen.aabb.get_center()
	return fitted


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if on_screen and swarm_particles else PackedStringArray(["The On Screen / Swarm Particles sockets are missing."])
