class_name TerrainDeformer
extends Node

## The one writer of the ground's displacement (GroundSurface.field). A stamp that is playing registers its shift
## with `set_live` on every peer (each one plays it from its own clock); what must stay (a mound, a crater, a hole) is
## decided by the server only: it calls `commit`, and every client applies the same bytes, so none of them recomputes
## it. A peer that joins later gets the whole ground in one snapshot. After each change the shape tells its listeners,
## and on the server the bodies the ground came up through stand on it again (StampCarry).
## It does not know what a spell is: stamps and cutters ask it.

const GROUP := &"terrain_deformer"
## Key of the dict in MpKit.push_snapshot.
const SNAPSHOT_KEY := "terrain"

@export var shape: GroundSurface


## The deformer of the map `node` is in, null outside a map.
static func of(node: Node) -> TerrainDeformer:
	return node.get_tree().get_first_node_in_group(GROUP) as TerrainDeformer if node != null and node.is_inside_tree() else null


func _ready() -> void:
	add_to_group(GROUP)
	if Engine.is_editor_hint() or not MpKit.is_networked():
		return
	if MpKit.is_server():
		MpKit.client_world_ready.connect(_push_snapshot)
	else:
		MpKit.snapshot_received.connect(_on_snapshot)


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if shape != null else PackedStringArray(["Falta el socket `shape` (el GroundSurface del mapa)."])


## True on the server (and alone): the only peer that decides what stays.
func is_authority() -> bool:
	return multiplayer.is_server()


## A stamp that is playing: its shift over `rect` right now (replaces its previous one). Every peer, from its own clock.
func set_live(key: String, rect: Rect2i, values: PackedFloat32Array) -> void:
	var standing := _standing(rect)
	shape.notify_changed(shape.field().set_live(key, rect, values))
	StampCarry.lift(standing, shape)


## The stamp under `key` is over.
func drop_live(key: String) -> void:
	shape.notify_changed(shape.field().drop_live(key))


## Server (or solo): adds `delta` (row by row over `rect`) to what stays, takes away the live stamp `key` in the same step,
## and sends the same numbers to every client.
func commit(rect: Rect2i, delta: PackedFloat32Array, key := "") -> void:
	if not is_authority():
		push_warning("TerrainDeformer.commit: only the server decides what stays.")
		return
	var ground := shape.field()
	var standing := _standing(rect)
	shape.notify_changed(ground.commit(rect, delta, key if not key.is_empty() else null))
	StampCarry.lift(standing, shape)
	if MpKit.is_server():
		rpc_commit.rpc(ground.rev, key, rect, delta)


## Server (or solo): takes the lattice vertex `id` away (a hole) or gives it back.
func set_removed(id: int, removed: bool) -> void:
	if not is_authority():
		push_warning("TerrainDeformer.set_removed: only the server decides the holes.")
		return
	var ground := shape.field()
	if ground.set_removed(id, removed):
		ground.rev += 1
		_tell_holes(id)
		if MpKit.is_server():
			rpc_removed.rpc(ground.rev, id, removed)


@rpc("authority", "call_remote", "reliable")
func rpc_commit(rev: int, key: String, rect: Rect2i, delta: PackedFloat32Array) -> void:
	var ground := shape.field()
	if rev <= ground.rev:
		return
	shape.notify_changed(ground.commit(rect, delta, key if not key.is_empty() else null))
	ground.rev = rev


@rpc("authority", "call_remote", "reliable")
func rpc_removed(rev: int, id: int, removed: bool) -> void:
	var ground := shape.field()
	if rev <= ground.rev:
		return
	ground.set_removed(id, removed)
	ground.rev = rev
	_tell_holes(id)


## Server (or solo): the bodies on the land of `rect` before it moves, so the ground that comes up through them carries them
## (StampCarry). Bodies are the server's: a client moves none.
func _standing(rect: Rect2i) -> Array[Node3D]:
	if not is_authority() or not is_inside_tree():
		return []
	return StampCarry.standing(get_tree(), shape, rect)


## The vertex `id` came or went: the shape says it moved, and that it was a hole (the collision flushes, the navmesh is baked again).
func _tell_holes(id: int) -> void:
	var lattice := shape.field()
	var around := Rect2i(id % lattice.size.x - 1, id / lattice.size.x - 1, 3, 3)
	shape.notify_changed(around)
	shape.holes_changed.emit(Rect2(Vector2(around.position) * lattice.cell_m, Vector2(around.size) * lattice.cell_m))


func _push_snapshot(peer_id: int) -> void:
	MpKit.push_snapshot_to(peer_id, {SNAPSHOT_KEY: shape.field().to_snapshot()})


func _on_snapshot(data: Dictionary) -> void:
	var mine: Variant = data.get(SNAPSHOT_KEY)
	if mine is Dictionary and int((mine as Dictionary)["rev"]) >= shape.field().rev:
		shape.field().apply_snapshot(mine)
		shape.notify_changed(Rect2i(Vector2i.ZERO, shape.field().size))
