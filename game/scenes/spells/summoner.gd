@tool
class_name Summoner
extends Node

## Creature summons of a wizard. begin() puts the
## creature in front of the wizard, translucent, when the cast starts; finish() spends the
## souls and lets it act, or removes it when the souls are gone. Server or solo only.

const NO_SOULS := Refusal.NO_SOULS

## First try ahead_m in front of the wizard, then these
## (side, ahead) offsets, then a ring of fallback_radius around it.
@export var ahead_m := 6.0
@export var offsets: PackedVector2Array = PackedVector2Array(
	[
		Vector2(-3, 6),
		Vector2(3, 6),
		Vector2(-2, 3),
		Vector2(2, 3),
		Vector2(-5, 3),
		Vector2(5, 3),
		Vector2(-2, 9),
		Vector2(2, 9),
		Vector2(5, 9),
		Vector2(-5, 9),
		Vector2(-8, 12),
		Vector2(-5, 12),
		Vector2(-2, 12),
		Vector2(2, 12),
		Vector2(5, 12),
		Vector2(8, 12),
		Vector2(-11, 15),
		Vector2(-8, 15),
		Vector2(-5, 15),
		Vector2(-2, 15),
		Vector2(2, 15),
		Vector2(5, 15),
		Vector2(8, 15),
		Vector2(11, 15),
	]
)
@export var fallback_radius := 15.0
@export var fallback_tries := 24
## Nothing within this half-width (m) of the spot.
@export var clear_half_width := 1.0
@export var clear_half_height := 10.0
@export var blocker_groups: PackedStringArray = PackedStringArray(["unit", "wizard"])
@export_flags_3d_physics var ground_mask := 1
## A spot more than this (m) above the land is on top of something (a tower, a roof): the creature
## would be born up there, so the spot is skipped.
@export_range(0.0, 5.0, 0.1, "suffix:m") var max_above_land_m := 0.5
## Played on the creature when it appears. Empty = no burst.
@export var summon_fx: ParticleType = preload("res://data/fx/summon.tres")
## Where on the new creature's body the burst plays.
@export var summon_socket: BodyFacts.Socket = BodyFacts.Socket.CENTER
## The wizard that owns this node (set in wizard_body.tscn).
@export var wizard: WizardBody


func _get_configuration_warnings() -> PackedStringArray:
	if wizard == null:
		return PackedStringArray(["Assign `wizard`: the WizardBody that owns this node."])
	return PackedStringArray()


func _ready() -> void:
	if not Engine.is_editor_hint() and wizard == null:
		push_error("%s: `wizard` is empty." % get_path())


func can_summon(type: CreatureType) -> bool:
	return type != null


func begin(type: CreatureType) -> Node3D:
	var spawner := get_tree().get_first_node_in_group(UnitSpawner.GROUP) as UnitSpawner
	if spawner == null:
		return null
	var at := spawn_point()
	var unit: Node3D = (
		spawner
		. spawn_unit(
			{
				"tag": type.tag,
				"label": type.display_name,
				"slot": wizard.owner_slot,
				"x": at.x,
				"y": at.y,
				"z": at.z,
				"yaw": wizard.rotation.y,
				"summoning": true,
			}
		)
	)
	if unit:
		FxBus.broadcast(summon_fx, BodyFacts.point(unit, summon_socket))
	return unit


## Returns "" when the creature is free to act, or the reason it was removed.
func finish(unit: Node3D, type: CreatureType) -> String:
	if unit == null or not is_instance_valid(unit):
		return ""
	var purse := wizard.get_node_or_null("SoulPurse") as SoulPurse
	if purse == null or not purse.spend(type.souls):
		unit.queue_free()
		return NO_SOULS
	(unit as UnitBody).finish_summon()
	return ""


func spawn_point() -> Vector3:
	var ahead := wizard.facing_flat()
	var side := Vector3(ahead.z, 0.0, -ahead.x)
	var origin := wizard.global_position
	var first: Variant = _ground_at(origin + ahead * ahead_m)
	if first != null and _is_clear(first):
		return first
	for offset in offsets:
		var spot: Variant = _ground_at(origin + side * offset.x + ahead * offset.y)
		if spot != null and _is_clear(spot):
			return spot
	for i in fallback_tries:
		var spot: Variant = _ground_at(
			origin + ahead.rotated(Vector3.UP, TAU * i / fallback_tries) * fallback_radius
		)
		if spot != null and _is_clear(spot):
			return spot
	return first if first != null else origin


func _ground_at(at: Vector3) -> Variant:
	return GroundRay.surface_point(wizard, at, ground_mask, GroundRay.wizard_rids(get_tree()))


func _is_clear(spot: Vector3) -> bool:
	if spot.y - SacrificeGround.height(wizard, spot) > max_above_land_m:
		return false
	for group in blocker_groups:
		for node in get_tree().get_nodes_in_group(group):
			if not node is Node3D or (node as Node).is_in_group(Corpse.GROUP):
				continue
			var d := (node as Node3D).global_position - spot
			if (
				absf(d.x) <= clear_half_width
				and absf(d.z) <= clear_half_width
				and absf(d.y) <= clear_half_height
			):
				return false
	return true
