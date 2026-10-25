extends Node

## Autoload FxBus. Plays ParticleType bursts by name (res://data/fx/<name>.tres) from a pool of
## SpriteParticles per type (RFC-029 029b): a play reuses an idle emitter instead of instancing one.
## RFC-052 052d (F363): every play, beam and scene emits `played` on the peer that draws it (also headless, before the
## headless guard, so an --audio-probe process hears it): FxSounds turns a burst or a beam into the `sound` of its type.
## Local only, never an RPC: a broadcast reaches every peer through the RPCs that already exist.

## What was played: `kind` is one of the KIND_* constants, `fx_name` the type name (a beam type, or the scene path for
## KIND_SCENE), `at` where (the middle of a beam).
signal played(kind: StringName, fx_name: String, at: Vector3)

## A burst of `play`.
const KIND_BURST := &"burst"
## A puff of a trail or of a repeated presentation (`play_puff`): many per second, never a sound of its own.
const KIND_PUFF := &"puff"
const KIND_BEAM := &"beam"
const KIND_SCENE := &"scene"

const SPRITE_PARTICLES := preload("res://scenes/fx/sprite_particles.tscn")
const TYPES_DIR := "res://data/fx/"

## Own generator for the particle seeds (RFC-029 029a, H1): a CPUParticles3D with a random seed
## draws it from the global RNG, the one MatchSeed seeds for the simulation. Constant seed, so two
## runs of the same lab draw the same sprites.
@export var particle_seed: int = 9529
## Emitters per type when its ParticleType has no `pool_max`. When all of a type are playing, the
## oldest one starts over.
@export_range(1, 256) var max_pooled_per_type: int = 12
## Builds every pool of data/fx up to its cap when the game loads. Building a CPUParticles3D draws
## from the global RNG; done here it happens before MatchSeed seeds the match, so a play never does.
@export var prewarm := true

## Own generator for the shapes of the beams (RFC-029 029d), apart from the particle seeds so a beam
## does not change which sprites a burst draws.
@export var beam_seed: int = 9829

var _types: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _beam_rng := RandomNumberGenerator.new()
## beam type name -> BeamType (or null).
var _beam_types: Dictionary = {}
## F151: scene path -> PackedScene (or null) of broadcast_scene.
var _scenes: Dictionary = {}
## beam type name -> Array[BeamFx] idle / playing (oldest first).
var _beam_idle: Dictionary = {}
var _beam_playing: Dictionary = {}
## type name -> Array[SpriteParticles] idle (hidden), ready for the next play.
var _idle: Dictionary = {}
## type name -> Array[SpriteParticles] playing, oldest first.
var _playing: Dictionary = {}


func _ready() -> void:
	_rng.seed = particle_seed
	_beam_rng.seed = beam_seed
	if prewarm and not _is_headless():
		_prewarm_all()


## The name FxBus knows a typed effect (ParticleType or BeamType loaded from data/fx/) by: a scene that holds the Resource passes
## `FxBus.name_of(type)` instead of writing the text.
static func name_of(type: Resource) -> String:
	return type.resource_path.get_file().get_basename() if type != null else ""


## Seed for the next emitter (SpriteParticles, SpriteEmitter): from this generator, never the global one.
func next_particle_seed() -> int:
	return _rng.randi()


## `dir` is not applied: the burst goes in its type's direction (it already did before the pool).
func play(type_name: String, at: Vector3, _dir := Vector3.UP) -> void:
	played.emit(KIND_BURST, type_name, at)
	_burst(type_name, at)


## A puff of a trail (FxTrail) or of a repeated presentation: drawn like `play`, but `played` says KIND_PUFF, so a type
## that also has a sound as a burst ("heal", "fire") does not sound thirty times a second.
func play_puff(type_name: String, at: Vector3) -> void:
	played.emit(KIND_PUFF, type_name, at)
	_burst(type_name, at)


func _burst(type_name: String, at: Vector3) -> void:
	if _is_headless():
		return
	var emitter := _take(type_name)
	if emitter == null:
		return
	emitter.replay(at, next_particle_seed())


