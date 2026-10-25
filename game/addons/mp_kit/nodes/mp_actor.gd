@tool
class_name MpActor
extends Node

## Drop one inside anything the network shares: a player, a bullet, a door. The server owns that node; what you
## tick under "Sync" reaches every peer (the synchronizer is built here, in the editor, and saved in the scene) and
## is drawn smoothly there. `owner_slot` says which player owns it (0 = nobody, the server). Calls travel by name:
##   net.to_server(&"buy", item)  ->  mp_sv_buy(item)  runs on the server (only the owner may ask)
##   net.to_all(&"flash")         ->  mp_all_flash()   runs on every peer (only the server may send)
## With `predict`, movement goes in `mp_move(input, delta)`: the server runs it, and the owner runs it at once with
## its own keys and corrects itself from the server's state (reconciliation), so its node answers without lag.
## Not: spawning (MpSpawner), input (MpInput), match state (MpState).

enum Smoothing {
	NONE, ## draw each server state as it arrives
	FOLLOW, ## chase the newest state: no delay, small stutters when packets arrive unevenly
	BUFFERED, ## draw a little in the past between two real states: smooth under jitter (default)
}

const SV_PREFIX := "mp_sv_"
const ALL_PREFIX := "mp_all_"
const SYNC_NAME := "MpSync"
## Largest argument list a client may send in one to_server call (var_to_bytes size).
const MAX_ARGS_BYTES := 4096
## to_server calls a client may make, shared by every MpActor of the process (per second, and at once).
static var server_calls := MpRateLimit.new(60.0, 120.0)

@export_group("Sync")
@export var sync_position: bool = true:
	set(value):
		sync_position = value
		_editor_rebuild()
@export var sync_rotation: bool = true:
	set(value):
		sync_rotation = value
		_editor_rebuild()
@export var sync_visible: bool = false:
	set(value):
		sync_visible = value
		_editor_rebuild()
## More properties of the parent ("health") or of a node under it ("Health:current").
@export var sync_extra: PackedStringArray = PackedStringArray():
	set(value):
		sync_extra = value
		_editor_rebuild()
## Server states sent per second (0 = every frame). Lower saves bandwidth; BUFFERED smoothing hides the gaps.
@export_range(0, 120) var send_hz: int = 0:
	set(value):
		send_hz = value
		_editor_rebuild()
@export_group("Smoothing")
@export var smoothing: Smoothing = Smoothing.BUFFERED:
	set(value):
		smoothing = value
		_editor_rebuild()
## BUFFERED: how far in the past proxies are drawn. About two server states; more hides worse networks.
@export_range(0.0, 0.5, 0.01) var buffer_delay_s: float = 0.1
## FOLLOW: how fast proxies chase the newest state.
@export var follow_speed: float = 14.0
@export var freeze_rigid_if_proxy: bool = true
@export_group("Prediction")
## The owner moves at once (the parent's `mp_move(input, delta)`) and is corrected by the server.
@export var predict: bool = false:
	set(value):
		predict = value
		_editor_rebuild()
@export_group("Owner")
## The player slot that owns this node (0 = the server). Spawners set it before the node enters the tree.
@export var owner_slot: int = 0

## Server time of the state being sent (synced with it; 0 = none yet). Proxies and reconciliation read it.
var net_stamp: float = 0.0
## The server's pose of the parent (synced instead of the parent's own position / rotation when smoothing or
## predicting, so on a client only this node writes the parent's pose).
var net_position: Vector3 = Vector3.ZERO
var net_rotation: Quaternion = Quaternion.IDENTITY

var _root: Node
var _calls: MpCalls
var _motion: MpProxyMotion
var _prediction: MpPrediction
var _sender_slot: int = -1


## The MpActor child of `node`, or null.
static func of(node: Node) -> MpActor:
	if node == null:
		return null
	for child in node.get_children():
		if child is MpActor:
			return child as MpActor
	return null


func _enter_tree() -> void:
	_editor_rebuild()


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		set_physics_process(false)
		return
	_root = get_parent()
	_calls = MpCalls.new(_root)
	process_priority = 10000
	MpAuthority.claim_server(_root)
	if get_node_or_null(SYNC_NAME) == null and not sync_entries().is_empty():
		push_error("MpActor on '%s': no %s child. Open the scene in the editor and save it (the editor builds it)." % [_root.name, SYNC_NAME])
	if freeze_rigid_if_proxy:
		MpAuthority.freeze_rigid_proxy(_root)
	if predict and (not _root.has_method(&"mp_move") or input() == null):
		push_error("MpActor on '%s': predict needs an MpInput next to it and mp_move(input, delta) on the parent" % _root.name)
		predict = false
	if predict:
		_prediction = MpPrediction.new(_root, input())
	_motion = MpProxyMotion.new(_root, smoothing == Smoothing.BUFFERED)
	_motion.delay_s = buffer_delay_s
	_motion.follow_speed = follow_speed
	_motion.move_position = sync_position
	_motion.move_rotation = sync_rotation
	if is_authority():
		_publish_pose()
	elif uses_net_pose() and net_stamp > 0.0:
		_motion.snap(net_position, net_rotation)
		if _prediction:
			_prediction.start_at(net_position)


