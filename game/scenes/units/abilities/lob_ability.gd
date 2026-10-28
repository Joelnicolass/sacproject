class_name LobAbility
extends AbilityEffect

## An ability that lobs `shots` ballistic shots at the target: the Ikarus's Sticky bomb (10 bombs,
## spread 0.2), the Pyrodactyl's Viscous oil (1 shot, spread 0) and the Bilemites (030 later).
## The body prepares (AbilitySlot's windup()) and at the shoot tick
## the shots fly and the mana is drained (the cooldown if it was 0).
## Each shot: direction = the way to the target, plus 0.5·g·d/speed² up, with
## the ranged accuracy (ShotAim.scatter: 2 draws), plus `spread` · a uniform direction (3 draws; a point of the cube [−1, 1]³,
## normalized); v = direction · speed, NOT normalized (the bomb flies a little faster or slower than
## the spell's speed). The stream is MatchSeed.rng(["lob", user, tick]): the same match and tick give the same volley.
## The target: an enemy creature is aimed at by its center led by its pace (like RangedWeapon);
## anything else is the point (the ground): an ally as the target is treated as the ground.
## Range: the spell's cast_range, to the aimed point.
## The shots are RangedShot of the shot container with the look `look` (gravity `falling`:
## 20 for mites, sticky bombs, oil, bombardment); what each does where it lands is that look's ShotImpact (StickImpact).
## They carry no intended target, so one of the shooter's own side is never hit.
## Limits: the shot leaves from ShotAim.origin (the body's front at shot_height, not the animation's hand); a
## shot that flies off the map ends at flight_limit meters.

## Shots per use (the Sticky bomb fires 10, the oil one).
@export var shots := 10
## Scale of the random push added to each direction (0.2·a random direction).
@export var spread := 0.2
## The shots' gravity in m/s². Also what the aim lifts the direction by.
@export var falling := 20.0
## The shot leaves from the body's front at this fraction of its height (as RangedWeapon.shot_height).
@export var shot_height := 0.7
## The shots' look (data/shots/sticky_bomb.tscn); empty = the ability's own `shot_look`.
@export var look: PackedScene
## A shot that has not hit anything flies at most this far.
@export var flight_limit := 300.0


func status(target_pos: Vector3, target: Node3D) -> String:
	if ability == null or user == null:
		return Refusal.BAD_TARGET
	if user.global_position.distance_to(_aim_point(target_pos, target)) > ability.cast_range_m:
		return Refusal.OUT_OF_RANGE
	return ""


## True once the volley left (the mana is spent even if every shot misses). False when there is nothing to shoot with.
func fire(target_pos: Vector3, target: Node3D) -> bool:
	if not is_multiplayer_authority() or ability == null or user == null:
		return false
	var spawner := ShotSpawner.of(user.get_tree())
	if spawner == null:
		push_warning("LobAbility: no ShotSpawner in the world.")
		return false
	var origin := ShotAim.origin(user, shot_height)
	var offset := _aim_point(target_pos, target) - origin
	var tick := MatchClock.now()
	var rng := MatchSeed.rng(["lob", who(user), tick])
	var accuracy := _accuracy()
	var look_id := FxWire.id_of(look if look != null else ability.shot_look)
	for index in shots:
		# A zero offset stays a zero direction (offset.length == 0 ? offset : normalized).
		var direction := offset.normalized() if offset.length_squared() > 0.0 else offset
		direction.y += 0.5 * falling * offset.length() / (ability.speed_m_s * ability.speed_m_s)
		direction = ShotAim.scatter(direction, accuracy, rng)
		direction += spread * _uniform_direction(rng)
		var velocity := direction * ability.speed_m_s
		var shot := spawner.spawn_shot({
			"tag": ability.tag,
			"look": look_id,
			"x": origin.x, "y": origin.y, "z": origin.z,
			"vx": velocity.x, "vy": velocity.y, "vz": velocity.z,
			"damage": float(ability.damage),
			"slot": int(user.get("owner_slot")) if "owner_slot" in user else 0,
			"gravity": falling,
			"max_distance": flight_limit,
			"target": "",
			"intended": str(target.get_path()) if _is_foe(target) else "",
			"shooter": str(user.get_path()),
		})
		if DebugLog.on(&"effects"):
			print("lob %s %s shot %d/%d %s v (%.4f, %.4f, %.4f) origin (%.4f, %.4f, %.4f) (tick %d)" % [
				who(user), ability.tag, index + 1, shots, shot.name if shot else "?", velocity.x, velocity.y, velocity.z,
				origin.x, origin.y, origin.z, tick])
	return true


## A point of the cube [−1, 1]³, normalized. The draws are the simulation's: do not reorder them.
func _uniform_direction(rng: RandomNumberGenerator) -> Vector3:
	return LobAbility.uniform_direction(rng)


## The cube point, 3 draws (MiteHop's too).
static func uniform_direction(rng: RandomNumberGenerator) -> Vector3:
	return Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized()


## What the volley aims at: an enemy creature's center, led by its pace; anything else (ground, ally, nothing) the point.
func _aim_point(target_pos: Vector3, target: Node3D) -> Vector3:
	if not _is_foe(target):
		return target_pos
	var center := BodyNudge.center(target)
	if ability == null or ability.speed_m_s <= 0.0 or not target is CharacterBody3D:
		return center
	var moving := (target as CharacterBody3D).velocity
	moving.y = 0.0
	return center + moving * (user.global_position.distance_to(center) / ability.speed_m_s)


## A live body of another side: the only kind a lob aims at (an ally is the ground).
func _is_foe(target: Node3D) -> bool:
	if target == null or not is_instance_valid(target) or not "owner_slot" in target or not "owner_slot" in user:
		return false
	if int(target.get("owner_slot")) == int(user.get("owner_slot")):
		return false
	return ProjectileTargets.is_live_body(target)


func _accuracy() -> float:
	var type: CreatureType = user.get("type")
	return float(type.ranged_accuracy_milli()) if type else 0.0
