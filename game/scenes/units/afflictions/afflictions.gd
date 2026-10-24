@tool
class_name Afflictions
extends Node3D

## F120 (RFC-030i): the one owner of «can this creature act?». Its Affliction children are the states (Stunned; later
## Petrified, Frozen), each with its AfflictionType. The body and the rest ask here, never a child:
## holds() (no AI, attack, turn or ability), immobilized() (not even pushed), drops_fliers(), damage_factor(),
## cc_protected() and clip_role(). Who wins between two states is the data's (`AfflictionType.cancels`), not the order of the children.
##
## The server (or solo) decides; `shown` (one bit per type) is replicated, so on a client a state is on exactly when
## its bit is, and the children draw it from there. It is a Node3D (like its children) so the looks under a state follow the body.

## The state that holds the body started (true) or the last one ended (false), or one that ends its special mode started
## or ended (F155, REVIEW-030r-b B1: a Rockform already held by the oil that is petrified changes `holds()` not at all).
## Idempotent for the listeners (the body cancels its attacks and closes Rockform). Every peer.
signal held_changed(held: bool)

## What a layer of a spell state (SpellAffliction) multiplies in a fight: how long swings and shots take, how well the body hits.
enum Stat { ATTACK_TIME, ACCURACY }

@export var body: Node3D
## On its death every state ends (sacengine: a dying creature leaves stunned).
@export var health: Health
## F149: the one owner of the frozen pose. While a state that immobilizes is on (petrified, frozen) the clip holds,
## on every peer from the replicated mask. Optional: empty = no pose to hold.
@export var clip_pose: ClipPlayback
## F149 (REVIEW-030k-b B1): the one owner of the mesh look. The tint of the state with a look (AfflictionType.has_look)
## and the highest look_priority among the ones that are on (petrified over frozen); none = off. A ward that turns the skin to stone
## (Skin of Stone) is plain stone when no state has a look. Every peer, from the
## mask, so two states that change in the same tick cannot undress each other. Optional: empty = no look.
@export var look: StoneLook
## F158: the body's wards. While one that counts as a shield is on the body is ccProtected (stats.d:86-90: shielded). Optional: empty = a shield does not protect.
@export var wards: Wards
## The bits of the states that are on (AfflictionType.bit). Replicated by the unit's MultiplayerSynchronizer.
@export var shown := 0:
	set(value):
		if value == shown:
			return
		var was := shown
		shown = value
		if is_node_ready() and not Engine.is_editor_hint():
			_show(was)


## The mask as it was before the last change of `shown` (every peer). A state that takes over from another in the same
## tick reads it (F121: Stunned after a Tumbling that landed lies hitFloor + getUp, not knock + getUp).
var previous := 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	AfflictionGlows.attach(self)
	if wards != null:
		wards.changed.connect(_show_look)
	if health and (not MpKit.is_networked() or MpKit.is_server()):
		health.died.connect(_on_died)
	if shown != 0:
		_show(0)


## The Afflictions of `node`, or null (a body without one is never afflicted).
static func of(node: Node) -> Afflictions:
	for child in node.get_children() if node else []:
		if child is Afflictions:
			return child
	return null


## What `node`'s spell states multiply `stat` by (1 without Afflictions): melee swing and shot time x5 a layer, melee accuracy and evasion x0.2.
static func stat_factor_of(node: Node, stat: Stat) -> float:
	var owner_node := of(node)
	return owner_node.stat_factor(stat) if owner_node else 1.0


## What `node`'s spell states add to its resistances (0 without Afflictions): Slime +0.2 a layer.
static func resistance_bonus_of(node: Node) -> float:
	var owner_node := of(node)
	return owner_node.resistance_bonus() if owner_node else 0.0


func is_on(type: AfflictionType) -> bool:
	return type != null and shown & (1 << type.bit) != 0


func holds() -> bool:
	return _any(&"holds")


## A state that is on takes the body out of the world: not an obstacle, not a target (Firewalking).
func hides() -> bool:
	return _any(&"hides")


func immobilized() -> bool:
	return _any(&"immobilizes")


## F159: a state that is on holds the body where it is (Vined: pins, sacengine effects.vined → fixed).
func pins() -> bool:
	return _any(&"pins")


## sacengine effects.fixed (state.d:8588-8590): a petrified, frozen or pinned body. The one answer to «can it be moved from outside?».
func fixed() -> bool:
	return immobilized() or pins()


## sacengine regenerationBlocked (stats.d:83): a body that is immobilized (petrified, frozen) or has a state that is on that stops it
## (Vined, Rings of Fire, Slime). Health.regenerate asks.
func blocks_regeneration() -> bool:
	return immobilized() or _any(&"blocks_regeneration")


## A state that is on lets a flier fall (petrified; Flight reads it).
func drops_fliers() -> bool:
	return _any(&"drops_fliers")


## A state that is on ends the body's special mode (petrified ends Rockform).
func breaks_special_modes() -> bool:
	return _any(&"breaks_special_modes")


## Product of the factors of the states that are on (1 with none). Health multiplies every hit by it, on both of its
## paths (damage and damage_typed): petrified ×0.2 (state.d:8965), stunned ×1.
func damage_factor() -> float:
	if shown == 0:
		return 1.0
	var factor := 1.0
	for affliction in _on():
		factor *= affliction.type.damage_factor
	return factor


