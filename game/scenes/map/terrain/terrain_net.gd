class_name TerrainNet
extends Node

## Carries what stays on the ground from the server to the clients: each stamp its Terrain keeps and each hole by RPC, and
## the whole ground in one MpKit snapshot to a peer that joins late. On a client it hands what arrives to the Terrain
## (`keep`, `set_hole`, `load_snapshot`), which decides whether it is newer and applies it. It decides nothing about the
## ground. Alone (no network) it sends nothing.

## Key of the dict in MpKit.push_snapshot.
const SNAPSHOT_KEY := "terrain"

## The ground it carries (its parent Terrain).
@export var terrain: Terrain


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if terrain != null else PackedStringArray(["Falta el socket `terrain` (el Terrain del mapa)."])


func _ready() -> void:
	if Engine.is_editor_hint() or terrain == null or not MpKit.is_networked():
		return
	if MpKit.is_server():
		terrain.kept.connect(send_kept)
		terrain.hole_set.connect(send_hole)
		MpKit.client_world_ready.connect(push_snapshot)
	else:
		MpKit.snapshot_received.connect(_on_snapshot)


## The server: every client applies the same kept stamp.
func send_kept(rev: int, key: String, rect: Rect2i, delta: PackedFloat32Array) -> void:
	if MpKit.is_server():
		rpc_commit.rpc(rev, key, rect, delta)


## The server: every client opens or closes the same hole.
func send_hole(rev: int, id: int, removed: bool) -> void:
	if MpKit.is_server():
		rpc_removed.rpc(rev, id, removed)


## The server: the peer `peer_id` that joined gets the whole ground (GroundField.to_snapshot).
func push_snapshot(peer_id: int) -> void:
	MpKit.push_snapshot_to(peer_id, {SNAPSHOT_KEY: terrain.field().to_snapshot()})


## A client got a kept stamp: `delta` row by row over `rect` (lattice vertices); `rev` is the server's count after it.
@rpc("authority", "call_remote", "reliable")
func rpc_commit(rev: int, key: String, rect: Rect2i, delta: PackedFloat32Array) -> void:
	terrain.keep(rev, key, rect, delta)


## A client got a hole that opened (`removed`) or closed at the lattice vertex `id`.
@rpc("authority", "call_remote", "reliable")
func rpc_removed(rev: int, id: int, removed: bool) -> void:
	terrain.set_hole(rev, id, removed)


func _on_snapshot(data: Dictionary) -> void:
	var mine: Variant = data.get(SNAPSHOT_KEY)
	if mine is Dictionary:
		terrain.load_snapshot(mine)
