class_name SpikeWave
extends Node3D

## The Rhinok's rings of spikes. SpikeImpact puts it in the shots' container where the shot burst (on the land),
## server (or solo) only. Its frame is MatchClock.now() − the tick it was born (frame 0 is the update of
## the hit). At damage_at_s[i] (14, 29, 44, 59, 89 ticks) ring i hurts; at `life_s` (90 ticks) it ends.
## Ring i goes from min_radius + i·offset to that + strip, offset = (effect_range − strip − min_radius) / (rings − 1):
## with hrba (effect range 30) [1, 7], [6,75, 12,75], [12,5, 18,5], [18,25, 24,25], [24, 30].
## Who a ring hurts: every live creature, wizard and building whose hit box
## is within the ring's outer radius of the center and whose feet are, seen from above, between
## its two radii; on the land and at most `max_height` over it; not the body the shot hit; not an ally of the shooter
## unless it is the shot's target (skipped here, before Health, whatever the friendly fire). Each takes the whole
## amount as splash ranged damage: one hit per ring; a body that stands where two
## rings overlap (6,75 to 7 m, …) takes both.
## Effects run before creatures: priority −1.
## An ally is a body of the shooter's slot; the spikes
## (spread at 30 per update on the growing circle) are presentation and are drawn
## ring by ring: on each damage frame one SpikeField event (FxBus.broadcast_scene, one RPC) fills that ring's strip
## with `spikes_per_m2` spikes (at most `max_spikes`), so the strip that hurts is the strip that bristles; they stand
## `spike_life_s`, so one ring stands at a time.

const _HEALTH := preload("res://scenes/components/health.gd")
const _SPLASH := preload("res://scenes/spells/splash_damage.gd")

## When each ring hurts, after the hit.
@export
var damage_at_s: PackedFloat64Array = PackedFloat64Array([0.2333, 0.4833, 0.7333, 0.9833, 1.4833])
## The width of a ring (m).
@export var strip := 6.0
## The inner radius of the first ring (m).
@export var min_radius := 1.0
## A body higher than this over the land is not hurt (m).
@export var max_height := 10.0
## How long the wave lasts (it ends after it).
@export_range(0.0, 10.0, 0.0001, "suffix:s") var life_s := 1.5
## The SPEL's effect range (hrba: 30 m); SpikeImpact writes it. The outer radius of the last ring and of the spikes.
@export var effect_range := 30.0
## The spikes of a ring: spike_field.tscn (an FxScene) played by FxBus on every peer (empty: none).
@export var spike_scene: PackedScene
## Spikes per square meter of a ring's strip.
@export var spikes_per_m2 := 1.0
@export_range(0, 2000) var max_spikes := 1000
## How tall a spike is while spreading.
@export var spike_height := 2.5
## How long a ring's spikes stand (s). A ring is one event every 15 frames, so 0,4 s (24 frames) keeps one ring standing at a time and the ring reads from above.
@export var spike_life_s := 0.4

## What SpikeImpact hands over (before begin()).
var amount := 0.0
var from_slot := 0
## The creature that fired the shot, as an absolute path (the shot may be gone); its drain feeds on every ring.
var attacker_path := NodePath()
## The shot's target and the body the shot hurt, or null.
var intended: Node3D
var touched: Node3D
## For the log: the shot's tag and name.
var label := ""

var _born := -1
var _last_frame := 0


## SpikeImpact, once it is in the tree where the shot burst: this tick is frame 0.
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
	for i in damage_at_s.size():
		var at := MatchClock.ticks_for(damage_at_s[i])
		if at > _last_frame and at <= frame:
			_ring(i, at)
	_last_frame = frame
	if frame >= MatchClock.ticks_for(life_s):
		if DebugLog.on(&"spikes"):
			print("rings %s end +%d (frame %d)" % [label, frame, MatchClock.now()])
		set_physics_process(false)
		queue_free()


