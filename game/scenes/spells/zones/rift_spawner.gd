class_name RiftSpawner
extends Node

## The mouth of a Demonic Rift: while the rift is open it lets a spirit out every third of a second,
## up to 24. Each spirit goes for the closest creature that is not an ally, inside the spell's range
## of a point drawn around the click and that no spirit went for yet; when there is none, it flies
## to the ground and the next one waits a second. When the last spirit is gone the rift closes. It
## does not move or hit (RiftSpirit) nor draw the rift (the zone's look). Server (or solo) only.

@export var zone: GroundZone
## The spirit scene it lets out (its root is a RiftSpirit).
@export var spirit_scene: PackedScene
@export_range(1, 64) var max_spirits := 24
@export_range(0.05, 5.0, 0.0001, "suffix:s") var every_s := 0.3333
## The wait after a spirit that found no creature.
@export_range(0.05, 5.0, 0.01, "suffix:s") var retry_s := 1.0
## The spirit comes out of the rift's edge, this share of the rift's radius from its middle, toward
## its target.
@export_range(0.0, 1.0, 0.05) var exit_share := 0.6
## The rift's wall, whose mesh gives its radius.
@export var wall: MeshInstance3D

var _out := 0
var _wait := 0
var _targeted := {}
var _alive: Array = []


func _ready() -> void:
	if spirit_scene == null:
		push_error("RiftSpawner %s: `spirit_scene` is empty, no spirit leaves the rift." % name)
	set_physics_process(zone != null and zone.is_authority() and not Engine.is_editor_hint())


func _physics_process(_delta: float) -> void:
	if zone.phase != GroundZone.Phase.ACTIVE:
		return
	_alive = _alive.filter(_is_out)
	if _out >= max_spirits:
		if _alive.is_empty():
			zone.finish()
		return
	_wait -= 1
	if _wait <= 0:
		_wait = MatchClock.ticks_for(every_s if _release() else retry_s)


## How many spirits have left the rift so far.
func spawned() -> int:
	return _out


func _is_out(spirit: Variant) -> bool:
	return is_instance_valid(spirit) and not (spirit as Node).is_queued_for_deletion()


## Sends one spirit out. True when it has a creature to go for.
func _release() -> bool:
	var spawner := SpellSpawner.of(get_tree())
	if spawner == null or spirit_scene == null:
		return true
	var rng := MatchSeed.rng(["rift", String(zone.name), _out])
	var around := zone.aim_point + ZoneRules.disk_point(rng, zone.spell.effect_range_m)
	var body := _closest_foe(around)
	var goal := BodyNudge.center(body) if body != null else around
	var rift := zone.points[0]
	var radius := _radius()
	var outward := Vector3(goal.x - rift.x, 0.0, goal.z - rift.z).normalized()
	var start := rift + outward * radius * exit_share
	var land := Terrain.of(self)
	var ground := land.height_at(start.x, start.z) if land != null else NAN
	start.y = rift.y if is_nan(ground) else ground
	var aimed := Vector3(outward.x, 5.0, outward.z).normalized()
	_out += 1
	var spirit := spawner.spawn_scene(
		spirit_scene,
		{
			"x": start.x,
			"y": start.y,
			"z": start.z,
			"goal": goal,
			"home": rift,
			"velocity": aimed * zone.spell.speed_m_s,
			"target": str(body.get_path()) if body != null else "",
			"slot": zone.from_slot,
			"speed": zone.spell.speed_m_s,
			"acceleration": zone.spell.acceleration_m_s2,
			"damage": float(zone.spell.damage),
			"range": zone.spell.effect_range_m,
			"loud": _out == 1 or rng.randi() % 3 == 0
		}
	)
	if spirit != null:
		_alive.append(spirit)
	if body != null:
		_targeted[body.get_instance_id()] = true
	return body != null


## The closest living creature or wizard that is not an ally, within the spell's range of `point`,
## that no spirit went for yet.
func _closest_foe(point: Vector3) -> Node3D:
	var best: Node3D
	var best_d := INF
	for body in SplashDamage.bodies_within(
		get_tree(), point, zone.spell.effect_range_m, null, ZonePulse.BODY_GROUPS
	):
		var d := BodyNudge.center(body).distance_to(point)
		var stance := SideRelations.stance(zone.from_slot, int(body.get("owner_slot")))
		if (
			d < best_d
			and stance != SideRelations.Stance.ALLY
			and not _targeted.has(body.get_instance_id())
		):
			best = body
			best_d = d
	return best


func _radius() -> float:
	var cylinder := wall.mesh as CylinderMesh if wall != null else null
	return cylinder.top_radius if cylinder != null else 2.5
