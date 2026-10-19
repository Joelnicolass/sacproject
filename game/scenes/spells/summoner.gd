class_name Summoner
extends Node

## Creature summons of a wizard (sacengine spawn / updateCreatureCasting). begin() puts the
## creature in front of the wizard, translucent, when the cast starts; finish() spends the
## souls and lets it act, or removes it when the souls are gone. Server or solo only.

const NO_SOULS := Refusal.NO_SOULS

## sacengine spawnPosition: first try ahead_m in front of the wizard, then these
## (side, ahead) offsets, then a ring of fallback_radius around it.
@export var ahead_m := 6.0
@export var offsets: PackedVector2Array = PackedVector2Array([
	Vector2(-3, 6), Vector2(3, 6),
	Vector2(-2, 3), Vector2(2, 3), Vector2(-5, 3), Vector2(5, 3),
	Vector2(-2, 9), Vector2(2, 9), Vector2(5, 9), Vector2(-5, 9),
	Vector2(-8, 12), Vector2(-5, 12), Vector2(-2, 12), Vector2(2, 12), Vector2(5, 12), Vector2(8, 12),
	Vector2(-11, 15), Vector2(-8, 15), Vector2(-5, 15), Vector2(-2, 15), Vector2(2, 15), Vector2(5, 15), Vector2(8, 15), Vector2(11, 15),
])
@export var fallback_radius := 15.0
@export var fallback_tries := 24
## sacengine isValidSpawnPosition: nothing within this half-width (m) of the spot.
@export var clear_half_width := 1.0
@export var clear_half_height := 10.0
@export var blocker_groups: PackedStringArray = PackedStringArray(["unit", "wizard"])
@export_flags_3d_physics var ground_mask := 1

@onready var _wizard: Node3D = get_parent()


func can_summon(type: CreatureType) -> bool:
	return type != null


func begin(type: CreatureType) -> Node3D:
	var spawner := get_tree().get_first_node_in_group("unit_spawner")
	if spawner == null:
		return null
	var at := spawn_point()
	var unit: Node3D = spawner.call("spawn_unit", {
		"tag": type.tag,
		"label": type.display_name,
		"slot": int(_wizard.get("owner_slot")),
		"x": at.x, "y": at.y, "z": at.z,
		"yaw": _wizard.rotation.y,
		"summoning": true,
	})
	if unit:
		FxBus.broadcast("summon", at + Vector3.UP)
	return unit


## Returns "" when the creature is free to act, or the reason it was removed.
func finish(unit: Node3D, type: CreatureType) -> String:
	if unit == null or not is_instance_valid(unit):
		return ""
	var purse := _wizard.get_node_or_null("SoulPurse")
	if purse == null or not bool(purse.call("spend", type.souls)):
		unit.queue_free()
		return NO_SOULS
	unit.call("finish_summon")
	return ""


func spawn_point() -> Vector3:
	var ahead := Vector3(0.0, 0.0, 1.0)
	if _wizard.has_method("facing_flat"):
		ahead = _wizard.call("facing_flat")
	var side := Vector3(ahead.z, 0.0, -ahead.x)
	var origin := _wizard.global_position
	var first: Variant = _ground_at(origin + ahead * ahead_m)
	if first != null and _is_clear(first):
		return first
	for offset in offsets:
		var spot: Variant = _ground_at(origin + side * offset.x + ahead * offset.y)
		if spot != null and _is_clear(spot):
			return spot
	for i in fallback_tries:
		var spot: Variant = _ground_at(origin + ahead.rotated(Vector3.UP, TAU * i / fallback_tries) * fallback_radius)
		if spot != null and _is_clear(spot):
			return spot
	return first if first != null else origin


func _ground_at(at: Vector3) -> Variant:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 500.0, at + Vector3.DOWN * 500.0)
	query.collision_mask = ground_mask
	var skip: Array[RID] = []
	for wizard in get_tree().get_nodes_in_group("wizard"):
		if wizard is CollisionObject3D:
			skip.append((wizard as CollisionObject3D).get_rid())
	query.exclude = skip
	var hit := _wizard.get_world_3d().direct_space_state.intersect_ray(query)
	return null if hit.is_empty() else hit.get("position")


func _is_clear(spot: Vector3) -> bool:
	for group in blocker_groups:
		for node in get_tree().get_nodes_in_group(group):
			if not node is Node3D or (node as Node).is_in_group("corpse"):
				continue
			var d := (node as Node3D).global_position - spot
			if absf(d.x) <= clear_half_width and absf(d.z) <= clear_half_width and absf(d.y) <= clear_half_height:
				return false
	return true