## offset = (effect range − strip − min_radius) / (damage frames − 1).
func ring_bounds(i: int) -> Vector2:
	var rings := damage_at_s.size()
	var offset := (effect_range - strip - min_radius) / float(rings - 1) if rings > 1 else 0.0
	var inner := min_radius + float(i) * offset
	return Vector2(inner, inner + strip)


## One ring: the damage callback for every body of its walk.
func _ring(i: int, frame: int) -> void:
	var bounds := ring_bounds(i)
	var center := global_position
	if DebugLog.on(&"spikes"):
		print(
			(
				"ring %d/%d %s +%d from %.2f to %.2f m (frame %d)"
				% [i + 1, damage_at_s.size(), label, frame, bounds.x, bounds.y, MatchClock.now()]
			)
		)
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
			print(
				(
					"  ring %d %s at %.3f m: %s"
					% [i + 1, body.name, distance, why if not why.is_empty() else "damage"]
				)
			)
		if why.is_empty():
			_SPLASH.hurt(
				body,
				amount,
				from_slot,
				_HEALTH.SPLASH_RANGED,
				0,
				get_node_or_null(attacker_path) if not attacker_path.is_empty() else null
			)


## One SpikeField event that fills ring i's strip (presentation, every peer).
func _bristle(i: int, bounds: Vector2) -> void:
	if spike_scene == null or spikes_per_m2 <= 0.0:
		return
	var area := PI * (bounds.y * bounds.y - bounds.x * bounds.x)
	FxBus.broadcast_scene(
		spike_scene,
		global_position,
		{
			"inner": bounds.x,
			"outer": bounds.y,
			"count": mini(max_spikes, ceili(area * spikes_per_m2)),
			"height": spike_height,
			"life": spike_life_s,
			"seed": MatchSeed.derive(["spikes", label, _born, i])
		}
	)


## Why the ring leaves `body` out (checked in order: land, height, ally), or "" when it hurts it.
func _excluded(body: Node3D, feet: Vector3) -> String:
	if not BodyNudge.on_land(body, feet):
		return "off the land"
	if feet.y > BodyNudge.ground_y(body, feet) + max_height:
		return "alto"
	var is_intended := intended != null and is_instance_valid(intended) and body == intended
	var side := int(body.get("owner_slot")) if "owner_slot" in body else 0
	if not is_intended and from_slot > 0 and side == from_slot:
		return "ally, no damage"
	return ""


func _log_start() -> void:
	var rings := PackedStringArray()
	for i in damage_at_s.size():
		var bounds := ring_bounds(i)
		rings.append(
			"+%d [%.2f, %.2f]" % [MatchClock.ticks_for(damage_at_s[i]), bounds.x, bounds.y]
		)
	var at := global_position
	print(
		(
			"rings %s at (%.3f, %.3f, %.3f) range %.1f m damage %d side %d intended %s touched %s rings %s (frame %d)"
			% [
				label,
				at.x,
				at.y,
				at.z,
				effect_range,
				roundi(amount),
				from_slot,
				_name_of(intended),
				_name_of(touched),
				", ".join(rings),
				_born
			]
		)
	)
	# Every body the rings may weigh, where it stands now (the replica walks the same list).
	for body in _SPLASH.bodies_within(get_tree(), at, effect_range + 10.0):
		var feet := body.global_position
		var health := body.get_node_or_null("Health") as Health
		var side := int(body.get("owner_slot")) if "owner_slot" in body else 0
		print(
			(
				"rings %s body %s feet (%.3f, %.3f, %.3f) ground %.3f land %s side %d max health %d"
				% [
					label,
					body.name,
					feet.x,
					feet.y,
					feet.z,
					BodyNudge.ground_y(body, feet),
					"yes" if BodyNudge.on_land(body, feet) else "no",
					side,
					roundi(health.maximum) if health else 0
				]
			)
		)


static func _name_of(body: Node3D) -> String:
	return str(body.name) if body != null and is_instance_valid(body) else "nobody"
