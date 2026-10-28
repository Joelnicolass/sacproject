class_name SeatPresence
extends Node

## The story of each seat of a networked match, told in the server's log, and the defeat of a seat that abandoned. It listens
## to the door of the match (`Mp.gate()`, MpMatchGate) on every path that hosts: listen host LAN, a room's dedicated or a
## «Servidor local», and the dedicated started by hand. One line per event, all with `log_prefix`:
## `slot N adentro` → `slot N cargó el mundo (k/n)` → `la simulación arranca (todos cargaron) en el tick T` →
## `slot N se fue` / `slot N volvió` (each with the wizard's place) → `peer P rechazado (motivo)` → `slot N abandonó y pierde`.
## `grep "^partida "` on the server's log reads the whole match in order.
## Not: who may sit or when the match starts (the gate), what the room is told (MatchTicketGlue).

## Before the text of each line. MatchTicketGlue's flow sets `partida <id>: ` for a match with a ticket.
@export var log_prefix := "partida lan: "

## Why the gate gave up on a seat -> the line told before «abandonó y pierde» (none for a seat past the grace).
const GIVE_UP_NOTES := {
	"not_loaded": "no cargó a tiempo, cuenta como abandono",
	"no_pick": "no mandó su pick a tiempo, cuenta como abandono",
}
## What the gate's `started(why)` means, in the log.
const START_NOTES := {
	"all_loaded": "todos cargaron",
	"host_started": "el host empezó",
	"load_timeout": "tiempo de carga vencido",
	"no_hold": "sin espera",
}


func _ready() -> void:
	var gate := Mp.gate()
	if gate == null:
		push_warning("SeatPresence: no hay MpMatchGate en MpKit")
		return
	gate.seat_admitted.connect(_on_seat_admitted)
	gate.seat_loaded.connect(_on_seat_loaded)
	gate.started.connect(_on_started)
	gate.seat_away.connect(_on_seat_away)
	gate.seat_abandoned.connect(_on_seat_abandoned)
	gate.turned_away.connect(_on_turned_away)


## The world's rule for losing, or null when there is no world yet (nothing to defeat).
func defeat_rule() -> DefeatRule:
	var state := get_tree().get_first_node_in_group(MatchState.GROUP) as MatchState
	if state == null:
		return null
	for child in state.get_children():
		if child is DefeatRule:
			return child as DefeatRule
	return null


func _on_seat_admitted(slot: int, back: bool) -> void:
	if not back:
		_say("slot %d adentro" % slot)
		return
	_say("slot %d volvió" % slot)
	_say(_slot_state(slot, "al volver"))


func _on_seat_loaded(slot: int, loaded: int, expected: int) -> void:
	_say("slot %d cargó el mundo (%d/%d)" % [slot, loaded, expected])


## The tick goes after the parenthesis: runs read the line with `startswith("… (todos cargaron)")`.
func _on_started(why: String) -> void:
	_say("la simulación arranca (%s) en el tick %d" % [START_NOTES.get(why, why), MatchClock.now()])


func _on_seat_away(slot: int) -> void:
	_say("slot %d se fue" % slot)
	_say(_slot_state(slot, "al irse"))


func _on_turned_away(peer_id: int, reason: String) -> void:
	_say("peer %d rechazado (%s)" % [peer_id, reason])


## The gate gave the seat up (past the grace, never loaded, never picked): it loses, and the match goes on until one team is
## left (the rule of the mode decides, as for any defeat). With no world yet MatchTicketGlue decides by the teams of the mode.
func _on_seat_abandoned(slot: int, why: String) -> void:
	if GIVE_UP_NOTES.has(why):
		_say("slot %d %s" % [slot, GIVE_UP_NOTES[why]])
	var rule := defeat_rule()
	if rule == null:
		return
	_say("slot %d abandonó y pierde" % slot)
	rule.defeat(slot)


## What the world holds for `slot`: its wizard (where it stands) and its living creatures.
func _slot_state(slot: int, when: String) -> String:
	var wizard := "sin mago"
	for node in get_tree().get_nodes_in_group(WizardBody.GROUP):
		if int(node.get("owner_slot")) == slot and node is Node3D:
			var at := (node as Node3D).global_position
			wizard = "mago en %.1f %.1f" % [at.x, at.z]
			break
	var creatures := 0
	for node in get_tree().get_nodes_in_group(UnitBody.GROUP):
		if int(node.get("owner_slot")) == slot and not node.is_queued_for_deletion():
			creatures += 1
	return "slot %d %s, %d criaturas (%s)" % [slot, wizard, creatures, when]


func _say(text: String) -> void:
	print(log_prefix + text)