func broadcast(type_name: String, at: Vector3, dir := Vector3.UP) -> void:
	if MpKit.is_networked():
		if MpKit.is_server():
			_play_everywhere.rpc(type_name, at, dir)
		return
	play(type_name, at, dir)


func particle_type(type_name: String) -> ParticleType:
	if not _types.has(type_name):
		var path := TYPES_DIR + type_name + ".tres"
		_types[type_name] = load(path) as ParticleType if ResourceLoader.exists(path) else null
	return _types[type_name]


## Most emitters FxBus keeps for the type (its `pool_max`, else `max_pooled_per_type`).
func pool_cap(type: ParticleType) -> int:
	return type.pool_max if type != null and type.pool_max > 0 else max_pooled_per_type


## An idle emitter of the type, a new one while under the cap, or the oldest playing one.
func _take(type_name: String) -> SpriteParticles:
	if not _playing.has(type_name) and not _open_pool(type_name):
		return null
	var idle: Array = _idle[type_name]
	var playing: Array = _playing[type_name]
	var emitter: SpriteParticles = null
	if not idle.is_empty():
		emitter = idle.pop_back()
	elif playing.size() < pool_cap(particle_type(type_name)):
		emitter = _build(type_name)
		if emitter == null:
			return null
	else:
		emitter = playing.pop_front()
	playing.push_back(emitter)
	return emitter


func _open_pool(type_name: String) -> bool:
	var type := particle_type(type_name)
	if type == null or type.lifetime_s <= 0.0:
		return false
	_idle[type_name] = []
	_playing[type_name] = []
	return true


func _build(type_name: String) -> SpriteParticles:
	var emitter: SpriteParticles = SPRITE_PARTICLES.instantiate()
	emitter.type = particle_type(type_name)
	emitter.pooled = true
	emitter.name = "%s_%d" % [type_name, (_playing[type_name] as Array).size() + (_idle[type_name] as Array).size()]
	add_child(emitter)
	if emitter.is_queued_for_deletion():
		## No atlas in the catalog: the type never draws, so it keeps no pool.
		_idle.erase(type_name)
		_playing.erase(type_name)
		_types[type_name] = null
		return null
	emitter.finished.connect(_release.bind(type_name, emitter))
	return emitter


func _release(type_name: String, emitter: SpriteParticles) -> void:
	var playing: Array = _playing.get(type_name, [])
	var at := playing.find(emitter)
	if at < 0:
		return
	playing.remove_at(at)
	(_idle[type_name] as Array).push_back(emitter)


func _prewarm_all() -> void:
	var dir := DirAccess.open(TYPES_DIR)
	if dir == null:
		return
	var names := PackedStringArray()
	for file in dir.get_files():
		var file_name := file.trim_suffix(".remap")
		if file_name.ends_with(".tres"):
			names.append(file_name.get_basename())
	names.sort()
	for type_name in names:
		if not _open_pool(type_name):
			continue
		var idle: Array = _idle[type_name]
		for i in pool_cap(particle_type(type_name)):
			var emitter := _build(type_name)
			if emitter == null:
				break
			idle.push_back(emitter)


static func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


@rpc("authority", "call_local", "unreliable")
func _play_everywhere(type_name: String, at: Vector3, dir: Vector3) -> void:
	play(type_name, at, dir)


const BEAM_TYPES_DIR := "res://data/fx/beams/"


## A bolt of the BeamType res://data/fx/beams/<type_name>.tres from `from` to `to` (RFC-029 029d).
## With `follow`, the end keeps its offset from that node while it lives. A type without `scene`
## gives only its flash at `to`.
func play_beam(type_name: String, from: Vector3, to: Vector3, follow: Node3D = null) -> void:
	played.emit(KIND_BEAM, type_name, from.lerp(to, 0.5))
	if _is_headless():
		return
	var type := beam_type(type_name)
	if type == null:
		return
	if type.scene == null:
		_beam_flash(type, to)
		return
	var beam := _take_beam(type_name, type)
	if beam != null:
		beam.play(from, to, _beam_rng.randi(), follow)


