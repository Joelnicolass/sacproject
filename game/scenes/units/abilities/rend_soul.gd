class_name RendSoulAbility
extends AbilityEffect

## F157 (RFC-030 030t-b): the Styx's Rend Soul (dner). sacengine useAbility → shoot0 (state.d:13463-13561): the body prepares its
## attack clip (windup_clip 0: 100 ticks) and at the shoot tick shootOnTick calls rendShoot (12750, 13226-13230), which adds the
## effect only if canRend (13219-13225): a soul that is NORMAL or EMERGING, free or of the user's side, not dropped. The mana
## and the cooldown are paid at the shoot tick whether or not the soul is still there (AbilitySlot does it).
## This effect only judges the soul and throws the SoulStrike; what happens the tick after is the strike's.
## Range: the SPEL's cast_range (90) in 3D, to the soul's center.
## Divergence (declared): the body does not walk closer or turn; out of range is refused.

## The strike (strikes/soul_strike.tscn), a child of the user's RangedWeapon.
@export var strike_scene: PackedScene
## The shot's look (data/shots/rend_soul.tscn: the blast at the soul and its sparks). Empty = a plain look with no blast.
@export var look: PackedScene


func status(_target_pos: Vector3, target: Node3D) -> String:
	if ability == null or user == null:
		return Refusal.BAD_TARGET
	var soul := _soul_of(target)
	if not can_rend(soul, _slot()):
		return Refusal.BAD_TARGET
	if user.global_position.distance_to(SoulStrike.center_of_soul(soul)) > ability.cast_range_m:
		return Refusal.OUT_OF_RANGE
	return ""


## canRend: the one answer for the order and for the strike that checks again.
static func can_rend(soul: Soul, slot: int) -> bool:
	return soul != null and is_instance_valid(soul) and soul.is_inside_tree() and not soul.is_queued_for_deletion() \
			and (soul.state == Soul.State.NORMAL or soul.state == Soul.State.EMERGING) \
			and soul.is_free_or_own(slot) and not soul.dropped


## rendShoot. False = the soul is gone by the shoot tick: nothing flies; the mana is spent all the same.
func fire(target_pos: Vector3, target: Node3D) -> bool:
	if not is_multiplayer_authority() or user == null or strike_scene == null:
		return false
	if not status(target_pos, target).is_empty():
		if DebugLog.on(&"effects"):
			print("reventar %s sin blanco válido (tick %d)" % [who(user), MatchClock.now()])
		return false
	var soul := _soul_of(target)
	var parent := user.weapons.ranged
	if parent == null:
		push_warning("RendSoulAbility: %s no tiene RangedWeapon." % who(user))
		return false
	var node := strike_scene.instantiate()
	var strike := node as SoulStrike
	if strike == null:
		node.free()
		push_warning("RendSoulAbility: la escena no es un SoulStrike.")
		return false
	strike.soul = soul
	parent.add_child(strike)
	var origin := ShotAim.shot_position(user)
	var center := SoulStrike.center_of_soul(soul)
	strike.launch({
		"tag": ability.tag,
		"x": origin.x, "y": origin.y, "z": origin.z,
		"aim_x": center.x, "aim_y": center.y, "aim_z": center.z,
		"damage": float(ability.damage),
		"slot": _slot(),
		"max_distance": ability.cast_range_m,
		"target": "",
		"shooter": str(user.get_path()),
	}, ShotLook.make(look), ability, parent)
	return true


## The soul the order was given on: the soul itself or the corpse it waits on.
func _soul_of(target: Node3D) -> Soul:
	if target == null or not is_instance_valid(target):
		return null
	return target as Soul if target is Soul else Soul.on_corpse(target)


func _slot() -> int:
	return int(user.get("owner_slot")) if "owner_slot" in user else 0
