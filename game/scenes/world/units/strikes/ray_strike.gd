class_name RayStrike
extends ShotStrike

## F124 (RFC-030 030m): instant rays, cast on given ticks. The Gnome (gnome_ray.tscn: one ray on tick 0, gnomeShoot
## state.d:11724-11735) and the Warmonger's gun (warmonger_gun.tscn, 030m-b: 16 bursts of 2 rays from tick 2, one every
## 4, WarmongerGun 11815-11819, 24121-24135, 11833-11850).
##
## A ray (`_cast`) is sacengine collideRay with `entry.id != attacker && isValidTarget`: it goes `max_distance` from the
## shot origin and stops on the first live body that is not the shooter, of any side, or on the ground or a structure
## (`stop_mask`). The damage is ShotImpact.land on the body it stopped on; with `foes_only` a body of the shooter's side
## that is not the intended target stops the ray and takes nothing (Health is not asked). The hit FX (ShotLook.impact_fx)
## plays where the ray ends, hit or not, and `beam` (FxBus) goes from the origin to there, or `beam_length` along it.

## How many bursts the strike fires before it ends.
@export_range(1, 64) var bursts := 1
## Tick of the first burst (0 = the tick of the shot).
@export_range(0, 120) var first_tick := 0
## Ticks between two bursts.
@export_range(1, 120) var period_ticks := 4
## Rays per burst.
@export_range(1, 8) var rays_per_burst := 1
## Each ray draws the accuracy again around the aimed point (ShotAim.scatter with a stream of its own). Off: every ray
## goes along the shot's direction (accuracy drawn once by RangedAttack).
@export var reroll := false
## Every burst leaves from the shooter's shot origin of that tick, and the strike ends when the shooter is no longer
## live. Off: from the origin of the shot.
@export var follow := false
## A body of the shooter's side that is not the intended target stops the ray and takes nothing. Off: Health decides
## (friendly fire, Health._side_factor).
@export var foes_only := false
## FxBus beam type (res://data/fx/beams/) drawn from the origin of each ray. Empty: none.
@export var beam := ""
## Meters of the beam along the ray: a gun flame at the muzzle (the Gnome's GnomeEffect, createGunFlameMeshes length
## 1.7, sacobject.d:4268-4283). 0: the whole ray, to where it ends.
@export_range(0.0, 200.0, 0.1, "suffix:m") var beam_length := 0.0
## Word for the strike in the log of a cut (`<label> <tag> cortada: …`).
@export var label := "rayo"
## What stops a ray besides the bodies: ground (1) and structures (2).
@export_flags_3d_physics var stop_mask := 3

var _bursts_fired := 0
var _rng: RandomNumberGenerator


func _strike_tick(age: int) -> void:
	if follow and (shooter() == null or not is_instance_valid(source)):
		_log("%s %s cortada: tirador muerto tras la ráfaga %d/%d" % [label, tag, _bursts_fired, bursts])
		finish()
		return
	if age < first_tick or (age - first_tick) % period_ticks != 0:
		return
	var from: Vector3 = source.shot_origin() if follow else origin
	_bursts_fired += 1
	if bursts > 1:
		_log("ráfaga %d/%d %s %s (tick %d)" % [_bursts_fired, bursts, tag, shooter_name(), MatchClock.now()])
	for _i in rays_per_burst:
		_cast(from, _ray_direction(from))
	if _bursts_fired >= bursts:
		finish()


func _ray_direction(from: Vector3) -> Vector3:
	if not reroll:
		return velocity.normalized() if velocity.length_squared() > 0.000001 else (aim - from).normalized()
	if _rng == null:
		_rng = MatchSeed.rng(["gun", shooter_name(), _born_tick])
	var offset := aim - from
	var direction := offset.normalized() if offset.length_squared() > 0.000001 else offset
	return ShotAim.scatter(direction, accuracy, _rng).normalized()


## One ray from `from` along `direction`: where it ends, what it hit, and what lands there.
func _cast(from: Vector3, direction: Vector3) -> void:
	var to := from + direction * max_distance
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = stop_mask
	var skip: Array[RID] = []
	var shooter_body: Node = get_node_or_null(shooter_path) if not shooter_path.is_empty() else null
	if shooter_body is CollisionObject3D:
		skip.append((shooter_body as CollisionObject3D).get_rid())
	var end := to
	var body: Node3D = null
	var stopped := false
	for _try in 16:
		query.exclude = skip
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			break
		var collider := hit.get("collider") as Node3D
		if collider != null and Attackable.is_body(collider) and not _ROCK.is_live_body(collider):
			var object := collider as CollisionObject3D
			if object == null:
				break
			skip.append(object.get_rid())
			continue
		end = hit.get("position")
		stopped = true
		if collider != null and Attackable.is_body(collider):
			body = collider
		break
	if not beam.is_empty():
		FxBus.broadcast_beam(beam, from, from + direction * beam_length if beam_length > 0.0 else end)
	var distance := from.distance_to(end)
	if body == null:
		_land(null, end)
		_log("rayo %s %s → %s a %.1f m (tick %d)" % [tag, shooter_name(), "suelo" if stopped else "nada", distance, MatchClock.now()])
		return
	var ally := _is_ally(body)
	var mark := " (aliado)" if ally else ""
	var wanted: Node = get_node_or_null(target_path) if not target_path.is_empty() else null
	if foes_only and ally and body != wanted:
		_land(null, end)
		_log("rayo %s %s → %s%s a %.1f m: sin daño (aliado) (tick %d)" % [tag, shooter_name(), _name_of(body), mark, distance, MatchClock.now()])
		return
	var taken := _land(body, end)
	_log("rayo %s %s → %s%s a %.1f m: %.1f (tick %d)" % [tag, shooter_name(), _name_of(body), mark, distance, taken, MatchClock.now()])


func _is_ally(body: Node3D) -> bool:
	return from_slot > 0 and "owner_slot" in body and int(body.get("owner_slot")) == from_slot


## Node names in the log: unique on the field (Druid2), unlike display names.
static func _name_of(body: Node) -> String:
	return str(body.name)
