class_name Stunned
extends Affliction

## F120 (RFC-030i-a): sacengine stunned. stunWithCooldown (state.d:8561-8568) refuses while the body's own stun cooldown
## runs or when canStun says no (8546-8553: a rock, a body playing dead, dying, still summoned, already stunned…), then
## holds it for the length of its clips: (knocked2Floor + getUp)·updateAnimFactor ticks on the ground, flyDamage in the
## air (8138-8150, 14170-14212). The cooldown counts from the stun, every tick.
##
## Look: the knock and get_up roles of ClipPose when the model has those clips; the export leaves them out (they would
## add ~1,6 GB to the clip cache), so meanwhile it falls on its side and gets up with a Tween on Tilt.
## WORKAROUND: Tween on Tilt rotation:z in place of the knocked2Floor/getUp mesh clips (disk, RFC-030i-a risk).

## sacengine updateAnimFactor: a 30 fps clip frame lasts 2 ticks of 60.
const FRAME_TICKS := 2

@export var clip_pose: ClipPosePlayer
@export var tilt: Node3D
## Its body_radius lifts the pivot while it lies, as Corpse.lay_down does, so half the body does not sink.
@export var visual: Node3D
@export_group("Fallback look")
## How far it leans on its side while it lies (degrees, about Tilt's z).
@export_range(0.0, 90.0) var fall_deg := 80.0
## The fall takes this long, or the whole knock if that is shorter.
@export var fall_s := 0.35
## In the air: how far it reels.
@export_range(0.0, 90.0) var air_sway_deg := 25.0
## Cut short (it died lying, or another state took over): back to upright in this long. A death leaves the height to
## Corpse, which lays it down from this pose.
@export var cut_s := 0.2

var _cooldown := 0
var _elapsed := 0
var _knock_ticks := 0
var _total := 0
var _airborne := false
var _tween: Tween


func _ready() -> void:
	set_physics_process(false)


## Server (or solo): sacengine stunWithCooldown. True when it stunned.
func stun_with_cooldown(cooldown_ticks: int) -> bool:
	var body := _body()
	if _cooldown > 0 or body == null or not _body_allows(body) or not _afflictions().admit(self):
		return false
	_cooldown = cooldown_ticks
	_afflictions().mark(self, true)
	print("aturdido %s durante %d (cuadro %d)" % [str(body.call("display_name")), _total, Engine.get_physics_frames()])
	return true


## Server (or solo): sacengine damageStun as the end of a petrification calls it (state.d:23732-23739, 8569-8577): the
## stun cooldown is cleared first, then it stuns with the damage-stun cooldown (4 s).
func knock(cooldown_ticks: int) -> bool:
	_cooldown = 0
	return stun_with_cooldown(cooldown_ticks)


func cooldown_ticks() -> int:
	return _cooldown


func clip_role() -> String:
	if _airborne:
		return "fly_damage"
	return "knock" if _elapsed < _knock_ticks else "get_up"


## canStun (state.d:8546-8553), with the port's names: a live, targetable creature (not summoning, held by a doctor,
## playing dead or dead) that is not a rock.
func _body_allows(body: Node3D) -> bool:
	if body.has_method("is_rock_form") and body.call("is_rock_form"):
		return false
	return not body.has_method("is_targetable") or bool(body.call("is_targetable"))


func _physics_process(_delta: float) -> void:
	if _cooldown > 0:
		_cooldown -= 1
	if is_on():
		_elapsed += 1
		if _simulates() and _elapsed >= _total:
			print("%s se levanta (cuadro %d)" % [str(_body().call("display_name")), Engine.get_physics_frames()])
			_afflictions().mark(self, false)
	if _cooldown <= 0 and not is_on():
		set_physics_process(false)


func _shown(on: bool) -> void:
	if on:
		_measure()
		_elapsed = 0
		set_physics_process(true)
	_play_fallback(on)


## The length from the body's clips (CreatureType.stun_animations), on every peer. Without knock or get_up the
## sacengine creature stands in stance1 for one loop; the port uses its rest clip (idle_animation).
func _measure() -> void:
	var body := _body()
	var type := body.get("type") as CreatureType if body else null
	var clips: Dictionary = type.stun_animations if type else {}
	_airborne = body != null and body.has_method("is_flying") and bool(body.call("is_flying"))
	var knock := _frames(clips, "knock")
	var up := _frames(clips, "get_up")
	if _airborne:
		knock = 0
		up = _frames(clips, "fly_damage")
		if up == 0 and type:
			up = int(type.flight_animations.get("fly", {}).get("frames", 0))
	elif knock + up == 0 and type:
		up = int(type.idle_animation.get("frames", 0))
	_knock_ticks = knock * FRAME_TICKS
	_total = maxi(1, (knock + up) * FRAME_TICKS)


static func _frames(clips: Dictionary, role: String) -> int:
	var clip: Variant = clips.get(role, {})
	return int((clip as Dictionary).get("frames", 0)) if clip is Dictionary else 0


func _play_fallback(on: bool) -> void:
	if _tween:
		_tween.kill()
		_tween = null
	if tilt == null:
		return
	if not on:
		if absf(tilt.rotation.z) > 0.0001 or tilt.position.y > 0.0001:
			_tween = tilt.create_tween()
			_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
			_tween.tween_property(tilt, "rotation:z", 0.0, cut_s).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			var health := _afflictions().health
			if health == null or not health.is_dead():
				_tween.parallel().tween_property(tilt, "position:y", 0.0, cut_s)
		return
	if clip_pose and clip_pose.has_role(clip_role()):
		return
	var tick_s := 1.0 / float(Engine.physics_ticks_per_second)
	var knock_s := _knock_ticks * tick_s
	var rest_s := maxf(0.0, (_total - _knock_ticks) * tick_s)
	_tween = tilt.create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	if _airborne:
		_tween.tween_property(tilt, "rotation:z", deg_to_rad(air_sway_deg), rest_s * 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tween.tween_property(tilt, "rotation:z", 0.0, rest_s * 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		return
	var radius := float(visual.call("body_radius")) if visual and visual.has_method("body_radius") else 0.0
	var down_s := minf(fall_s, knock_s)
	if down_s > 0.0:
		_tween.tween_property(tilt, "rotation:z", deg_to_rad(fall_deg), down_s).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.parallel().tween_property(tilt, "position:y", radius, down_s).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.tween_interval(knock_s - down_s)
	else:
		tilt.rotation.z = deg_to_rad(fall_deg)
		tilt.position.y = radius
	_tween.tween_property(tilt, "rotation:z", 0.0, rest_s).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.parallel().tween_property(tilt, "position:y", 0.0, rest_s).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
