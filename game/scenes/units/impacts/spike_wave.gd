class_name SpikeWave
extends Node3D

## F151 (RFC-030 030n-b): the Rhinok's rings of spikes, sacengine RhinokProjectile phase spreading (state.d:4996-5025,
## updateRhinokProjectile 24942-25037). SpikeImpact puts it in the shots' container where the shot burst (on the land),
## server (or solo) only. Its frame is MatchClock.now() − the tick it was born (sacengine: frame 0 is the update of
## the hit). On frame damage_frames[i] (14, 29, 44, 59, 89) ring i hurts; on frame `life_ticks` (90) it ends.
## Ring i goes from min_radius + i·offset to that + strip, offset = (effect_range − strip − min_radius) / (rings − 1):
## with hrba (effectRange 30) [1, 7], [6,75, 12,75], [12,5, 18,5], [18,25, 24,25], [24, 30].
## Who a ring hurts (the callback of dealDamageAt, 24985-25001): every live creature, wizard and building whose hit box
## is within the ring's outer radius of the center (dealDamageAt's walk) and whose feet are, seen from above, between
## its two radii; on the land and at most `max_height` over it; not the body the shot hit; not an ally of the shooter
## unless it is the shot's target (skipped here, before Health, whatever the friendly fire). Each takes the whole
## amount as splash ranged damage (dealRangedDamage, DamageMod.splash): one hit per ring; a body that stands where two
## rings overlap (6,75 to 7 m, …) takes both, as in sacengine.
## sacengine axes (x, y, z up) are the port's (x, z, y up). Effects run before creatures (state.d:29331): priority −1.
## Deviations (declared): an ally is a body of the shooter's slot (sacengine: the stance of the sides); the spikes
## (Spike effects, 25023-25030, spreadingSpikeRate 30 per update on the growing circle) are presentation and are drawn
## ring by ring: on each damage frame one SpikeField event (FxBus.broadcast_scene, one RPC) fills that ring's strip
## with `spikes_per_m2` spikes (at most `max_spikes`), so the strip that hurts is the strip that bristles; they stand
## `spike_life_s` (shorter than sacengine's 2/3 s, so one ring stands at a time).

const _HEALTH := preload("res://scenes/components/health.gd")
const _SPLASH := preload("res://scenes/world/spells/splash_damage.gd")

## sacengine damageFrames (15−1, 30−1, 45−1, 60−1, 90−1).
@export var damage_frames: PackedInt32Array = PackedInt32Array([14, 29, 44, 59, 89])
## sacengine stripSize: the width of a ring (m).
@export var strip := 6.0
## sacengine minRadius: the inner radius of the first ring (m).
@export var min_radius := 1.0
## sacengine maxDamageHeight: a body higher than this over the land is not hurt (m).
@export var max_height := 10.0
## sacengine numProjectileFrames: the last frame (the wave ends after it).
@export var life_ticks := 90
## The SPEL's effectRange (hrba: 30 m); SpikeImpact writes it. The outer radius of the last ring and of the spikes.
@export var effect_range := 30.0
## The spikes of a ring: SpikeField scene played by FxBus on every peer (empty: none).
@export_file("*.tscn") var spike_scene := "res://scenes/fx/spike_field.tscn"
## Spikes per square meter of a ring's strip (sacengine keeps about 30 per update · 40 updates = 1200 standing on the
## circle at full radius).
@export var spikes_per_m2 := 1.0
@export_range(0, 2000) var max_spikes := 1000
## sacengine placeSpike(…, 2.5) while spreading.
@export var spike_height := 2.5
## How long a ring's spikes stand (s). sacengine: 2/3 s, but spawned all the time on the growing circle; here a ring is
## one event every 15 frames, so 0,4 s (24 frames) keeps one ring standing at a time and the ring reads from above.
@export var spike_life_s := 0.4

## What SpikeImpact hands over (before begin()).
var amount := 0.0
var from_slot := 0
## F164b: the creature that fired the shot, as an absolute path (the shot may be gone); its drain feeds on every ring.
var attacker_path := NodePath()
## The shot's target (sacengine intendedTarget) and the body the shot hurt (actualTarget), or null.
var intended: Node3D
var touched: Node3D
## For the log: the shot's tag and name.
var label := ""

var _born := -1
var _last_frame := 0


## SpikeImpact, once it is in the tree where the shot burst: this tick is frame 0 (sacengine hitframe).
func begin() -> void:
	_born = MatchClock.now()
	if DebugLog.on(&"spikes"):
		_log_start()


