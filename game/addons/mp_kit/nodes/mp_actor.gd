@tool
class_name MpActor
extends Node

## Drop one inside anything the network shares: a player, a bullet, a door. The server owns that node; what you
## tick under "Sync" reaches every peer (the synchronizer is built here, in the editor, and saved in the scene) and
## is smoothed there. `owner_slot` says which player owns it (0 = nobody, the server). Calls travel by name:
##   net.to_server(&"buy", item)  ->  mp_sv_buy(item)  runs on the server (only the owner may ask)
##   net.to_all(&"flash")         ->  mp_all_flash()   runs on every peer (only the server may send)
## Both methods live on this node's parent. Not: spawning (MpSpawner), input (MpInput), match state (MpState).

const SV_PREFIX := "mp_sv_"
const ALL_PREFIX := "mp_all_"
const SYNC_NAME := "MpSync"
## Largest argument list a client may send in one to_server call (var_to_bytes size).
const MAX_ARGS_BYTES := 4096

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
@export_group("Smoothing")
## Smooth position and rotation on the peers that only draw this node.
@export var smooth: bool = true
@export var smooth_speed: float = 14.0
@export var freeze_rigid_if_proxy: bool = true
@export_group("Owner")
## The player slot that owns this node (0 = the server). Spawners set it before the node enters the tree.
@export var owner_slot: int = 0

var _root: Node
var _smoother := MpSmoother.new()
var _sender_slot: int = -1
var _arity: Dictionary = {}


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
		return
	_root = get_parent()
	process_priority = 10000
	MpAuthority.claim_server(_root)
	if get_node_or_null(SYNC_NAME) == null and not sync_entries().is_empty():
		push_error("MpActor on '%s': no %s child. Open the scene in the editor and save it (the editor builds it)." % [_root.name, SYNC_NAME])
	if freeze_rigid_if_proxy:
		MpAuthority.freeze_rigid_proxy(_root)
	set_process(smooth and (sync_position or sync_rotation))


func _process(delta: float) -> void:
	if not MpKit.is_networked() or MpKit.is_server() or _root.is_multiplayer_authority():
		return
	_smoother.step(_root, delta, smooth_speed)


## True where the rules of this node run: solo or the server.
func is_authority() -> bool:
	return MpKit.is_authority()


## True on the machine of the player that owns this node.
func is_local() -> bool:
	return owner_slot > 0 and owner_slot == MpKit.local_slot()


## Inside an mp_sv_* call: the slot that asked (0 = the server itself). Elsewhere: -1.
func sender_slot() -> int:
	return _sender_slot


## Ask the server to run mp_sv_<action>(args...) on this node. Solo and the server run it at once.
func to_server(action: StringName, ...args: Array) -> void:
	if MpKit.is_authority():
		_run(SV_PREFIX, action, args, MpKit.local_slot())
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
	_run(ALL_PREFIX, action, args, 0)
	if not MpKit.is_networked():
		return
	for peer_id in multiplayer.get_peers():
		if _sees(peer_id):
			rpc_all_call.rpc_id(peer_id, action, args)


## What the synchronizer sends, from the inspector.
func sync_entries() -> PackedStringArray:
	var out := PackedStringArray()
	if sync_position:
		out.append("position")
	if sync_rotation:
		out.append("rotation")
	if sync_visible:
		out.append("visible")
	out.append_array(sync_extra)
	return out


@rpc("any_peer", "call_remote", "reliable")
func rpc_server_call(action: StringName, args: Array) -> void:
	if not multiplayer.is_server():
		return
	var slot := MpKit.slot_for_peer(multiplayer.get_remote_sender_id())
	if slot <= 0 or (owner_slot != 0 and slot != owner_slot):
		return
	if var_to_bytes(args).size() > MAX_ARGS_BYTES:
		return
	_run(SV_PREFIX, action, args, slot)


@rpc("authority", "call_remote", "reliable")
func rpc_all_call(action: StringName, args: Array) -> void:
	_run(ALL_PREFIX, action, args, 0)


func _run(prefix: String, action: StringName, args: Array, slot: int) -> void:
	var method := prefix + String(action)
	if not _accepts(method, args.size()):
		push_warning("MpActor '%s': no %s(%d args) on the parent" % [_root.name, method, args.size()])
		return
	_sender_slot = slot
	_root.callv(method, args)
	_sender_slot = -1


## The parent has `method` and it takes `count` arguments (defaults included).
func _accepts(method: String, count: int) -> bool:
	if not _arity.has(method):
		_arity[method] = Vector2i(-1, -1)
		for info in _root.get_method_list():
			if info["name"] == method:
				var total: int = info["args"].size()
				_arity[method] = Vector2i(total - info["default_args"].size(), total)
				break
	var range_ok: Vector2i = _arity[method]
	return range_ok.x >= 0 and count >= range_ok.x and count <= range_ok.y


func _sees(peer_id: int) -> bool:
	var sync := get_node_or_null(SYNC_NAME) as MultiplayerSynchronizer
	return sync == null or sync.public_visibility or sync.get_visibility_for(peer_id)


func _editor_rebuild() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		_rebuild_sync.call_deferred()


func _rebuild_sync() -> void:
	var scene := get_tree().edited_scene_root if is_inside_tree() else null
	if scene == null or owner != scene or get_parent() == null:
		return
	var self_path := String(get_parent().get_path_to(self)) + ":owner_slot"
	MpSyncBuilder.ensure(self, SYNC_NAME, NodePath("../.."), sync_entries(), PackedStringArray([self_path]), scene)
	update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	if get_parent() == null or owner == null:
		return PackedStringArray(["MpActor goes inside the node the network shares (not as a scene root)."])
	if get_node_or_null(SYNC_NAME) == null:
		return PackedStringArray(["Save the scene: the %s child is built in the editor." % SYNC_NAME])
	return PackedStringArray()
