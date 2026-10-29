class_name Stunned
extends Affliction

## A creature knocked out for a while. A stun refuses while the body's own stun cooldown runs or
## when it cannot be stunned (a rock, a body playing dead, dying, still summoned, already stunned…),
## then holds it for the length of its clips: (knocked to the floor + get up) ticks on the ground,
## the damage-fly clip in the air. The cooldown counts from the stun, every tick.
##
## A wizard too: its WizardType clips; it never flies.
## Look: the knock, hit_floor and get_up roles of ClipPose when the model has those clips; a model
## without one falls on its side and gets up with a Tween on Tilt.
## WORKAROUND: Tween on Tilt rotation:z, only for a model whose scene lacks the stun clip.

## A 30 fps clip frame lasts 2 ticks of 60.
const FRAME_TICKS := 2

## The state whose landing hands over to this one (tumbling.tres). Then it lies hit_floor + get_up,
## not knock + get_up; a client tells it from Afflictions.previous. Optional: empty = always knock +
## get_up.
@export var fall_type: AfflictionType
@export var clip_pose: ClipPlayback
@export var tilt: Node3D
## Its body_radius lifts the pivot while it lies, as Corpse.lay_down does, so half the body does not
## sink.
@export var visual: Node3D
@export_group("Fallback look")
## How far it leans on its side while it lies (degrees, about Tilt's z).
@export_range(0.0, 90.0) var fall_deg := 80.0
## The fall takes this long, or the whole knock if that is shorter.
@export var fall_s := 0.35
## In the air: how far it reels.
@export_range(0.0, 90.0) var air_sway_deg := 25.0
## Cut short (it died lying, or another state took over): back to upright in this long. A death
## leaves the height to Corpse, which lays it down from this pose.
@export var cut_s := 0.2
## A body whose Corpse lays it down from the lying pose (a creature). Off (a wizard, no Corpse): a
## death also brings the pivot back to 0, or the ghost and the revived wizard would float.
@export var corpse_lays_down := true

var _cooldown := 0
var _elapsed := 0
var _knock_ticks := 0
var _total := 0
var _airborne := false
## Lying after a fall rather than knocked down.
var _from_fall := false
var _tween: Tween


func _ready() -> void:
	set_physics_process(false)


## Server (or solo): stuns with the cooldown rule. True when it stunned.
func stun_with_cooldown(cooldown_ticks: int) -> bool:
	var body := _body()
	if _cooldown > 0 or body == null or not _body_allows(body) or not _afflictions().admit(self):
		return false
	_cooldown = cooldown_ticks
	_from_fall = false
	_afflictions().mark(self, true)
	print("stunned %s for %d (frame %d)" % [_body_name(), _total, MatchClock.now()])
	return true


## Server (or solo): a thrown body landed (Tumbling). It keeps the mode stunned and plays hit_floor,
## then get_up: no stun check, no cooldown (the one it had keeps running).
func fall_down() -> void:
	var body := _body()
	if body == null:
		return
	_from_fall = true
	_afflictions().mark(self, true)
	print(
		(
			"stunned after a fall %s for %d (hit_floor + get_up) (frame %d)"
			% [_body_name(), _total, MatchClock.now()]
		)
	)


## Server (or solo): the stun the end of a petrification calls: the
## stun cooldown is cleared first, then it stuns with the damage-stun cooldown (4 s).
func knock(cooldown_ticks: int) -> bool:
	_cooldown = 0
	return stun_with_cooldown(cooldown_ticks)


func cooldown_ticks() -> int:
	return _cooldown


func clip_role() -> String:
	if _airborne:
		return "fly_damage"
	if _elapsed < _knock_ticks:
		return "hit_floor" if _from_fall else "knock"
	return "get_up"


## Can it be stunned, in this game's terms: a live, targetable creature (not summoning, held by a
## doctor, playing dead or dead) that is not a rock.
func _body_allows(body: Node3D) -> bool:
	if body is UnitBody and (body as UnitBody).is_rock_form():
		return false
	return GameBody.targetable(body)


func _physics_process(_delta: float) -> void:
	if _cooldown > 0:
		_cooldown -= 1
	if is_on():
		_elapsed += 1
		if is_multiplayer_authority() and _elapsed >= _total:
			print("%s gets up (frame %d)" % [_body_name(), MatchClock.now()])
			_afflictions().mark(self, false)
	if _cooldown <= 0 and not is_on():
		set_physics_process(false)


func _shown(on: bool) -> void:
	if on:
		if not is_multiplayer_authority():
			_from_fall = fall_type != null and _afflictions().previous & (1 << fall_type.bit) != 0
		_measure()
		_elapsed = 0
		set_physics_process(true)
	_play_fallback(on)


## The length from the body's clips (the knock, get_up, fly_damage and hit_floor roles of its
## model), on every peer. Without knock or get_up the body plays its `gesture` clip.
func _measure() -> void:
	var body := _body()
	var facts := _clip_facts(body)
	_airborne = body is UnitBody and (body as UnitBody).is_flying()
	var knock := facts.frames(&"hit_floor" if _from_fall else &"knock")
	var up := facts.frames(&"get_up")
	if _from_fall:
		_airborne = false
	elif _airborne:
		knock = 0
		up = facts.frames(&"fly_damage")
		if up == 0:
			up = facts.frames(&"fly")
	elif knock + up == 0:
		up = facts.frames(&"gesture")
	_knock_ticks = knock * FRAME_TICKS
	_total = maxi(1, (knock + up) * FRAME_TICKS)


## What the body says about its clips (a wizard: its WizardType; it has no `type`, which other
## readers take for a creature's), else its CreatureType.
static func _clip_facts(body: Node3D) -> ClipFacts:
	if body is WizardBody:
		var wizard: WizardType = (body as WizardBody).clip_type()
		return wizard.clip_facts() if wizard != null else ClipFacts.of(null)
	var creature: CreatureType = body.get("type") as CreatureType if body else null
	return creature.clip_facts() if creature != null else ClipFacts.of(null)


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
			(
				_tween
				. tween_property(tilt, "rotation:z", 0.0, cut_s)
				. set_trans(Tween.TRANS_SINE)
				. set_ease(Tween.EASE_OUT)
			)
			var health := _afflictions().health
			if health == null or not health.is_dead() or not corpse_lays_down:
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
		(
			_tween
			. tween_property(tilt, "rotation:z", deg_to_rad(air_sway_deg), rest_s * 0.3)
			. set_trans(Tween.TRANS_SINE)
			. set_ease(Tween.EASE_OUT)
		)
		(
			_tween
			. tween_property(tilt, "rotation:z", 0.0, rest_s * 0.7)
			. set_trans(Tween.TRANS_SINE)
			. set_ease(Tween.EASE_IN_OUT)
		)
		return
	var radius := (visual as BodyVisual).body_radius() if visual is BodyVisual else 0.0
	var down_s := minf(fall_s, knock_s)
	if down_s > 0.0:
		(
			_tween
			. tween_property(tilt, "rotation:z", deg_to_rad(fall_deg), down_s)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN)
		)
		(
			_tween
			. parallel()
			. tween_property(tilt, "position:y", radius, down_s)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN)
		)
		_tween.tween_interval(knock_s - down_s)
	else:
		tilt.rotation.z = deg_to_rad(fall_deg)
		tilt.position.y = radius
	_tween.tween_property(tilt, "rotation:z", 0.0, rest_s).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)
	(
		_tween
		. parallel()
		. tween_property(tilt, "position:y", 0.0, rest_s)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
