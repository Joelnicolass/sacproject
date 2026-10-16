class_name GrudgeMemory
extends Node

## The grudges of a peasant (RFC-024 addendum 1, 024b2; sacengine grudgeMask, state.d:8933-8936 and
## absorbHerdGrudges 13634-13645). The first hit that takes health from a full bar writes the side of the
## attacker into the mask; a peasant flees from every side in its mask as if it were an enemy. The herd
## shares it: every `herd_interval_s` the peasant takes the mask of each member of its own side within
## `herd_range` that costs the same mana (all the Farmers do), so a grudge reaches the others within a
## second. Server or solo only; the mask is not replicated (the clients only draw).

signal grudge_added(slot: int)

## Meta of the body that holds its memory, so the herd finds it without looking for a node by name.
const META := &"grudge_memory"

@export var body: UnitBody
@export var health: Health
@export_group("Herd")
## sacengine absorbHerdGrudges range (state.d:13635).
@export var herd_range := 80.0
## Decision of the port: sacengine absorbs every tick; every 0.1 s is as fast as a person can tell.
@export var herd_interval_s := 0.1
## Group of the peasants that share the grudges.
@export var herd_group := &"peasant"

## Bit `slot` set = a grudge against that slot (sacengine uses the side; the port's slot is side + 1).
var mask := 0

var _left := 0.0


func _ready() -> void:
	if MpKit.is_networked() and not MpKit.is_server():
		set_physics_process(false)
		return
	if health == null:
		health = get_node_or_null("../Health") as Health
	if body == null:
		body = get_parent() as UnitBody
	if health != null:
		health.hit.connect(_on_hit)
	if body != null:
		body.add_to_group(herd_group)
		body.set_meta(META, self)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if body == null and not get_parent() is UnitBody:
		warnings.append("Falta el cuerpo (body).")
	if health == null and get_node_or_null("../Health") == null:
		warnings.append("Falta la vida (health).")
	return warnings


func has_grudge(slot: int) -> bool:
	return slot > 0 and slot < 32 and (mask & (1 << slot)) != 0


func note(slot: int) -> void:
	if slot <= 0 or slot >= 32 or has_grudge(slot):
		return
	mask |= 1 << slot
	grudge_added.emit(slot)


func _on_hit(_amount: float, from_slot: int, was_full: bool) -> void:
	if was_full and from_slot != int(body.owner_slot):
		note(from_slot)


func _physics_process(delta: float) -> void:
	if body == null or body.is_dead():
		return
	_left -= delta
	if _left > 0.0:
		return
	_left = herd_interval_s
	absorb_herd()


## The grudges of the herd members around this peasant join its own.
func absorb_herd() -> void:
	var here := body.global_position
	var own_cost := body.type.mana_cost if body.type else 0
	for node in get_tree().get_nodes_in_group(herd_group):
		var member := node as UnitBody
		if member == null or member == body or member.owner_slot != body.owner_slot or member.is_dead():
			continue
		if (member.type.mana_cost if member.type else 0) != own_cost:
			continue
		var d := member.global_position - here
		if Vector2(d.x, d.z).length() > herd_range:
			continue
		var other := member.get_meta(META, null) as GrudgeMemory
		if other == null:
			continue
		var gained := other.mask & ~mask
		if gained == 0:
			continue
		for slot in range(1, 32):
			if gained & (1 << slot):
				note(slot)
