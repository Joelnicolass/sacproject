@tool
class_name RedVortex
extends Node3D

## The red vortex the Sac Doctor falls out of (sacengine RedVortex, radius 2.5 m, state.d:15463-15543):
## a flat red ring with a glowing center that faces the camera (`disc`, vtx1 + vtx2, 2 s to open, 1 s
## to close) and drops that fall from under it (`effect`, vtx2). It exists from the start of the cast
## until the doctor comes out or the cast is interrupted; the SacrificeSystem spawns and frees it on
## the server and the spawner shows it on every peer. Only the drawing is here: the dedicated server
## draws nothing. When it is freed it leaves a closing copy of the ring behind (1 s).

const SPRITES := preload("res://scenes/fx/sprite_particles.tscn")

## The ring and its center (scenes/fx/portal_disc.tscn with data/fx/portal_red.tres).
@export var disc: PortalDisc
## One drop of the vortex (data/fx/red_vortex.tres): falls from the ring, 2 per tick in the original.
@export var effect: ParticleType
## Seconds between bursts of `effect.count` drops. Original: 2 drops per tick (120/s).
@export_range(0.01, 1.0, 0.0001, "suffix:s") var pulse_s := 0.0333
## Drops start once the ring is this open (state.d:15465: scale > 0.3).
@export_range(0.0, 1.0, 0.05) var drops_after := 0.3
## Where the drops come out under the center, as a fraction of the radius (state.d:15471: -0.8).
@export var drops_depth := 0.8
## The server frees it after this long if nobody did (a wizard freed mid-cast). 0 = never. Counted in ticks of the
## match (MatchClock.ticks_for, RFC-032 032d), not with the render delta.
@export var max_life_s := 0.0

var _pulse_left := 0.0
## Physics ticks lived (server or solo; a pause does not count, _physics_process does not run).
var _life_ticks := 0


func _ready() -> void:
	if Engine.is_editor_hint() or disc == null:
		return
	## The scene shows the ring open (for the editor); in play it emerges.
	disc.openness = 0.0
	disc.open()
	tree_exiting.connect(_leave_closing_ring)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if disc == null:
		warnings.append("Asigná en `disc` el PortalDisc rojo del vórtice.")
	if effect == null:
		warnings.append("Asigná en `effect` el ParticleType de las gotas (data/fx/red_vortex.tres).")
	return warnings


## Simulation: the lifetime, on the server only.
func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or max_life_s <= 0.0 or (MpKit.is_networked() and not MpKit.is_server()):
		return
	_life_ticks += 1
	if _life_ticks >= MatchClock.ticks_for(max_life_s):
		queue_free()


## Presentation: the drops (every peer that draws).
func _process(delta: float) -> void:
	if Engine.is_editor_hint() or is_queued_for_deletion():
		return
	_pulse_left -= delta
	if _pulse_left > 0.0:
		return
	_pulse_left = pulse_s
	_drops()


## Before the children leave the tree: a closing copy of the ring stays where it was.
func _leave_closing_ring() -> void:
	if Engine.is_editor_hint() or disc == null or not BodyCatalog.loads_meshes():
		return
	var tree := get_tree()
	if tree == null or tree.root == null or disc.openness <= 0.0:
		return
	## The node goes away at once: a copy of the ring stays at the same place and closes by itself.
	var ghost := disc.duplicate() as PortalDisc
	var at := global_transform * disc.transform
	var openness := disc.openness
	var host := tree.current_scene if tree.current_scene != null else tree.root
	host.add_child.call_deferred(ghost)
	ghost.ready.connect(func() -> void:
		ghost.global_transform = at
		ghost.openness = openness
		ghost.close(), CONNECT_ONE_SHOT)


func _drops() -> void:
	if effect == null or disc == null or DisplayServer.get_name() == "headless":
		return
	if disc.openness <= drops_after:
		return
	var emitter: SpriteParticles = SPRITES.instantiate()
	emitter.type = effect
	add_child(emitter)
	emitter.position = Vector3(0.0, -drops_depth * disc.radius.y * disc.openness, 0.0)
