class_name MpSpawner
extends MultiplayerSpawner

## Native MultiplayerSpawner that holds spawn + sync per peer until that peer
## has this spawner in its tree.
##
## Engine rules this works around (Godot 4):
## - A spawned node reaches a peer once ANY of its synchronizers is visible to
##   it; a node with no synchronizer reaches every peer, even one on the lobby.
## - The spawner and every non-spawned synced node are addressed by path. If the
##   first packet arrives while the peer lacks that node, the path fails and the
##   engine never retries: that spawner (or static node) stays dead for the peer.
## - The spawn packet lists the synchronizers the node has when it is sent.
##
## Scope: the synchronizers this spawner owns are held, spawned actors and
## static world nodes alike. A synchronizer belongs to the spawners whose parent
## is its nearest ancestor with MpSpawner children (rooms, sub-worlds); one with
## no such ancestor (a static node beside the world) belongs to every MpSpawner
## of the scene. Everything under spawn_path belongs to this spawner.
##
## Server: held synchronizers are hidden; a peer is revealed when its copy of
## this spawner reports ready (and, with room_id, while it is seated there).
## Client: reports ready on its own (deferred) and asks MpKit for world_ready.
## Cost (server): one walk of the scene per reveal / seat change, and a type
## check per node added to the tree (only synchronizers do more). Nothing per frame.

const GATE_NAME := "MpSpawnGate"

@export var extra_scenes: Array[PackedScene] = []
## Hold spawn/sync per peer until that peer's copy of this spawner is ready.
## Turn off only if every peer already has this scene when anything spawns.
@export var hold_until_world_ready: bool = true
## The engine sends a node with no MultiplayerSynchronizer to every peer, and the
## failed path breaks this spawner for that peer. Such actors get an empty
## synchronizer named GATE_NAME on every peer as they enter spawn_path.
@export var gate_unsynced_spawns: bool = true
## Hub rooms: reveal only to peers seated in this room (MpKit.rooms). Empty = every
## ready peer. Usually set by glue at runtime, on the server.
@export var room_id: StringName = &"":
	set(value):
		if room_id == value:
			return
		room_id = value
		_refresh_all()

var _root: Node
var _ready_peers: Dictionary = {}
var _entering: Array[Node] = []
var _warned: Dictionary = {}


func _ready() -> void:
	for scene in extra_scenes:
		if scene == null:
			continue
		var path := scene.resource_path
		if path.is_empty():
			continue
		add_spawnable_scene(path)

	if spawn_path.is_empty() or spawn_path == NodePath("."):
		push_warning("MpSpawner '%s': set spawn_path to the parent of replicated actors" % name)
		return

	_root = get_node_or_null(spawn_path)
	if _root == null:
		push_warning("MpSpawner '%s': spawn_path does not resolve" % name)
		return

	if not MpKit.is_networked() or not hold_until_world_ready:
		return

	_root.child_entered_tree.connect(_on_child_entered)
	if not MpKit.is_server():
		_report_ready.call_deferred()
		return

	for sync in _held_syncs():
		_hold(sync)
	get_tree().node_added.connect(_on_node_added)
	MpKit.peer_left.connect(_on_peer_left)
	if MpKit.rooms:
		MpKit.rooms.peer_seated.connect(_on_seat_changed)
		MpKit.rooms.peer_unseated.connect(_on_seat_changed)


func _exit_tree() -> void:
	if _root and _root.child_entered_tree.is_connected(_on_child_entered):
		_root.child_entered_tree.disconnect(_on_child_entered)
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	if MpKit.peer_left.is_connected(_on_peer_left):
		MpKit.peer_left.disconnect(_on_peer_left)
	if MpKit.rooms:
		if MpKit.rooms.peer_seated.is_connected(_on_seat_changed):
			MpKit.rooms.peer_seated.disconnect(_on_seat_changed)
		if MpKit.rooms.peer_unseated.is_connected(_on_seat_changed):
			MpKit.rooms.peer_unseated.disconnect(_on_seat_changed)


## Server (or solo) only: instance `scene` under spawn_path with `props` set first ({"position": p, ...}),
## and the MpActor owner when `owner_slot` > 0. The scene must be in this spawner's list (Extra Scenes or the
## Auto Spawn List): every peer needs the same list, so it cannot be added only here at runtime.
func spawn_actor(scene: PackedScene, props: Dictionary = {}, owner_slot: int = 0) -> Node:
	if not MpKit.is_authority():
		push_warning("MpSpawner '%s': spawn_actor() only runs on the server" % name)
		return null
	if scene == null or _root == null:
		return null
	if not _lists(scene.resource_path):
		push_error("MpSpawner '%s': add %s to Extra Scenes" % [name, scene.resource_path])
		return null
	var node := scene.instantiate()
	for key in props:
		node.set(key, props[key])
	var net := MpActor.of(node)
	if net and owner_slot > 0:
		net.owner_slot = owner_slot
	_root.add_child(node, true)
	return node


func _lists(path: String) -> bool:
	for i in get_spawnable_scene_count():
		if get_spawnable_scene(i) == path:
			return true
	return false


## True on the server once `peer_id` has this spawner and may see its actors.
func is_revealed_to(peer_id: int) -> bool:
	if not _ready_peers.has(peer_id):
		return false
	if room_id == &"":
		return true
	return MpKit.rooms != null and MpKit.rooms.room_id_for_peer(peer_id) == room_id