## The state of `type` on this body, or null.
func child_for(type: AfflictionType) -> Affliction:
	for child in get_children():
		var affliction := child as Affliction
		if affliction != null and affliction.type == type:
			return affliction
	return null


## Product of what the states that are on make `stat` (1 with none). Server: the layers are counted there.
func stat_factor(stat: Stat) -> float:
	var factor := 1.0
	for affliction in _on() if shown != 0 else []:
		if affliction is SpellAffliction:
			factor *= (affliction as SpellAffliction).stat_factor(stat)
	return factor


## Sum of what the states that are on add to every resistance (0 with none). Server.
func resistance_bonus() -> float:
	var bonus := 0.0
	for affliction in _on() if shown != 0 else []:
		if affliction is SpellAffliction:
			bonus += (affliction as SpellAffliction).resistance_bonus()
	return bonus


func cc_protected() -> bool:
	if wards != null and wards.shielded():
		return true
	return _any(&"cc_protects")


## Server: the body's velocity for this tick, as the states that are on say (F121: a Tumbling body flies its ballistic
## path, sacengine CreatureMovement.tumbling). With none, `velocity` as it came. The body calls it once per tick, after
## its own gravity and before BodyAvoidance and move_and_slide.
func steer(velocity: Vector3, delta: float) -> Vector3:
	if shown == 0:
		return velocity
	for affliction in _on():
		velocity = affliction.steer(velocity, delta)
	return velocity


## The clip role of the first state that is on and says one; "" when none.
func clip_role() -> String:
	if shown == 0:
		return ""
	for affliction in _on():
		var role := affliction.clip_role()
		if not role.is_empty():
			return role
	return ""


## The role `clip_pose` shows while a state says one: that role when the model has its clip, else idle (the Tween of
## the state draws the rest). "" = no state says one. UnitBody and WizardBody both play this.
func pose_role(clip_pose: ClipPlayback) -> String:
	var role := clip_role()
	if role.is_empty() or clip_pose == null or clip_pose.has_role(role):
		return role
	return "idle"


## Server: may `affliction` start? Every state that is on must be one it cancels (so a stunned body refuses a second
## stun, sacengine canStun state.d:8546-8553). The ones it cancels end here. F155: a type that `coexists` (Oiled) skips the
## states that are on, and a state that is on and coexists is skipped by the others (neither direction refuses or cancels).
func admit(affliction: Affliction) -> bool:
	if affliction.type == null or (body and not body.is_inside_tree()):
		return false
	var cancelled: Array[Affliction] = []
	for other in _on():
		if affliction.type.coexists or other.type.coexists:
			continue
		if not affliction.type.cancels.has(other.type.id):
			return false
		cancelled.append(other)
	for other in cancelled:
		mark(other, false)
	return true


## Server: puts the bit of `affliction` on or off.
func mark(affliction: Affliction, on: bool) -> void:
	var bit := 1 << affliction.type.bit
	shown = (shown | bit) if on else (shown & ~bit)


## Is a state that is on flagged `flag` (a bool of its AfflictionType)? The one loop behind holds(), hides(), pins()...
func _any(flag: StringName) -> bool:
	if shown == 0:
		return false
	for affliction in _on():
		if affliction.type.get(flag):
			return true
	return false


func _on() -> Array[Affliction]:
	var found: Array[Affliction] = []
	for child in get_children():
		var affliction := child as Affliction
		if affliction and affliction.type and is_on(affliction.type):
			found.append(affliction)
	return found


func _show(was: int) -> void:
	previous = was
	var was_held := false
	var was_breaking := false
	for child in get_children():
		var affliction := child as Affliction
		if affliction == null or affliction.type == null:
			continue
		var bit := 1 << affliction.type.bit
		if was & bit != 0 and affliction.type.holds:
			was_held = true
		if was & bit != 0 and affliction.type.breaks_special_modes:
			was_breaking = true
		if (was & bit) != (shown & bit):
			affliction._shown(shown & bit != 0)
			affliction.shown_changed.emit(shown & bit != 0)
	if clip_pose:
		clip_pose.frozen = immobilized()
	_show_look()
	var held := holds()
	if held != was_held or breaks_special_modes() != was_breaking:
		held_changed.emit(held)


## Idempotent: the look follows the mask, whatever changed and in whatever order.
func _show_look() -> void:
	if look == null:
		return
	var best: AfflictionType = null
	var swap: Texture2D = null
	for affliction in _on():
		var type := affliction.type
		if type.has_look and (best == null or type.look_priority > best.look_priority):
			best = type
		if type.look_texture != null:
			swap = type.look_texture
	look.swap_texture = swap
	var skin := wards != null and wards.stone_skin()
	if best:
		look.apply(best.look_tint, best.look_base, best.look_gain, best.look_roughness, best.look_metallic)
	elif skin:
		look.apply_stone()
	look.stone = best != null or skin


func _on_died(_from_slot: int) -> void:
	shown = 0


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if body == null:
		warnings.append("Falta body: el cuerpo que los estados detienen.")
	if health == null:
		warnings.append("Falta health: sin ella los estados no terminan al morir.")
	return warnings
