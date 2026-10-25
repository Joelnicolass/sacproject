class_name PeasantBehavior
extends Node

## What a peasant does with no order (RFC-024 addendum 1, 024b2; sacengine updateCreatureAI,
## state.d:13732-13760): with a shelter within `shelter_distance` it looks for the closest enemy within
## `scare_distance` (a stance enemy or a side it holds a grudge against) and runs the other way, and with
## none it stands still; with no shelter near it crouches (COWER) and waits. A shelter is a building with
## the BLDG shelter flag (5 jhut + 6 jwg1 in High Noon, adenda 1.1 [DATOS]) or an altar, as long as its side
## is not an enemy of the peasant's side. It never attacks (aggressiveness 0). The 50 m distances are
## sacengine's, who marks the rule «TODO: figure out the original rule»: according to [S]. The manual says
## the villagers flee near their village and cower on the outskirts [DOC], which is the same shape.
## Server or solo only; the mode it sets reaches the clients through the unit's synchronizer.

@export var body: UnitBody
@export var grudge: GrudgeMemory
## Where the hits come from: a hit starts the panic.
@export var health: Health
@export_group("Distances (sacengine state.d:13610-13611)")
## shelterDistance: how far a shelter may be for the peasant to dare to stand.
@export var shelter_distance := 50.0
## scareDistance: how close an enemy has to be to make it run.
@export var scare_distance := 50.0
@export_group("Run")
## Decision of the port (sacengine runs at a point mirrored through the enemy every tick): how far ahead of the
## peasant the point it runs to lies, straight away from the scare.
@export var flee_leg_m := 30.0
## Decision of the port: sacengine decides on the turn of its AI queue; this is a fixed period.
@export var think_interval_s := 0.25
## Bodies that scare it.
@export var scare_groups: PackedStringArray = PackedStringArray(["unit", "wizard", "doctor"])
@export_group("Panic")
## A hit makes the peasant run from whoever hit it, near or far, with or without a shelter.
@export var panic_s := 4.0
## How far the panic leg reaches before it re-decides (longer than a calm flee: it is running for its life).
@export var panic_leg_m := 40.0
@export_group("Look (RFC-028c)")
## Decision of the port: «working the fields» is in sacengine's peasant FSM with no rule decompiled, so a calm
## peasant (standing near a shelter with no scare, mode IDLE) plays `work_role` instead of its idle clip.
## Off = the CRE8 idle. Presentation only, on every peer.
@export var work_when_calm := true
## Clip role of the calm peasant (UnitBody roles: "work" = dig, PEdi).
@export var work_role := "work"

## "cower", "flee" or "stand": what it decided last, for probes and the report.
var state := &"stand"

var _left := 0.0
var _panic_left := 0.0
var _panic_from := 0


func _ready() -> void:
	if body == null:
		body = get_parent() as UnitBody
	if body and work_when_calm:
		# IDLE is the calm state of a peasant (flee = MOVE, cower = COWER): every peer shows it the same way.
		body.set_idle_role(work_role)
	if MpKit.is_networked() and not MpKit.is_server():
		set_physics_process(false)
		return
	if health != null:
		health.hit.connect(_on_hit)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if body == null and not get_parent() is UnitBody:
		warnings.append("Falta el cuerpo (body).")
	return warnings


func _physics_process(delta: float) -> void:
	if body == null or not _free_to_act():
		return
	_panic_left = maxf(_panic_left - delta, 0.0)
	_left -= delta
	if _left > 0.0:
		return
	_left = think_interval_s
	think()


## A hit from another side: run for `panic_s`, whatever the distance (the calm rule only sees 50 m).
func _on_hit(_amount: float, from_slot: int, _was_full: bool) -> void:
	if body == null or body.is_dead() or from_slot == int(body.owner_slot):
		return
	_panic_from = from_slot
	_panic_left = panic_s
	_left = 0.0


## Only an idle, walking or cowering peasant thinks; a dead, held or revived one is somebody else's.
func _free_to_act() -> bool:
	if body.ordered:
		return false
	match body.mode:
		UnitBody.Mode.IDLE, UnitBody.Mode.MOVE, UnitBody.Mode.COWER:
			return true
	return false


func think() -> void:
	if _panic_left > 0.0 and _panic():
		return
	if closest_shelter() == null:
		state = &"cower"
		body.start_cower()
		return
	if body.is_cowering():
		body.halt()
	var scare := closest_scare()
	if scare == null:
		state = &"stand"
		if body.mode == UnitBody.Mode.MOVE:
			body.halt()
		return
	state = &"flee"
	var away := body.global_position - scare.global_position
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = Vector3(sin(body.rotation.y), 0.0, cos(body.rotation.y))
	body.begin_walk(body.global_position + away.normalized() * flee_leg_m)


## Runs straight away from the closest body of the side that hit it. False when none is left to run from.
func _panic() -> bool:
	var threat := _closest_of_slot(_panic_from)
	if threat == null:
		return false
	state = &"flee"
	if body.is_cowering():
		body.halt()
	var away := body.global_position - threat.global_position
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = Vector3(sin(body.rotation.y), 0.0, cos(body.rotation.y))
	body.begin_walk(body.global_position + away.normalized() * panic_leg_m)
	return true


func _closest_of_slot(slot: int) -> Node3D:
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


## sacengine closestPeasantShelterInRange (state.d:28850): a standing shelter of a side that is not an
## enemy of the peasant, within `shelter_distance`.
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


## closestEnemyInRange with the grudges: the closest body within `scare_distance` that is a stance enemy or
## of a side in the grudge mask.
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
