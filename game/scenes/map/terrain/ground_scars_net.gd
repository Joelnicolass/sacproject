class_name GroundScarsNet
extends Node

## Brings a player who comes back after a drop up to date with the marks on the ground. Each peer paints the marks on its own
## when it sees the effect (nothing travels per mark), so when a peer's world gets ready the server hands it the list of what was
## painted (GroundScars.marks) in one MpKit snapshot: its own list when it draws (a listen host), else the list of a player already
## in, asked by RPC (a dedicated server draws nothing). The peer cleans its tiles and paints the list again.
## What it does not do: paint or keep the list (GroundScars), decide what leaves a mark. Alone (no network) it does nothing.

## Key of the dict in MpKit.push_snapshot_to.
const SNAPSHOT_KEY := "ground_scars"

## The marks it carries (its parent GroundScars).
@export var scars: GroundScars

## Server: player asked for its list -> the peer that list is for.
var _asked: Dictionary = {}


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if scars != null else PackedStringArray(["Falta el socket `scars` (el GroundScars del mapa)."])


func _ready() -> void:
	if Engine.is_editor_hint() or scars == null or not MpKit.is_networked():
		return
	if MpKit.is_server():
		MpKit.client_world_ready.connect(_on_world_ready)
	else:
		MpKit.snapshot_received.connect(_on_snapshot)


## The server: the world of `peer_id` is ready. Its own list if it draws, else one from a player whose world is ready too.
func _on_world_ready(peer_id: int) -> void:
	if scars.is_active():
		_send(peer_id, scars.marks.to_wire())
		return
	for donor in multiplayer.get_peers():
		if donor != peer_id and MpKit.is_peer_world_ready(donor):
			_asked[donor] = peer_id
			rpc_share.rpc_id(donor)
			return


func _send(peer_id: int, wire: Dictionary) -> void:
	if GroundScarRecord.count(wire) > 0:
		MpKit.push_snapshot_to(peer_id, {SNAPSHOT_KEY: wire})


## A player: the server wants the marks this peer painted (an empty list headless).
@rpc("authority", "call_remote", "reliable")
func rpc_share() -> void:
	rpc_shared.rpc_id(1, scars.marks.to_wire())


## The server: the list of a player it asked, passed on to the peer it was for.
@rpc("any_peer", "call_remote", "reliable")
func rpc_shared(wire: Dictionary) -> void:
	var donor := multiplayer.get_remote_sender_id()
	if not MpKit.is_server() or not _asked.has(donor):
		return
	var peer_id := int(_asked[donor])
	_asked.erase(donor)
	if multiplayer.get_peers().has(peer_id):
		_send(peer_id, wire)


func _on_snapshot(data: Dictionary) -> void:
	var wire: Variant = data.get(SNAPSHOT_KEY)
	if not wire is Dictionary or not scars.is_active():
		return
	scars.clear()
	for entry: Array in GroundScarRecord.entries(wire):
		scars.stamp(entry[0], entry[1], entry[2])
