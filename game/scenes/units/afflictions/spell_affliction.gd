class_name SpellAffliction
extends Affliction

## A temporary state a spell lays on a body, one layer for each cast (Rings of Fire, Slime): each layer has its own clock, damage and
## side; the bit is on while any layer is left. What the layers do to the body is knobs: a pace factor per layer, swings and shots that
## take longer, a worse aim, a higher resistance, damage over time. It does not decide who may be targeted (SpellTarget) nor draw
## itself (the looks under it listen to `shown_changed`). The server (or solo) runs the layers; `shown` (the bit) is what every peer sees.
## Ref: sacengine ringsOfFire / updateRingsOfFire (state.d:10726-10742, 17687-17704), slime / updateSlime (10744-10764, 17765-17786), 1381-1383, 8950, 9237.

enum Duration { FIXED, BY_LIFE }

## FIXED: the spell's duration in seconds. BY_LIFE: creature_k / max health · duration (a wizard: wizard_factor · duration), like the other
## crowd control (Affliction.cc_ticks).
@export var duration_mode := Duration.FIXED
@export var creature_k := 1000.0
@export var wizard_factor := 0.25
## Layers the body can have at once; a cast over this many does nothing.
@export_range(1, 16) var max_stacks := 1
@export_group("Per layer")
## The body's speed on the ground is this to the power of the layers (a flier is not slowed). 1 = no change.
@export var pace_per_stack := 1.0
## Its swings and shots take this to the power of the layers times as long.
@export var attack_time_per_stack := 1.0
## Its melee accuracy and the evasion it has against a blow are multiplied by this to the power of the layers.
@export var accuracy_per_stack := 1.0
## Added to every resistance for each layer.
@export var resistance_bonus_per_stack := 0.0
@export_group("Damage")
## The damage per second is the spell's `damage` (Rings of Fire: 95).
@export var damage_from_spell := false
@export var damage_kind: StringName = Health.DIRECT_SPELL
## The hit skips the shields of the body.
@export var pierce_shield := false

## Ticks each layer has left, the side that laid it and the damage it does each tick. Server only.
var _left := PackedInt32Array()
var _slots := PackedInt32Array()
var _hits := PackedFloat64Array()


func _ready() -> void:
	set_physics_process(false)


func layers() -> int:
	return _left.size()


## Ticks one layer lasts under `spell` on this body.
func lay_ticks(spell: SpellType) -> int:
	var body := _body()
	if body == null or spell == null:
		return 0
	if duration_mode == Duration.FIXED:
		return ceili(float(MatchClock.TICKS_PER_SECOND) * spell.duration_s)
	var health := _afflictions().health
	return cc_ticks(body.is_in_group(&"wizard"), health.maximum if health else 0.0, spell.duration_s, creature_k, wizard_factor)


## Server (or solo). True when a layer went on.
func lay(spell: SpellType, from_slot: int) -> bool:
	var owner_node := _afflictions()
	var ticks := lay_ticks(spell)
	var dead := owner_node.health != null and owner_node.health.is_dead()
	if ticks <= 0 or dead or not is_multiplayer_authority() or _left.size() >= max_stacks or not owner_node.admit(self):
		return false
	_left.append(ticks)
	_slots.append(from_slot)
	_hits.append((float(spell.damage) if damage_from_spell else 0.0) / MatchClock.TICKS_PER_SECOND_F)
	owner_node.mark(self, true)
	_apply_pace()
	set_physics_process(true)
	return true


## What the layers multiply `stat` by.
func stat_factor(stat: Afflictions.Stat) -> float:
	var per := attack_time_per_stack if stat == Afflictions.Stat.ATTACK_TIME else accuracy_per_stack
	return pow(per, float(_left.size()))


func resistance_bonus() -> float:
	return resistance_bonus_per_stack * float(_left.size())


## Each tick every layer does its damage and counts down; the bit goes with the last one.
func _physics_process(_delta: float) -> void:
	var health := _afflictions().health
	var kept := 0
	for i in _left.size():
		if _hits[i] > 0.0 and health != null:
			health.damage_typed(_hits[i], damage_kind, _slots[i], false, pierce_shield)
			if i >= _left.size():
				return  ## the hit killed the body: Afflictions ended every state and _shown cleared the layers
		_left[i] -= 1
		if _left[i] > 0:
			_left[kept] = _left[i]
			_slots[kept] = _slots[i]
			_hits[kept] = _hits[i]
			kept += 1
	_left.resize(kept)
	_slots.resize(kept)
	_hits.resize(kept)
	_apply_pace()
	if kept == 0:
		set_physics_process(false)
		_afflictions().mark(self, false)


## Every peer, when the bit changes. On the server a bit turned off from outside (the body died) clears the layers.
func _shown(on: bool) -> void:
	if on or not is_multiplayer_authority() or _left.is_empty():
		return
	_left.clear()
	_slots.clear()
	_hits.clear()
	_apply_pace()
	set_physics_process(false)


## PaceFactors is the one owner of the body's speed: this gives it the factor of the layers under the state's name.
func _apply_pace() -> void:
	var pace := PaceFactors.of(_body())
	if pace != null and pace_per_stack != 1.0:
		pace.set_factor(type.id, 1.0 if BodyNudge.airborne(_body()) else pow(pace_per_stack, float(_left.size())))
