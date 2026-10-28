class_name ManaSource
extends Node3D

## Gives mana to bodies within reach (3D distance). A source with an owner feeds that side and its allies.
## Sources add up. The server (or solo) feeds ManaPool.add(); clients only see the replicated value.
## FOUNT and ALTAR read rate and radius from `rules`; CUSTOM keeps the exported values.
## Every creature is fed this way, not only wizards;
## a body with can_take_mana() false (dead, being summoned) gets nothing (canRegenerateMana).
## The reach of a FOUNT and an ALTAR comes from ReachFacts.of_rules(rules), the rate from `rules`.
## Ref: res://scenes/match/reach_facts.gd (fount_m, altar_m); sacengine updateCreatureStats state.d:14409, canRegenerateMana.

enum Kind { FOUNT, ALTAR, CUSTOM }

## Every mana source (founts and altars).
const GROUP := &"mana_source"

@export var kind := Kind.FOUNT
@export var rules: MatchRules
@export var rate := 33.333
@export var radius := 50.0
## Optional: a sphere shape drawn in the editor; when set, its radius is the reach (the `radius` above is ignored).
@export var reach: CollisionShape3D
## -1: any body (manafount). Otherwise only that player slot (its altar).
@export var owner_slot := -1
@export var target_groups: PackedStringArray = PackedStringArray(["wizard", "unit"])


func _ready() -> void:
	add_to_group(GROUP)
	_read_rules()
	if not is_multiplayer_authority():
		set_physics_process(false)


func _read_rules() -> void:
	if rules == null:
		return
	var facts := ReachFacts.of_rules(rules)
	match kind:
		Kind.FOUNT:
			rate = rules.manafount_rate
			radius = facts.fount_m
		Kind.ALTAR:
			rate = rules.altar_rate
			radius = facts.altar_m


## Metres from the source a body still gets mana.
func reach_m() -> float:
	var sphere := reach.shape as SphereShape3D if reach != null else null
	return sphere.radius if sphere != null else radius


func reaches(body: Node3D) -> bool:
	if owner_slot >= 0:
		var body_slot := int(body.get("owner_slot"))
		if body_slot != owner_slot and SideRelations.stance(owner_slot, body_slot) != SideRelations.Stance.ALLY:
			return false
	return global_position.distance_to(body.global_position) < reach_m()


static func _can_take_mana(body: Node3D) -> bool:
	if body is WizardBody:
		return (body as WizardBody).can_take_mana()
	if body is UnitBody:
		return (body as UnitBody).can_take_mana()
	return true


func _physics_process(delta: float) -> void:
	if rate <= 0.0:
		return
	for group in target_groups:
		for node in get_tree().get_nodes_in_group(group):
			var body := node as Node3D
			if body == null or not reaches(body):
				continue
			if not _can_take_mana(body):
				continue
			var pool := body.get_node_or_null("ManaPool")
			if pool:
				pool.add(rate * delta)
