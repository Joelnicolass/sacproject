extends Node

## The one door to every visual effect: a burst (ParticleType), a bolt (BeamType) or a scene
## (PackedScene with an FxScene root). `broadcast*` is what the server calls: one RPC with the id
## (FxWire) to each peer with its world loaded (MpKit.ready_peers), and here too; each draws it with
## its own pools (%Bursts, %Beams). `play*` draws on this peer only. Every play says `played(kind,
## fx, at)` first, also headless (FxSounds, CameraShake and the checks listen); a headless process
## then returns and instances nothing.
## What it does not do: keep the pools, turn ids into effects (FxWire), or decide who plays what.

## `kind` is a KIND_* constant, `fx` the ParticleType, BeamType or PackedScene, `at` where (the
## middle of a beam).
signal played(kind: StringName, fx: Resource, at: Vector3)

const KIND_BURST := &"burst"
## A puff of a trail or a repeated presentation: many per second, never a sound of its own.
const KIND_PUFF := &"puff"
const KIND_BEAM := &"beam"
const KIND_SCENE := &"scene"

## Own generator for the particle seeds (a random seed would draw the global RNG, the simulation's).
@export var particle_seed: int = 9529
## Own generator for the shapes of the beams.
@export var beam_seed: int = 9829
@export var prewarm := true  ## Builds every pool when the client loads (never headless).

var _rng := RandomNumberGenerator.new()
var _beam_rng := RandomNumberGenerator.new()

@onready var _bursts: BurstPool = %Bursts
@onready var _beams: BeamPool = %Beams


func _ready() -> void:
	_rng.seed = particle_seed
	_beam_rng.seed = beam_seed
	if prewarm and not _is_headless():
		_bursts.prewarm_all()
		_beams.prewarm_all()


## Seed for the next emitter (SpriteParticles, SpriteEmitter).
func next_particle_seed() -> int:
	return _rng.randi()


## A burst of `fx` at `at` on this peer. `dir` ZERO = the direction of its type.
func play(fx: ParticleType, at: Vector3, dir := Vector3.ZERO) -> void:
	_burst(KIND_BURST, fx, at, dir)


## A puff of a trail: like `play`, but `played` says KIND_PUFF (a puff never sounds).
func puff(fx: ParticleType, at: Vector3) -> void:
	_burst(KIND_PUFF, fx, at, Vector3.ZERO)


## `play` on every peer with a world (the server calls it; a client never does).
func broadcast(fx: ParticleType, at: Vector3, dir := Vector3.ZERO) -> void:
	if fx == null or _is_client():
		return
	for peer_id in MpKit.ready_peers():
		_play_everywhere.rpc_id(peer_id, FxWire.id_of(fx), at, dir)
	play(fx, at, dir)


## A bolt of `beam` from `from` to `to`. With `follow`, the end keeps its offset from that node
## while it lives.
func play_beam(beam: BeamType, from: Vector3, to: Vector3, follow: Node3D = null) -> void:
	if beam == null:
		return
	played.emit(KIND_BEAM, beam, from.lerp(to, 0.5))
	if not _is_headless():
		_beams.play(beam, from, to, _beam_rng.randi(), follow)


## `follow` travels as its path (the units have the same path on every peer).
func broadcast_beam(beam: BeamType, from: Vector3, to: Vector3, follow: Node3D = null) -> void:
	if beam == null or _is_client():
		return
	var path := str(follow.get_path()) if follow != null and follow.is_inside_tree() else ""
	for peer_id in MpKit.ready_peers():
		_play_beam_everywhere.rpc_id(peer_id, FxWire.id_of(beam), from, to, path)
	play_beam(beam, from, to, follow)


## A scene whose root is an FxScene, at `at`: it goes under the current scene, answers
## `play(params)` and frees itself. Never headless.
func play_scene(packed: PackedScene, at: Vector3, params: Dictionary) -> void:
	if packed == null:
		return
	played.emit(KIND_SCENE, packed, at)
	var parent := get_tree().current_scene
	if _is_headless() or parent == null:
		return
	var instance := packed.instantiate()
	var node := instance as FxScene
	if node == null:
		instance.free()
		push_error("FxBus: the root of %s is not an FxScene" % FxWire.label_of(packed))
		return
	var parent_3d := parent as Node3D
	node.position = parent_3d.global_transform.affine_inverse() * at if parent_3d != null else at
	parent.add_child(node)
	node.global_position = at
	node.play(params)


func broadcast_scene(packed: PackedScene, at: Vector3, params: Dictionary) -> void:
	if packed == null or _is_client():
		return
	for peer_id in MpKit.ready_peers():
		_play_scene_everywhere.rpc_id(peer_id, FxWire.id_of(packed), at, params)
	play_scene(packed, at, params)


func _burst(kind: StringName, fx: ParticleType, at: Vector3, dir: Vector3) -> void:
	if fx == null:
		return
	played.emit(kind, fx, at)
	if not _is_headless():
		_bursts.play(fx, at, next_particle_seed(), dir)


## A client never broadcasts; the server (or solo) sends to the peers with a world and plays here (a
## dedicated only says `played`).
static func _is_client() -> bool:
	return MpKit.is_networked() and not MpKit.is_server()


static func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


@rpc("authority", "call_local", "unreliable")
func _play_everywhere(id: String, at: Vector3, dir: Vector3) -> void:
	play(FxWire.resource(id) as ParticleType, at, dir)


@rpc("authority", "call_local", "unreliable")
func _play_beam_everywhere(id: String, from: Vector3, to: Vector3, follow_path: String) -> void:
	var follow: Node3D = null
	if not follow_path.is_empty():
		follow = get_tree().root.get_node_or_null(NodePath(follow_path)) as Node3D
	play_beam(FxWire.resource(id) as BeamType, from, to, follow)


@rpc("authority", "call_local", "unreliable")
func _play_scene_everywhere(id: String, at: Vector3, params: Dictionary) -> void:
	play_scene(FxWire.resource(id) as PackedScene, at, params)
