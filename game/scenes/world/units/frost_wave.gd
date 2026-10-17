class_name FrostWave
extends ShotInFlight

## F149 (RFC-030 030k-b): the Silverback's Icy Breath (rdba), sacengine updateSilverbackProjectile (state.d:24758-24831).
## The breath flies straight through everything (ShotLook.collides off: no body, no ground) for its range and grows:
## on its update number n (frame = n − 1) its radius is finalSilverbackProjectileSize · frame / (60 · range / speed),
## 7,5 m at the end. Every update it walks the bodies whose hit box is within that radius (dealDamageAt with the
## Silverback's callback) and each body is taken once in the whole flight (damagedTargets):
##   the shot's target: the whole amount as direct ranged damage (dealRangedDamage), then tryFreezeWithCooldown;
##   a body of the shooter's side: nothing;
##   any other body: amount · (1 − d / radius) as splash ranged damage; a creature or a wizard that was not frozen when
##     the breath touched it tries to freeze at the end of the update (toFreeze);
##   a building: the damage only.
## The freeze is the body's own Afflictions/Frozen (tryFreezeWithCooldown with the SPEL `zerf`).
## The breath's mist (SilverbackEffect, ParticleType.freeze) is presentation: ShotLook.trail_fx on every peer.
## Deviation (declared): on its first update the radius is 0 and the port's walk (SplashDamage.bodies_within) takes
## nobody; sacengine takes a body whose box holds the point.

const _HEALTH := preload("res://scenes/world/components/health.gd")
const _SPLASH := preload("res://scenes/world/spells/splash_damage.gd")
const TICKS := float(MatchClock.TICKS_PER_SECOND)

## sacengine finalSilverbackProjectileSize: the radius at the end of the range (m).
@export var final_radius := 7.5
## The SPEL of the freeze a touched body may take (zerf: 20 s, 150 of spell damage when it thaws).
@export var freeze_spell := "zerf"
## The Frozen state under each body.
@export var frozen_path := NodePath("Afflictions/Frozen")
## A body in one of these groups takes the damage only (sacengine TargetType.building).
@export var building_groups: Array[StringName] = [&"structure"]
## Print the start of the breath and every body it touches. Off in the product; the bench (debug/ai_match.gd) turns it
## on for every breath (agent/tools/f149_expect.py reads it).
static var log_touches := false

## The bodies already taken (damagedTargets): each one once in the whole flight.
var _touched := {}
var _spell: SpellType
var _warned := false


## updateSilverbackProjectile, one update: the radius of this frame, the walk, then the bodies to freeze.
func _fly(shot: RangedShot, at: Vector3) -> void:
	var amount := shot.damage
	var from_slot := shot.from_slot
	var radius := radius_at(ticks - 1, shot)
	if ticks == 1 and log_touches:
		_log_start(shot, at)
	var intended := _intended(shot)
	var to_freeze: Array[Frozen] = []
	for body in _SPLASH.bodies_within(get_tree(), at, radius):
		var health := body.get_node_or_null("Health") as Health
		if _touched.has(body) or health == null or health.maximum <= 0.0:
			continue
		_touched[body] = true
		var frozen: Frozen = null if _is_building(body) else body.get_node_or_null(frozen_path) as Frozen
		var can_freeze := frozen != null and not frozen.is_on()
		var distance := _SPLASH.box_distance(body, at)
		if body == intended:
			_log_touch(shot, body, at, distance, radius, "directo")
			_SPLASH.hurt(body, amount, from_slot, _HEALTH.DIRECT_RANGED)
			if can_freeze:
				frozen.try_freeze_with_cooldown(_freeze_spell(), from_slot)
			continue
		if from_slot > 0 and _side(body) == from_slot:
			_log_touch(shot, body, at, distance, radius, "mismo bando")
			continue
		_log_touch(shot, body, at, distance, radius, "salpicadura")
		_SPLASH.hurt(body, amount * maxf(0.0, 1.0 - distance / radius), from_slot, _HEALTH.SPLASH_RANGED)
		if can_freeze:
			to_freeze.append(frozen)
	for frozen in to_freeze:
		if is_instance_valid(frozen):
			frozen.try_freeze_with_cooldown(_freeze_spell(), from_slot)


## The radius on `frame` (0 on the first update): final_radius · frame / (60 · range / speed), from the shot's SPEL;
## without one, from the shot's own range and speed.
func radius_at(frame: int, shot: RangedShot) -> float:
	var ability := shot.ability
	var reach := ability.cast_range if ability else shot.max_distance
	var speed := ability.speed if ability else shot.velocity.length()
	if speed <= 0.0 or reach <= 0.0 or not is_finite(reach):
		return 0.0
	return final_radius * float(frame) / (TICKS * reach / speed)


func _intended(shot: RangedShot) -> Node:
	return null if shot.target_path.is_empty() else shot.get_node_or_null(shot.target_path)


func _freeze_spell() -> SpellType:
	if _spell == null:
		_spell = GameData.spell(freeze_spell)
		if _spell == null and not _warned:
			_warned = true
			push_warning("FrostWave: GameData no tiene el SPEL %s." % freeze_spell)
	return _spell


func _is_building(body: Node) -> bool:
	for group in building_groups:
		if body.is_in_group(group):
			return true
	return false


static func _side(body: Node) -> int:
	return int(body.get("owner_slot")) if "owner_slot" in body else 0


func _log_start(shot: RangedShot, at: Vector3) -> void:
	var velocity := shot.velocity
	var direction := velocity.normalized()
	var target := _intended(shot)
	print("onda %s tick 1 en (%.3f, %.3f, %.3f) dir (%.5f, %.5f, %.5f) paso %.4f radio final %.2f en %.4f ticks a %s (cuadro %d)" % [
		shot.name, at.x, at.y, at.z, direction.x, direction.y, direction.z, velocity.length() / TICKS, final_radius,
		final_radius / maxf(radius_at(1, shot), 0.000001), str(target.name) if target else "nadie", MatchClock.now()])


func _log_touch(shot: RangedShot, body: Node3D, at: Vector3, distance: float, radius: float, what: String) -> void:
	if not log_touches:
		return
	print("onda %s toca %s tick %d en (%.3f, %.3f, %.3f) a %.3f m radio %.3f %s: %s" % [shot.name, str(body.name),
		ticks, at.x, at.y, at.z, distance, radius, _box_text(body), what])


## The hit box SplashDamage measures against, for the log (a capsule, cylinder or box under Collision, axis-aligned).
static func _box_text(body: Node3D) -> String:
	var col := body.get_node_or_null("Collision") as CollisionShape3D
	if body.has_method("hit_box") or col == null or col.shape == null or col.shape is BoxShape3D:
		return "caja ?"
	var half := Vector3(0.3, 0.9, 0.3)
	if col.shape is CapsuleShape3D:
		var capsule := col.shape as CapsuleShape3D
		half = Vector3(capsule.radius, capsule.height * 0.5, capsule.radius)
	elif col.shape is CylinderShape3D:
		var cylinder := col.shape as CylinderShape3D
		half = Vector3(cylinder.radius, cylinder.height * 0.5, cylinder.radius)
	var center := col.global_position
	return "caja (%.3f, %.3f, %.3f) ± (%.3f, %.3f, %.3f)" % [center.x, center.y, center.z, half.x, half.y, half.z]


func _exit_tree() -> void:
	if ticks > 0 and log_touches:
		print("onda %s %d actualizaciones, %d tocados" % [get_parent().name, ticks, _touched.size()])
