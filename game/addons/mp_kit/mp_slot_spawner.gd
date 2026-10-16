class_name MpSlotSpawner
extends MpSpawner

## Optional: one packed pawn per occupied slot. Genre-neutral plumbing.
## Dedicated never spawns slot 0. Listen host spawns local slot in _ready.
## Joiners spawn on client_world_ready. Identity: node name Pawn_<slot>
## and `player_slot` if the actor exposes it.

@export var pawn_scene: PackedScene
@export var spawn_points: NodePath
@export var actor_name_prefix: String = "Pawn_"
@export var despawn_on_leave: bool = true

var _pawns: Dictionary = {}


func _ready() -> void:
	if pawn_scene != null and not pawn_scene.resource_path.is_empty():
		if extra_scenes.find(pawn_scene) < 0:
			extra_scenes.append(pawn_scene)
	super._ready()
	if pawn_scene == null:
		push_warning("MpSlotSpawner '%s': assign pawn_scene" % name)
		return
	if not MpKit.is_networked():
		spawn_slot(MpKit.local_slot())
		return
	if not MpKit.is_server():
		return
	MpKit.client_world_ready.connect(_on_slot_world_ready)
	if despawn_on_leave:
		MpKit.peer_left.connect(_on_slot_peer_left)
	if MpKit.is_listen_host():
		spawn_slot(MpKit.local_slot())


func _exit_tree() -> void:
	if MpKit.client_world_ready.is_connected(_on_slot_world_ready):
		MpKit.client_world_ready.disconnect(_on_slot_world_ready)
	if MpKit.peer_left.is_connected(_on_slot_peer_left):
		MpKit.peer_left.disconnect(_on_slot_peer_left)
	super._exit_tree()


func spawn_occupied() -> void:
	for slot in MpKit.occupied_slots():
		spawn_slot(slot)


func spawn_slot(slot: int) -> Node:
	if slot <= 0 or _pawns.has(slot):
		return _pawns.get(slot)
	if pawn_scene == null or _root == null:
		return null
	var pawn := pawn_scene.instantiate()
	pawn.name = "%s%d" % [actor_name_prefix, slot]
	if "player_slot" in pawn:
		pawn.player_slot = slot
	_place(pawn, slot)
	_root.add_child(pawn, true)
	_pawns[slot] = pawn
	return pawn


func pawn_for(slot: int) -> Node:
	return _pawns.get(slot)


func _place(pawn: Node, slot: int) -> void:
	var points := _spawn_points_node()
	if points == null:
		return
	var markers := points.get_children()
	if markers.is_empty():
		return
	var marker: Node = markers[(slot - 1) % markers.size()]
	if pawn is Node2D and marker is Node2D and _root is Node2D:
		(pawn as Node2D).position = (_root as Node2D).to_local((marker as Node2D).global_position)
	elif pawn is Node3D and marker is Node3D and _root is Node3D:
		(pawn as Node3D).position = (_root as Node3D).to_local((marker as Node3D).global_position)


func _spawn_points_node() -> Node:
	if not spawn_points.is_empty():
		var node := get_node_or_null(spawn_points)
		if node:
			return node
	var parent := get_parent()
	if parent:
		return parent.get_node_or_null("SpawnPoints")
	return null


func _on_slot_world_ready(peer_id: int) -> void:
	if not MpKit.is_server():
		return
	spawn_slot(MpKit.slot_for_peer(peer_id))


func _on_slot_peer_left(_peer_id: int, slot: int) -> void:
	if not _pawns.has(slot):
		return
	var pawn: Node = _pawns[slot]
	_pawns.erase(slot)
	if is_instance_valid(pawn):
		pawn.queue_free()
