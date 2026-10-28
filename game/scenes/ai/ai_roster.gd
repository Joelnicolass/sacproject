@tool
class_name AiRoster
extends Node

## Seats the AI of this match. For each seat: the pick goes to SacrificeFlow.slot_picks (published
## to the clients on the channel that already exists), the WizardSpawner makes the wizard of its
## slot (replicated like any wizard), and an AiSide (a child of this node) plays it. Only where the
## game is simulated: solo or the server; a client never has a side. The seats are
## MatchRules.ai_seats; when the rules have none, SacrificeFlow.solo_ai_seats («Contra la IA», or
## the dedicated with --ai-slots). No seats = nothing happens (a match of humans, as before).
## Ref: RFC-024 §4 (024f).

signal seated(slot: int, side: AiSide)

@export var world: Node3D
@export var wizard_spawner: MpSlotSpawner
## The scene of an AI side; a seat with its own side_scene uses that one.
@export var side_scene: PackedScene
## Off: the match takes no AI seat (a check scene that seats its own sides).
@export var enabled := true
## Seconds between the spawn of the wizards and the start of their sides: the wizard settles on the
## ground first.
@export_range(0.0, 5.0, 0.0001, "suffix:s") var settle_s := 0.3333

## AiSide by slot, once seated.
var sides: Dictionary = {}


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	for pair in [["world", world], ["wizard_spawner", wizard_spawner], ["side_scene", side_scene]]:
		if pair[1] == null:
			warnings.append("Missing `%s`." % pair[0])
	return warnings


func _ready() -> void:
	if Engine.is_editor_hint() or not enabled:
		return
	if not is_multiplayer_authority():
		return
	var seats := _seats()
	if seats.is_empty():
		return
	_seat_all.call_deferred(seats)


func _seats() -> Array[AiSeat]:
	var rules := world.get("rules") as MatchRules if world != null else null
	if rules != null and not rules.ai_seats.is_empty():
		return rules.ai_seats
	return SacrificeFlow.solo_ai_seats


func _seat_all(seats: Array[AiSeat]) -> void:
	var placed: Array[AiSeat] = []
	for template in seats:
		# The .tres is never changed: the god drawn for this match goes on a copy.
		var seat := template.duplicate() as AiSeat
		if seat.god == null:
			seat.god = _draw_god(seat.slot)
		var chosen := WizardPick.new()
		chosen.wizard = seat.wizard if seat.wizard != null else SacrificeFlow.default_pick.wizard
		chosen.god = seat.god
		SacrificeFlow.board.set_ai(seat.slot, chosen)
		wizard_spawner.spawn_slot(seat.slot)
		placed.append(seat)
	for _tick in MatchClock.ticks_for(settle_s):
		await get_tree().physics_frame
	for seat in placed:
		var wizard := wizard_spawner.pawn_for(seat.slot) as Node3D
		if wizard == null:
			push_warning("AiRoster: no wizard for slot %d" % seat.slot)
			continue
		var side := (
			(seat.side_scene if seat.side_scene != null else side_scene).instantiate() as AiSide
		)
		side.name = "AiSide%d" % seat.slot
		add_child(side)
		side.setup(world, wizard, seat)
		side.active = seat.start_active
		sides[seat.slot] = side
		if DebugLog.on(&"ai_seat"): print(
				(
					"ai slot %d ready (%s, %s)"
					% [seat.slot, seat.god.id(), side.play.difficulty.display_name]
				)
			)
		seated.emit(seat.slot, side)


## A seat without a god («Aleatorio»): drawn from the match seed among the gods the lobby offers, so
## a seeded match draws the same god.
func _draw_god(slot: int) -> GodType:
	var gods := GameCatalog.shared().offered_gods()
	var rng := MatchSeed.rng(["ai_god", slot])
	return gods[rng.randi_range(0, gods.size() - 1)]
