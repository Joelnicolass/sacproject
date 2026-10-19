class_name ManaSource
extends Node3D

## Gives mana to bodies within `radius` (3D distance, as sacengine ManaProximity).
## Sources add up. The server (or solo) feeds ManaPool.add(); clients only see the replicated value.
## FOUNT and ALTAR read rate and radius from `rules`; CUSTOM keeps the exported values.
## sacengine feeds every creature this way, not only wizards (updateCreatureStats, state.d:14409);
## a body with can_take_mana() false (dead, being summoned) gets nothing (canRegenerateMana).

enum Kind { FOUNT, ALTAR, CUSTOM }

@export var kind := Kind.FOUNT
@export var rules: MatchRules
@export var rate := 33.333
@export var radius := 50.0
## -1: any body (manafount). Otherwise only that player slot (its altar).
@export var owner_slot := -1
@export var target_groups: PackedStringArray = PackedStringArray(["wizard", "unit"])


func _ready() -> void:
	add_to_group("mana_source")
	_read_rules()
	if MpKit.is_networked() and not MpKit.is_server():
		set_physics_process(false)


func _read_rules() -> void:
	if rules == null:
		return
	match kind:
		Kind.FOUNT:
			rate = rules.manafount_rate
			radius = rules.manafount_radius
		Kind.ALTAR:
			rate = rules.altar_rate
			radius = rules.altar_radius


## What the audit calls this source: «fount», «altar» or «manalith» (a CUSTOM one: the structure's).
func source_name() -> StringName:
	match kind:
		Kind.FOUNT:
			return &"fount"
		Kind.ALTAR:
			return &"altar"
	return &"manalith"


func reaches(body: Node3D) -> bool:
	if owner_slot >= 0 and int(body.get("owner_slot")) != owner_slot:
		return false
	return global_position.distance_to(body.global_position) < radius


func _physics_process(delta: float) -> void:
	if rate <= 0.0:
		return
	for group in target_groups:
		for node in get_tree().get_nodes_in_group(group):
			var body := node as Node3D
			if body == null or not reaches(body):
				continue
			if body.has_method("can_take_mana") and not body.call("can_take_mana"):
				continue
			var pool := body.get_node_or_null("ManaPool")
			if pool:
				pool.add(rate * delta, source_name())
