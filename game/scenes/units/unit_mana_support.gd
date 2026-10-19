extends Node3D

## Server-authoritative mana support aura for units like Manahoar (hmba).
## Mirrors sacengine addManahoar shape (state.d): aura radius 40 and rate derived from
## allied manalith distance (50..1000) with a triangular ramp peaking at 20 mana/s.

@export var rules: MatchRules
@export var owner_slot := 0
@export var enabled := false
@export var source_ability_tag := "hmba"
@export var target_groups: PackedStringArray = PackedStringArray(["wizard", "unit"])

var _body: Node3D


func setup(body: Node3D, creature: CreatureType, slot: int, match_rules: MatchRules) -> void:
	_body = body
	owner_slot = slot
	rules = match_rules
	enabled = creature != null and source_ability_tag in creature.ability_tags


func _ready() -> void:
	if MpKit.is_networked() and not MpKit.is_server():
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not enabled or _body == null:
		return
	if _body.has_method("is_dead") and _body.call("is_dead"):
		return
	if _body.has_method("is_summoning") and _body.call("is_summoning"):
		return
	var rate := _rate_from_manaliths()
	if rate <= 0.0:
		return
	var radius := rules.manahoar_radius if rules else 40.0
	for group in target_groups:
		for node in get_tree().get_nodes_in_group(group):
			var target := node as Node3D
			if target == null:
				continue
			if int(target.get("owner_slot")) != owner_slot:
				continue
			if target.global_position.distance_to(global_position) > radius:
				continue
			if target.has_method("can_take_mana") and not target.call("can_take_mana"):
				continue
			var pool := target.get_node_or_null("ManaPool")
			if pool:
				pool.call("add", rate * delta, &"manahoar")


func _rate_from_manaliths() -> float:
	var peak := rules.manahoar_rate if rules else 20.0
	var near := rules.manahoar_near_distance if rules else 50.0
	var far := rules.manahoar_far_distance if rules else 1000.0
	if peak <= 0.0 or near <= 0.0 or far <= near:
		return 0.0
	var total := 0.0
	for node in get_tree().get_nodes_in_group("structure"):
		## RFC-049 049c: the manaliths of the allies count too (state.d:28598-28606).
		var structure_slot := int(node.get("owner_slot"))
		if structure_slot != owner_slot and SideRelations.stance(owner_slot, structure_slot) != SideRelations.Stance.ALLY:
			continue
		if str(node.get("spell_tag")) != "htlm":
			continue
		var manalith := node as Node3D
		if manalith == null:
			continue
		var distance := global_position.distance_to(manalith.global_position)
		if distance >= far:
			continue
		if distance <= near:
			total += peak * (distance / near)
		else:
			total += peak * ((far - distance) / (far - near))
	return total