func _physics_process(delta: float) -> void:
	if is_authority():
		if _prediction:
			_prediction.server_tick(delta, is_local() or not MpKit.is_networked())
		_publish_pose()
	elif _prediction and is_local():
		_prediction.owner_tick(delta, net_stamp, _motion, net_position, net_rotation)


func _process(delta: float) -> void:
	if not MpKit.is_networked() or MpKit.is_server() or not uses_net_pose():
		return
	if not (predict and is_local()):
		_motion.draw(delta, net_stamp, net_position, net_rotation)


## True when the pose travels in net_position / net_rotation (smoothing or prediction) instead of the parent's own.
func uses_net_pose() -> bool:
	return smoothing != Smoothing.NONE or predict


## True where the rules of this node run: solo or the server.
func is_authority() -> bool:
	return MpKit.is_authority()


## Owner with prediction: how far the last server correction moved this node (0 = the prediction was right).
func last_correction() -> float:
	return _prediction.last_correction if _prediction else 0.0


## True on the machine of the player that owns this node.
func is_local() -> bool:
	return owner_slot > 0 and owner_slot == MpKit.local_slot()


## The MpInput next to this node, or null.
func input() -> MpInput:
	for child in get_parent().get_children():
		if child is MpInput:
			return child as MpInput
	return null


## Inside an mp_sv_* call: the slot that asked (0 = the server itself). Elsewhere: -1.
func sender_slot() -> int:
	return _sender_slot


## After a teleport or respawn: on a client, jump to the server's pose instead of sliding there.
func snap() -> void:
	if _motion and not is_authority():
		_motion.snap(net_position, net_rotation)


## Ask the server to run mp_sv_<action>(args...) on this node. Solo and the server run it at once.
func to_server(action: StringName, ...args: Array) -> void:
	if MpKit.is_authority():
		_run_sv(action, args, MpKit.local_slot())
		return
	if owner_slot != 0 and not is_local():
		push_warning("MpActor '%s': to_server(%s) from a peer that does not own it" % [_root.name, action])
		return
	rpc_server_call.rpc_id(MpAuthority.SERVER_PEER, action, args)


## Server only: run mp_all_<action>(args...) here and on every peer that has this node.
func to_all(action: StringName, ...args: Array) -> void:
	if not MpKit.is_authority():
		push_warning("MpActor '%s': to_all(%s) only runs on the server" % [_root.name, action])
		return
	_calls.run(ALL_PREFIX, action, args)
	if not MpKit.is_networked():
		return
	var sync := get_node_or_null(SYNC_NAME) as MultiplayerSynchronizer
	for peer_id in multiplayer.get_peers():
		if sync == null or sync.public_visibility or sync.get_visibility_for(peer_id):
			rpc_all_call.rpc_id(peer_id, action, args)


## What the synchronizer sends, from the inspector (MpActorSync builds it).
func sync_entries() -> PackedStringArray:
	return MpActorSync.entries(self)


@rpc("any_peer", "call_remote", "reliable")
func rpc_server_call(action: StringName, args: Array) -> void:
	if not multiplayer.is_server():
		return
	var slot := MpKit.slot_for_peer(multiplayer.get_remote_sender_id())
	if slot <= 0 or (owner_slot != 0 and slot != owner_slot):
		return
	if var_to_bytes(args).size() > MAX_ARGS_BYTES or not server_calls.allow(multiplayer.get_remote_sender_id()):
		return
	_run_sv(action, args, slot)


@rpc("authority", "call_remote", "reliable")
func rpc_all_call(action: StringName, args: Array) -> void:
	_calls.run(ALL_PREFIX, action, args)


func _run_sv(action: StringName, args: Array, slot: int) -> void:
	_sender_slot = slot
	_calls.run(SV_PREFIX, action, args)
	_sender_slot = -1


## Server: the stamp and pose the synchronizer sends this tick.
func _publish_pose() -> void:
	net_stamp = MpNetClock.stamp()
	net_position = MpProxyMotion.position_of(_root)
	net_rotation = MpProxyMotion.rotation_of(_root)


func _editor_rebuild() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		_rebuild_sync.call_deferred()


func _rebuild_sync() -> void:
	MpActorSync.rebuild(self)


func _get_configuration_warnings() -> PackedStringArray:
	if get_parent() == null or owner == null:
		return PackedStringArray(["MpActor goes inside the node the network shares (not as a scene root)."])
	if get_node_or_null(SYNC_NAME) == null:
		return PackedStringArray(["Save the scene: the %s child is built in the editor." % SYNC_NAME])
	if predict and not get_parent().has_method(&"mp_move"):
		return PackedStringArray(["Predict is on: the parent needs func mp_move(input: MpInput, delta: float)."])
	return PackedStringArray()
