class_name GroundScarsNet
extends Node

## Brings a player who comes back after a drop up to date with the marks on the ground. Each peer paints the marks on its own
## when it sees the effect (nothing travels per mark), so when a peer's world gets ready a donor hands it its list
## (GroundScars.marks) in MpKit snapshots: the server itself when it draws (a listen host), else a player already in, asked by
## RPC (a dedicated server draws nothing). What was in the air then (the rocks of an Erupt the peer never saw) lands after the
## list: until every ScarMark the donor had in the tree is gone, it passes on each mark it paints, and the peer merges them with
## its own (GroundScarRecord.merge), so a mark both paint shows once. Then a last snapshot says it is done.
## What it does not do: paint or keep the list (GroundScars), decide what leaves a mark. Alone (no network) it does nothing.

## Key of the dict in MpKit.push_snapshot_to.
const SNAPSHOT_KEY := "ground_scars"

## The marks it carries (its parent GroundScars).
@export var scars: GroundScars

## Server, when a player gives: peer catching up -> that player (until the peer reloads its world or one of them leaves).
var _donor_of: Dictionary = {}
## Donor: peer catching up -> the ScarMarks (instance id -> true) shown in the donor's tree when its list left, not gone or hidden yet.
var _waiting: Dictionary = {}


func _get_configuration_warnings() -> PackedStringArray:
	return (
		PackedStringArray()
		if scars != null
		else PackedStringArray(["The `scars` socket is missing (the map's GroundScars)."])
	)


func _ready() -> void:
	if Engine.is_editor_hint() or scars == null or not MpKit.is_networked():
		return
	scars.marks.added.connect(_on_added)
	multiplayer.peer_disconnected.connect(_on_peer_left)
	if MpKit.is_server():
		MpKit.client_world_ready.connect(_on_world_ready)
	else:
		MpKit.snapshot_received.connect(_on_snapshot)


## The server: the world of `peer_id` is ready. It gives itself if it draws, else a player whose world is ready too.
func _on_world_ready(peer_id: int) -> void:
	_donor_of.erase(peer_id)
	if scars.is_active():
		_give(peer_id)
		return
	for donor in multiplayer.get_peers():
		if donor != peer_id and MpKit.is_peer_world_ready(donor):
			_donor_of[peer_id] = donor
			rpc_give.rpc_id(donor, peer_id)
			return


## The donor: its list now, then each new mark while a ScarMark of its tree now may still paint one.
func _give(peer_id: int) -> void:
	var waiting: Dictionary = {}
	if scars.is_active():
		for node: ScarMark in get_tree().get_nodes_in_group(ScarMark.GROUP):
			if not node.is_visible_in_tree():
				continue  # a pooled effect waiting hidden: nothing in the air
			var gone := _on_mark_gone.bind(node.get_instance_id())
			waiting[node.get_instance_id()] = true
			if not node.tree_exited.is_connected(gone):
				node.tree_exited.connect(gone)
				node.visibility_changed.connect(gone)
	_waiting.erase(peer_id)
	if not waiting.is_empty():
		_waiting[peer_id] = waiting
	var wire := scars.marks.to_wire()
	wire[GroundScarRecord.DONE] = waiting.is_empty()
	if GroundScarRecord.count(wire) > 0 or not waiting.is_empty():
		_pass(peer_id, wire)


func _on_added(path: String, at: Vector3, max_height_m: float, ordinal: int) -> void:
	for peer_id: int in _waiting:
		_pass(peer_id, GroundScarRecord.one(path, at, max_height_m, ordinal))


## A ScarMark left the tree or hid (a pooled effect that ended): it paints nothing more until it plays again, which this peer sees.
func _on_mark_gone(id: int) -> void:
	var mark := instance_from_id(id) as ScarMark
	if mark != null and mark.is_inside_tree() and mark.is_visible_in_tree():
		return
	if mark != null:
		mark.tree_exited.disconnect(_on_mark_gone.bind(id))
		mark.visibility_changed.disconnect(_on_mark_gone.bind(id))
	if not is_inside_tree():
		return
	for peer_id: int in _waiting.keys():
		var waiting := _waiting[peer_id] as Dictionary
		waiting.erase(id)
		if waiting.is_empty():
			_waiting.erase(peer_id)
			_pass(peer_id, {GroundScarRecord.DONE: true})


## To the peer catching up: straight from the server, through it from a player.
func _pass(peer_id: int, wire: Dictionary) -> void:
	if not MpKit.is_server():
		rpc_relay.rpc_id(1, peer_id, wire)
	elif multiplayer.get_peers().has(peer_id):
		MpKit.push_snapshot_to(peer_id, {SNAPSHOT_KEY: wire})


func _on_peer_left(peer_id: int) -> void:
	_waiting.erase(peer_id)
	_donor_of.erase(peer_id)
	for target: int in _donor_of.keys():
		if int(_donor_of[target]) == peer_id:
			_donor_of.erase(target)
			_pass(target, {GroundScarRecord.DONE: true})


## A player: the server wants it to give its marks to `peer_id`.
@rpc("authority", "call_remote", "reliable")
func rpc_give(peer_id: int) -> void:
	_give(peer_id)


## The server: a player passes marks on to the peer it gives to.
@rpc("any_peer", "call_remote", "reliable")
func rpc_relay(peer_id: int, wire: Dictionary) -> void:
	if MpKit.is_server() and int(_donor_of.get(peer_id, 0)) == multiplayer.get_remote_sender_id():
		_pass(peer_id, wire)


## The peer catching up: merges what came with what it paints itself; a snapshot that says done ends it.
func _on_snapshot(data: Dictionary) -> void:
	var wire: Variant = data.get(SNAPSHOT_KEY)
	if not wire is Dictionary or not scars.is_active():
		return
	if scars.marks.merge == null:
		scars.marks.begin_catch_up()
	for entry: Array in GroundScarRecord.entries(wire):
		var texture := entry[0] as Texture2D
		for i in scars.marks.merge.given_copies(texture.resource_path, entry[1], entry[3]):
			scars.paint(texture, entry[1], entry[2])
	if bool((wire as Dictionary).get(GroundScarRecord.DONE, false)):
		scars.marks.end_catch_up()