func _physics_process(_delta: float) -> void:
	if _born < 0:
		return
	var frame := MatchClock.now() - _born
	if frame <= _last_frame:
		return
	for i in damage_frames.size():
		if damage_frames[i] > _last_frame and damage_frames[i] <= frame:
			_ring(i, damage_frames[i])
	_last_frame = frame
	if frame >= life_ticks:
		if DebugLog.on(&"spikes"):
			print("anillos %s fin +%d (cuadro %d)" % [label, frame, MatchClock.now()])
		set_physics_process(false)
		queue_free()


## sacengine: offset = (effectRange − stripSize − minRadius) / (damageFrames.length − 1).
func ring_bounds(i: int) -> Vector2:
	var rings := damage_frames.size()
	var offset := (effect_range - strip - min_radius) / float(rings - 1) if rings > 1 else 0.0
	var inner := min_radius + float(i) * offset
	return Vector2(inner, inner + strip)


## One ring: the callback of dealDamageAt (state.d:24985-25001) for every body of its walk.
func _ring(i: int, frame: int) -> void:
	var bounds := ring_bounds(i)
	var center := global_position
	if DebugLog.on(&"spikes"):
		print("anillo %d/%d %s +%d de %.2f a %.2f m (cuadro %d)" % [i + 1, damage_frames.size(), label, frame, bounds.x,
			bounds.y, MatchClock.now()])
	_bristle(i, bounds)
	var skip: Node3D = touched if touched != null and is_instance_valid(touched) else null
	for body in _SPLASH.bodies_within(get_tree(), center, bounds.y, skip):
		var health := body.get_node_or_null("Health") as Health
		if health == null or health.maximum <= 0.0:
			continue
		var feet := body.global_position
		var distance := Vector2(feet.x - center.x, feet.z - center.z).length()
		if distance < bounds.x or distance > bounds.y:
			continue
		var why := _excluded(body, feet)
		if DebugLog.on(&"spikes"):
			print("  anillo %d %s a %.3f m: %s" % [i + 1, body.name, distance, why if not why.is_empty() else "daño"])
		if why.is_empty():
			_SPLASH.hurt(body, amount, from_slot, _HEALTH.SPLASH_RANGED, 0, get_node_or_null(attacker_path) if not attacker_path.is_empty() else null)


## One SpikeField event that fills ring i's strip (presentation, every peer).
func _bristle(i: int, bounds: Vector2) -> void:
	if spike_scene.is_empty() or spikes_per_m2 <= 0.0:
		return
	var area := PI * (bounds.y * bounds.y - bounds.x * bounds.x)
	FxBus.broadcast_scene(spike_scene, global_position, {"inner": bounds.x, "outer": bounds.y,
		"count": mini(max_spikes, ceili(area * spikes_per_m2)), "height": spike_height, "life": spike_life_s,
		"seed": MatchSeed.derive(["spikes", label, _born, i])})


## Why the ring leaves `body` out (sacengine's callback order: land, height, ally), or "" when it hurts it.
func _excluded(body: Node3D, feet: Vector3) -> String:
	if not BodyNudge.on_land(body, feet):
		return "fuera de la tierra"
	if feet.y > BodyNudge.ground_y(body, feet) + max_height:
		return "alto"
	var is_intended := intended != null and is_instance_valid(intended) and body == intended
	var side := int(body.get("owner_slot")) if "owner_slot" in body else 0
	if not is_intended and from_slot > 0 and side == from_slot:
		return "aliado, sin daño"
	return ""



func _log_start() -> void:
	var rings := PackedStringArray()
	for i in damage_frames.size():
		var bounds := ring_bounds(i)
		rings.append("+%d [%.2f, %.2f]" % [damage_frames[i], bounds.x, bounds.y])
	var at := global_position
	print("anillos %s en (%.3f, %.3f, %.3f) alcance %.1f m daño %d bando %d pedido %s tocado %s anillos %s (cuadro %d)" % [
		label, at.x, at.y, at.z, effect_range, roundi(amount), from_slot, _name_of(intended), _name_of(touched),
		", ".join(rings), _born])
	## Every body the rings may weigh, where it stands now (the replica walks the same list).
	for body in _SPLASH.bodies_within(get_tree(), at, effect_range + 10.0):
		var feet := body.global_position
		var health := body.get_node_or_null("Health") as Health
		var side := int(body.get("owner_slot")) if "owner_slot" in body else 0
		print("anillos %s cuerpo %s pies (%.3f, %.3f, %.3f) suelo %.3f tierra %s bando %d vida máx %d" % [label,
			body.name, feet.x, feet.y, feet.z, BodyNudge.ground_y(body, feet),
			"sí" if BodyNudge.on_land(body, feet) else "no", side, roundi(health.maximum) if health else 0])


static func _name_of(body: Node3D) -> String:
	return str(body.name) if body != null and is_instance_valid(body) else "nadie"
