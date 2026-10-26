class_name MpReplicate
extends Node

## Child of a replicated actor. Server authority, sync props, freeze rigid proxies.
## Same code for listen-server and dedicated.

@export var actor: NodePath
## Properties the synchronizer of this actor should send (spawn + always). Informative: MpActor builds its own.
## The synchronizer must exist in the scene; this node does not create it at runtime.
@export var sync_properties: PackedStringArray = PackedStringArray([
	".:position",
	".:rotation",
	".:visible",
])
@export var freeze_rigid_if_proxy: bool = true
## Smooth proxy transforms between net updates. Off on the authority.
@export var interpolate: bool = true
@export var interpolate_speed: float = 14.0

var _target: Node
var _smoother := MpSmoother.new()


func _ready() -> void:
	process_priority = 10000
	_target = _resolve_target()
	if _target == null:
		push_warning("MpReplicate: no actor (parent or NodePath)")
		return
	MpAuthority.claim_server(_target)
	if not sync_properties.is_empty() and not _has_sync(_target):
		# A child cannot add a sibling here (the actor is still setting up its
		# children), and a later one would miss the spawn packet.
		push_error(
			"MpReplicate: '%s' has no MultiplayerSynchronizer. Add one in the scene (or use MpActor, which builds it) or call MpAuthority.ensure_sync before add_child."
			% _target.name
		)
	if freeze_rigid_if_proxy:
		MpAuthority.freeze_rigid_proxy(_target)
	set_process(interpolate)


func _process(delta: float) -> void:
	if not interpolate or _target == null:
		return
	if not MpKit.is_networked() or MpKit.is_server():
		return
	if _target.is_multiplayer_authority():
		return
	_smoother.step(_target, delta, interpolate_speed)


func _has_sync(node: Node) -> bool:
	for child in node.get_children():
		if child is MultiplayerSynchronizer and child.name != MpSpawner.GATE_NAME:
			return true
	return false


func _resolve_target() -> Node:
	if actor.is_empty():
		return get_parent()
	return get_node_or_null(actor)
