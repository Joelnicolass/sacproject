class_name TerrainNet
extends Node

## Carries what stays on the ground from the server to the clients: each kept stamp and each hole by RPC, and the whole ground
## in one MpKit snapshot to a peer that joins late. It only sends and tells what arrived (its signals); it applies nothing and
## decides nothing: Terrain sends through it and applies what it tells. Alone (no network) it sends nothing.

## A client got a kept stamp: `delta` row by row over `rect` (lattice vertices); `rev` is the server's count after it.
signal kept_received(rev: int, key: String, rect: Rect2i, delta: PackedFloat32Array)
## A client got a hole that opened (`removed`) or closed at the lattice vertex `id`.
signal hole_received(rev: int, id: int, removed: bool)
## A client got the whole ground (GroundField.to_snapshot).
signal snapshot_received(data: Dictionary)
## The server: the peer `peer_id` joined and wants the whole ground (answer with push_snapshot).
signal snapshot_wanted(peer_id: int)

## Key of the dict in MpKit.push_snapshot.
const SNAPSHOT_KEY := "terrain"


func _ready() -> void:
	if Engine.is_editor_hint() or not MpKit.is_networked():
		return
	if MpKit.is_server():
		MpKit.client_world_ready.connect(snapshot_wanted.emit)
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


## The server: the peer gets the whole ground.
func push_snapshot(peer_id: int, data: Dictionary) -> void:
	MpKit.push_snapshot_to(peer_id, {SNAPSHOT_KEY: data})


@rpc("authority", "call_remote", "reliable")
func rpc_commit(rev: int, key: String, rect: Rect2i, delta: PackedFloat32Array) -> void:
	kept_received.emit(rev, key, rect, delta)


@rpc("authority", "call_remote", "reliable")
func rpc_removed(rev: int, id: int, removed: bool) -> void:
	hole_received.emit(rev, id, removed)


func _on_snapshot(data: Dictionary) -> void:
	var mine: Variant = data.get(SNAPSHOT_KEY)
	if mine is Dictionary:
		snapshot_received.emit(mine)
