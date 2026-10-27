class_name StickImpact
extends ShotImpact

## A shot that sticks to the creature it touches instead of hurting it: the Ikarus's Sticky bomb
## (×0.75) and the Bilemites (×0.8). The bomb that touches the ground or a
## building (not a creature) vanishes; the one that touches a creature of another side that can be stuck to
## sticks to it for ability.duration_s seconds: it is gone at `duration · 60 + 1` updates. No damage.
## The pieces are Clinging's (the body's component): this node only asks it to stick one. The slowdown is PaceFactors'.
## Divergence (declared): a creature that cannot be stuck to (dying, summoning) stops the bomb in the port; in the original
## the bomb flies through it.
## Ref: F129 (RFC-030 030r-a); Ikarus acia, sacengine updateStickyBomb (state.d:25531-25578), canBeStickyBombed = canBePoisoned 25524-25529, `++infectionTime <= updateFPS·duration`.

## Which pile on the body it joins (Clinging.STICKY / Clinging.MITES).
@export var kind: StringName = &"sticky"
## What one piece multiplies the body's pace by (0.75 ^ sticky bombs, 0.8 ^ blight mites).
## Ref: sacengine numStickyBombs, numBlightMites.
@export var factor := 0.75
## Seconds it lasts when the shot has no SPEL (ability.duration_s is the rule).
@export var fallback_seconds := 10.0
## Updates past duration · 60 at which it lets go (the `++infectionTime` runs once more than the frames it holds).
@export var extra_ticks := 1


func _affect(shot: Node3D, target: Node3D, point: Vector3, ability: AbilityType) -> void:
	if target == null or not is_instance_valid(target):
		_log("%s toca suelo en %s" % [shot.name, _vec(point)])
		return
	var poisoning := Poisoning.of(target)
	var clinging := Clinging.of(target)
	if poisoning == null or clinging == null or not poisoning.can_be_poisoned():
		_log("%s se pierde en %s (no se le puede pegar) en %s" % [shot.name, str(target.name), _vec(point)])
		return
	var seconds := ability.duration_s if ability != null and ability.duration_s > 0.0 else fallback_seconds
	var ticks := int(seconds * MatchClock.TICKS_PER_SECOND) + extra_ticks
	_log("%s pega a %s en %s" % [shot.name, str(target.name), _vec(point)])
	clinging.stick(kind, ticks, factor)


func _log(text: String) -> void:
	if DebugLog.on(&"cling"):
		print("bomba %s %s (tick %d)" % [kind, text, MatchClock.now()])


static func _vec(v: Vector3) -> String:
	return "(%.3f, %.3f, %.3f)" % [v.x, v.y, v.z]
