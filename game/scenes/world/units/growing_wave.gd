class_name GrowingWave
extends ShotInFlight

## F149 (RFC-030 030k-b), generalised by F162 (030w-c): a creature's wave that grows while it flies. The Silverback's
## Icy Breath (rdba, sacengine updateSilverbackProjectile, state.d:24758-24831), the Spitfire's fire wave (fhba,
## updateSpitfireProjectile, 23025-23069) and the Gargoyle's wave (ehba, updateGargoyleProjectile, 23079-23113) are the
## same walk; only what a touched body takes besides the damage changes, and that is a WaveTouch child.
## The wave flies straight through everything (ShotLook.collides off: no body, no ground) for its range and grows:
## on its update number n (frame = n − 1) its radius is final_radius · frame / (60 · range / speed). Every update it
## walks the bodies whose hit box is within that radius (dealDamageAt with the callback of the shooter) and each body is
## taken once in the whole flight (damagedTargets):
##   the shot's target: the whole amount as direct ranged damage (dealRangedDamage) with the shot's mods;
##   a body of the shooter's side: nothing;
##   any other body: amount · (1 − d / radius) as splash ranged damage with the shot's mods.
## Each WaveTouch child adds its effect: before_hit and after_hit around the damage of every body that takes it, and
## settled() at the end of the update (FreezeTouch: Silverback, IgniteTouch: Spitfire; the Gargoyle's wave has none).
## The wave's mist is presentation: ShotLook.trail_fx on every peer.
## Deviation (declared): on its first update the radius is 0 and the port's walk (SplashDamage.bodies_within) takes
## nobody; sacengine takes a body whose box holds the point.

const _HEALTH := preload("res://scenes/world/components/health.gd")
const _SPLASH := preload("res://scenes/world/spells/splash_damage.gd")
const TICKS := float(MatchClock.TICKS_PER_SECOND)

## sacengine final*ProjectileSize: the radius at the end of the range (m). Silverback and Spitfire 7,5, Gargoyle 6.
@export var final_radius := 7.5
## A body in one of these groups takes the damage only (sacengine TargetType.building).
@export var building_groups: Array[StringName] = [&"structure"]
## Print the start of the wave and every body it touches. Off in the product; the bench (debug/ai_match.gd) turns it
## on for every wave (agent/tools/f149_expect.py and f162_expect.py read it).
static var log_touches := false

## The bodies already taken (damagedTargets): each one once in the whole flight.
var _touched := {}
var _touches: Array[WaveTouch] = []


func _ready() -> void:
	for child in get_children():
		if child is WaveTouch:
			_touches.append(child)


## One update: the radius of this frame, the walk (damage and the touches around it), then settled().
func _fly(shot: RangedShot, at: Vector3) -> void:
	var amount := shot.damage
	var from_slot := shot.from_slot
	var radius := radius_at(ticks - 1, shot)
	if ticks == 1 and log_touches:
		_log_start(shot, at)
	var intended := _intended(shot)
	var shooter := ShotImpact.shooter_of(shot)
	for body in _SPLASH.bodies_within(get_tree(), at, radius):
		var health := body.get_node_or_null("Health") as Health
		if _touched.has(body) or health == null or health.maximum <= 0.0:
			continue
		_touched[body] = true
		var distance := _SPLASH.box_distance(body, at)
		if body == intended:
			_log_touch(shot, body, at, distance, radius, "directo")
			var direct_states := _before(body, true, shot)
			_SPLASH.hurt(body, amount, from_slot, _HEALTH.DIRECT_RANGED, shot.mods, shooter)
			_after(body, true, direct_states, shot)
			continue
		if from_slot > 0 and _side(body) == from_slot:
			_log_touch(shot, body, at, distance, radius, "mismo bando")
			continue
		_log_touch(shot, body, at, distance, radius, "salpicadura")
		var splash_states := _before(body, false, shot)
		_SPLASH.hurt(body, amount * maxf(0.0, 1.0 - distance / radius), from_slot, _HEALTH.SPLASH_RANGED, shot.mods, shooter)
		_after(body, false, splash_states, shot)
	for touch in _touches:
		touch.settled(shot)


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


## True when the body is a building (sacengine TargetType.building): a touch may skip it.
func is_building(body: Node) -> bool:
	for group in building_groups:
		if body.is_in_group(group):
			return true
	return false


## The states the touches read before the damage (WaveTouch.before_hit), in the order of the children.
func _before(body: Node3D, direct: bool, shot: RangedShot) -> Array:
	var states := []
	for touch in _touches:
		states.append(touch.before_hit(body, direct, shot, self))
	return states


func _after(body: Node3D, direct: bool, states: Array, shot: RangedShot) -> void:
	for i in _touches.size():
		_touches[i].after_hit(body, direct, states[i], shot)


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
