class_name DivineSightEye
extends Node3D

## The eye of the Ranger's Divine Sight that flies and watches the foes.
## DivineSight (the AbilityEffect) spawns it through the ShotSpawner; this node flies it.
## The server (or solo) simulates, the clients get position and scale (MpReplicate) and only draw.
##
## Each tick (frame counts from the tick it was born, the first update is frame 1):
##   lifetime = rising_ticks + duration · 60 (SPEL duration 30 s → 1845 ticks). scale = min(1, frame, lifetime − frame) /
##   (rising_ticks − 1): it grows while it rises and shrinks over the last rising_ticks; the glow's alpha is scale².
##   Rising (frame < rising_ticks = 45): it stays where it was born and only goes up, from half to the whole flying_height (4 m)
##   over the land (or a building top).
##   Then, while it has no target: it flies straight at the SPEL's speed (30 m/s) for range / speed seconds (250 m → 500 ticks) and
##   stops there; every tick it looks for the closest enemy creature within the SPEL's range (250 m) of the eye.
##   With a target: acceleration (3 m/s added per TICK, not per second: the original does not divide it) towards the center of its
##   box, velocity capped at the speed and at «the distance to the center · 60» (so it settles on it); the flying height becomes
##   the target's top over the land + half flying_height. A target that is gone (dead, freed) is dropped for good: the eye keeps the
##   velocity it had and never looks again (target = −1).
##   It never goes under land + flying height: the velocity is not changed but that step is pushed up (capped at the speed).
##   After the rise its Vision (a child) sees, for its side, every foe within the SPEL's effectRange (75 m) of the eye: it looks every
##   refresh_s and the side keeps in mind what it saw for twice that long.
## Ends at the lifetime. It survives the death of the one who cast it.
## Divergences (declared): (1) frontOfAIQueue: the original looks for the target only on the ticks its creature is at the front of the
## side's AI queue; the eye looks every tick. (2) The target is a valid foe by TargetRules.is_valid_foe_of (no stealth, no rock, no
## corpse), the port's one definition. (3) The sight has no terrain line of sight and it marks foes, not a grid of terrain cells (the port has no fog
## of war): it looks on the tick of its own cycle, not at (id + frame) % 30.
## Look: the sprite `scri` (4x4 sheet, 16 frames) on a 2.5 x 2.25 m billboard,
## shadeless, energy 3 (the material's albedo_color), alpha blended with alpha = scale². One cell per 8 ticks (4 x 2), so a cycle is
## 128 ticks. Each copy runs its own clock from the tick it appears (presentation only:
## a client has no frame count, so it counts physics ticks itself).
## Ref: F165 (RFC-030); Ranger eesd, sacengine DivineSight (state.d:5058-5067), updateDivineSight 25159-25214, SacDivineSight renderer.d:882-891 and 3517-3530, animationDelay, updateAnimFactor.

signal ended

const GROUP := &"divine_sight_eye"

## How high over the land the eye flies (m).
## Ref: sacengine divineSightFlyingHeight.
@export var flying_height := 4.0
## How long the eye rises before it flies.
## Ref: sacengine divineSightNumRisingFrames (45 ticks).
@export_range(0.0333, 10.0, 0.0001, "suffix:s") var rising_s := 0.75
## How often the eye looks again; the side keeps what it saw twice as long.
## Ref: sacengine updateVision `refresh` = updateFPS / 2.
@export_range(0.0166, 5.0, 0.0001, "suffix:s") var refresh_s := 0.5
## Who may be the target: the moving bodies of the creature type.
## Ref: sacengine.
@export var target_groups: Array[StringName] = [&"wizard", &"unit"]
## The sprite (a MeshInstance3D with its own StandardMaterial3D whose uv1_scale is one cell); its alpha follows scale².
@export var glow: MeshInstance3D
## What the eye sees for the side of the Ranger who sent it (its radius is the SPEL's effectRange).
@export var vision: Vision
## Cells of the sprite sheet (scri.png) and how long each one stays (4 x 2 ticks).
## Ref: sacengine animationDelay, updateAnimFactor.
@export var frames_h := 4
@export var frames_v := 4
@export_range(0.0166, 1.0, 0.0001, "suffix:s") var frame_s := 0.1333


## rising_s in ticks (the frames count ticks).
var rising_ticks: int:
	get: return MatchClock.ticks_for(rising_s)
var slot := 0
var ability: AbilityType
var velocity := Vector3.ZERO
## The creature it homes on; null while it still looks, or once it was dropped (`lost`).
var target: Node3D
var lost := false
var frame := 0

var _born := -1
var _last_frame := 0
var _last_land := 0.0
var _shooter_name := ""
var _material: StandardMaterial3D
var _first_tick := 0


## The packet of DivineSight.fire (ShotSpawner.spawn_scene): name, x/y/z, vx/vy/vz (m/s), slot, tag, shooter (its name, for the log).
## `eye_ability`: the ability the packet's `tag` names (ShotSpawner turns the text into it).
func setup(data: Dictionary, eye_ability: AbilityType) -> void:
	name = str(data["name"])
	position = Vector3(float(data["x"]), float(data["y"]), float(data["z"]))
	velocity = Vector3(float(data["vx"]), float(data["vy"]), float(data["vz"]))
	slot = int(data.get("slot", 0))
	ability = eye_ability
	_shooter_name = str(data.get("shooter", ""))
	vision.side_slot = slot
	vision.radius_m = eye_ability.effect_range_m
	vision.refresh_s = refresh_s
	vision.forget_s = refresh_s * 2.0
	vision.watching = false
	_last_land = position.y
	scale = Vector3.ONE * 0.001
	## The spawn packet lists the synchronizers that exist now (a late joiner's copy must already have them).
	var net := MpReplicate.new()
	net.name = "Net"
	net.sync_properties = PackedStringArray([".:position", ".:scale"])
	MpAuthority.ensure_sync(self, net.sync_properties)
	add_child(net)


