class_name MeleeSwing
extends RefCounted

## The swing in course: how long it lasts, the frames where its blows land and the share of the damage each carries. It is read
## once when the swing starts, so the ticks that follow read only variables. Not: whether a blow hits (MeleeWeapon).
## An animation without attack events hits on its last frame.

## Used when the model has no attack clip: the humanoid swing, 24 frames at 30 fps with the blow on frame 15.
const FALLBACK_FRAMES := 24
const FALLBACK_RATE := 30.0
const FALLBACK_BLOWS: PackedInt32Array = [15]

var active := false
## Which clip plays: 0 attack, 1 attack2, 2 attack3 (the downward one).
var index := 0
var frames := 0
var rate := FALLBACK_RATE
var blows := PackedInt32Array()
var pending := 0.0
var elapsed := 0.0
var next_tick := 0


## The swing the target calls for: the downward one when it lies below, else a random one of the other two the model has; -1 when
## the model has none (the fallback swing plays). The only draw is the pick between the two.
static func pick(
	facts: ClipFacts,
	body: Node3D,
	target: Node3D,
	height: float,
	downward_threshold: float,
	rng: RandomNumberGenerator
) -> int:
	var own_mid := body.global_position.y + height * 0.5
	var foe_mid := (
		target.global_position.y + float(MeleeRules.profile_of(target).get("height", 1.8)) * 0.5
	)
	if foe_mid + downward_threshold < own_mid and facts.frames(MeleeRules.SWING_ROLES[2]) > 0:
		return 2
	var choices: Array[int] = []
	for swing in 2:
		if facts.frames(MeleeRules.SWING_ROLES[swing]) > 0:
			choices.append(swing)
	return choices[rng.randi() % choices.size()] if not choices.is_empty() else -1


## Reads the numbers of swing `choice` (-1: the fallback) and starts counting from zero.
func begin(facts: ClipFacts, choice: int) -> void:
	active = true
	index = maxi(choice, 0)
	if choice < 0:
		frames = FALLBACK_FRAMES
		rate = FALLBACK_RATE
		blows = FALLBACK_BLOWS
	else:
		var role := MeleeRules.SWING_ROLES[choice]
		frames = facts.frames(role)
		rate = float(facts.fps(role))
		blows = facts.hits(role)
		if blows.is_empty():
			blows = PackedInt32Array([frames - 1])
	pending = float(frames) / (rate * float(maxi(1, blows.size())))
	elapsed = 0.0
	next_tick = 0


## The next blow of the swing is due.
func blow_due() -> bool:
	return next_tick < blows.size() and elapsed >= float(blows[next_tick]) / rate


func ended() -> bool:
	return elapsed >= float(frames) / rate