## One RPC per beam. `follow` travels as its path (the units have the same path on every peer).
func broadcast_beam(type_name: String, from: Vector3, to: Vector3, follow: Node3D = null) -> void:
	var path := str(follow.get_path()) if follow != null and follow.is_inside_tree() else ""
	if MpKit.is_networked():
		if MpKit.is_server():
			_play_beam_everywhere.rpc(type_name, from, to, path)
		return
	play_beam(type_name, from, to, follow)


func beam_type(type_name: String) -> BeamType:
	if not _beam_types.has(type_name):
		var path := BEAM_TYPES_DIR + type_name + ".tres"
		_beam_types[type_name] = load(path) as BeamType if ResourceLoader.exists(path) else null
	return _beam_types[type_name]


func _take_beam(type_name: String, type: BeamType) -> BeamFx:
	if not _beam_playing.has(type_name):
		_beam_idle[type_name] = []
		_beam_playing[type_name] = []
	var idle: Array = _beam_idle[type_name]
	var playing: Array = _beam_playing[type_name]
	var beam: BeamFx = null
	if not idle.is_empty():
		beam = idle.pop_back()
	elif playing.size() < type.pool_max:
		beam = type.scene.instantiate() as BeamFx
		if beam == null:
			return null
		beam.type = type
		beam.pooled = true
		beam.name = "beam_%s_%d" % [type_name, playing.size() + idle.size()]
		add_child(beam)
		beam.finished.connect(_release_beam.bind(type_name, beam))
	else:
		beam = playing.pop_front()
	playing.push_back(beam)
	return beam


func _release_beam(type_name: String, beam: BeamFx) -> void:
	var playing: Array = _beam_playing.get(type_name, [])
	var at := playing.find(beam)
	if at < 0:
		return
	playing.remove_at(at)
	(_beam_idle[type_name] as Array).push_back(beam)


## The flash alone (a BeamType without `scene`), from the rig's FxLightLayer like a burst's light.
func _beam_flash(type: BeamType, at: Vector3) -> void:
	if type.light != null:
		type.light.light_up(get_tree(), null, at)


@rpc("authority", "call_local", "unreliable")
func _play_beam_everywhere(type_name: String, from: Vector3, to: Vector3, follow_path: String) -> void:
	var follow: Node3D = null
	if not follow_path.is_empty():
		follow = get_tree().root.get_node_or_null(NodePath(follow_path)) as Node3D
	play_beam(type_name, from, to, follow)


## F151: a presentation scene played on every peer with its parameters, one RPC per event (not one per piece: the
## Rhinok's ring of spikes is one call). `scene_path` is a PackedScene whose root has play(params: Dictionary); it goes
## under the current scene at `at` and frees itself. Never headless.
func broadcast_scene(scene_path: String, at: Vector3, params: Dictionary) -> void:
	if MpKit.is_networked():
		if MpKit.is_server():
			_play_scene_everywhere.rpc(scene_path, at, params)
		return
	play_scene(scene_path, at, params)


func play_scene(scene_path: String, at: Vector3, params: Dictionary) -> void:
	played.emit(KIND_SCENE, scene_path, at)
	if _is_headless() or not scene_path.begins_with("res://"):
		return
	if not _scenes.has(scene_path):
		_scenes[scene_path] = load(scene_path) as PackedScene if ResourceLoader.exists(scene_path) else null
	var packed: PackedScene = _scenes[scene_path]
	var parent := get_tree().current_scene
	if packed == null or parent == null:
		return
	var node := packed.instantiate() as Node3D
	if node == null or not node.has_method("play"):  # dynamic: the root of any FX scene answers play(params)
		if node:
			node.free()
		return
	## Placed before it enters the tree: a SoundEmitter3D inside the scene plays where it is born.
	var parent_3d := parent as Node3D
	node.position = parent_3d.global_transform.affine_inverse() * at if parent_3d != null else at
	parent.add_child(node)
	node.global_position = at
	node.call("play", params)


@rpc("authority", "call_local", "unreliable")
func _play_scene_everywhere(scene_path: String, at: Vector3, params: Dictionary) -> void:
	play_scene(scene_path, at, params)