func _report_ready() -> void:
	if not is_inside_tree() or not MpKit.is_networked() or MpKit.is_server():
		return
	MpKit.request_world_ready()
	rpc_spawner_ready.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func rpc_spawner_ready() -> void:
	if not multiplayer.is_server() or not hold_until_world_ready:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if _ready_peers.has(peer_id):
		return
	_ready_peers[peer_id] = true
	_refresh(peer_id)


## Runs on every peer as an actor enters spawn_path, before its children do.
## The gate takes the same place in the spawn packet on server and client.
func _on_child_entered(node: Node) -> void:
	if node.get_parent() != _root:
		return
	if MpKit.is_server() and not node.is_node_ready():
		# Synchronizers the actor adds while it sets up (_enter_tree, _ready) still
		# go in its spawn packet; later ones do not.
		if not _entering.has(node):
			_entering.append(node)
		var done := _entering.erase.bind(node)
		for sig: Signal in [node.ready, node.tree_exited]:
			if not sig.is_connected(done):
				sig.connect(done, CONNECT_ONE_SHOT)
	if gate_unsynced_spawns and _syncs_under(node).is_empty():
		var gate := MultiplayerSynchronizer.new()
		gate.name = GATE_NAME
		gate.replication_config = SceneReplicationConfig.new()
		node.add_child(gate)
	if not MpKit.is_server():
		return
	for sync in _syncs_under(node):
		_hold(sync)


## Every synchronizer entering this spawner's scope is held before the engine
## can send anything for it. One added after its actor was set up is held too
## (so it cannot break this spawner for peers on the lobby), and reported.
func _on_node_added(node: Node) -> void:
	if not node is MultiplayerSynchronizer or not _owns(node):
		return
	var sync := node as MultiplayerSynchronizer
	var actor := _actor_of(sync)
	if actor and not _entering.has(actor):
		_warn_late(sync)
	_hold(sync)


func _on_peer_left(peer_id: int, _slot: int) -> void:
	# The replication interface already dropped the peer: its visibility is gone.
	_ready_peers.erase(peer_id)


func _on_seat_changed(_room_id: StringName, peer_id: int, _seat: int) -> void:
	if room_id != &"" and _ready_peers.has(peer_id):
		_refresh(peer_id)


func _refresh_all() -> void:
	if not is_inside_tree() or not MpKit.is_server():
		return
	for peer_id in _ready_peers.keys():
		_refresh(peer_id)


func _refresh(peer_id: int) -> void:
	if not multiplayer.get_peers().has(peer_id):
		return
	var visible := is_revealed_to(peer_id)
	for sync in _held_syncs():
		if sync.public_visibility:
			_warn_late(sync)
			_hold(sync)
		# A shared synchronizer (no spawner above it) is revealed by any of its
		# spawners and never hidden by one: a room spawner must not hide it.
		if visible or not _is_shared(sync):
			sync.set_visibility_for(peer_id, visible)


## Hidden from everyone, then shown to the peers that already qualify.
func _hold(sync: MultiplayerSynchronizer) -> void:
	sync.public_visibility = false
	for peer_id in _ready_peers.keys():
		if multiplayer.get_peers().has(peer_id) and is_revealed_to(peer_id):
			sync.set_visibility_for(peer_id, true)


func _warn_late(sync: MultiplayerSynchronizer) -> void:
	var id := sync.get_instance_id()
	if _warned.has(id):
		return
	_warned[id] = true
	push_error(
		"MpSpawner '%s': %s was added after its node was set up. Put synchronizers in the scene (or add them before add_child): the spawn packet and late joiners miss it."
		% [name, get_path_to(sync)]
	)


func _owns(node: Node) -> bool:
	var anchor := _anchor_of(node)
	return anchor == null or anchor == _root or anchor == get_parent()


func _is_shared(node: Node) -> bool:
	return _anchor_of(node) == null


## spawn_path, or the nearest ancestor with MpSpawner children; null if neither.
func _anchor_of(node: Node) -> Node:
	var cursor := node.get_parent()
	while cursor and cursor != get_tree().root:
		if cursor == _root or _has_spawner(cursor):
			return cursor
		cursor = cursor.get_parent()
	return null


## The direct child of spawn_path that holds `node`, or null for static nodes.
func _actor_of(node: Node) -> Node:
	var cursor := node
	while cursor and cursor.get_parent():
		if cursor.get_parent() == _root:
			return cursor
		cursor = cursor.get_parent()
	return null


## Synchronizers this spawner owns, from the top of the scene down. Subtrees
## owned by other spawners are skipped.
func _held_syncs() -> Array[MultiplayerSynchronizer]:
	var out: Array[MultiplayerSynchronizer] = []
	_collect(_scene_top(), out)
	return out


func _collect(node: Node, out: Array[MultiplayerSynchronizer]) -> void:
	if _is_foreign(node):
		return
	if node is MultiplayerSynchronizer and _owns(node):
		out.append(node as MultiplayerSynchronizer)
	for child in node.get_children():
		_collect(child, out)


## A subtree that belongs to other spawners: it has MpSpawner children and holds
## neither this spawner nor its spawn_path.
func _is_foreign(node: Node) -> bool:
	if not _has_spawner(node) or node == get_parent():
		return false
	if node.is_ancestor_of(self):
		return false
	return not (_root and (node == _root or node.is_ancestor_of(_root)))


func _has_spawner(node: Node) -> bool:
	for child in node.get_children():
		if child is MpSpawner:
			return true
	return false


func _scene_top() -> Node:
	var node: Node = self
	while node.get_parent() and node.get_parent() != get_tree().root:
		node = node.get_parent()
	return node


func _syncs_under(node: Node) -> Array[MultiplayerSynchronizer]:
	var out: Array[MultiplayerSynchronizer] = []
	_collect(node, out)
	return out
