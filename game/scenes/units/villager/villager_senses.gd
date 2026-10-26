class_name VillagerSenses
extends Node

## What a villager notices: the closest shelter that is still standing, the closest body that scares it (an enemy by stance, or a side it
## holds a grudge against), and the side that hit it last (the panic). It only answers; the Brain decides what to do with it.
## A shelter is a building with the shelter flag or an altar, as long as its side is not an enemy of the villager's side.
## Not: what to do about it (VillagerBrain and its states) nor who bears the grudges (GrudgeMemory). Server or solo only.
## Ref: sacengine closestPeasantShelterInRange (state.d:28850), updateCreatureAI (state.d:13732-13760); the 50 m distances are sacengine's,
## who marks the rule «TODO: figure out the original rule»; the manual says the villagers flee near their village and cower outside it.

## A hit from another side started the panic: the Brain thinks at once.
signal panicked

@export var body: UnitBody
@export var grudge: GrudgeMemory
## Where the hits come from: a hit starts the panic.
@export var health: Health
@export_group("Distances")
## shelterDistance: how far a shelter may be for the villager to dare to stand.
@export var shelter_distance := 50.0
## scareDistance: how close an enemy has to be to make it run.
@export var scare_distance := 50.0
## Bodies that scare it, and where to look for them.
@export var scare_groups: PackedStringArray = PackedStringArray(["unit", "wizard", "doctor"])
@export_group("Panic")
## A hit makes the villager run from whoever hit it, near or far, with or without a shelter.
@export var panic_s := 4.0

## The panic that is left (s) and the slot that caused it.
var panic_left := 0.0
var panic_from := 0


func _ready() -> void:
	if not body.simulates():
		return
	if health != null:
		health.hit.connect(_on_hit)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if body == null:
		warnings.append("Falta el cuerpo (body).")
	return warnings


## Time passes: the panic wears off.
func age(delta: float) -> void:
	panic_left = maxf(panic_left - delta, 0.0)


## The closest body of the side that hit it; null when none is left.
func closest_of_slot(slot: int) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for group in scare_groups:
		for node in get_tree().get_nodes_in_group(group):
			var other := node as Node3D
			if other == null or int(other.get("owner_slot")) != slot:
				continue
			var d := _flat(other.global_position)
			if d < best_d:
				best_d = d
				best = other
	return best


## A standing shelter of a side that is not an enemy of the villager, within `shelter_distance`.
func closest_shelter() -> Node3D:
	var best: Node3D = null
	var best_d := shelter_distance
	for group in [MapBuilding.SHELTER_GROUP, Altar.GROUP]:
		for node in get_tree().get_nodes_in_group(group):
			var place := node as Node3D
			if place == null or not _stands(place):
				continue
			var slot := int(place.get("owner_slot"))
			if SideRelations.stance(slot, body.owner_slot) == SideRelations.Stance.ENEMY:
				continue
			var d := _flat(place.global_position)
			if d <= best_d:
				best_d = d
				best = place
	return best


## closestEnemyInRange with the grudges: the closest body within `scare_distance` that is a stance enemy or of a side in the grudge mask.
func closest_scare() -> Node3D:
	var best: Node3D = null
	var best_d := scare_distance
	for group in scare_groups:
		for node in get_tree().get_nodes_in_group(group):
			if not TargetRules.is_valid_foe_of(body.owner_slot, node, body, false):
				continue
			var other := node as Node3D
			var slot := int(other.get("owner_slot"))
			if not SideRelations.is_enemy(body.owner_slot, slot) and not (grudge != null and grudge.has_grudge(slot)):
				continue
			var d := _flat(other.global_position)
			if d <= best_d:
				best_d = d
				best = other
	return best


## A hit from another side: run for `panic_s`, whatever the distance (the calm rule only sees 50 m).
func _on_hit(_amount: float, from_slot: int, _was_full: bool) -> void:
	if body == null or body.is_dead() or from_slot == int(body.owner_slot):
		return
	panic_from = from_slot
	panic_left = panic_s
	panicked.emit()


static func _stands(place: Node3D) -> bool:
	if place is MapBuilding:
		return (place as MapBuilding).is_sheltering()
	if place is Altar:
		return (place as Altar).is_standing()
	if place is RitualSite:
		return (place as RitualSite).is_standing()
	return true


func _flat(point: Vector3) -> float:
	var d := point - body.global_position
	return Vector2(d.x, d.z).length()
