class_name Affliction
extends Node3D

## F120 (RFC-030i): one state that takes the creature out of the fight (Stunned; later Petrified, Frozen). A child of
## Afflictions, which owns the questions the body asks and the replicated mask. Whether it is on is that mask's bit
## (`type.bit`), the same on the server and on the clients. Variants start themselves (stun_with_cooldown, petrify…)
## through Afflictions.admit/mark and draw themselves in _shown().

## The state went on (true) or off (false). Every peer, from the replicated mask: whoever draws it (a look, an emitter) listens here.
signal shown_changed(on: bool)

@export var type: AfflictionType


func is_on() -> bool:
	var owner_node := _afflictions()
	return owner_node != null and type != null and owner_node.is_on(type)


## F158: an on-hit passive (MeleeOnHit) or a spell lays this state on the body with `spell` from the side `from_slot`. True when it
## took hold. Default: this state is not laid that way.
func inflict(_spell: SpellType, _from_slot: int) -> bool:
	return false


## A spell lays this state on the body with `spell` from the side `from_slot` (AfflictAction). True when it took hold. Default: the
## same as an on-hit passive; a state that a spell starts in its own way (Frozen: no Yeti cooldown) overrides it.
func lay(spell: SpellType, from_slot: int) -> bool:
	return inflict(spell, from_slot)


## `lay`, for a state that may not last longer than `max_s` seconds (the Vinewall: never more than what is left of the wall). A state whose
## length does not come from the spell ignores the cap.
func lay_within(spell: SpellType, from_slot: int, _max_s: float) -> bool:
	return lay(spell, from_slot)


## How many ticks `lay` would hold the state on this body under `spell` (0 = it would not take). The AI rates a spell by it.
func lay_ticks(_spell: SpellType) -> int:
	return 0


## sacengine's crowd-control lifetime (Freeze 10701-10702, Grasping Vines 10806): cast(int)ceil(updateFPS · duration), duration =
## (wizard ? 0.25 : 1000 / max health) · the SPEL's duration. Plain GDScript floats (RFC-036e): a tick of difference from
## sacengine's float32 is accepted. 0 for a creature with no health.
static func cc_ticks(wizard: bool, max_health: float, spell_duration: float, creature_k := 1000.0, wizard_factor := 0.25) -> int:
	var seconds := wizard_factor * spell_duration
	if not wizard:
		if max_health <= 0.0:
			return 0
		seconds = creature_k / max_health * spell_duration
	return ceili(float(MatchClock.TICKS_PER_SECOND) * seconds)


## The clip role the body plays while it is on ("" = it does not say).
func clip_role() -> String:
	return ""


## Server, every tick while it is on: the body's velocity (Afflictions.steer). Default: it does not move the body.
func steer(velocity: Vector3, _delta: float) -> Vector3:
	return velocity


## Every peer, when its bit changes: start or stop the look (and the local clock of the clip). Also when Afflictions
## ends it on the server (a state that cancels it started, or the body died).
func _shown(_on: bool) -> void:
	pass


func _afflictions() -> Afflictions:
	return get_parent() as Afflictions


func _body() -> Node3D:
	var owner_node := _afflictions()
	return owner_node.body if owner_node else null


## The body's name for the log.
func _body_name() -> String:
	return str(_body().call("display_name"))  # dynamic: the body is a unit or a wizard


func _simulates() -> bool:
	return not MpKit.is_networked() or MpKit.is_server()