func _ready() -> void:
	add_to_group(GROUP)
	if glow and glow.material_override is StandardMaterial3D:
		_material = (glow.material_override as StandardMaterial3D).duplicate()
		glow.material_override = _material
	_first_tick = Engine.get_physics_frames()
	if not is_multiplayer_authority():
		set_physics_process(false)
		return
	_born = MatchClock.now()
	if DebugLog.on(&"eye"):
		print("ojo %s de %s nace en (%.3f, %.3f, %.3f) v (%.3f, %.3f, %.3f) lado %d (cuadro %d)" % [name, _shooter_name, position.x,
			position.y, position.z, velocity.x, velocity.y, velocity.z, slot, _born])


func _process(_delta: float) -> void:
	if _material:
		_material.albedo_color.a = clampf(scale.x * scale.x, 0.0, 1.0)
		var cells := frames_h * frames_v
		var cell := posmod(floori(float(Engine.get_physics_frames() - _first_tick) / maxi(1, MatchClock.ticks_for(frame_s))), cells)
		_material.uv1_offset = Vector3(float(cell % frames_h) / frames_h, float(floori(float(cell) / frames_h)) / frames_v, 0.0)


func _physics_process(_delta: float) -> void:
	if _born < 0 or ability == null:
		return
	var now := MatchClock.now() - _born
	if now <= _last_frame:
		return
	for step_frame in range(_last_frame + 1, now + 1):
		if not _step(step_frame):
			set_physics_process(false)
			if DebugLog.on(&"eye"):
				print("ojo %s termina (cuadro %d)" % [name, MatchClock.now()])
			ended.emit()
			queue_free()
			return
	_last_frame = now


func lifetime_ticks() -> int:
	return rising_ticks + roundi(ability.duration_s * MatchClock.TICKS_PER_SECOND_F) if ability else rising_ticks


## updateDivineSight: false when the eye is over.
func _step(at_frame: int) -> bool:
	frame = at_frame
	var lifetime := float(lifetime_ticks())
	var grown := minf(1.0, minf(float(frame), lifetime - float(frame)) / float(rising_ticks - 1))
	scale = Vector3.ONE * maxf(grown, 0.001)
	if frame < rising_ticks:
		position.y = _height(position) + 0.5 * flying_height + float(frame) * (0.5 * flying_height) / float(rising_ticks - 1)
		return true
	if not vision.watching:
		vision.watching = true
	var flying := flying_height
	if target == null and not lost:
		var travel := frame - rising_ticks
		if float(travel) * ability.speed_m_s < MatchClock.TICKS_PER_SECOND_F * ability.cast_range_m:
			velocity = velocity.normalized() * ability.speed_m_s
		elif float(travel - 1) * ability.speed_m_s < MatchClock.TICKS_PER_SECOND_F * ability.cast_range_m:
			velocity = Vector3.ZERO
		target = _closest_foe()
		if target and DebugLog.on(&"eye"):
			print("ojo %s fija %s en el cuadro %d (a %.3f m)" % [name, target.name, MatchClock.now(), BodyNudge.center(target).distance_to(position)])
	elif target != null:
		if _alive(target):
			var box := BodyNudge.box(target)
			var center := box.get_center()
			flying = box.end.y - _height(center) + 0.5 * flying_height
			var offset := center - position
			velocity += offset.normalized() * ability.acceleration_m_s2
			if velocity.length() > ability.speed_m_s:
				velocity = velocity.normalized() * ability.speed_m_s
			if velocity.length() > MatchClock.TICKS_PER_SECOND_F * offset.length():
				velocity = velocity.normalized() * offset.length() * MatchClock.TICKS_PER_SECOND_F
		else:
			if DebugLog.on(&"eye"):
				print("ojo %s suelta su blanco (cuadro %d)" % [name, MatchClock.now()])
			target = null
			lost = true
	var next := position + velocity / MatchClock.TICKS_PER_SECOND_F
	var land := _height(position)
	if next.y < land + flying:
		var pushed := velocity
		pushed.y += (land + flying - next.y) * MatchClock.TICKS_PER_SECOND_F
		if pushed.length() > ability.speed_m_s:
			pushed = pushed.normalized() * ability.speed_m_s
		next = position + pushed / MatchClock.TICKS_PER_SECOND_F
	position = next
	return float(frame) < lifetime


## The closest enemy creature (or wizard) within the SPEL's range of the eye, or null. Ties keep the first in group order.
func _closest_foe() -> Node3D:
	var best: Node3D
	var best_distance := ability.cast_range_m
	for group in target_groups:
		for node in get_tree().get_nodes_in_group(group):
			var body := node as Node3D
			if body == null or not TargetRules.is_valid_foe_of(slot, body):
				continue
			var distance := BodyNudge.center(body).distance_to(position)
			if distance <= ability.cast_range_m and (best == null or distance < best_distance):
				best = body
				best_distance = distance
	return best


## isValidTarget(target, creature): still in the world and not dead.
func _alive(body: Node3D) -> bool:
	if not is_instance_valid(body) or not body.is_inside_tree() or body.is_in_group(Corpse.GROUP):
		return false
	var health := body.get_node_or_null("Health") as Health
	return health != null and not health.is_dead()


## The top of the land or a building under `at`. Over a hole (no collider) the last height found.
## Ref: sacengine getHeight.
func _height(at: Vector3) -> float:
	var land := RangedShot.land_height(self, at)
	if land > -INF:
		_last_land = land
	return _last_land
