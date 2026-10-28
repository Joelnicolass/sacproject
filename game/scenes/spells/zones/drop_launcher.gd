@tool
class_name DropLauncher
extends Node

## Makes the drop of a cloud: when its ZoneDropper says where, it spawns `drop` (a ZoneDrop scene) at its start, with the point it
## must reach, the time it takes and the numbers of the spell. It does not choose where (ZoneDropper) nor move or hurt (ZoneDrop and its
## children). Server (or solo) only.

enum Start { ABOVE_POINT, CLOUD_DISK, CASTER_DISK, ZONE_COLUMN }

@export var zone: GroundZone
@export var dropper: ZoneDropper
## The drop scene it spawns (its root is a ZoneDrop).
@export var drop: PackedScene
@export var start := Start.ABOVE_POINT
## The cloud: a drop of ABOVE_POINT or CLOUD_DISK starts at its height.
@export var cloud_at: Marker3D
## For the disks: how far from their centre it can start, as a share of the spell's effect range.
@export_range(0.0, 2.0, 0.01) var disk_share := 0.5
## CASTER_DISK: how far under the land it starts.
@export_range(0.0, 5.0, 0.1, "suffix:m") var buried_m := 1.0
## The seconds from its start to its goal.
@export_range(0.1, 30.0, 0.1, "suffix:s") var fall_s := 2.0
## ZONE_COLUMN: it starts over the zone's center, at a random height up to this much over the land (a volcano's mouth).
@export_range(0.0, 400.0, 1.0, "suffix:m") var column_m := 120.0
## The drop is shot at the spell's speed, leaning up for its gravity, instead of flying for `fall_s` (a lava ball).
@export var shoots := false

var _rng: RandomNumberGenerator


func _ready() -> void:
	if zone == null or dropper == null or Engine.is_editor_hint() or not zone.is_authority():
		return
	_rng = MatchSeed.rng(["launcher", String(zone.name), String(name)])
	dropper.chosen.connect(_launch)


func _launch(point: Vector3, _body: Node3D) -> void:
	if drop == null:
		push_error("DropLauncher %s: `drop` is empty, nothing falls." % name)
		return
	var spawner := SpellSpawner.of(get_tree())
	if spawner == null:
		return
	var from := _start(point)
	var goal := (
		Vector3(point.x, zone.global_position.y, point.z) if start == Start.ABOVE_POINT else point
	)
	var spell := zone.spell
	var data := {
		"x": from.x,
		"y": from.y,
		"z": from.z,
		"goal": goal,
		"fall_s": fall_s,
		"slot": zone.from_slot,
		"caster": str(zone.caster_path),
		"damage": float(spell.damage),
		"damage_range": spell.damage_range_m,
		"effect_range": spell.effect_range_m
	}
	if shoots:
		data["shot_speed"] = spell.speed_m_s
	spawner.spawn_scene(drop, data)


func _start(point: Vector3) -> Vector3:
	var height := cloud_at.global_position.y if cloud_at != null else point.y
	match start:
		Start.CLOUD_DISK:
			var around := (
				(cloud_at.global_position if cloud_at != null else zone.global_position) + _disk()
			)
			return Vector3(around.x, height, around.z)
		Start.CASTER_DISK:
			var wizard := zone.caster()
			var base := (
				(wizard.global_position if wizard != null else zone.global_position) + _disk()
			)
			return Vector3(
				base.x,
				ZoneGround.height(self, base.x, base.z, zone.global_position.y) - buried_m,
				base.z
			)
		Start.ZONE_COLUMN:
			var mouth := zone.global_position
			return Vector3(
				mouth.x,
				ZoneGround.height(self, mouth.x, mouth.z, mouth.y) + _rng.randf() * column_m,
				mouth.z
			)
	return Vector3(point.x, height, point.z)


func _disk() -> Vector3:
	return ZoneRules.disk_point(_rng, zone.spell.effect_range_m * disk_share)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if zone == null or dropper == null:
		warnings.append("The zone and its ZoneDropper are missing.")
	if drop == null:
		warnings.append("`drop` is empty: drag the drop scene.")
	return warnings
