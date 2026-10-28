class_name ZoneDust
extends Node3D

## Dust that rises from the ground around a zone while it is in some of its phases: a few puffs each
## tick at random spots of the disc, most of them near the center, each on the ground where the
## ground is at that moment (so it follows a mound as it lifts). On every peer, from the zone's
## phase; a dedicated server draws nothing. It does not hurt anyone.

@export var zone: GroundZone
## The puff (FxBus, under data/fx/).
@export var type: ParticleType
## Puffs each tick.
@export_range(0, 24) var per_tick := 4
## Most puffs fall within this distance of the center; the rest anywhere within `wide_m`.
@export_range(1.0, 100.0, 0.5, "suffix:m") var near_m := 15.0
@export_range(1.0, 200.0, 0.5, "suffix:m") var wide_m := 50.0
## It puffs from the phase `from_phase` to the phase `to_phase` (inclusive).
@export var from_phase := GroundZone.Phase.CASTING
@export var to_phase := GroundZone.Phase.ARMING

var _rng: RandomNumberGenerator
var _land: Terrain


func _ready() -> void:
	process_physics_priority = 1
	set_physics_process(
		(
			not Engine.is_editor_hint()
			and zone != null
			and type != null
			and DisplayServer.get_name() != "headless"
		)
	)
	_rng = MatchSeed.rng(["zone_dust", String(zone.name) if zone != null else ""])
	_land = Terrain.of(self)


func _get_configuration_warnings() -> PackedStringArray:
	return (
		PackedStringArray()
		if zone != null and type != null
		else PackedStringArray(["The zone (zone) or the particle type (type) is missing."])
	)


func _physics_process(_delta: float) -> void:
	if zone.phase < from_phase or zone.phase > to_phase or _land == null:
		return
	for i in per_tick:
		var angle := _rng.randf() * TAU
		var reach := (
			wide_m * (1.0 - _rng.randf() * _rng.randf())
			if _rng.randi() % 4 == 0
			else near_m * _rng.randf()
		)
		var spot := zone.global_position + Vector3(cos(angle) * reach, 0.0, sin(angle) * reach)
		var ground := _land.height_at(spot.x, spot.z)
		if not is_nan(ground):
			spot.y = ground + global_position.y - zone.global_position.y
			FxBus.puff(type, spot)
