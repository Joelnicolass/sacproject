class_name MatchStateNet
extends Node

## Carries the state of the match from the server to the clients: every change as an MpKit snapshot, the current one to a peer
## whose world just got ready (a seat that comes back gets the altars as they are now), and, on a dedicated started by hand,
## the end of the match to the kit. A client hands what arrives to MatchState (`apply_snapshot`). It decides nothing about the
## match. Alone (no network) it does nothing.

## Key of the dict in MpKit.push_snapshot (MpFlow ignores a snapshot with no world_id).
const SNAPSHOT_KEY := "match"

## The state it carries (its parent MatchState).
@export var state: MatchState


func _get_configuration_warnings() -> PackedStringArray:
	return (
		PackedStringArray()
		if state != null
		else PackedStringArray(["The socket `state` (the MatchState) is missing."])
	)


func _ready() -> void:
	if Engine.is_editor_hint() or state == null or not MpKit.is_networked():
		return
	if MpKit.is_server():
		state.snapshot_changed.connect(_push_snapshot)
		state.finished.connect(_on_finished)
		MpKit.client_world_ready.connect(_push_snapshot_to)
	else:
		MpKit.snapshot_received.connect(_on_snapshot_received)


func _push_snapshot() -> void:
	MpKit.push_snapshot({SNAPSHOT_KEY: state.to_snapshot()})


func _push_snapshot_to(peer_id: int) -> void:
	MpKit.push_snapshot_to(peer_id, {SNAPSHOT_KEY: state.to_snapshot()})


## A dedicated started by hand: tells MpKit the match is over, so it opens the next one as soon as the last player leaves
## (not past the grace). A room's match reports through its MatchTicketGlue (the agent tells the kit); a listen host and solo
## do not serve a next match, so nothing changes there.
func _on_finished() -> void:
	if MpKit.is_dedicated() and get_tree().get_nodes_in_group(MpMatchAgent.GROUP).is_empty():
		MpKit.broadcast_session_ended(state.result())


func _on_snapshot_received(data: Dictionary) -> void:
	var mine: Variant = data.get(SNAPSHOT_KEY)
	if mine is Dictionary:
		state.apply_snapshot(mine)
