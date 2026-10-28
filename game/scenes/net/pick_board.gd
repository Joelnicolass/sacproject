class_name PickBoard
extends Node

## The picks of the match by MpKit slot. The server stores what each client sends (checked by MatchWire) and publishes the table;
## a client keeps the one it receives. It does not choose the local pick (SacrificeFlow) and does not decide who may pick (the room
## rules do). In the dedicated of a room, the ticket brings the picks, so the clients' own are ignored and not erased when they leave.

signal changed
## Every seat the ticket left open has sent its pick: the world can start.
signal complete

const PICK_CHANNEL := &"pick"
const SLOT_PICKS_CHANNEL := &"slot_picks"

## Picks by MpKit slot; the server writes, the clients mirror.
var picks: Dictionary[int, WizardPick] = {}
## Only in the dedicated a room server launched (`--match-ticket-file`).
var ticket_glue: MatchTicketGlue

## Slots an AI plays (solo or server; set_ai fills it). No player's keys come for them.
var _ai_slots: Dictionary[int, bool] = {}


func _ready() -> void:
	MpKit.custom_received.connect(_on_custom_received)
	MpKit.peer_left.connect(_on_peer_left)


## True when an AI plays `slot` (known where the game is simulated).
func is_ai(slot: int) -> bool:
	return _ai_slots.has(slot)


## A client tells the server its pick when it gets its slot.
func announce(local_pick: WizardPick) -> void:
	if MpKit.is_networked() and not MpKit.is_server():
		MpKit.send_custom(PICK_CHANNEL, MatchWire.encode_pick(local_pick))


## Solo or server: the pick of an AI slot (AiRoster), published like a human's.
func set_ai(slot: int, chosen: WizardPick) -> void:
	if MpKit.is_networked() and not MpKit.is_server():
		return
	_ai_slots[slot] = true
	picks[slot] = chosen
	if MpKit.is_networked():
		_publish()
	else:
		changed.emit()


func _on_custom_received(channel: StringName, data: Dictionary, from_peer: int) -> void:
	if channel == PICK_CHANNEL:
		_store(data, from_peer)
	elif channel == SLOT_PICKS_CHANNEL and not MpKit.is_server():
		var raw: Variant = data.get("picks")
		if raw is Dictionary:
			picks = MatchWire.decode_picks(raw)
			changed.emit()


func _store(data: Dictionary, from_peer: int) -> void:
	if not MpKit.is_server():
		return
	var slot := MpKit.slot_for_peer(from_peer)
	# The ticket closed the picks: the client that just got its slot only needs to hear them.
	if ticket_glue != null:
		if ticket_glue.is_pick_open(slot):
			_accept_open(from_peer, slot, data)
		else:
			_publish()
		return
	var chosen: WizardPick = MatchWire.decode_pick(data, true)
	if slot <= 0 or chosen == null:
		return
	picks[slot] = chosen
	print("slot %d pick %s %s" % [slot, chosen.wizard.model_id(), chosen.god.id()])
	_publish()


## The pick of a seat the ticket left open, checked by the same rules as a room's. An invalid one is rejected (the player is told
## `bad_pick` and may come back with the same credential and choose again). With every pick in, the world starts.
func _accept_open(from_peer: int, slot: int, data: Dictionary) -> void:
	var chosen: WizardPick = MatchWire.decode_pick(data, true)
	if chosen == null:
		print("partida %s: slot %d pick inválido, rechazado" % [ticket_glue.agent.match_id, slot])
		MpKit.reject_peer(from_peer, "bad_pick")
		return
	picks[slot] = chosen
	ticket_glue.close_pick(slot)
	print("partida %s: slot %d pick %s %s (elegido al entrar)" % [ticket_glue.agent.match_id, slot, chosen.wizard.model_id(), chosen.god.id()])
	_publish()
	if not ticket_glue.picks_pending():
		complete.emit()


func _on_peer_left(peer_id: int, slot: int) -> void:
	print("peer_left peer %d slot %d" % [peer_id, slot])
	if ticket_glue != null or not picks.has(slot):
		return
	picks.erase(slot)
	_publish()


func _publish() -> void:
	MpKit.broadcast_custom(SLOT_PICKS_CHANNEL, {"picks": MatchWire.encode_picks(picks)})
	changed.emit()
