@tool
class_name BoltLauncher
extends Node

## Cloudkill's bolt: when its ZoneDropper says where, a lightning bolt leaves the cloud for the body (or the point of the land) and, when
## it arrives, its splash hurts what stands near. The bolt (LightningStrike) does the flight and the damage to the body it reaches; this
## adds only the splash. It does not choose where (ZoneDropper). Server (or solo) only.

@export var zone: GroundZone
@export var dropper: ZoneDropper
## The bolt's scene (scenes/units/abilities/lightning_strike.tscn).
@export var bolt: PackedScene
## Where the bolt leaves from: the cloud.
@export var cloud_at: Marker3D


func _ready() -> void:
	if not Engine.is_editor_hint() and zone != null and dropper != null and zone.is_authority():
		dropper.chosen.connect(_launch)


func _launch(point: Vector3, body: Node3D) -> void:
	var strike := LightningStrike.launch(
		bolt,
		self,
		zone.caster(),
		cloud_at.global_position,
		body,
		point,
		float(zone.spell.damage),
		zone.spell.tag
	)
	if strike != null:
		strike.struck.connect(_splash)


## The splash of the bolt on whatever is within the spell's damage range of where it arrived, but the body it hit.
func _splash(body: Node3D, at: Vector3) -> void:
	SplashDamage.deal(
		get_tree(),
		at,
		float(zone.spell.damage),
		zone.spell.damage_range_m,
		body,
		zone.from_slot,
		Health.SPLASH_SPELL
	)


func _get_configuration_warnings() -> PackedStringArray:
	return (
		PackedStringArray()
		if zone != null and dropper != null and bolt != null and cloud_at != null
		else PackedStringArray(
			["The zone, its ZoneDropper, the bolt and the cloud (Marker3D) are missing."]
		)
	)
