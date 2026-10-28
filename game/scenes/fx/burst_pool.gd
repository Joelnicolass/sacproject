class_name BurstPool
extends Node

## The emitters of the bursts (SpriteParticles), one small pool per ParticleType: a play reuses an
## idle emitter instead of instancing one, and when all of a type are playing the oldest starts
## over. The client builds every pool of data/fx (and its folders) when it loads, so a play never
## builds one (building draws from the global RNG, and it must happen before MatchSeed seeds the
## match). Never in a headless process.
## What it does not do: pick the effect or the place (FxBus), talk to the network, or sound.

const SPRITE_PARTICLES := preload("res://scenes/fx/sprite_particles.tscn")

## Emitters per type when its ParticleType has no `pool_max`.
@export_range(1, 256) var max_per_type: int = 12

## type -> Array[SpriteParticles] idle (hidden) / playing (oldest first). A type with no atlas is
## `_dead`: it never draws.
var _idle: Dictionary[ParticleType, Array] = {}
var _playing: Dictionary[ParticleType, Array] = {}
var _dead: Dictionary[ParticleType, bool] = {}


## Most emitters the pool keeps for the type (its `pool_max`, else `max_per_type`).
func cap_of(type: ParticleType) -> int:
	return type.pool_max if type != null and type.pool_max > 0 else max_per_type


## Plays `type` at `at` (a new emitter while under the cap, else the oldest). `dir` ZERO = the
## type's own direction.
func play(type: ParticleType, at: Vector3, burst_seed: int, dir: Vector3) -> void:
	var emitter := _take(type)
	if emitter != null:
		emitter.replay(at, burst_seed, dir)


## Builds every pool of data/fx and its folders up to its cap.
func prewarm_all() -> void:
	for found: Resource in FxWire.all_in(FxWire.PARTICLES_DIR):
		var type := found as ParticleType
		if type != null and _open(type):
			for i in cap_of(type):
				var emitter := _build(type)
				if emitter == null:
					break
				_idle[type].push_back(emitter)


## Warm-up (WarmHook in fx_bus.tscn): one burst of every type at `stage` for one drawn frame, then
## hidden. FxBus says nothing (no `played`: no sound, no shake); its own seed, so the global RNG is
## not drawn. The start gate pauses the tree while the world loads and a paused emitter never places
## its sprites (they stay at the world's origin, out of view, and nothing is drawn): the flashed
## emitters process meanwhile.
func flash_all(stage: Node3D) -> void:
	var shown: Array[SpriteParticles] = []
	for found: Resource in FxWire.all_in(FxWire.PARTICLES_DIR):
		var emitter := _take(found as ParticleType)
		if emitter != null:
			emitter.process_mode = Node.PROCESS_MODE_ALWAYS
			emitter.replay(stage.global_position, 0)
			shown.append(emitter)
	await RenderingServer.frame_post_draw
	for emitter in shown:
		emitter.emitting = false
		emitter.hide()
		emitter.process_mode = Node.PROCESS_MODE_INHERIT


func _take(type: ParticleType) -> SpriteParticles:
	if not _playing.has(type) and not _open(type):
		return null
	var idle: Array = _idle[type]
	var playing: Array = _playing[type]
	var emitter: SpriteParticles = null
	if not idle.is_empty():
		emitter = idle.pop_back()
	elif playing.size() < cap_of(type):
		emitter = _build(type)
		if emitter == null:
			return null
	else:
		emitter = playing.pop_front()
	playing.push_back(emitter)
	return emitter


func _open(type: ParticleType) -> bool:
	if type == null or type.lifetime_s <= 0.0 or _dead.has(type):
		return false
	if not _playing.has(type):
		_idle[type] = []
		_playing[type] = []
	return true


func _build(type: ParticleType) -> SpriteParticles:
	var emitter: SpriteParticles = SPRITE_PARTICLES.instantiate()
	emitter.type = type
	emitter.pooled = true
	emitter.name = (
		"%s_%d"
		% [FxWire.label_of(type), (_playing[type] as Array).size() + (_idle[type] as Array).size()]
	)
	add_child(emitter)
	if emitter.is_queued_for_deletion():
		# No atlas in the catalog: the type never draws, so it keeps no pool.
		_idle.erase(type)
		_playing.erase(type)
		_dead[type] = true
		return null
	emitter.finished.connect(_release.bind(type, emitter))
	return emitter


func _release(type: ParticleType, emitter: SpriteParticles) -> void:
	var playing: Array = _playing.get(type, [])
	var at := playing.find(emitter)
	if at < 0:
		return
	playing.remove_at(at)
	(_idle[type] as Array).push_back(emitter)
