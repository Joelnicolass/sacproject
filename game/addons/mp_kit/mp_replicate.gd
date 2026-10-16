class_name MpReplicate
extends Node

## Child of a replicated actor. Server authority, sync props, freeze rigid proxies.
## Same code for listen-server and dedicated.

@export var actor: NodePath
## Properties Wire replication puts on the new synchronizer (spawn + always).
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
var _display_pos: Vector3 = Vector3.ZERO
var _net_pos: Vector3 = Vector3.ZERO
var _display_rot: float = 0.0
var _net_rot: float = 0.0
var _display_quat: Quaternion = Quaternion.IDENTITY
var _net_quat: Quaternion = Quaternion.IDENTITY
var _is_2d: bool = false
var _primed: bool = false


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
			"MpReplicate: '%s' has no MultiplayerSynchronizer. Add it in the scene (Project → Tools → MpKit: Wire replication on selection) or with MpAuthority.ensure_sync before add_child."
			% _target.name
		)
	if freeze_rigid_if_proxy:
		MpAuthority.freeze_rigid_proxy(_target)
	_is_2d = _target is Node2D
	set_process(interpolate)


func _process(delta: float) -> void:
	if not interpolate or _target == null:
		return
	if not MpKit.is_networked() or MpKit.is_server():
		return
	if _target.is_multiplayer_authority():
		return
	var alpha := 1.0 - exp(-interpolate_speed * delta)
	if _is_2d:
		_interp_2d(alpha)
	elif _target is Node3D:
		_interp_3d(alpha)


func _interp_2d(alpha: float) -> void:
	var n := _target as Node2D
	var live := n.position
	if not _primed:
		_display_pos = Vector3(live.x, live.y, 0.0)
		_net_pos = _display_pos
		_display_rot = n.rotation
		_net_rot = n.rotation
		_primed = true
		return
	if live.distance_squared_to(Vector2(_display_pos.x, _display_pos.y)) > 0.0000001:
		_net_pos = Vector3(live.x, live.y, 0.0)
		_net_rot = n.rotation
	_display_pos = _display_pos.lerp(_net_pos, alpha)
	_display_rot = lerp_angle(_display_rot, _net_rot, alpha)
	n.position = Vector2(_display_pos.x, _display_pos.y)
	n.rotation = _display_rot


func _interp_3d(alpha: float) -> void:
	var n := _target as Node3D
	if not _primed:
		_display_pos = n.position
		_net_pos = n.position
		_display_quat = n.quaternion
		_net_quat = n.quaternion
		_primed = true
		return
	if n.position.distance_squared_to(_display_pos) > 0.0000001:
		_net_pos = n.position
		_net_quat = n.quaternion
	_display_pos = _display_pos.lerp(_net_pos, alpha)
	_display_quat = _display_quat.slerp(_net_quat, alpha)
	n.position = _display_pos
	n.quaternion = _display_quat


func _has_sync(node: Node) -> bool:
	for child in node.get_children():
		if child is MultiplayerSynchronizer and child.name != MpSpawner.GATE_NAME:
			return true
	return false


func _resolve_target() -> Node:
	if actor.is_empty():
		return get_parent()
	return get_node_or_null(actor)
