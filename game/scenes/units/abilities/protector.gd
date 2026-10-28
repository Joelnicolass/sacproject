class_name Protector
extends AbilityEffect

## The Ent's Protector: a life shield for the Ent and the allies around it. It is refused while the Ent
## already has a life shield (nothing spent); else the Ent takes the life shield and a Protector effect is added.
## The effect runs once, on the next tick: every creature whose center is within effect range (30 m,
## 3D, center to center) of the Ent's, of its side, not itself, valid (alive, on the field) and not a wizard, takes
## the life shield, which refuses one that already has a shield. Statics (buildings) are not creatures.
## The pending tick is MatchClock's (fire tick + 1), processed in _physics_process (priority −1, before the bodies).
## The shield is each body's LifeShield; its time is the hsba spell's duration · 60.

## The shield it gives (data/catalog/abilities/life_shield.tres, Life Shield): its duration is the shield's.
@export var life_shield: AbilityType
## Ticks after fire() at which the allies are shielded (the effect's first update).
@export var allies_delay_ticks := 1
## The debug log also lists the same-side bodies up to this many times effect range, as «fuera».
@export var log_radius_factor := 2.0

## MatchClock tick at which the allies are shielded. -1 = nothing pending.
var _pending_at := -1


func status(_target_pos: Vector3, _target: Node3D) -> String:
	var own := LifeShield.of(user)
	if own == null or own.is_on():
		return Refusal.BAD_TARGET
	return ""


func fire(_target_pos: Vector3, _target: Node3D) -> bool:
	if not is_multiplayer_authority():
		return false
	var own := LifeShield.of(user)
	if own == null or not own.start(shield_ticks()):
		return false
	_pending_at = MatchClock.now() + allies_delay_ticks
	set_physics_process(true)
	return true


## The hsba SPEL's duration in ticks (1200).
func shield_ticks() -> int:
	return LifeShield.ticks_for(life_shield)


func _physics_process(_delta: float) -> void:
	if _pending_at < 0 or MatchClock.now() < _pending_at:
		return
	_pending_at = -1
	set_physics_process(false)
	if _valid(user):
		_shield_allies()


func _shield_allies() -> void:
	var radius := ability.effect_range_m if ability else 30.0
	var origin := BodyNudge.center(user)
	var slot := int(user.get("owner_slot"))
	var ticks := shield_ticks()
	var seen: Array = []
	for node in get_tree().get_nodes_in_group(UnitBody.GROUP):
		var other := node as UnitBody
		if other == null or other == user or int(other.owner_slot) != slot or not _valid(other):
			continue
		var distance := origin.distance_to(BodyNudge.center(other))
		var shield := LifeShield.of(other)
		var verdict := "out"
		if distance <= radius:
			verdict = "no shield"
			if shield:
				verdict = "yes" if shield.start(ticks) else "already had one"
		if DebugLog.on(&"effects") and distance <= radius * log_radius_factor:
			seen.append([distance, "%s %.1f m %s" % [who(other), distance, verdict]])
	if DebugLog.on(&"effects"):
		seen.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		var parts := PackedStringArray()
		for entry in seen:
			parts.append(str(entry[1]))
		print(
			(
				"protector %s: %s (tick %d)"
				% [
					who(user),
					"; ".join(parts) if not parts.is_empty() else "nobody",
					MatchClock.now()
				]
			)
		)


## Alive and on the field (not dead, not being summoned, not taken by a Sac Doctor).
func _valid(body: Node3D) -> bool:
	if body == null or not is_instance_valid(body) or not body is UnitBody:
		return false
	var unit := body as UnitBody
	return not unit.is_dead() and not unit.is_summoning() and not unit.is_taken()
