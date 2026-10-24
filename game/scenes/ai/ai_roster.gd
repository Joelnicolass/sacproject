@tool
class_name AiRoster
extends Node

## RFC-024 §4 (024f): seats the AI of this match. For each seat: the pick goes to SacrificeFlow.slot_picks (published to the
## clients on the channel that already exists), the WizardSpawner makes the wizard of its slot (replicated like any wizard),
## and an AiSide (a child of this node) plays it. Only where the game is simulated: solo or the server; a client never has a
## side. The seats are MatchRules.ai_seats; when the rules have none, SacrificeFlow.solo_ai_seats («Contra la IA», or the
## dedicated with --ai-slots). No seats = nothing happens (a match of humans, as before).

signal seated(slot: int, side: AiSide)

@export var world: Node3D
@export var wizard_spawner: MpSlotSpawner
## The scene of an AI side; a seat with its own side_scene uses that one.
@export var side_scene: PackedScene
## The bench (debug/ai_match) turns it off: it seats its own sides, with its audit and its pause.
@export var enabled := true
## Seconds between the spawn of the wizards and the start of their sides: the wizard settles on the ground first.
@export_range(0.0, 5.0, 0.0001, "suffix:s") var settle_s := 0.3333

## AiSide by slot, once seated.
var sides: Dictionary = {}


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	for pair in [["world", world], ["wizard_spawner", wizard_spawner], ["side_scene", side_scene]]:
		if pair[1] == null:
			warnings.append("Falta `%s`." % pair[0])
	return warnings


func _ready() -> void:
	if Engine.is_editor_hint() or not enabled:
		return
	if MpKit.is_networked() and not MpKit.is_server():
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
		## The .tres is never changed: the god drawn for this match goes on a copy.
		var seat := template.duplicate() as AiSeat
		if not GameData.gods().has(str(seat.god)):
			seat.god = _draw_god(seat.slot)
		var wizard_type := GameData.wizard(seat.wizard)
		SacrificeFlow.set_ai_pick(seat.slot, {
			"wizard": seat.wizard, "model": wizard_type.model if wizard_type != null else "jnwr", "god": str(seat.god)})
		wizard_spawner.spawn_slot(seat.slot)
		placed.append(seat)
	for _tick in MatchClock.ticks_for(settle_s):
		await get_tree().physics_frame
	for seat in placed:
		var wizard := wizard_spawner.pawn_for(seat.slot) as Node3D
		if wizard == null:
			push_warning("AiRoster: no hay mago para el slot %d" % seat.slot)
			continue
		var side := (seat.side_scene if seat.side_scene != null else side_scene).instantiate() as AiSide
		side.name = "AiSide%d" % seat.slot
		add_child(side)
		side.setup(world, wizard, seat)
		side.active = seat.start_active
		sides[seat.slot] = side
		print("ia slot %d lista (%s, %s)" % [seat.slot, seat.god, side.difficulty.display_name])
		seated.emit(seat.slot, side)


## A seat without a god («Aleatorio»): drawn from the match seed, so a seeded match draws the same god.
func _draw_god(slot: int) -> StringName:
	var gods := GameData.gods()
	var rng := MatchSeed.rng(["ai_god", slot])
	return StringName(gods[rng.randi_range(0, gods.size() - 1)])
