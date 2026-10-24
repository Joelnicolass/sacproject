@tool
class_name ZoneDropper
extends Node

## What a cloud lets go: while its zone acts, `rate_per_s` times a second it picks where something falls, a point of a disk around the
## zone or, when a body is near, that body, and says so with `chosen`. It does not make what falls (DropLauncher, BoltLauncher) nor time
## the zone (GroundZone). Server (or solo) only; every draw comes from MatchSeed, so one seed gives one rain.
## Ref: sacengine updateRainOfFrogs, updateRainOfFire, updateBombardment, updateCloudkill (state.d:19367-19395, 21099-21131, 21300-21333, 22074-22108).

## `point` stands on the land; `body` is the creature the drop was pulled to (null = a plain point).
signal chosen(point: Vector3, body: Node3D)

@export var zone: GroundZone
@export_range(0.0, 60.0, 0.1, "suffix:/s") var rate_per_s := 3.0
## The disk the points come from: this share of the spell's effect range, around the zone.
@export_range(0.0, 2.0, 0.01) var reach_share := 1.0
enum Pick { PULL_TO_NEAREST, BODY_OR_RING }

## How it chooses: a point of the disk that a body near it pulls (rain, meteorites), or a random body of the disk (with a chance
## that falls as the bodies are few) and otherwise a point of the ring between `ring_min_m` and the disk's edge (a volcano's lava).
@export var pick := Pick.PULL_TO_NEAREST
@export_range(0.0, 100.0, 0.5, "suffix:m") var ring_min_m := 30.0
## BODY_OR_RING: a body is chosen with chance n / (n + decoys), n being the bodies in the disk.
@export_range(0, 16) var decoys := 4
@export_group("Pull to bodies")
## A body this close (flat distance) to the chosen point takes the drop; a body up to `far_m` takes it with `far_chance`.
@export_range(0.0, 100.0, 0.5, "suffix:m") var near_m := 10.0
@export_range(0.0, 100.0, 0.5, "suffix:m") var far_m := 25.0
@export_range(0.0, 1.0, 0.01) var far_chance := 0.667
## Who can pull a drop (Cloudkill's bolt also goes for buildings).
@export var groups: Array[StringName] = [&"wizard", &"unit"]

var _rng: RandomNumberGenerator


func _ready() -> void:
	set_physics_process(not Engine.is_editor_hint() and zone != null and zone.is_authority())
	if is_physics_processing():
		_rng = MatchSeed.rng(["dropper", String(zone.name), String(name)])


func _physics_process(_delta: float) -> void:
	if zone.phase != GroundZone.Phase.ACTIVE or zone.cancelled:
		return
	var per_tick := rate_per_s / MatchClock.TICKS_PER_SECOND_F
	var count := floori(per_tick) + (1 if _rng.randf() < per_tick - floorf(per_tick) else 0)
	for _i in count:
		_choose()


func _choose() -> void:
	var centre := zone.global_position
	var reach := zone.spell.effect_range_m * reach_share
	var spot := centre + ZoneRules.disk_point(_rng, reach)
	var body: Node3D
	if pick == Pick.BODY_OR_RING:
		var angle := _rng.randf_range(-PI, PI)
		spot = centre + Vector3(cos(angle), 0.0, sin(angle)) * _rng.randf_range(ring_min_m, maxf(reach, ring_min_m))
		var crowd := SplashDamage.bodies_within(get_tree(), centre, reach, null, groups)
		if not crowd.is_empty() and _rng.randi_range(0, crowd.size() + decoys - 1) < crowd.size():
			body = crowd[_rng.randi_range(0, crowd.size() - 1)]
	else:
		body = _pulled(centre, spot)
	if body != null:
		spot = BodyNudge.center(body)
	spot.y = ZoneGround.height(self, spot.x, spot.z, centre.y)
	chosen.emit(spot, body)


## The closest body to `spot` among those within the spell's range of the zone, if it is near enough to take the drop.
func _pulled(centre: Vector3, spot: Vector3) -> Node3D:
	var best: Node3D
	var best_d := INF
	for body in SplashDamage.bodies_within(get_tree(), centre, zone.spell.effect_range_m, null, groups):
		var at := BodyNudge.center(body)
		var d := Vector2(at.x - spot.x, at.z - spot.z).length()
		if d < best_d:
			best = body
			best_d = d
	if best == null or best_d >= far_m:
		return null
	return best if best_d < near_m or _rng.randf() < far_chance else null


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if zone != null else PackedStringArray(["Falta la zona (GroundZone) de la que sale lo que cae."])
